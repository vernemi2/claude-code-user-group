import { createElement } from "lwc";
import AccountOutstandingBalanceTile from "c/accountOutstandingBalanceTile";
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

describe("c-account-outstanding-balance-tile", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-account-outstanding-balance-tile", {
      is: AccountOutstandingBalanceTile
    });
    element.recordId = "001000000000001";
    document.body.appendChild(element);
    return element;
  }

  it("renders a spinner while loading before the wire emits", () => {
    const element = createComponent();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
    expect(spinner.alternativeText).toBe("Loading outstanding balance");
    expect(element.shadowRoot.querySelector("button.tile")).toBeNull();
  });

  it("renders an error badge when the wire emits an error", async () => {
    const element = createComponent();

    getAgingBreakdown.error();
    await flushPromises();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("Outstanding balance unavailable");
    expect(badge.iconName).toBe("utility:warning");
    expect(element.shadowRoot.querySelector("button.tile")).toBeNull();
  });

  it("renders the populated tile with formatted amount and plural count", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: [],
      totalUnpaidCount: 3,
      totalUnpaidAmount: 4250
    });
    await flushPromises();

    const tile = element.shadowRoot.querySelector("button.tile");
    expect(tile).not.toBeNull();

    const amount = tile.querySelector(".tile-amount").textContent.trim();
    expect(amount).toContain("4,250");
    expect(amount).not.toBe("4250");

    const count = tile.querySelector(".tile-count").textContent.trim();
    expect(count).toBe("3 open invoices");
  });

  it("renders the singular count when there is exactly one open invoice", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: [],
      totalUnpaidCount: 1,
      totalUnpaidAmount: 100
    });
    await flushPromises();

    const tile = element.shadowRoot.querySelector("button.tile");
    expect(tile).not.toBeNull();
    const count = tile.querySelector(".tile-count").textContent.trim();
    expect(count).toBe("1 open invoice");
  });

  it("renders the zero state with a clickable tile when there are no open invoices", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: [],
      totalUnpaidCount: 0,
      totalUnpaidAmount: 0
    });
    await flushPromises();

    const tile = element.shadowRoot.querySelector("button.tile");
    expect(tile).not.toBeNull();

    const amount = tile.querySelector(".tile-amount").textContent.trim();
    expect(amount).toContain("0");

    const count = tile.querySelector(".tile-count").textContent.trim();
    expect(count).toBe("No open invoices");

    tile.click();
    await flushPromises();
    expect(mockNavigate).toHaveBeenCalledTimes(1);
  });

  it("navigates to the Account Invoices related list when the tile is clicked", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: [],
      totalUnpaidCount: 3,
      totalUnpaidAmount: 4250
    });
    await flushPromises();

    const tile = element.shadowRoot.querySelector("button.tile");
    tile.click();
    await flushPromises();

    expect(mockNavigate).toHaveBeenCalledTimes(1);
    const pageRef = mockNavigate.mock.calls[0][0];
    expect(pageRef.type).toBe("standard__recordRelationshipPage");
    expect(pageRef.attributes.objectApiName).toBe("Account");
    expect(pageRef.attributes.relationshipApiName).toBe("Invoices__r");
    expect(pageRef.attributes.actionName).toBe("view");
    expect(pageRef.attributes.recordId).toBe("001000000000001");
  });

  it("exposes a non-empty aria-label on the populated tile for accessibility", async () => {
    const element = createComponent();

    getAgingBreakdown.emit({
      buckets: [],
      totalUnpaidCount: 3,
      totalUnpaidAmount: 4250
    });
    await flushPromises();

    const tile = element.shadowRoot.querySelector("button.tile");
    const ariaLabel = tile.getAttribute("aria-label");
    expect(ariaLabel).toBeTruthy();
    expect(ariaLabel.length).toBeGreaterThan(0);
  });
});
