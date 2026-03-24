@IsTest
private class SOQL_InvoiceTest {
  @IsTest
  static void shouldQueryWithDefaultFields() {
    SOQL.mock('SOQL_Invoice').thenReturn(new List<Invoice__c>());

    Test.startTest();
    List<Invoice__c> results = SOQL_Invoice.query()
      .mockId('SOQL_Invoice')
      .toList();
    Test.stopTest();

    Assert.areEqual(0, results.size(), 'Should return mocked empty list');
  }

  @IsTest
  static void shouldFilterByAccountId() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Account__c = accountId, Amount__c = 100.00)
    };
    SOQL.mock('SOQL_InvoiceTest.byAccountId').thenReturn(mockInvoices);

    Test.startTest();
    List<Invoice__c> results = SOQL_Invoice.query()
      .byAccountId(accountId)
      .mockId('SOQL_InvoiceTest.byAccountId')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return filtered invoices');
  }

  @IsTest
  static void shouldFilterOverdue() {
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Amount__c = 500.00, Status__c = 'Sent')
    };
    SOQL.mock('SOQL_InvoiceTest.overdue').thenReturn(mockInvoices);

    Test.startTest();
    List<Invoice__c> results = SOQL_Invoice.query()
      .overdue()
      .mockId('SOQL_InvoiceTest.overdue')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return overdue invoices');
  }

  @IsTest
  static void shouldChainFilters() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Account__c = accountId, Amount__c = 200.00)
    };
    SOQL.mock('SOQL_InvoiceTest.chained').thenReturn(mockInvoices);

    Test.startTest();
    List<Invoice__c> results = SOQL_Invoice.query()
      .byAccountId(accountId)
      .overdue()
      .mockId('SOQL_InvoiceTest.chained')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return chained filter results');
  }
}
