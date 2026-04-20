import { createElement } from "lwc";
import InvoiceDueChip from "c/invoiceDueChip";
import { getRecord } from "lightning/uiRecordApi";
import { flushPromises } from "c/testUtils";

const FIXED_TODAY = new Date(2026, 3, 20);

function buildRecord({ dueDate = null, status = "Open" } = {}) {
  return {
    apiName: "Invoice__c",
    fields: {
      Due_Date__c: { value: dueDate },
      Status__c: { value: status }
    }
  };
}

function addDays(baseDate, days) {
  const copy = new Date(baseDate.getTime());
  copy.setDate(copy.getDate() + days);
  const yyyy = copy.getFullYear();
  const mm = String(copy.getMonth() + 1).padStart(2, "0");
  const dd = String(copy.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

describe("c-invoice-due-chip", () => {
  let originalDateNow;
  let OriginalDate;

  beforeEach(() => {
    OriginalDate = global.Date;
    originalDateNow = Date.now;
    const fixedTime = FIXED_TODAY.getTime();
    class MockDate extends OriginalDate {
      constructor(...args) {
        if (args.length === 0) {
          super(fixedTime);
        } else {
          super(...args);
        }
      }
      static now() {
        return fixedTime;
      }
    }
    MockDate.UTC = OriginalDate.UTC;
    MockDate.parse = OriginalDate.parse;
    global.Date = MockDate;
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    global.Date = OriginalDate;
    Date.now = originalDateNow;
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-invoice-due-chip", {
      is: InvoiceDueChip
    });
    element.recordId = "a01000000000001";
    document.body.appendChild(element);
    return element;
  }

  function getBadge(element) {
    return element.shadowRoot.querySelector("lightning-badge");
  }

  function getStatusSpan(element) {
    return element.shadowRoot.querySelector('span[role="status"]');
  }

  describe("hidden states", () => {
    it("renders nothing while the wire is loading", () => {
      const element = createComponent();
      expect(getBadge(element)).toBeNull();
      expect(getStatusSpan(element)).toBeNull();
    });

    it("renders nothing when the wire emits an error", async () => {
      const element = createComponent();

      getRecord.error();
      await flushPromises();

      expect(getBadge(element)).toBeNull();
      expect(getStatusSpan(element)).toBeNull();
    });

    it("renders nothing when the due date is null", async () => {
      const element = createComponent();

      getRecord.emit(buildRecord({ dueDate: null, status: "Open" }));
      await flushPromises();

      expect(getBadge(element)).toBeNull();
    });

    it("renders nothing when status is Paid", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -3), status: "Paid" })
      );
      await flushPromises();

      expect(getBadge(element)).toBeNull();
    });

    it("renders nothing when status is Cancelled", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 2), status: "Cancelled" })
      );
      await flushPromises();

      expect(getBadge(element)).toBeNull();
    });
  });

  describe("variant boundaries", () => {
    it("renders error variant when overdue by one day", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -1), status: "Open" })
      );
      await flushPromises();

      const badge = getBadge(element);
      expect(badge).not.toBeNull();
      expect(badge.variant).toBe("error");
      expect(badge.label).toBe("1 day overdue");
    });

    it("renders warning variant when due today (0 days)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 0), status: "Open" })
      );
      await flushPromises();

      const badge = getBadge(element);
      expect(badge.variant).toBe("warning");
      expect(badge.label).toBe("Due today");
    });

    it("renders warning variant when due in 1 day (lower amber boundary)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 1), status: "Open" })
      );
      await flushPromises();

      const badge = getBadge(element);
      expect(badge.variant).toBe("warning");
      expect(badge.label).toBe("Due in 1 day");
    });

    it("renders warning variant when due in 7 days (upper amber boundary)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 7), status: "Open" })
      );
      await flushPromises();

      const badge = getBadge(element);
      expect(badge.variant).toBe("warning");
      expect(badge.label).toBe("Due in 7 days");
    });

    it("renders success variant when due in 8 days (just past amber threshold)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 8), status: "Open" })
      );
      await flushPromises();

      const badge = getBadge(element);
      expect(badge.variant).toBe("success");
      expect(badge.label).toBe("Due in 8 days");
    });
  });

  describe("pluralization", () => {
    it("uses singular 'day' when exactly one day overdue", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -1), status: "Open" })
      );
      await flushPromises();

      expect(getBadge(element).label).toBe("1 day overdue");
    });

    it("uses plural 'days' when more than one day overdue", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -5), status: "Open" })
      );
      await flushPromises();

      expect(getBadge(element).label).toBe("5 days overdue");
    });

    it("uses singular 'day' when due in exactly one day", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 1), status: "Open" })
      );
      await flushPromises();

      expect(getBadge(element).label).toBe("Due in 1 day");
    });

    it("uses plural 'days' when due in more than one day", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 4), status: "Open" })
      );
      await flushPromises();

      expect(getBadge(element).label).toBe("Due in 4 days");
    });
  });

  describe("accessibility", () => {
    it("exposes a role=status container with an aria-label describing the overdue state", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -1), status: "Open" })
      );
      await flushPromises();

      const statusSpan = getStatusSpan(element);
      expect(statusSpan).not.toBeNull();
      expect(statusSpan.getAttribute("aria-label")).toBe(
        "Invoice is 1 day overdue"
      );
    });

    it("uses 'due today' wording in aria-label when due today", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 0), status: "Open" })
      );
      await flushPromises();

      expect(getStatusSpan(element).getAttribute("aria-label")).toBe(
        "Invoice is due today"
      );
    });

    it("uses 'due in N days' wording in aria-label when due soon (plural)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 3), status: "Open" })
      );
      await flushPromises();

      expect(getStatusSpan(element).getAttribute("aria-label")).toBe(
        "Invoice is due in 3 days"
      );
    });

    it("uses 'due in 1 day' wording in aria-label when due in exactly one day (singular)", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, 1), status: "Open" })
      );
      await flushPromises();

      expect(getStatusSpan(element).getAttribute("aria-label")).toBe(
        "Invoice is due in 1 day"
      );
    });

    it("uses plural 'days overdue' wording in aria-label when multiple days overdue", async () => {
      const element = createComponent();

      getRecord.emit(
        buildRecord({ dueDate: addDays(FIXED_TODAY, -10), status: "Open" })
      );
      await flushPromises();

      expect(getStatusSpan(element).getAttribute("aria-label")).toBe(
        "Invoice is 10 days overdue"
      );
    });
  });
});
