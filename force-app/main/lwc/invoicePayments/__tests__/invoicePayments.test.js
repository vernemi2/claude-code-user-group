import { createElement } from "lwc";
import InvoicePayments from "c/invoicePayments";
import { getRecord } from "lightning/uiRecordApi";
import getPayments from "@salesforce/apex/PaymentController.getPayments";
import getRemainingBalance from "@salesforce/apex/PaymentController.getRemainingBalance";
import createPayment from "@salesforce/apex/PaymentController.createPayment";
import { flushPromises } from "c/testUtils";

jest.mock(
  "@salesforce/apex/PaymentController.getPayments",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PaymentController.getRemainingBalance",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PaymentController.createPayment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }),
  { virtual: true }
);

const MOCK_PAYMENTS = [
  {
    Id: "a01000000000001",
    Name: "PAY-00001",
    Amount__c: 500.0,
    Payment_Date__c: "2026-03-15",
    Payment_Method__c: "Credit Card",
    Reference_Number__c: "REF-001"
  },
  {
    Id: "a01000000000002",
    Name: "PAY-00002",
    Amount__c: 200.0,
    Payment_Date__c: "2026-03-20",
    Payment_Method__c: "Bank Transfer",
    Reference_Number__c: null
  }
];

describe("c-invoice-payments", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-invoice-payments", {
      is: InvoicePayments
    });
    element.recordId = "a00000000000001";
    document.body.appendChild(element);
    return element;
  }

  function emitInvoiceRecord(status) {
    getRecord.emit({
      fields: {
        Status__c: { value: status }
      }
    });
  }

  function findInputByLabel(element, label) {
    const inputs = element.shadowRoot.querySelectorAll("lightning-input");
    return [...inputs].find((input) => input.label === label) || null;
  }

  it("should display payment list when payments exist", async () => {
    const element = createComponent();

    emitInvoiceRecord("Sent");
    getPayments.emit(MOCK_PAYMENTS);
    getRemainingBalance.emit(300.0);

    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data).toHaveLength(2);

    const heading = element.shadowRoot.querySelector("h3");
    expect(heading.textContent).toContain("Payment History");
  });

  it("should show empty state when no payments", async () => {
    const element = createComponent();

    emitInvoiceRecord("Sent");
    getPayments.emit([]);
    getRemainingBalance.emit(1000.0);

    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });

  it("should pre-fill amount with remaining balance", async () => {
    const element = createComponent();

    emitInvoiceRecord("Sent");
    getPayments.emit([]);
    getRemainingBalance.emit(750.5);

    await flushPromises();

    const amountInput = findInputByLabel(element, "Amount");
    expect(amountInput).not.toBeNull();
    expect(amountInput.value).toBe(750.5);
  });

  it("should disable form when invoice status is Draft", async () => {
    const element = createComponent();

    emitInvoiceRecord("Draft");
    getPayments.emit([]);
    getRemainingBalance.emit(1000.0);

    await flushPromises();

    const warning = element.shadowRoot.querySelector(".slds-alert_warning");
    expect(warning).not.toBeNull();

    const heading = warning.querySelector("h2");
    expect(heading.textContent).toContain("Draft");

    const amountInput = findInputByLabel(element, "Amount");
    expect(amountInput).toBeNull();
  });

  it("should disable form when invoice status is Cancelled", async () => {
    const element = createComponent();

    emitInvoiceRecord("Cancelled");
    getPayments.emit([]);
    getRemainingBalance.emit(1000.0);

    await flushPromises();

    const warning = element.shadowRoot.querySelector(".slds-alert_warning");
    expect(warning).not.toBeNull();

    const heading = warning.querySelector("h2");
    expect(heading.textContent).toContain("Cancelled");
  });

  it("should show fully paid message when balance is zero", async () => {
    const element = createComponent();

    emitInvoiceRecord("Paid");
    getPayments.emit(MOCK_PAYMENTS);
    getRemainingBalance.emit(0);

    await flushPromises();

    const alerts = element.shadowRoot.querySelectorAll(".slds-notify_alert");
    const paidAlert = [...alerts].find(
      (a) => !a.classList.contains("slds-alert_warning")
    );
    expect(paidAlert).not.toBeNull();
    expect(paidAlert.textContent).toContain("fully paid");
  });

  it("should call createPayment on form submit", async () => {
    createPayment.mockResolvedValue({ Id: "a01000000000003" });

    const element = createComponent();

    emitInvoiceRecord("Sent");
    getPayments.emit([]);
    getRemainingBalance.emit(500.0);

    await flushPromises();

    const amountInput = findInputByLabel(element, "Amount");
    amountInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: 250 } })
    );

    const dateInput = findInputByLabel(element, "Payment Date");
    dateInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "2026-04-01" } })
    );

    await flushPromises();

    const submitButton = element.shadowRoot.querySelector("lightning-button");
    submitButton.click();

    await flushPromises();

    expect(createPayment).toHaveBeenCalledWith({
      invoiceId: "a00000000000001",
      amount: 250,
      paymentDate: "2026-04-01",
      paymentMethod: null,
      referenceNumber: null
    });
  });

  it("should show error toast on failed payment", async () => {
    createPayment.mockRejectedValue({
      body: { message: "Payment exceeds balance" }
    });

    const element = createComponent();

    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    emitInvoiceRecord("Sent");
    getPayments.emit([]);
    getRemainingBalance.emit(500.0);

    await flushPromises();

    const amountInput = findInputByLabel(element, "Amount");
    amountInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: 600 } })
    );

    const dateInput = findInputByLabel(element, "Payment Date");
    dateInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "2026-04-01" } })
    );

    await flushPromises();

    const submitButton = element.shadowRoot.querySelector("lightning-button");
    submitButton.click();

    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    const toastEvent = toastHandler.mock.calls[0][0];
    expect(toastEvent.detail.variant).toBe("error");
  });
});
