public class PaymentTriggerHandler extends TriggerHandler {
  private final PaymentService paymentService;

  public PaymentTriggerHandler() {
    this.paymentService = (PaymentService) InstanceProvider.provide(
      PaymentService.class
    );
  }

  protected override void beforeInsert(List<SObject> triggerNew) {
    paymentService.validatePaymentsOnInsert((List<Payment__c>) triggerNew);
  }

  protected override void beforeUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    paymentService.validatePaymentsOnUpdate(
      (List<Payment__c>) triggerNew.values(),
      triggerOld
    );
  }

  protected override void afterInsert(Map<Id, SObject> triggerNew) {
    paymentService.syncInvoiceStatusAfterChange(
      collectInvoiceIds(triggerNew.values())
    );
  }

  protected override void afterUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    paymentService.syncInvoiceStatusAfterChange(
      collectInvoiceIds(triggerNew.values())
    );
  }

  protected override void afterDelete(Map<Id, SObject> triggerOld) {
    paymentService.syncInvoiceStatusAfterChange(
      collectInvoiceIds(triggerOld.values())
    );
  }

  private Set<Id> collectInvoiceIds(List<SObject> payments) {
    Set<Id> invoiceIds = new Set<Id>();
    for (SObject record : payments) {
      Payment__c payment = (Payment__c) record;
      invoiceIds.add(payment.Invoice__c);
    }
    return invoiceIds;
  }
}
