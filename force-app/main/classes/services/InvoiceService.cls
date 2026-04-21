public with sharing class InvoiceService {
  private static final Integer DEFAULT_DAYS = 30;
  private static final Map<String, Integer> TERM_TO_DAYS = new Map<String, Integer>{
    'Due on Receipt' => 0,
    'Net 15' => 15,
    'Net 30' => 30,
    'Net 45' => 45,
    'Net 60' => 60,
    'Net 90' => 90
  };

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

  public void populateDueDates(List<Invoice__c> invoices) {
    List<Invoice__c> candidates = new List<Invoice__c>();
    Set<Id> accountIds = new Set<Id>();
    for (Invoice__c invoice : invoices) {
      if (invoice.Due_Date__c != null) {
        continue;
      }
      candidates.add(invoice);
      if (invoice.Account__c != null) {
        accountIds.add(invoice.Account__c);
      }
    }

    if (candidates.isEmpty()) {
      return;
    }

    Map<Id, Account> accountsById = accountIds.isEmpty()
      ? new Map<Id, Account>()
      : new Map<Id, Account>(
          (List<Account>) SOQL_Account.query()
            .byIds(accountIds)
            .mockId('InvoiceService.getPaymentTerms')
            .toList()
        );

    for (Invoice__c invoice : candidates) {
      Date anchor = invoice.Invoice_Date__c != null
        ? invoice.Invoice_Date__c
        : Date.today();
      Account account = invoice.Account__c != null
        ? accountsById.get(invoice.Account__c)
        : null;
      String term = account != null ? account.Payment_Terms__c : null;
      Integer days = term != null && TERM_TO_DAYS.containsKey(term)
        ? TERM_TO_DAYS.get(term)
        : DEFAULT_DAYS;
      invoice.Due_Date__c = anchor.addDays(days);
    }
  }

  public class OverdueInvoiceSummary {
    @AuraEnabled
    public Integer overdueCount;
    @AuraEnabled
    public Decimal totalOverdueAmount;
  }
}
