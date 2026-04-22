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

  private static final String BUCKET_CURRENT = 'Current';
  private static final String BUCKET_1_30 = '1-30 days';
  private static final String BUCKET_31_60 = '31-60 days';
  private static final String BUCKET_61_90 = '61-90 days';
  private static final String BUCKET_90_PLUS = '90+ days';

  private static final String SEVERITY_CURRENT = 'current';
  private static final String SEVERITY_LOW = 'low';
  private static final String SEVERITY_MEDIUM = 'medium';
  private static final String SEVERITY_HIGH = 'high';
  private static final String SEVERITY_CRITICAL = 'critical';

  private final PaymentService paymentService;

  public InvoiceService() {
    this.paymentService = (PaymentService) InstanceProvider.provide(
      PaymentService.class
    );
  }

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

  public InvoiceAgingBreakdown getAgingBreakdown(Id accountId) {
    if (accountId == null) {
      return buildEmptyBreakdown();
    }

    List<Invoice__c> unpaidInvoices = SOQL_Invoice.query()
      .unpaid()
      .byAccountId(accountId)
      .mockId('InvoiceService.getUnpaidInvoices')
      .toList();

    if (unpaidInvoices.isEmpty()) {
      return buildEmptyBreakdown();
    }

    Set<Id> invoiceIds = new Set<Id>();
    for (Invoice__c invoice : unpaidInvoices) {
      invoiceIds.add(invoice.Id);
    }

    Map<Id, Decimal> paymentTotalsByInvoice = paymentService.getPaymentTotals(
      invoiceIds
    );

    Map<String, AgingBucket> bucketsByLabel = buildEmptyBucketMap();
    Decimal totalUnpaidAmount = 0;
    Integer totalUnpaidCount = 0;
    Date today = Date.today();

    for (Invoice__c invoice : unpaidInvoices) {
      Decimal invoiceAmount = invoice.Amount__c != null ? invoice.Amount__c : 0;
      Decimal paid = paymentTotalsByInvoice.containsKey(invoice.Id)
        ? paymentTotalsByInvoice.get(invoice.Id)
        : 0;
      Decimal remainingBalance = invoiceAmount - paid;

      if (remainingBalance <= 0) {
        continue;
      }

      String label = classifyBucket(
        invoice.Status__c,
        invoice.Due_Date__c,
        today
      );
      AgingBucket bucket = bucketsByLabel.get(label);
      bucket.count += 1;
      bucket.totalAmount += remainingBalance;

      totalUnpaidAmount += remainingBalance;
      totalUnpaidCount += 1;
    }

    InvoiceAgingBreakdown breakdown = new InvoiceAgingBreakdown();
    breakdown.buckets = orderedBuckets(bucketsByLabel);
    breakdown.totalUnpaidAmount = totalUnpaidAmount;
    breakdown.totalUnpaidCount = totalUnpaidCount;
    return breakdown;
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

  private String classifyBucket(String status, Date dueDate, Date today) {
    if (status == 'Draft' || dueDate == null) {
      return BUCKET_CURRENT;
    }
    Integer daysOverdue = dueDate.daysBetween(today);
    if (daysOverdue <= 0) {
      return BUCKET_CURRENT;
    }
    if (daysOverdue <= 30) {
      return BUCKET_1_30;
    }
    if (daysOverdue <= 60) {
      return BUCKET_31_60;
    }
    if (daysOverdue <= 90) {
      return BUCKET_61_90;
    }
    return BUCKET_90_PLUS;
  }

  private Map<String, AgingBucket> buildEmptyBucketMap() {
    Map<String, AgingBucket> buckets = new Map<String, AgingBucket>();
    buckets.put(BUCKET_CURRENT, newBucket(BUCKET_CURRENT, SEVERITY_CURRENT));
    buckets.put(BUCKET_1_30, newBucket(BUCKET_1_30, SEVERITY_LOW));
    buckets.put(BUCKET_31_60, newBucket(BUCKET_31_60, SEVERITY_MEDIUM));
    buckets.put(BUCKET_61_90, newBucket(BUCKET_61_90, SEVERITY_HIGH));
    buckets.put(BUCKET_90_PLUS, newBucket(BUCKET_90_PLUS, SEVERITY_CRITICAL));
    return buckets;
  }

  private List<AgingBucket> orderedBuckets(
    Map<String, AgingBucket> bucketsByLabel
  ) {
    return new List<AgingBucket>{
      bucketsByLabel.get(BUCKET_CURRENT),
      bucketsByLabel.get(BUCKET_1_30),
      bucketsByLabel.get(BUCKET_31_60),
      bucketsByLabel.get(BUCKET_61_90),
      bucketsByLabel.get(BUCKET_90_PLUS)
    };
  }

  private AgingBucket newBucket(String label, String severity) {
    AgingBucket bucket = new AgingBucket();
    bucket.label = label;
    bucket.severity = severity;
    bucket.count = 0;
    bucket.totalAmount = 0;
    return bucket;
  }

  private InvoiceAgingBreakdown buildEmptyBreakdown() {
    InvoiceAgingBreakdown breakdown = new InvoiceAgingBreakdown();
    breakdown.buckets = orderedBuckets(buildEmptyBucketMap());
    breakdown.totalUnpaidAmount = 0;
    breakdown.totalUnpaidCount = 0;
    return breakdown;
  }

  public class OverdueInvoiceSummary {
    @AuraEnabled
    public Integer overdueCount;
    @AuraEnabled
    public Decimal totalOverdueAmount;
  }

  public class InvoiceAgingBreakdown {
    @AuraEnabled
    public List<AgingBucket> buckets;
    @AuraEnabled
    public Decimal totalUnpaidAmount;
    @AuraEnabled
    public Integer totalUnpaidCount;
  }

  public class AgingBucket {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String severity;
    @AuraEnabled
    public Integer count;
    @AuraEnabled
    public Decimal totalAmount;
  }
}
