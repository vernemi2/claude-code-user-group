@IsTest
private class InstanceProviderTest {
  @IsTest
  static void testInstanceProvider() {
    TestService service = (TestService) InstanceProvider.provide(
      TestService.class
    );

    Assert.areEqual(
      TestService.MESSAGE,
      service.getMessage(),
      'Expected a message to be returned!'
    );
  }
  @IsTest
  static void testInstanceProviderMock() {
    UniversalMocker serviceMock = UniversalMocker.mock(TestService.class);
    serviceMock.when('getMessage').thenReturn('Hello Mock!');

    InstanceProvider.injectMock(TestService.class, serviceMock.createStub());

    TestService service = (TestService) InstanceProvider.provide(
      TestService.class
    );

    Assert.areEqual(
      'Hello Mock!',
      service.getMessage(),
      'Expected a message to be returned!'
    );
  }
}
