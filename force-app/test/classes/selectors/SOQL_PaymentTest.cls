@IsTest
private class SOQL_PaymentTest {
  @IsTest
  static void shouldQueryWithDefaultFields() {
    SOQL.mock('SOQL_Payment').thenReturn(new List<Payment__c>());

    Test.startTest();
    List<Payment__c> results = SOQL_Payment.query()
      .mockId('SOQL_Payment')
      .toList();
    Test.stopTest();

    Assert.areEqual(0, results.size(), 'Should return mocked empty list');
  }

  @IsTest
  static void shouldFilterByInvoiceId() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    List<Payment__c> mockPayments = new List<Payment__c>{
      new Payment__c(Invoice__c = invoiceId, Amount__c = 250.00)
    };
    SOQL.mock('SOQL_PaymentTest.byInvoiceId').thenReturn(mockPayments);

    Test.startTest();
    List<Payment__c> results = SOQL_Payment.query()
      .byInvoiceId(invoiceId)
      .mockId('SOQL_PaymentTest.byInvoiceId')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return filtered payment');
  }

  @IsTest
  static void shouldFilterByInvoiceIds() {
    Id invoiceId1 = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Id invoiceId2 = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Set<Id> invoiceIds = new Set<Id>{ invoiceId1, invoiceId2 };
    List<Payment__c> mockPayments = new List<Payment__c>{
      new Payment__c(Invoice__c = invoiceId1, Amount__c = 100.00),
      new Payment__c(Invoice__c = invoiceId2, Amount__c = 200.00)
    };
    SOQL.mock('SOQL_PaymentTest.byInvoiceIds').thenReturn(mockPayments);

    Test.startTest();
    List<Payment__c> results = SOQL_Payment.query()
      .byInvoiceIds(invoiceIds)
      .mockId('SOQL_PaymentTest.byInvoiceIds')
      .toList();
    Test.stopTest();

    Assert.areEqual(
      2,
      results.size(),
      'Should return payments for both invoices'
    );
  }

  @IsTest
  static void shouldChainFilters() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Set<Id> invoiceIds = new Set<Id>{ invoiceId };
    List<Payment__c> mockPayments = new List<Payment__c>{
      new Payment__c(Invoice__c = invoiceId, Amount__c = 150.00)
    };
    SOQL.mock('SOQL_PaymentTest.chained').thenReturn(mockPayments);

    Test.startTest();
    List<Payment__c> results = SOQL_Payment.query()
      .byInvoiceId(invoiceId)
      .byInvoiceIds(invoiceIds)
      .mockId('SOQL_PaymentTest.chained')
      .toList();
    Test.stopTest();

    Assert.areEqual(1, results.size(), 'Should return chained filter results');
  }
}
