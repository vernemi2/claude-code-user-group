import { createElement } from "lwc";
import InvoiceLifecycleTracker from "c/invoiceLifecycleTracker";
import { getRecord } from "lightning/uiRecordApi";
import { flushPromises } from "c/testUtils";

function buildRecord({ status } = {}) {
  return {
    apiName: "Invoice__c",
    fields: {
      Status__c: { value: status }
    }
  };
}

describe("c-invoice-lifecycle-tracker", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-invoice-lifecycle-tracker", {
      is: InvoiceLifecycleTracker
    });
    element.recordId = "a01000000000001";
    document.body.appendChild(element);
    return element;
  }

  function getTracker(element) {
    return element.shadowRoot.querySelector('div[role="group"]');
  }

  function getSkeleton(element) {
    return element.shadowRoot.querySelector(".lifecycle-tracker_skeleton");
  }

  function getStepElements(element) {
    return element.shadowRoot.querySelectorAll("span[data-step]");
  }

  function getConnectorElements(element) {
    return element.shadowRoot.querySelectorAll("span[data-connector]");
  }

  function getCancelledOverlay(element) {
    return element.shadowRoot.querySelector(".lifecycle-cancelled-overlay");
  }

  describe("loading state", () => {
    it("renders a skeleton placeholder while the wire is loading", () => {
      const element = createComponent();

      const skeleton = getSkeleton(element);
      expect(skeleton).not.toBeNull();
      expect(skeleton.getAttribute("aria-hidden")).toBe("true");
      expect(skeleton.querySelectorAll(".lifecycle-step_skeleton").length).toBe(
        3
      );
      expect(
        skeleton.querySelectorAll(".lifecycle-connector_skeleton").length
      ).toBe(2);
      expect(getTracker(element)).toBeNull();
    });
  });

  describe("error state", () => {
    it("renders nothing when the wire emits an error", async () => {
      const element = createComponent();

      getRecord.error();
      await flushPromises();

      expect(getSkeleton(element)).toBeNull();
      expect(getTracker(element)).toBeNull();
      expect(getStepElements(element).length).toBe(0);
    });
  });

  describe("status branches", () => {
    it("renders Draft: step 1 current, steps 2 and 3 upcoming", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Draft" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps.length).toBe(3);
      expect(steps[0].classList.contains("lifecycle-step_current")).toBe(true);
      expect(steps[0].getAttribute("aria-current")).toBe("step");
      expect(steps[1].classList.contains("lifecycle-step_upcoming")).toBe(true);
      expect(steps[1].getAttribute("aria-current")).toBeNull();
      expect(steps[2].classList.contains("lifecycle-step_upcoming")).toBe(true);
      expect(steps[2].getAttribute("aria-current")).toBeNull();

      const connectors = getConnectorElements(element);
      expect(
        connectors[0].classList.contains("lifecycle-connector_upcoming")
      ).toBe(true);
      expect(
        connectors[1].classList.contains("lifecycle-connector_upcoming")
      ).toBe(true);
    });

    it("renders Sent: step 1 completed, step 2 current, step 3 upcoming", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Sent" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps[0].classList.contains("lifecycle-step_completed")).toBe(
        true
      );
      expect(steps[0].getAttribute("aria-current")).toBeNull();
      expect(steps[1].classList.contains("lifecycle-step_current")).toBe(true);
      expect(steps[1].getAttribute("aria-current")).toBe("step");
      expect(steps[2].classList.contains("lifecycle-step_upcoming")).toBe(true);

      const connectors = getConnectorElements(element);
      expect(
        connectors[0].classList.contains("lifecycle-connector_completed")
      ).toBe(true);
      expect(
        connectors[1].classList.contains("lifecycle-connector_upcoming")
      ).toBe(true);
    });

    it("renders Paid: all completed, step 3 marked as current", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Paid" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps[0].classList.contains("lifecycle-step_completed")).toBe(
        true
      );
      expect(steps[1].classList.contains("lifecycle-step_completed")).toBe(
        true
      );
      expect(steps[2].classList.contains("lifecycle-step_current")).toBe(true);
      expect(steps[2].getAttribute("aria-current")).toBe("step");

      const connectors = getConnectorElements(element);
      expect(
        connectors[0].classList.contains("lifecycle-connector_completed")
      ).toBe(true);
      expect(
        connectors[1].classList.contains("lifecycle-connector_completed")
      ).toBe(true);
    });

    it("renders Overdue: step 2 current-error variant", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Overdue" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps[0].classList.contains("lifecycle-step_completed")).toBe(
        true
      );
      expect(steps[1].classList.contains("lifecycle-step_current-error")).toBe(
        true
      );
      expect(steps[1].getAttribute("aria-current")).toBe("step");
      expect(steps[2].classList.contains("lifecycle-step_upcoming")).toBe(true);
    });

    it("renders Cancelled: all muted, no aria-current, overlay rendered", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Cancelled" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps.length).toBe(3);
      steps.forEach((step) => {
        expect(step.classList.contains("lifecycle-step_muted")).toBe(true);
        expect(step.getAttribute("aria-current")).toBeNull();
      });

      const connectors = getConnectorElements(element);
      connectors.forEach((connector) => {
        expect(connector.classList.contains("lifecycle-connector_muted")).toBe(
          true
        );
      });

      const overlay = getCancelledOverlay(element);
      expect(overlay).not.toBeNull();
      expect(overlay.getAttribute("aria-label")).toBe("Cancelled");
    });
  });

  describe("unknown status fallback", () => {
    it("treats null status as Draft", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: null }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps[0].classList.contains("lifecycle-step_current")).toBe(true);
      expect(steps[0].getAttribute("aria-current")).toBe("step");
      expect(steps[1].classList.contains("lifecycle-step_upcoming")).toBe(true);
      expect(steps[2].classList.contains("lifecycle-step_upcoming")).toBe(true);
      expect(getCancelledOverlay(element)).toBeNull();
    });

    it("treats an unrecognized status as Draft", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Unexpected" }));
      await flushPromises();

      const steps = getStepElements(element);
      expect(steps[0].classList.contains("lifecycle-step_current")).toBe(true);
      expect(steps[0].getAttribute("aria-current")).toBe("step");
      expect(steps[1].classList.contains("lifecycle-step_upcoming")).toBe(true);
      expect(steps[2].classList.contains("lifecycle-step_upcoming")).toBe(true);
    });
  });

  describe("accessibility", () => {
    it("exposes role=group with a descriptive aria-label for Draft", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Draft" }));
      await flushPromises();

      const tracker = getTracker(element);
      expect(tracker).not.toBeNull();
      expect(tracker.getAttribute("aria-label")).toBe(
        "Invoice lifecycle: Draft. Step 1 of 3."
      );
    });

    it("exposes aria-label reflecting the Sent step", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Sent" }));
      await flushPromises();

      expect(getTracker(element).getAttribute("aria-label")).toBe(
        "Invoice lifecycle: Sent. Step 2 of 3."
      );
    });

    it("exposes aria-label reflecting the Paid step", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Paid" }));
      await flushPromises();

      expect(getTracker(element).getAttribute("aria-label")).toBe(
        "Invoice lifecycle: Paid. Step 3 of 3."
      );
    });

    it("calls out the overdue state in aria-label when status is Overdue", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Overdue" }));
      await flushPromises();

      expect(getTracker(element).getAttribute("aria-label")).toBe(
        "Invoice lifecycle: Sent (overdue). Step 2 of 3."
      );
    });

    it("uses a halted-lifecycle aria-label when status is Cancelled", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ status: "Cancelled" }));
      await flushPromises();

      const tracker = getTracker(element);
      expect(tracker.getAttribute("aria-label")).toBe(
        "Invoice cancelled. Lifecycle halted."
      );
      const currentStep = tracker.querySelector('[aria-current="step"]');
      expect(currentStep).toBeNull();
    });
  });
});
