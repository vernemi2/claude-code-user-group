@IsTest
private class PaymentControllerTest {
  @IsTest
  static void shouldReturnPaymentsForValidInvoiceId() {
    Id fakeInvoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    List<Payment__c> mockPayments = new List<Payment__c>{
      new Payment__c(Amount__c = 200.00, Invoice__c = fakeInvoiceId),
      new Payment__c(Amount__c = 300.00, Invoice__c = fakeInvoiceId)
    };

    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('getPaymentsForInvoice').thenReturn(mockPayments);
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    List<Payment__c> result = PaymentController.getPayments(fakeInvoiceId);
    Test.stopTest();

    Assert.areEqual(2, result.size(), 'Should return two mocked payments');
    mockInstance.assertThat().method('getPaymentsForInvoice').wasCalled(1);
  }

  @IsTest
  static void shouldReturnEmptyListWhenInvoiceIdIsNull() {
    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('getPaymentsForInvoice').thenReturnVoid();
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    List<Payment__c> result = PaymentController.getPayments(null);
    Test.stopTest();

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
    mockInstance.assertThat().method('getPaymentsForInvoice').wasNeverCalled();
  }

  @IsTest
  static void shouldReturnRemainingBalanceForValidInvoiceId() {
    Id fakeInvoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);

    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('getRemainingBalance').thenReturn(500.00);
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    Decimal result = PaymentController.getRemainingBalance(fakeInvoiceId);
    Test.stopTest();

    Assert.areEqual(500.00, result, 'Should return mocked remaining balance');
    mockInstance.assertThat().method('getRemainingBalance').wasCalled(1);
  }

  @IsTest
  static void shouldReturnZeroBalanceWhenInvoiceIdIsNull() {
    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('getRemainingBalance').thenReturnVoid();
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    Decimal result = PaymentController.getRemainingBalance(null);
    Test.stopTest();

    Assert.areEqual(0, result, 'Should return zero for null invoice ID');
    mockInstance.assertThat().method('getRemainingBalance').wasNeverCalled();
  }

  @IsTest
  static void shouldCreatePaymentSuccessfully() {
    Id fakeInvoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);
    Payment__c mockPayment = new Payment__c(
      Invoice__c = fakeInvoiceId,
      Amount__c = 150.00,
      Payment_Date__c = Date.today(),
      Payment_Method__c = 'Credit Card',
      Reference_Number__c = 'REF-001'
    );

    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('createPayment').thenReturn(mockPayment);
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    Payment__c result = PaymentController.createPayment(
      fakeInvoiceId,
      150.00,
      Date.today(),
      'Credit Card',
      'REF-001'
    );
    Test.stopTest();

    Assert.areEqual(
      150.00,
      result.Amount__c,
      'Should return mocked payment amount'
    );
    Assert.areEqual(
      fakeInvoiceId,
      result.Invoice__c,
      'Should return mocked payment invoice'
    );
    mockInstance.assertThat().method('createPayment').wasCalled(1);
  }

  @IsTest
  static void shouldThrowAuraExceptionOnCreateFailure() {
    Id fakeInvoiceId = SOQL.IdGenerator.get(Invoice__c.SObjectType);

    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance
      .when('createPayment')
      .thenThrow(new DmlException('Insert failed'));
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    try {
      PaymentController.createPayment(
        fakeInvoiceId,
        150.00,
        Date.today(),
        'Credit Card',
        'REF-001'
      );
      Assert.fail('Should have thrown AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
    }
    Test.stopTest();

    mockInstance.assertThat().method('createPayment').wasCalled(1);
  }
}
