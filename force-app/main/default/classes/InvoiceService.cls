public with sharing class InvoiceService {
  public OverdueInvoiceSummary getOverdueInvoiceSummary(Id accountId) {
    List<Invoice__c> overdueInvoices = SOQL_Invoice.query()
      .byAccountId(accountId)
      .overdue()
      .mockId('InvoiceService.getOverdueInvoices')
      .toList();

    Decimal totalAmount = 0;
    for (Invoice__c invoice : overdueInvoices) {
      totalAmount += invoice.Amount__c != null ? invoice.Amount__c : 0;
    }

    OverdueInvoiceSummary summary = new OverdueInvoiceSummary();
    summary.overdueCount = overdueInvoices.size();
    summary.totalOverdueAmount = totalAmount;
    return summary;
  }

  public class OverdueInvoiceSummary {
    @AuraEnabled
    public Integer overdueCount;
    @AuraEnabled
    public Decimal totalOverdueAmount;
  }
}
