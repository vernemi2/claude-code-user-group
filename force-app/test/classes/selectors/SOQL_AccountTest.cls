@IsTest
private class SOQL_AccountTest {
  @IsTest
  static void shouldQueryWithDefaultFields() {
    SOQL.mock('SOQL_Account').thenReturn(new List<Account>());

    Test.startTest();
    List<Account> results = SOQL_Account.query()
      .mockId('SOQL_Account')
      .toList();
    Test.stopTest();

    Assert.areEqual(0, results.size(), 'Should return mocked empty list');
  }

  @IsTest
  static void shouldFilterByIds() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    List<Account> mockAccounts = new List<Account>{
      new Account(Id = accountId, Name = 'Acme', Payment_Terms__c = 'Net 30')
    };
    SOQL.mock('SOQL_AccountTest.byIds').thenReturn(mockAccounts);

    Test.startTest();
    List<Account> results = SOQL_Account.query()
      .byIds(new Set<Id>{ accountId })
      .mockId('SOQL_AccountTest.byIds')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return filtered accounts');
  }

  @IsTest
  static void shouldFilterByEmptyIdSet() {
    SOQL.mock('SOQL_AccountTest.emptyIds').thenReturn(new List<Account>());

    Test.startTest();
    List<Account> results = SOQL_Account.query()
      .byIds(new Set<Id>())
      .mockId('SOQL_AccountTest.emptyIds')
      .toList();
    Test.stopTest();

    Assert.areEqual(
      0,
      results.size(),
      'Should handle empty id set without exception'
    );
  }
}
