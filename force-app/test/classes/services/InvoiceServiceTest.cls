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

  @IsTest
  static void shouldSetDueDateToInvoiceDatePlus30WhenAccountHasNet30Terms() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = 'Net 30')
        }
      );
    Invoice__c invoice = new Invoice__c(
      Account__c = accountId,
      Invoice_Date__c = Date.newInstance(2026, 4, 1)
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.newInstance(2026, 5, 1),
      invoice.Due_Date__c,
      'Due date should be invoice date + 30 days for Net 30'
    );
  }

  @IsTest
  static void shouldSetDueDateToInvoiceDatePlus15WhenAccountHasNet15Terms() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = 'Net 15')
        }
      );
    Invoice__c invoice = new Invoice__c(
      Account__c = accountId,
      Invoice_Date__c = Date.newInstance(2026, 4, 1)
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.newInstance(2026, 4, 16),
      invoice.Due_Date__c,
      'Due date should be invoice date + 15 days for Net 15'
    );
  }

  @IsTest
  static void shouldSetDueDateEqualToInvoiceDateWhenDueOnReceipt() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = 'Due on Receipt')
        }
      );
    Invoice__c invoice = new Invoice__c(
      Account__c = accountId,
      Invoice_Date__c = Date.newInstance(2026, 4, 1)
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.newInstance(2026, 4, 1),
      invoice.Due_Date__c,
      'Due date should equal invoice date when Due on Receipt'
    );
  }

  @IsTest
  static void shouldDefaultToNet30WhenPaymentTermsIsNull() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = null)
        }
      );
    Invoice__c invoice = new Invoice__c(
      Account__c = accountId,
      Invoice_Date__c = Date.newInstance(2026, 4, 1)
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.newInstance(2026, 5, 1),
      invoice.Due_Date__c,
      'Due date should default to invoice date + 30 when terms are null'
    );
  }

  @IsTest
  static void shouldDefaultToNet30WhenAccountIsNull() {
    SOQL.mock('InvoiceService.getPaymentTerms').thenReturn(new List<Account>());
    Invoice__c invoice = new Invoice__c(
      Invoice_Date__c = Date.newInstance(2026, 4, 1)
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.newInstance(2026, 5, 1),
      invoice.Due_Date__c,
      'Due date should default to invoice date + 30 when account is null'
    );
  }

  @IsTest
  static void shouldPreserveDueDateWhenAlreadySetByUser() {
    Date userDueDate = Date.newInstance(2026, 12, 31);
    Invoice__c invoice = new Invoice__c(
      Account__c = SOQL.IdGenerator.get(Account.SObjectType),
      Invoice_Date__c = Date.newInstance(2026, 4, 1),
      Due_Date__c = userDueDate
    );

    InvoiceService service = new InvoiceService();

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Integer queriesAfter = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(
      userDueDate,
      invoice.Due_Date__c,
      'User-set due date should be preserved'
    );
    Assert.areEqual(
      queriesBefore,
      queriesAfter,
      'Service should short-circuit before any SOQL when all due dates are set'
    );
  }

  @IsTest
  static void shouldUseTodayWhenInvoiceDateIsNull() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = 'Net 30')
        }
      );
    Invoice__c invoice = new Invoice__c(Account__c = accountId);

    InvoiceService service = new InvoiceService();

    Test.startTest();
    service.populateDueDates(new List<Invoice__c>{ invoice });
    Test.stopTest();

    Assert.areEqual(
      Date.today().addDays(30),
      invoice.Due_Date__c,
      'Due date should be today + 30 when invoice date is null'
    );
  }

  @IsTest
  static void shouldBulkProcess200InvoicesInOneQuery() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    SOQL.mock('InvoiceService.getPaymentTerms')
      .thenReturn(
        new List<Account>{
          new Account(Id = accountId, Payment_Terms__c = 'Net 30')
        }
      );
    List<Invoice__c> invoices = new List<Invoice__c>();
    Date invoiceDate = Date.newInstance(2026, 4, 1);
    for (Integer i = 0; i < 200; i++) {
      invoices.add(
        new Invoice__c(
          Account__c = Math.mod(i, 2) == 0 ? accountId : null,
          Invoice_Date__c = invoiceDate
        )
      );
    }

    InvoiceService service = new InvoiceService();

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    service.populateDueDates(invoices);
    Integer queriesAfter = Limits.getQueries();
    Test.stopTest();

    Assert.isTrue(
      queriesAfter - queriesBefore <= 1,
      'Should execute at most one query for 200 invoices'
    );
    Assert.areEqual(
      Date.newInstance(2026, 5, 1),
      invoices[0].Due_Date__c,
      'First invoice should have correct due date'
    );
    Assert.areEqual(
      Date.newInstance(2026, 5, 1),
      invoices[199].Due_Date__c,
      'Last invoice should have correct due date'
    );
  }
}
