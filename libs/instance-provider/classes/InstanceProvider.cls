public without sharing class InstanceProvider {
  // Stores mock implementations for types
  private static final Map<Type, Object> registeredMocks = new Map<Type, Object>();

  /**
   * Returns an instance of the requested type.
   * Returns the mock if one is registered; otherwise a new instance.
   */
  public static Object provide(Type targetType) {
    Object mock = registeredMocks.get(targetType);
    return mock ?? targetType.newInstance();
  }

  /**
   * Registers a mock instance to use instead of creating a new one.
   * Allowed only during test execution.
   */
  public static void injectMock(Type typeToMock, Object mockInstance) {
    if (!Test.isRunningTest()) {
      throw new InstanceProviderException(
        'injectMock can only be called during a test.'
      );
    }
    registeredMocks.put(typeToMock, mockInstance);
  }
  private class InstanceProviderException extends Exception {
  }
}
