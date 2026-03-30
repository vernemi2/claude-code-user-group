import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import LOCALE from "@salesforce/i18n/locale";
import CURRENCY from "@salesforce/i18n/currency";
import ACCOUNT_FIELD from "@salesforce/schema/Opportunity.AccountId";
import getOverdueInvoiceSummary from "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary";

const OPPORTUNITY_FIELDS = [ACCOUNT_FIELD];

export default class OverdueInvoiceBanner extends LightningElement {
  @api recordId;

  @wire(getRecord, { recordId: "$recordId", fields: OPPORTUNITY_FIELDS })
  opportunity;

  @wire(getOverdueInvoiceSummary, { accountId: "$accountId" })
  invoiceSummary;

  get accountId() {
    return this.opportunity?.data
      ? getFieldValue(this.opportunity.data, ACCOUNT_FIELD)
      : undefined;
  }

  get hasOverdueInvoices() {
    return this.invoiceSummary?.data?.overdueCount > 0;
  }

  get overdueCount() {
    return this.invoiceSummary?.data?.overdueCount ?? 0;
  }

  get formattedAmount() {
    const amount = this.invoiceSummary?.data?.totalOverdueAmount ?? 0;
    return new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: CURRENCY
    }).format(amount);
  }

  get bannerMessage() {
    const count = this.overdueCount;
    const invoiceWord = count === 1 ? "invoice" : "invoices";
    return `This Account has ${count} overdue ${invoiceWord} totaling ${this.formattedAmount}`;
  }
}
