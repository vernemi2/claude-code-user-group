trigger PaymentTrigger on Payment__c(
  before insert,
  before update,
  after insert,
  after update,
  after delete
) {
  new PaymentTriggerHandler().run();
}
