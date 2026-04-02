public inherited sharing class SOQL_Payment extends SOQL implements SOQL.Selector {
  public static SOQL_Payment query() {
    return new SOQL_Payment();
  }

  private SOQL_Payment() {
    super(Payment__c.SObjectType);
    with(
        Payment__c.Id,
        Payment__c.Name,
        Payment__c.Invoice__c,
        Payment__c.Amount__c,
        Payment__c.Payment_Date__c
      )
      .with(Payment__c.Payment_Method__c, Payment__c.Reference_Number__c)
      .systemMode()
      .withoutSharing();
  }

  public SOQL_Payment byInvoiceId(Id invoiceId) {
    whereAre(SOQL.Filter.with(Payment__c.Invoice__c).equal(invoiceId));
    return this;
  }

  public SOQL_Payment byInvoiceIds(Set<Id> invoiceIds) {
    whereAre(SOQL.Filter.with(Payment__c.Invoice__c).isIn(invoiceIds));
    return this;
  }
}
