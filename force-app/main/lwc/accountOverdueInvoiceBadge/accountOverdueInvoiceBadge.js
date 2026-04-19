import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import LOCALE from "@salesforce/i18n/locale";
import CURRENCY from "@salesforce/i18n/currency";
import getOverdueInvoiceSummary from "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary";

export default class AccountOverdueInvoiceBadge extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  @wire(getOverdueInvoiceSummary, { accountId: "$recordId" })
  invoiceSummary;

  get isLoading() {
    return !this.invoiceSummary?.data && !this.invoiceSummary?.error;
  }

  get hasError() {
    return !!this.invoiceSummary?.error;
  }

  get hasOverdue() {
    return this.overdueCount > 0;
  }

  get overdueCount() {
    return this.invoiceSummary?.data?.overdueCount ?? 0;
  }

  get totalAmount() {
    return this.invoiceSummary?.data?.totalOverdueAmount ?? 0;
  }

  get formattedAmount() {
    return new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: CURRENCY
    }).format(this.totalAmount);
  }

  get invoiceWord() {
    return this.overdueCount === 1 ? "invoice" : "invoices";
  }

  get badgeLabel() {
    return `${this.overdueCount} overdue \u00B7 ${this.formattedAmount} at risk`;
  }

  get ariaLabel() {
    if (this.isLoading) {
      return "Checking overdue invoices";
    }
    if (this.hasError) {
      return "Overdue invoice status unavailable";
    }
    if (this.hasOverdue) {
      return `${this.overdueCount} overdue ${this.invoiceWord} totaling ${this.formattedAmount}. Open related invoices.`;
    }
    return "No overdue invoices. Open related invoices.";
  }

  handleNavigate() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordRelationshipPage",
      attributes: {
        recordId: this.recordId,
        objectApiName: "Account",
        relationshipApiName: "Invoices__r",
        actionName: "view"
      }
    });
  }
}
