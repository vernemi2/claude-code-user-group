@IsTest
private class InvoiceTriggerHandlerTest {
  @IsTest
  static void shouldResolveInvoiceServiceViaInstanceProvider() {
    UniversalMocker serviceMock = UniversalMocker.mock(InvoiceService.class);
    serviceMock.when('populateDueDates').thenReturnVoid();
    InstanceProvider.injectMock(InvoiceService.class, serviceMock.createStub());

    Test.startTest();
    InvoiceTriggerHandler handler = new InvoiceTriggerHandler();
    Test.stopTest();

    Assert.isNotNull(
      handler,
      'Handler should instantiate with injected service'
    );
  }

  @IsTest
  static void shouldDelegateBeforeInsertToInvoiceService() {
    UniversalMocker serviceMock = UniversalMocker.mock(InvoiceService.class);
    serviceMock.when('populateDueDates').thenReturnVoid();
    InstanceProvider.injectMock(InvoiceService.class, serviceMock.createStub());
    List<Invoice__c> newInvoices = new List<Invoice__c>{
      new Invoice__c(Invoice_Date__c = Date.today())
    };
    InvoiceTriggerHandlerHarness harness = new InvoiceTriggerHandlerHarness();

    Test.startTest();
    harness.invokeBeforeInsert(newInvoices);
    Test.stopTest();

    serviceMock.assertThat().method('populateDueDates').wasCalled(1);
    List<Invoice__c> passed = (List<Invoice__c>) serviceMock
      .forMethod('populateDueDates')
      .andInvocationNumber(0)
      .getValueOf('invoices');
    Assert.areEqual(
      newInvoices,
      passed,
      'Handler should forward Trigger.new to the service'
    );
  }

  private class InvoiceTriggerHandlerHarness extends InvoiceTriggerHandler {
    public void invokeBeforeInsert(List<Invoice__c> newInvoices) {
      this.beforeInsert((List<SObject>) newInvoices);
    }
  }
}
