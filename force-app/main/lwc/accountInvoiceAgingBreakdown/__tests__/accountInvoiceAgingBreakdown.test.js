import { createElement } from "lwc";
import AccountInvoiceAgingBreakdown from "c/accountInvoiceAgingBreakdown";
import getAgingBreakdown from "@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown";
import { flushPromises } from "c/testUtils";

const mockNavigate = jest.fn();

jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const GenerateUrl = Symbol("GenerateUrl");
  const mixin = (Base) =>
    class extends Base {
      [Navigate](...args) {
        mockNavigate(...args);
      }
      [GenerateUrl]() {
        return Promise.resolve("https://example.com");
      }
    };
  mixin.Navigate = Navigate;
  mixin.GenerateUrl = GenerateUrl;
  return {
    NavigationMixin: mixin,
    CurrentPageReference: jest.fn()
  };
});

jest.mock(
  "@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const BUCKETS_FIXTURE = [
  { label: "Current", severity: "current", count: 2, totalAmount: 500 },
  { label: "1-30 days", severity: "low", count: 1, totalAmount: 250 },
  { label: "31-60 days", severity: "medium", count: 0, totalAmount: 0 },
  { label: "61-90 days", severity: "high", count: 1, totalAmount: 1000 },
  { label: "90+ days", severity: "critical", count: 3, totalAmount: 3200 }
];

describe("c-account-invoice-aging-breakdown", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-account-invoice-aging-breakdown", {
      is: AccountInvoiceAgingBreakdown
    });
    element.recordId = "001000000000001";
    document.body.appendChild(element);
    return element;
  }

  it("renders a spinner while loading before the wire emits", () => {
    const element = createComponent();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll("button.tile").length).toBe(0);
  });

  it("renders five bucket tiles when data emits with unpaid invoices", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: BUCKETS_FIXTURE,
      totalUnpaidCount: 7,
      totalUnpaidAmount: 4950
    });
    await flushPromises();

    const tiles = element.shadowRoot.querySelectorAll("button.tile");
    expect(tiles.length).toBe(5);
    expect(tiles[0].dataset.bucketLabel).toBe("Current");
    expect(tiles[4].dataset.bucketLabel).toBe("90+ days");
  });

  it("renders the empty state when totalUnpaidCount is zero", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: BUCKETS_FIXTURE.map((b) => ({
        ...b,
        count: 0,
        totalAmount: 0
      })),
      totalUnpaidCount: 0,
      totalUnpaidAmount: 0
    });
    await flushPromises();

    const emptyRow = element.shadowRoot.querySelector(".empty-row");
    expect(emptyRow).not.toBeNull();
    expect(emptyRow.textContent).toContain("No outstanding invoices");
    expect(element.shadowRoot.querySelectorAll("button.tile").length).toBe(0);
  });

  it("renders an error badge when the wire emits an error", async () => {
    const element = createComponent();

    getAgingBreakdown.error();
    await flushPromises();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("Aging breakdown unavailable");
    expect(badge.iconName).toBe("utility:warning");
    expect(element.shadowRoot.querySelectorAll("button.tile").length).toBe(0);
  });

  it("formats bucket amounts as currency and shows count labels", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: BUCKETS_FIXTURE,
      totalUnpaidCount: 7,
      totalUnpaidAmount: 4950
    });
    await flushPromises();

    const tiles = element.shadowRoot.querySelectorAll("button.tile");
    const currentAmount = tiles[0]
      .querySelector(".tile-amount")
      .textContent.trim();
    expect(currentAmount).toContain("500");
    // currency symbol will vary by locale, but it should not be a raw number
    expect(currentAmount).not.toBe("500");

    const singularCount = tiles[1].querySelector(".tile-count").textContent;
    expect(singularCount.trim()).toBe("1 invoice");

    const pluralCount = tiles[0].querySelector(".tile-count").textContent;
    expect(pluralCount.trim()).toBe("2 invoices");

    const zeroCount = tiles[2].querySelector(".tile-count").textContent;
    expect(zeroCount.trim()).toBe("0 invoices");
  });

  it("navigates to the Account Invoices related list when a tile is clicked", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: BUCKETS_FIXTURE,
      totalUnpaidCount: 7,
      totalUnpaidAmount: 4950
    });
    await flushPromises();

    const tiles = element.shadowRoot.querySelectorAll("button.tile");
    tiles[4].click();
    await flushPromises();

    expect(mockNavigate).toHaveBeenCalledTimes(1);
    const pageRef = mockNavigate.mock.calls[0][0];
    expect(pageRef.type).toBe("standard__recordRelationshipPage");
    expect(pageRef.attributes.relationshipApiName).toBe("Invoices__r");
    expect(pageRef.attributes.objectApiName).toBe("Account");
    expect(pageRef.attributes.recordId).toBe("001000000000001");
    expect(pageRef.attributes.actionName).toBe("view");
  });

  it("exposes accessible aria-labels on every tile", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: BUCKETS_FIXTURE,
      totalUnpaidCount: 7,
      totalUnpaidAmount: 4950
    });
    await flushPromises();

    const tiles = element.shadowRoot.querySelectorAll("button.tile");
    tiles.forEach((tile) => {
      const ariaLabel = tile.getAttribute("aria-label");
      expect(ariaLabel).toBeTruthy();
      expect(ariaLabel.length).toBeGreaterThan(0);
    });
  });
});
