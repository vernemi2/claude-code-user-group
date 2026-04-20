import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import DUE_DATE_FIELD from "@salesforce/schema/Invoice__c.Due_Date__c";
import STATUS_FIELD from "@salesforce/schema/Invoice__c.Status__c";

const AMBER_THRESHOLD_DAYS = 7;
const MS_PER_DAY = 86_400_000;
const TERMINAL_STATUSES = new Set(["Paid", "Cancelled"]);

export default class InvoiceDueChip extends LightningElement {
  @api recordId;

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [DUE_DATE_FIELD, STATUS_FIELD]
  })
  invoice;

  get isLoading() {
    return !this.invoice?.data && !this.invoice?.error;
  }

  get hasError() {
    return !!this.invoice?.error;
  }

  get dueDate() {
    return this.invoice?.data
      ? getFieldValue(this.invoice.data, DUE_DATE_FIELD)
      : null;
  }

  get status() {
    return this.invoice?.data
      ? getFieldValue(this.invoice.data, STATUS_FIELD)
      : null;
  }

  get isTerminalStatus() {
    return TERMINAL_STATUSES.has(this.status);
  }

  get isVisible() {
    if (this.isLoading || this.hasError) {
      return false;
    }
    if (!this.dueDate) {
      return false;
    }
    if (this.isTerminalStatus) {
      return false;
    }
    return true;
  }

  get daysUntilDue() {
    if (!this.dueDate) {
      return null;
    }
    const now = new Date();
    const todayUtc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
    const [year, month, day] = this.dueDate.split("-").map(Number);
    const dueUtc = Date.UTC(year, month - 1, day);
    return Math.round((dueUtc - todayUtc) / MS_PER_DAY);
  }

  get isOverdue() {
    return this.daysUntilDue !== null && this.daysUntilDue < 0;
  }

  get isDueToday() {
    return this.daysUntilDue === 0;
  }

  get isDueSoon() {
    const days = this.daysUntilDue;
    return days !== null && days >= 1 && days <= AMBER_THRESHOLD_DAYS;
  }

  get chipVariant() {
    if (this.isOverdue) {
      return "error";
    }
    if (this.isDueToday || this.isDueSoon) {
      return "warning";
    }
    return "success";
  }

  get badgeClass() {
    return `invoice-due-chip invoice-due-chip_${this.chipVariant}`;
  }

  get chipLabel() {
    const days = this.daysUntilDue;
    if (this.isOverdue) {
      const overdueBy = Math.abs(days);
      return `${overdueBy} ${overdueBy === 1 ? "day" : "days"} overdue`;
    }
    if (this.isDueToday) {
      return "Due today";
    }
    return `Due in ${days} ${days === 1 ? "day" : "days"}`;
  }

  get ariaLabel() {
    const days = this.daysUntilDue;
    if (this.isOverdue) {
      const overdueBy = Math.abs(days);
      return `Invoice is ${overdueBy} ${overdueBy === 1 ? "day" : "days"} overdue`;
    }
    if (this.isDueToday) {
      return "Invoice is due today";
    }
    return `Invoice is due in ${days} ${days === 1 ? "day" : "days"}`;
  }
}
