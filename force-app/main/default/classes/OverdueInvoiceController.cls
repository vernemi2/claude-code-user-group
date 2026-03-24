public with sharing class OverdueInvoiceController {
  @AuraEnabled(cacheable=true)
  public static InvoiceService.OverdueInvoiceSummary getOverdueInvoiceSummary(
    Id accountId
  ) {
    if (accountId == null) {
      InvoiceService.OverdueInvoiceSummary empty = new InvoiceService.OverdueInvoiceSummary();
      empty.overdueCount = 0;
      empty.totalOverdueAmount = 0;
      return empty;
    }

    InvoiceService service = (InvoiceService) InstanceProvider.provide(
      InvoiceService.class
    );
    return service.getOverdueInvoiceSummary(accountId);
  }
}
