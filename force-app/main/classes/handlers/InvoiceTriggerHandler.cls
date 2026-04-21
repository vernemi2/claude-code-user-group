public virtual class InvoiceTriggerHandler extends TriggerHandler {
  private final InvoiceService invoiceService;

  public InvoiceTriggerHandler() {
    this.invoiceService = (InvoiceService) InstanceProvider.provide(
      InvoiceService.class
    );
  }

  protected override void beforeInsert(List<SObject> triggerNew) {
    invoiceService.populateDueDates((List<Invoice__c>) triggerNew);
  }
}
