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
  static void shouldReturnEmptyBreakdownWhenAccountIdIsNull() {
    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      null
    );
    Integer queriesAfter = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(
      queriesBefore,
      queriesAfter,
      'Null accountId should short-circuit without SOQL'
    );
    Assert.areEqual(
      5,
      breakdown.buckets.size(),
      'Should return five empty buckets'
    );
    Assert.areEqual(
      0,
      breakdown.totalUnpaidCount,
      'Total unpaid count should be zero'
    );
    Assert.areEqual(
      0,
      breakdown.totalUnpaidAmount,
      'Total unpaid amount should be zero'
    );
    paymentMock.assertThat().method('getPaymentTotals').wasNeverCalled();
  }

  @IsTest
  static void shouldReturnFiveEmptyBucketsWhenNoInvoicesExistForAccount() {
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>());

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      5,
      breakdown.buckets.size(),
      'Empty account should return five empty buckets'
    );
    Assert.areEqual(
      'Current',
      breakdown.buckets[0].label,
      'First bucket should be Current'
    );
    Assert.areEqual(
      '1-30 days',
      breakdown.buckets[1].label,
      'Second bucket should be 1-30 days'
    );
    Assert.areEqual(
      '31-60 days',
      breakdown.buckets[2].label,
      'Third bucket should be 31-60 days'
    );
    Assert.areEqual(
      '61-90 days',
      breakdown.buckets[3].label,
      'Fourth bucket should be 61-90 days'
    );
    Assert.areEqual(
      '90+ days',
      breakdown.buckets[4].label,
      'Fifth bucket should be 90+ days'
    );
    for (InvoiceService.AgingBucket bucket : breakdown.buckets) {
      Assert.areEqual(
        0,
        bucket.count,
        'Empty account bucket count should be zero'
      );
      Assert.areEqual(
        0,
        bucket.totalAmount,
        'Empty account bucket total should be zero'
      );
    }
    Assert.areEqual(
      0,
      breakdown.totalUnpaidCount,
      'Total count should be zero'
    );
    Assert.areEqual(
      0,
      breakdown.totalUnpaidAmount,
      'Total amount should be zero'
    );
  }

  @IsTest
  static void shouldClassifyDraftInvoicesAsCurrentRegardlessOfDueDate() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Amount__c = 500.00,
      Status__c = 'Draft',
      Due_Date__c = Date.today().addDays(-120)
    );
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>{ invoice });

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals').thenReturn(new Map<Id, Decimal>());
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      breakdown.buckets[0].count,
      'Draft invoice should land in Current bucket even if due date is 120 days overdue'
    );
    Assert.areEqual(
      500.00,
      breakdown.buckets[0].totalAmount,
      'Current bucket should carry full draft amount'
    );
    Assert.areEqual(
      1,
      breakdown.totalUnpaidCount,
      'Draft should still count as unpaid'
    );
  }

  @IsTest
  static void shouldClassifyNullDueDateAsCurrent() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Amount__c = 250.00,
      Status__c = 'Sent',
      Due_Date__c = null
    );
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>{ invoice });

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals').thenReturn(new Map<Id, Decimal>());
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      breakdown.buckets[0].count,
      'Null due date should land in Current bucket'
    );
    Assert.areEqual(
      250.00,
      breakdown.buckets[0].totalAmount,
      'Current bucket should carry full amount'
    );
  }

  @IsTest
  static void shouldClassifyBoundaryDayValuesIntoCorrectBuckets() {
    Date today = Date.today();
    List<Invoice__c> invoices = new List<Invoice__c>();
    // boundary pairs: dueDate offset -> expected bucket
    Map<Integer, String> offsetToBucket = new Map<Integer, String>{
      0 => 'Current',
      -1 => '1-30 days',
      -30 => '1-30 days',
      -31 => '31-60 days',
      -60 => '31-60 days',
      -61 => '61-90 days',
      -90 => '61-90 days',
      -91 => '90+ days'
    };

    Map<String, Decimal> expectedAmountsByBucket = new Map<String, Decimal>();
    Map<String, Integer> expectedCountsByBucket = new Map<String, Integer>();

    for (Integer offset : offsetToBucket.keySet()) {
      invoices.add(
        new Invoice__c(
          Id = SOQL.IdGenerator.get(Invoice__c.SObjectType),
          Amount__c = 100.00,
          Status__c = 'Sent',
          Due_Date__c = today.addDays(offset)
        )
      );
      String expectedBucket = offsetToBucket.get(offset);
      expectedAmountsByBucket.put(
        expectedBucket,
        (expectedAmountsByBucket.containsKey(expectedBucket)
          ? expectedAmountsByBucket.get(expectedBucket)
          : 0) + 100.00
      );
      expectedCountsByBucket.put(
        expectedBucket,
        (expectedCountsByBucket.containsKey(expectedBucket)
          ? expectedCountsByBucket.get(expectedBucket)
          : 0) + 1
      );
    }

    SOQL.mock('InvoiceService.getUnpaidInvoices').thenReturn(invoices);

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals').thenReturn(new Map<Id, Decimal>());
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Map<String, InvoiceService.AgingBucket> bucketByLabel = new Map<String, InvoiceService.AgingBucket>();
    for (InvoiceService.AgingBucket b : breakdown.buckets) {
      bucketByLabel.put(b.label, b);
    }

    for (String label : expectedCountsByBucket.keySet()) {
      Assert.areEqual(
        expectedCountsByBucket.get(label),
        bucketByLabel.get(label).count,
        'Bucket ' +
          label +
          ' should have expected count for boundary day values'
      );
      Assert.areEqual(
        expectedAmountsByBucket.get(label),
        bucketByLabel.get(label).totalAmount,
        'Bucket ' +
          label +
          ' should have expected amount for boundary day values'
      );
    }
    Assert.areEqual(
      8,
      breakdown.totalUnpaidCount,
      'All eight boundary invoices should be counted'
    );
    Assert.areEqual(
      800.00,
      breakdown.totalUnpaidAmount,
      'Total amount should sum all eight invoices'
    );
  }

  @IsTest
  static void shouldUseRemainingBalanceWhenPartialPaymentsExist() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Amount__c = 1000.00,
      Status__c = 'Sent',
      Due_Date__c = Date.today().addDays(-10)
    );
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>{ invoice });

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals')
      .thenReturn(new Map<Id, Decimal>{ invoiceId => 300.00 });
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      breakdown.buckets[1].count,
      '10-day overdue invoice should land in 1-30 days bucket'
    );
    Assert.areEqual(
      700.00,
      breakdown.buckets[1].totalAmount,
      'Bucket amount should reflect remaining balance after partial payment'
    );
    Assert.areEqual(
      700.00,
      breakdown.totalUnpaidAmount,
      'Total unpaid amount should reflect remaining balance'
    );
  }

  @IsTest
  static void shouldExcludeFullyPaidInvoicesFromBreakdown() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Amount__c = 500.00,
      Status__c = 'Sent',
      Due_Date__c = Date.today().addDays(-5)
    );
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>{ invoice });

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals')
      .thenReturn(new Map<Id, Decimal>{ invoiceId => 500.00 });
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      breakdown.totalUnpaidCount,
      'Fully paid invoice should be excluded'
    );
    Assert.areEqual(
      0,
      breakdown.totalUnpaidAmount,
      'Fully paid invoice amount should be excluded'
    );
    for (InvoiceService.AgingBucket bucket : breakdown.buckets) {
      Assert.areEqual(
        0,
        bucket.count,
        'No bucket should contain fully paid invoices'
      );
    }
  }

  @IsTest
  static void shouldHandleNullInvoiceAmountGracefully() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Amount__c = null,
      Status__c = 'Sent',
      Due_Date__c = Date.today().addDays(-5)
    );
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>{ invoice });

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals').thenReturn(new Map<Id, Decimal>());
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      breakdown.totalUnpaidCount,
      'Null amount invoice (zero remaining) should be excluded'
    );
  }

  @IsTest
  static void shouldAssignCorrectSeverityToEachBucket() {
    SOQL.mock('InvoiceService.getUnpaidInvoices')
      .thenReturn(new List<Invoice__c>());

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      'current',
      breakdown.buckets[0].severity,
      'Current bucket should have current severity'
    );
    Assert.areEqual(
      'low',
      breakdown.buckets[1].severity,
      '1-30 bucket should have low severity'
    );
    Assert.areEqual(
      'medium',
      breakdown.buckets[2].severity,
      '31-60 bucket should have medium severity'
    );
    Assert.areEqual(
      'high',
      breakdown.buckets[3].severity,
      '61-90 bucket should have high severity'
    );
    Assert.areEqual(
      'critical',
      breakdown.buckets[4].severity,
      '90+ bucket should have critical severity'
    );
  }

  @IsTest
  static void shouldBulkAggregateManyUnpaidInvoices() {
    Id accountId = SOQL.IdGenerator.get(Account.SObjectType);
    Date today = Date.today();
    List<Invoice__c> invoices = new List<Invoice__c>();
    Map<Id, Decimal> payments = new Map<Id, Decimal>();
    for (Integer i = 0; i < 200; i++) {
      Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
      invoices.add(
        new Invoice__c(
          Id = invoiceId,
          Amount__c = 100.00,
          Status__c = 'Sent',
          Due_Date__c = today.addDays(-15)
        )
      );
    }
    SOQL.mock('InvoiceService.getUnpaidInvoices').thenReturn(invoices);

    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('getPaymentTotals').thenReturn(payments);
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    InvoiceService service = new InvoiceService();

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown breakdown = service.getAgingBreakdown(
      accountId
    );
    Test.stopTest();

    Assert.areEqual(
      200,
      breakdown.totalUnpaidCount,
      'Should aggregate 200 invoices'
    );
    Assert.areEqual(
      200,
      breakdown.buckets[1].count,
      'All 200 should land in 1-30 days bucket'
    );
    Assert.areEqual(
      20000.00,
      breakdown.totalUnpaidAmount,
      'Total should sum all 200 amounts'
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
