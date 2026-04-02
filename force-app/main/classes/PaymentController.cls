public with sharing class PaymentController {
  @AuraEnabled(cacheable=true)
  public static List<Payment__c> getPayments(Id invoiceId) {
    if (invoiceId == null) {
      return new List<Payment__c>();
    }
    PaymentService service = (PaymentService) InstanceProvider.provide(
      PaymentService.class
    );
    return service.getPaymentsForInvoice(invoiceId);
  }

  @AuraEnabled(cacheable=true)
  public static Decimal getRemainingBalance(Id invoiceId) {
    if (invoiceId == null) {
      return 0;
    }
    PaymentService service = (PaymentService) InstanceProvider.provide(
      PaymentService.class
    );
    return service.getRemainingBalance(invoiceId);
  }

  @AuraEnabled
  public static Payment__c createPayment(
    Id invoiceId,
    Decimal amount,
    Date paymentDate,
    String paymentMethod,
    String referenceNumber
  ) {
    PaymentService service = (PaymentService) InstanceProvider.provide(
      PaymentService.class
    );
    Payment__c payment = new Payment__c(
      Invoice__c = invoiceId,
      Amount__c = amount,
      Payment_Date__c = paymentDate,
      Payment_Method__c = paymentMethod,
      Reference_Number__c = referenceNumber
    );
    try {
      return service.createPayment(payment);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}
