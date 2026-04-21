public inherited sharing class SOQL_Account extends SOQL implements SOQL.Selector {
  public static SOQL_Account query() {
    return new SOQL_Account();
  }

  private SOQL_Account() {
    super(Account.SObjectType);
    with(Account.Id, Account.Name, Account.Payment_Terms__c)
      .systemMode()
      .withoutSharing();
  }

  public SOQL_Account byIds(Set<Id> accountIds) {
    whereAre(SOQL.Filter.with(Account.Id).isIn(accountIds));
    return this;
  }
}
