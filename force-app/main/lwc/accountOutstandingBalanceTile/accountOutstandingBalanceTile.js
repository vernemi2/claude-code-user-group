import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import LOCALE from "@salesforce/i18n/locale";
import CURRENCY from "@salesforce/i18n/currency";
import getAgingBreakdown from "@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown";

export default class AccountOutstandingBalanceTile extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  @wire(getAgingBreakdown, { accountId: "$recordId" })
  breakdown;

  get isLoading() {
    return !this.breakdown?.data && !this.breakdown?.error;
  }

  get hasError() {
    return !!this.breakdown?.error;
  }

  get hasData() {
    return !!this.breakdown?.data;
  }

  get totalAmount() {
    return this.breakdown?.data?.totalUnpaidAmount ?? 0;
  }

  get openCount() {
    return this.breakdown?.data?.totalUnpaidCount ?? 0;
  }

  get formattedAmount() {
    return new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: CURRENCY
    }).format(this.totalAmount);
  }

  get countLabel() {
    const count = this.openCount;
    if (count === 0) {
      return "No open invoices";
    }
    if (count === 1) {
      return "1 open invoice";
    }
    return `${count} open invoices`;
  }

  get ariaLabel() {
    if (this.isLoading) {
      return "Loading outstanding balance";
    }
    if (this.hasError) {
      return "Outstanding balance unavailable";
    }
    return `Outstanding balance ${this.formattedAmount} across ${this.countLabel}. Open related invoices.`;
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
