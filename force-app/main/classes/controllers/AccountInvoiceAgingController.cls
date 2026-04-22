public with sharing class AccountInvoiceAgingController {
  @AuraEnabled(cacheable=true)
  public static InvoiceService.InvoiceAgingBreakdown getAgingBreakdown(
    Id accountId
  ) {
    InvoiceService service = (InvoiceService) InstanceProvider.provide(
      InvoiceService.class
    );
    return service.getAgingBreakdown(accountId);
  }
}
