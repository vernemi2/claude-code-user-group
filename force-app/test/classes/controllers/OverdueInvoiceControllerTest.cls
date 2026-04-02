@IsTest
private class OverdueInvoiceControllerTest {
  @IsTest
  static void shouldReturnSummaryForValidAccountId() {
    InvoiceService.OverdueInvoiceSummary mockSummary = new InvoiceService.OverdueInvoiceSummary();
    mockSummary.overdueCount = 3;
    mockSummary.totalOverdueAmount = 1500.00;

    UniversalMocker mockInstance = UniversalMocker.mock(InvoiceService.class);
    mockInstance.when('getOverdueInvoiceSummary').thenReturn(mockSummary);
    InstanceProvider.injectMock(
      InvoiceService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = OverdueInvoiceController.getOverdueInvoiceSummary(
      SOQL.IdGenerator.get(Account.SObjectType)
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      result.overdueCount,
      'Should return mocked overdue count'
    );
    Assert.areEqual(
      1500.00,
      result.totalOverdueAmount,
      'Should return mocked total amount'
    );
    mockInstance.assertThat().method('getOverdueInvoiceSummary').wasCalled(1);
  }

  @IsTest
  static void shouldReturnEmptySummaryWhenAccountIdIsNull() {
    UniversalMocker mockInstance = UniversalMocker.mock(InvoiceService.class);
    mockInstance.when('getOverdueInvoiceSummary').thenReturnVoid();
    InstanceProvider.injectMock(
      InvoiceService.class,
      mockInstance.createStub()
    );

    Test.startTest();
    InvoiceService.OverdueInvoiceSummary result = OverdueInvoiceController.getOverdueInvoiceSummary(
      null
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      result.overdueCount,
      'Should return zero count for null account'
    );
    Assert.areEqual(
      0,
      result.totalOverdueAmount,
      'Should return zero amount for null account'
    );
    mockInstance.assertThat()
      .method('getOverdueInvoiceSummary')
      .wasNeverCalled();
  }
}
