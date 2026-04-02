import { LightningElement, api, wire } from "lwc";
import {
  getRecord,
  getFieldValue,
  notifyRecordChange
} from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LOCALE from "@salesforce/i18n/locale";
import CURRENCY from "@salesforce/i18n/currency";
import STATUS_FIELD from "@salesforce/schema/Invoice__c.Status__c";
import getPayments from "@salesforce/apex/PaymentController.getPayments";
import getRemainingBalance from "@salesforce/apex/PaymentController.getRemainingBalance";
import createPayment from "@salesforce/apex/PaymentController.createPayment";

const INVOICE_FIELDS = [STATUS_FIELD];

const COLUMNS = [
  { label: "Payment #", fieldName: "Name", type: "text" },
  { label: "Amount", fieldName: "Amount__c", type: "currency" },
  { label: "Date", fieldName: "Payment_Date__c", type: "date" },
  { label: "Method", fieldName: "Payment_Method__c", type: "text" },
  { label: "Reference", fieldName: "Reference_Number__c", type: "text" }
];

export default class InvoicePayments extends LightningElement {
  @api recordId;

  columns = COLUMNS;
  amount = null;
  paymentDate = null;
  paymentMethod = "";
  referenceNumber = "";
  isSubmitting = false;

  wiredPaymentsResult;
  wiredBalanceResult;

  @wire(getRecord, { recordId: "$recordId", fields: INVOICE_FIELDS })
  invoice;

  @wire(getPayments, { invoiceId: "$recordId" })
  wiredPayments(result) {
    this.wiredPaymentsResult = result;
  }

  @wire(getRemainingBalance, { invoiceId: "$recordId" })
  wiredBalance(result) {
    this.wiredBalanceResult = result;
    if (result.data != null && this.amount === null) {
      this.amount = result.data;
    }
  }

  get invoiceStatus() {
    return this.invoice?.data
      ? getFieldValue(this.invoice.data, STATUS_FIELD)
      : null;
  }

  get isFormDisabled() {
    const status = this.invoiceStatus;
    return status === "Draft" || status === "Cancelled";
  }

  get disabledMessage() {
    return `Payments cannot be recorded against invoices in ${this.invoiceStatus} status.`;
  }

  get payments() {
    return this.wiredPaymentsResult?.data ?? [];
  }

  get hasPayments() {
    return this.payments.length > 0;
  }

  get remainingBalance() {
    return this.wiredBalanceResult?.data ?? 0;
  }

  get formattedBalance() {
    return new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: CURRENCY
    }).format(this.remainingBalance);
  }

  get isLoaded() {
    return this.wiredBalanceResult?.data != null;
  }

  get isFullyPaid() {
    return this.isLoaded && this.remainingBalance <= 0;
  }

  get showForm() {
    return !this.isFormDisabled && !this.isFullyPaid && this.isLoaded;
  }

  get paymentMethodOptions() {
    return [
      { label: "--None--", value: "" },
      { label: "Credit Card", value: "Credit Card" },
      { label: "Bank Transfer", value: "Bank Transfer" },
      { label: "Check", value: "Check" },
      { label: "Cash", value: "Cash" },
      { label: "Other", value: "Other" }
    ];
  }

  get isSubmitDisabled() {
    return this.isSubmitting || !this.amount || !this.paymentDate;
  }

  handleAmountChange(event) {
    this.amount = event.detail.value;
  }

  handleDateChange(event) {
    this.paymentDate = event.detail.value;
  }

  handleMethodChange(event) {
    this.paymentMethod = event.detail.value;
  }

  handleReferenceChange(event) {
    this.referenceNumber = event.detail.value;
  }

  async handleSubmit() {
    this.isSubmitting = true;
    try {
      await createPayment({
        invoiceId: this.recordId,
        amount: this.amount,
        paymentDate: this.paymentDate,
        paymentMethod: this.paymentMethod || null,
        referenceNumber: this.referenceNumber || null
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Payment recorded successfully.",
          variant: "success"
        })
      );

      this.resetForm();
      await Promise.all([
        refreshApex(this.wiredPaymentsResult),
        refreshApex(this.wiredBalanceResult)
      ]);
      notifyRecordChange([{ recordId: this.recordId }]);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Failed to create payment.",
          variant: "error"
        })
      );
    } finally {
      this.isSubmitting = false;
    }
  }

  resetForm() {
    this.amount = null;
    this.paymentDate = null;
    this.paymentMethod = "";
    this.referenceNumber = "";
  }
}
