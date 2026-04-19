import { createElement } from "lwc";
import AccountOverdueInvoiceBadge from "c/accountOverdueInvoiceBadge";
import getOverdueInvoiceSummary from "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary";
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
  "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

describe("c-account-overdue-invoice-badge", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-account-overdue-invoice-badge", {
      is: AccountOverdueInvoiceBadge
    });
    element.recordId = "001000000000001";
    document.body.appendChild(element);
    return element;
  }

  function getBadge(element) {
    return element.shadowRoot.querySelector("lightning-badge");
  }

  it("renders the loading badge before the wire emits", () => {
    const element = createComponent();

    const badge = getBadge(element);
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("Checking invoices…");
    expect(badge.iconName).toBeFalsy();
  });

  it("renders neutral 'No overdue invoices' badge when count is zero", async () => {
    const element = createComponent();

    getOverdueInvoiceSummary.emit({
      overdueCount: 0,
      totalOverdueAmount: 0
    });
    await flushPromises();

    const badge = getBadge(element);
    expect(badge.label).toBe("No overdue invoices");
    expect(badge.iconName).toBeFalsy();
  });

  it("renders warning badge with plural wording and formatted amount for multiple overdue", async () => {
    const element = createComponent();

    getOverdueInvoiceSummary.emit({
      overdueCount: 3,
      totalOverdueAmount: 12540
    });
    await flushPromises();

    const badge = getBadge(element);
    expect(badge.iconName).toBe("utility:warning");
    expect(badge.label).toContain("3 overdue");
    expect(badge.label).toContain("$12,540.00");
    expect(badge.label).toContain("at risk");
  });

  it("uses singular wording when exactly one invoice is overdue", async () => {
    const element = createComponent();

    getOverdueInvoiceSummary.emit({
      overdueCount: 1,
      totalOverdueAmount: 750
    });
    await flushPromises();

    const badge = getBadge(element);
    expect(badge.label).toContain("1 overdue");
    expect(badge.label).toContain("$750.00");
    expect(badge.label).toContain("at risk");

    const ariaLabel = element.shadowRoot
      .querySelector("button")
      .getAttribute("aria-label");
    expect(ariaLabel).toContain("1 overdue invoice ");
  });

  it("renders the error badge when the wire emits an error", async () => {
    const element = createComponent();

    getOverdueInvoiceSummary.error();
    await flushPromises();

    const badge = getBadge(element);
    expect(badge.label).toBe("Invoice status unavailable");
    expect(badge.iconName).toBe("utility:warning");
  });

  it("navigates to the Account Invoices related list when clicked", async () => {
    const element = createComponent();

    getOverdueInvoiceSummary.emit({
      overdueCount: 2,
      totalOverdueAmount: 1000
    });
    await flushPromises();

    const button = element.shadowRoot.querySelector("button");
    button.click();
    await flushPromises();

    expect(mockNavigate).toHaveBeenCalledTimes(1);
    const pageRef = mockNavigate.mock.calls[0][0];
    expect(pageRef.type).toBe("standard__recordRelationshipPage");
    expect(pageRef.attributes.relationshipApiName).toBe("Invoices__r");
    expect(pageRef.attributes.objectApiName).toBe("Account");
    expect(pageRef.attributes.recordId).toBe("001000000000001");
    expect(pageRef.attributes.actionName).toBe("view");
  });

  it("exposes a keyboard-accessible button with a non-empty aria-label", () => {
    const element = createComponent();

    const button = element.shadowRoot.querySelector("button");
    expect(button).not.toBeNull();
    expect(button.getAttribute("type")).toBe("button");

    const ariaLabel = button.getAttribute("aria-label");
    expect(ariaLabel).toBeTruthy();
    expect(ariaLabel.length).toBeGreaterThan(0);
  });
});
