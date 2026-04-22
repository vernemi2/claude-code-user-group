@IsTest
private class PaymentServiceTest {
  @IsTest
  static void shouldRejectPaymentOnDraftInvoice() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Draft',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(new List<Map<String, Object>>());

    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 100.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(new List<Payment__c>{ payment });
    Test.stopTest();

    Assert.isTrue(
      payment.hasErrors(),
      'Payment against Draft invoice should have validation error'
    );
  }

  @IsTest
  static void shouldRejectPaymentOnCancelledInvoice() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Cancelled',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(new List<Map<String, Object>>());

    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 100.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(new List<Payment__c>{ payment });
    Test.stopTest();

    Assert.isTrue(
      payment.hasErrors(),
      'Payment against Cancelled invoice should have validation error'
    );
  }

  @IsTest
  static void shouldAllowPaymentOnSentInvoice() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(new List<Map<String, Object>>());

    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 500.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(new List<Payment__c>{ payment });
    Test.stopTest();

    Assert.isFalse(
      payment.hasErrors(),
      'Payment within balance on Sent invoice should not have errors'
    );
  }

  @IsTest
  static void shouldRejectPaymentExceedingBalance() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 800.00
          }
        }
      );

    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 300.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(new List<Payment__c>{ payment });
    Test.stopTest();

    Assert.isTrue(
      payment.hasErrors(),
      'Payment exceeding remaining balance should have validation error'
    );
  }

  @IsTest
  static void shouldAllowPaymentEqualToBalance() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 800.00
          }
        }
      );

    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 200.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(new List<Payment__c>{ payment });
    Test.stopTest();

    Assert.isFalse(
      payment.hasErrors(),
      'Payment equal to remaining balance should not have errors'
    );
  }

  @IsTest
  static void shouldExcludeOldAmountOnUpdate() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Id paymentId = SOQL.IdGenerator.get(Payment__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForValidation')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 500.00
          }
        }
      );

    Payment__c oldPayment = new Payment__c(
      Id = paymentId,
      Invoice__c = invoiceId,
      Amount__c = 300.00
    );
    Payment__c newPayment = new Payment__c(
      Id = paymentId,
      Invoice__c = invoiceId,
      Amount__c = 400.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnUpdate(
      new List<Payment__c>{ newPayment },
      new Map<Id, SObject>{ paymentId => oldPayment }
    );
    Test.stopTest();

    Assert.isFalse(
      newPayment.hasErrors(),
      'Updated payment within adjusted balance should not have errors'
    );
  }

  @IsTest
  static void shouldSetInvoiceToPaidWhenFullyPaid() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForSync')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 1000.00
          }
        }
      );
    DML.mock('PaymentService.updateInvoiceStatus').allUpdates();

    PaymentService service = new PaymentService();

    Test.startTest();
    service.syncInvoiceStatusAfterChange(new Set<Id>{ invoiceId });
    Test.stopTest();
  }

  @IsTest
  static void shouldNotChangePaidStatusWhenAlreadyPaid() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Paid',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForSync')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 1000.00
          }
        }
      );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.syncInvoiceStatusAfterChange(new Set<Id>{ invoiceId });
    Test.stopTest();
  }

  @IsTest
  static void shouldRevertPaidToSentOnDelete() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Paid',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForSync')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 500.00
          }
        }
      );
    DML.mock('PaymentService.updateInvoiceStatus').allUpdates();

    PaymentService service = new PaymentService();

    Test.startTest();
    service.syncInvoiceStatusAfterChange(new Set<Id>{ invoiceId });
    Test.stopTest();
  }

  @IsTest
  static void shouldNotRevertNonPaidInvoice() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(
      Id = invoiceId,
      Status__c = 'Sent',
      Amount__c = 1000.00
    );
    SOQL.mock('PaymentService.getInvoicesForSync')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 500.00
          }
        }
      );

    PaymentService service = new PaymentService();

    Test.startTest();
    service.syncInvoiceStatusAfterChange(new Set<Id>{ invoiceId });
    Test.stopTest();
  }

  @IsTest
  static void shouldReturnPaymentsForInvoice() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    List<Payment__c> mockPayments = new List<Payment__c>{
      new Payment__c(Invoice__c = invoiceId, Amount__c = 250.00),
      new Payment__c(Invoice__c = invoiceId, Amount__c = 150.00)
    };
    SOQL.mock('PaymentService.getPaymentsForInvoice').thenReturn(mockPayments);

    PaymentService service = new PaymentService();

    Test.startTest();
    List<Payment__c> results = service.getPaymentsForInvoice(invoiceId);
    Test.stopTest();

    Assert.areEqual(
      2,
      results.size(),
      'Should return mocked payments for invoice'
    );
  }

  @IsTest
  static void shouldReturnRemainingBalance() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Invoice__c invoice = new Invoice__c(Id = invoiceId, Amount__c = 1000.00);
    SOQL.mock('PaymentService.getInvoiceForBalance')
      .thenReturn(new List<Invoice__c>{ invoice });
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => 600.00
          }
        }
      );

    PaymentService service = new PaymentService();

    Test.startTest();
    Decimal remaining = service.getRemainingBalance(invoiceId);
    Test.stopTest();

    Assert.areEqual(
      400.00,
      remaining,
      'Remaining balance should be invoice amount minus payments'
    );
  }

  @IsTest
  static void shouldCreatePayment() {
    DML.mock('PaymentService.createPayment').allInserts();
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = 500.00
    );

    PaymentService service = new PaymentService();

    Test.startTest();
    Payment__c result = service.createPayment(payment);
    Test.stopTest();

    Assert.isNotNull(result, 'Should return the payment record');
  }

  @IsTest
  static void shouldReturnPaymentTotalsByInvoice() {
    Id invoiceA = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Id invoiceB = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceA,
            'totalAmount' => 400.00
          },
          new Map<String, Object>{
            'Invoice__c' => invoiceB,
            'totalAmount' => 750.00
          }
        }
      );

    PaymentService service = new PaymentService();

    Test.startTest();
    Map<Id, Decimal> totals = service.getPaymentTotals(
      new Set<Id>{ invoiceA, invoiceB }
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      totals.size(),
      'Should return totals for both invoice ids'
    );
    Assert.areEqual(
      400.00,
      totals.get(invoiceA),
      'Invoice A total should match aggregate'
    );
    Assert.areEqual(
      750.00,
      totals.get(invoiceB),
      'Invoice B total should match aggregate'
    );
  }

  @IsTest
  static void shouldReturnZeroTotalWhenAggregateSumIsNull() {
    Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    SOQL.mock('PaymentService.getPaymentTotals')
      .thenReturn(
        new List<Map<String, Object>>{
          new Map<String, Object>{
            'Invoice__c' => invoiceId,
            'totalAmount' => null
          }
        }
      );

    PaymentService service = new PaymentService();

    Test.startTest();
    Map<Id, Decimal> totals = service.getPaymentTotals(
      new Set<Id>{ invoiceId }
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      totals.get(invoiceId),
      'Null aggregate sum should be coerced to zero'
    );
  }

  @IsTest
  static void shouldHandleBulkPaymentValidation() {
    List<Id> invoiceIds = new List<Id>();
    List<Invoice__c> invoices = new List<Invoice__c>();
    List<Map<String, Object>> aggregateResults = new List<Map<String, Object>>();

    for (Integer i = 0; i < 10; i++) {
      Id invoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
      invoiceIds.add(invoiceId);
      invoices.add(
        new Invoice__c(Id = invoiceId, Status__c = 'Sent', Amount__c = 10000.00)
      );
      aggregateResults.add(
        new Map<String, Object>{
          'Invoice__c' => invoiceId,
          'totalAmount' => 0.00
        }
      );
    }

    SOQL.mock('PaymentService.getInvoicesForValidation').thenReturn(invoices);
    SOQL.mock('PaymentService.getPaymentTotals').thenReturn(aggregateResults);

    List<Payment__c> payments = new List<Payment__c>();
    for (Integer i = 0; i < 200; i++) {
      payments.add(
        new Payment__c(
          Invoice__c = invoiceIds[Math.mod(i, 10)],
          Amount__c = 10.00
        )
      );
    }

    PaymentService service = new PaymentService();

    Test.startTest();
    service.validatePaymentsOnInsert(payments);
    Test.stopTest();

    for (Payment__c payment : payments) {
      Assert.isFalse(
        payment.hasErrors(),
        'Bulk payments within balance should not have errors'
      );
    }
  }
}
