trigger InvoiceTrigger on Invoice__c(before insert) {
  new InvoiceTriggerHandler().run();
}
