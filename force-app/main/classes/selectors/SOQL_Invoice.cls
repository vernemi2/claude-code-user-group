public inherited sharing class SOQL_Invoice extends SOQL implements SOQL.Selector {
  public static SOQL_Invoice query() {
    return new SOQL_Invoice();
  }

  private SOQL_Invoice() {
    super(Invoice__c.SObjectType);
    with(
        Invoice__c.Id,
        Invoice__c.Name,
        Invoice__c.Account__c,
        Invoice__c.Amount__c,
        Invoice__c.Due_Date__c
      )
      .with(Invoice__c.Status__c)
      .systemMode()
      .withoutSharing();
  }

  public SOQL_Invoice byAccountId(Id accountId) {
    whereAre(SOQL.Filter.with(Invoice__c.Account__c).equal(accountId));
    return this;
  }

  public SOQL_Invoice unpaid() {
    whereAre(
      SOQL.Filter.with(Invoice__c.Status__c)
        .notIn(new List<String>{ 'Paid', 'Cancelled' })
    );
    return this;
  }

  public SOQL_Invoice overdue() {
    whereAre(
      SOQL.FilterGroup
        .add(SOQL.Filter.with(Invoice__c.Due_Date__c).lessThan(Date.today()))
        .add(
          SOQL.Filter.with(Invoice__c.Status__c)
            .notIn(new List<String>{ 'Paid', 'Cancelled' })
        )
    );
    return this;
  }
}
