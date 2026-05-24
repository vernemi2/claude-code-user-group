@IsTest
private class AccountInvoiceAgingControllerTest {
  @IsTest
  static void shouldReturnBreakdownFromServiceForValidAccount() {
    InvoiceService.InvoiceAgingBreakdown mockBreakdown = new InvoiceService.InvoiceAgingBreakdown();
    InvoiceService.AgingBucket bucket = new InvoiceService.AgingBucket();
    bucket.label = 'Current';
    bucket.severity = 'current';
    bucket.count = 2;
    bucket.totalAmount = 500.00;
    mockBreakdown.buckets = new List<InvoiceService.AgingBucket>{ bucket };
    mockBreakdown.totalUnpaidCount = 2;
    mockBreakdown.totalUnpaidAmount = 500.00;

    UniversalMocker mockInstance = UniversalMocker.mock(InvoiceService.class);
    mockInstance.when('getAgingBreakdown').thenReturn(mockBreakdown);
    InstanceProvider.injectMock(
      InvoiceService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown result = AccountInvoiceAgingController.getAgingBreakdown(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      result.totalUnpaidCount,
      'Controller should return mocked count'
    );
    Assert.areEqual(
      500.00,
      result.totalUnpaidAmount,
      'Controller should return mocked amount'
    );
    Assert.areEqual(
      1,
      result.buckets.size(),
      'Controller should return mocked buckets'
    );
    mockInstance.assertThat().method('getAgingBreakdown').wasCalled(1);
  }

  @IsTest
  static void shouldDelegateToServiceWhenAccountIdIsNull() {
    InvoiceService.InvoiceAgingBreakdown emptyBreakdown = new InvoiceService.InvoiceAgingBreakdown();
    emptyBreakdown.buckets = new List<InvoiceService.AgingBucket>();
    emptyBreakdown.totalUnpaidCount = 0;
    emptyBreakdown.totalUnpaidAmount = 0;

    UniversalMocker mockInstance = UniversalMocker.mock(InvoiceService.class);
    mockInstance.when('getAgingBreakdown').thenReturn(emptyBreakdown);
    InstanceProvider.injectMock(
      InvoiceService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    InvoiceService.InvoiceAgingBreakdown result = AccountInvoiceAgingController.getAgingBreakdown(
      null
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      result.totalUnpaidCount,
      'Null accountId should yield zero count'
    );
    Assert.areEqual(
      0,
      result.totalUnpaidAmount,
      'Null accountId should yield zero amount'
    );
    mockInstance.assertThat().method('getAgingBreakdown').wasCalled(1);
  }
}
