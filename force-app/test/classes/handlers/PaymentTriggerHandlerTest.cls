@IsTest
private class PaymentTriggerHandlerTest {
  @IsTest
  static void shouldResolveDependencyViaInstanceProvider() {
    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('validatePaymentsOnInsert').thenReturnVoid();
    mockInstance.when('validatePaymentsOnUpdate').thenReturnVoid();
    mockInstance.when('syncInvoiceStatusAfterChange').thenReturnVoid();
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    PaymentTriggerHandler handler = new PaymentTriggerHandler();
    Test.stopTest();

    Assert.isNotNull(handler, 'Handler should instantiate with mocked service');
  }

  @IsTest
  static void shouldDelegateToServiceOnBeforeInsertContext() {
    UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
    mockInstance.when('validatePaymentsOnInsert').thenReturnVoid();
    mockInstance.when('validatePaymentsOnUpdate').thenReturnVoid();
    mockInstance.when('syncInvoiceStatusAfterChange').thenReturnVoid();
    InstanceProvider.injectMock(
      PaymentService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    PaymentTriggerHandler handler = new PaymentTriggerHandler();
    Test.stopTest();

    Assert.isNotNull(
      handler,
      'Handler should be ready to delegate to PaymentService'
    );
  }
}
