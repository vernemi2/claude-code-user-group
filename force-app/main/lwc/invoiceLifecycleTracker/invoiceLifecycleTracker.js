import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import STATUS_FIELD from "@salesforce/schema/Invoice__c.Status__c";

const STATUS_DRAFT = "Draft";
const STATUS_SENT = "Sent";
const STATUS_PAID = "Paid";
const STATUS_OVERDUE = "Overdue";
const STATUS_CANCELLED = "Cancelled";

const KNOWN_STATUSES = new Set([
  STATUS_DRAFT,
  STATUS_SENT,
  STATUS_PAID,
  STATUS_OVERDUE,
  STATUS_CANCELLED
]);

const STEP_DEFINITIONS = [
  { key: "draft", label: "Draft" },
  { key: "sent", label: "Sent" },
  { key: "paid", label: "Paid" }
];

const STATE_COMPLETED = "completed";
const STATE_CURRENT = "current";
const STATE_CURRENT_ERROR = "current-error";
const STATE_UPCOMING = "upcoming";
const STATE_MUTED = "muted";

const BASE_STEP_CLASS = "lifecycle-step";
const BASE_CONNECTOR_CLASS = "lifecycle-connector";

export default class InvoiceLifecycleTracker extends LightningElement {
  @api recordId;

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [STATUS_FIELD]
  })
  invoice;

  get isLoading() {
    return !this.invoice?.data && !this.invoice?.error;
  }

  get hasError() {
    return !!this.invoice?.error;
  }

  get status() {
    return this.invoice?.data
      ? getFieldValue(this.invoice.data, STATUS_FIELD)
      : null;
  }

  get effectiveStatus() {
    return KNOWN_STATUSES.has(this.status) ? this.status : STATUS_DRAFT;
  }

  get isCancelled() {
    return this.effectiveStatus === STATUS_CANCELLED;
  }

  get showCancelledOverlay() {
    return this.isCancelled;
  }

  get stepStates() {
    switch (this.effectiveStatus) {
      case STATUS_SENT:
        return [STATE_COMPLETED, STATE_CURRENT, STATE_UPCOMING];
      case STATUS_PAID:
        return [STATE_COMPLETED, STATE_COMPLETED, STATE_CURRENT];
      case STATUS_OVERDUE:
        return [STATE_COMPLETED, STATE_CURRENT_ERROR, STATE_UPCOMING];
      case STATUS_CANCELLED:
        return [STATE_MUTED, STATE_MUTED, STATE_MUTED];
      case STATUS_DRAFT:
      default:
        return [STATE_CURRENT, STATE_UPCOMING, STATE_UPCOMING];
    }
  }

  get steps() {
    const states = this.stepStates;
    return STEP_DEFINITIONS.map((step, index) => {
      const state = states[index];
      const isCurrent =
        !this.isCancelled &&
        (state === STATE_CURRENT || state === STATE_CURRENT_ERROR);
      return {
        key: step.key,
        label: step.label,
        position: index + 1,
        classes: `${BASE_STEP_CLASS} ${BASE_STEP_CLASS}_${state}`,
        ariaCurrent: isCurrent ? "step" : undefined,
        srLabel: `${step.label}: ${this.describeState(state)}`
      };
    });
  }

  get connectors() {
    const states = this.stepStates;
    return [0, 1].map((index) => {
      const left = states[index];
      const right = states[index + 1];
      let connectorState;
      if (left === STATE_MUTED || right === STATE_MUTED) {
        connectorState = STATE_MUTED;
      } else if (left === STATE_COMPLETED) {
        connectorState = STATE_COMPLETED;
      } else {
        connectorState = STATE_UPCOMING;
      }
      return {
        key: `connector-${index}`,
        classes: `${BASE_CONNECTOR_CLASS} ${BASE_CONNECTOR_CLASS}_${connectorState}`
      };
    });
  }

  get groupAriaLabel() {
    if (this.isCancelled) {
      return "Invoice cancelled. Lifecycle halted.";
    }
    const currentIndex = this.stepStates.findIndex(
      (state) => state === STATE_CURRENT || state === STATE_CURRENT_ERROR
    );
    const currentStep = STEP_DEFINITIONS[currentIndex];
    const label = currentStep ? currentStep.label : STATUS_DRAFT;
    const position = currentIndex >= 0 ? currentIndex + 1 : 1;
    if (this.effectiveStatus === STATUS_OVERDUE) {
      return `Invoice lifecycle: Sent (overdue). Step ${position} of 3.`;
    }
    return `Invoice lifecycle: ${label}. Step ${position} of 3.`;
  }

  describeState(state) {
    switch (state) {
      case STATE_COMPLETED:
        return "completed";
      case STATE_CURRENT:
        return "current step";
      case STATE_CURRENT_ERROR:
        return "current step, overdue";
      case STATE_MUTED:
        return "cancelled";
      case STATE_UPCOMING:
      default:
        return "upcoming";
    }
  }
}
