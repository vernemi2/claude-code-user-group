@IsTest
private class InvoiceServiceTest {
  @IsTest
  static void shouldReturnSummaryWhenOverdueInvoicesExist() {
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Amount__c = 1000.00),
      new Invoice__c(Amount__c = 500.50)
    };
    SOQL.mock('InvoiceService.getOverdueInvoices').thenReturn(mockInvoices);

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = service.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      result.overdueCount,
      'Should return count of overdue invoices'
    );
    Assert.areEqual(
      1500.50,
      result.totalOverdueAmount,
      'Should sum invoice amounts'
    );
  }

  @IsTest
  static void shouldReturnZeroWhenNoOverdueInvoices() {
    SOQL.mock('InvoiceService.getOverdueInvoices')
      .thenReturn(new List<Invoice__c>());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = service.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(0, result.overdueCount, 'Should return zero count');
    Assert.areEqual(0, result.totalOverdueAmount, 'Should return zero amount');
  }

  @IsTest
  static void shouldHandleSingleOverdueInvoice() {
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Amount__c = 250.00)
    };
    SOQL.mock('InvoiceService.getOverdueInvoices').thenReturn(mockInvoices);

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = service.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      result.overdueCount,
      'Should return single invoice count'
    );
    Assert.areEqual(
      250.00,
      result.totalOverdueAmount,
      'Should return single invoice amount'
    );
  }

  @IsTest
  static void shouldHandleNullAmountsGracefully() {
    List<Invoice__c> mockInvoices = new List<Invoice__c>{
      new Invoice__c(Amount__c = 100.00),
      new Invoice__c(Amount__c = null)
    };
    SOQL.mock('InvoiceService.getOverdueInvoices').thenReturn(mockInvoices);

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = service.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      result.overdueCount,
      'Should count all invoices including null amounts'
    );
    Assert.areEqual(
      100.00,
      result.totalOverdueAmount,
      'Should skip null amounts in sum'
    );
  }

  @IsTest
  static void shouldHandleBulkInvoices() {
    List<Invoice__c> mockInvoices = new List<Invoice__c>();
    for (Integer i = 0; i < 200; i++) {
      mockInvoices.add(new Invoice__c(Amount__c = 10.00));
    }
    SOQL.mock('InvoiceService.getOverdueInvoices').thenReturn(mockInvoices);

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = service.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(200, result.overdueCount, 'Should handle 200 invoices');
    Assert.areEqual(
      2000.00,
      result.totalOverdueAmount,
      'Should sum 200 invoices correctly'
    );
  }
}
