import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import LOCALE from "@salesforce/i18n/locale";
import CURRENCY from "@salesforce/i18n/currency";
import getAgingBreakdown from "@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown";

const SEVERITY_TO_VARIANT = {
  current: "inverse",
  low: "warning",
  medium: "warning",
  high: "error",
  critical: "error"
};

const SEVERITY_TO_ICON = {
  current: null,
  low: null,
  medium: null,
  high: "utility:warning",
  critical: "utility:warning"
};

export default class AccountInvoiceAgingBreakdown extends NavigationMixin(
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

  get isEmpty() {
    return this.hasData && (this.breakdown.data.totalUnpaidCount ?? 0) === 0;
  }

  get showBuckets() {
    return this.hasData && !this.isEmpty;
  }

  get buckets() {
    const data = this.breakdown?.data;
    if (!data?.buckets) {
      return [];
    }
    return data.buckets.map((bucket) => this.decorateBucket(bucket));
  }

  decorateBucket(bucket) {
    const count = bucket.count ?? 0;
    const totalAmount = bucket.totalAmount ?? 0;
    const formattedAmount = this.formatCurrency(totalAmount);
    const countLabel = count === 1 ? "1 invoice" : `${count} invoices`;
    return {
      label: bucket.label,
      severity: bucket.severity,
      count,
      totalAmount,
      formattedAmount,
      countLabel,
      badgeVariant: SEVERITY_TO_VARIANT[bucket.severity] ?? "inverse",
      iconName: SEVERITY_TO_ICON[bucket.severity] ?? null,
      hasIcon: !!SEVERITY_TO_ICON[bucket.severity],
      cssClass: `tile severity-${bucket.severity}`,
      ariaLabel: `${bucket.label}: ${countLabel} totaling ${formattedAmount}. Open related invoices.`
    };
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat(LOCALE, {
      style: "currency",
      currency: CURRENCY
    }).format(amount ?? 0);
  }

  handleBucketClick() {
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
