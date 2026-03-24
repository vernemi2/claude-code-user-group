import { createElement } from "lwc";
import OverdueInvoiceBanner from "c/overdueInvoiceBanner";
import { getRecord } from "lightning/uiRecordApi";
import getOverdueInvoiceSummary from "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary";

jest.mock(
  "@salesforce/apex/OverdueInvoiceController.getOverdueInvoiceSummary",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("c-overdue-invoice-banner", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-overdue-invoice-banner", {
      is: OverdueInvoiceBanner
    });
    element.recordId = "006000000000001";
    document.body.appendChild(element);
    return element;
  }

  it("should display banner when overdue invoices exist", async () => {
    const element = createComponent();

    getRecord.emit({
      fields: {
        AccountId: { value: "001000000000001" }
      }
    });

    await flushPromises();

    getOverdueInvoiceSummary.emit({
      overdueCount: 2,
      totalOverdueAmount: 5000.0
    });

    await flushPromises();

    const banner = element.shadowRoot.querySelector(".slds-notify_alert");
    expect(banner).not.toBeNull();

    const heading = element.shadowRoot.querySelector("h2");
    expect(heading.textContent).toContain("2 overdue invoices");
    expect(heading.textContent).toContain("$5,000.00");
  });

  it("should hide banner when no overdue invoices", async () => {
    const element = createComponent();

    getRecord.emit({
      fields: {
        AccountId: { value: "001000000000001" }
      }
    });

    await flushPromises();

    getOverdueInvoiceSummary.emit({
      overdueCount: 0,
      totalOverdueAmount: 0
    });

    await flushPromises();

    const banner = element.shadowRoot.querySelector(".slds-notify_alert");
    expect(banner).toBeNull();
  });

  it("should hide banner when Account is null", async () => {
    const element = createComponent();

    getRecord.emit({
      fields: {
        AccountId: { value: null }
      }
    });

    await flushPromises();

    const banner = element.shadowRoot.querySelector(".slds-notify_alert");
    expect(banner).toBeNull();
  });

  it("should use singular form for single invoice", async () => {
    const element = createComponent();

    getRecord.emit({
      fields: {
        AccountId: { value: "001000000000001" }
      }
    });

    await flushPromises();

    getOverdueInvoiceSummary.emit({
      overdueCount: 1,
      totalOverdueAmount: 750.0
    });

    await flushPromises();

    const heading = element.shadowRoot.querySelector("h2");
    expect(heading.textContent).toContain("1 overdue invoice ");
  });
});
