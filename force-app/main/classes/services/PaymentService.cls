public with sharing class PaymentService {
  private static final Set<String> INVALID_STATUSES = new Set<String>{
    'Draft',
    'Cancelled'
  };

  public void validatePaymentsOnInsert(List<Payment__c> payments) {
    validatePayments(payments, null);
  }

  public void validatePaymentsOnUpdate(
    List<Payment__c> newPayments,
    Map<Id, SObject> oldPayments
  ) {
    validatePayments(newPayments, oldPayments);
  }

  public void syncInvoiceStatusAfterChange(Set<Id> invoiceIds) {
    if (invoiceIds.isEmpty()) {
      return;
    }

    List<Invoice__c> invoices = SOQL_Invoice.query()
      .with(Invoice__c.Amount__c, Invoice__c.Status__c)
      .byIds(invoiceIds)
      .mockId('PaymentService.getInvoicesForSync')
      .toList();

    Map<Id, Decimal> paymentTotalsByInvoice = getPaymentTotals(invoiceIds);

    List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
    for (Invoice__c invoice : invoices) {
      Decimal totalPayments = paymentTotalsByInvoice.containsKey(invoice.Id)
        ? paymentTotalsByInvoice.get(invoice.Id)
        : 0;
      Decimal invoiceAmount = invoice.Amount__c != null ? invoice.Amount__c : 0;

      if (totalPayments >= invoiceAmount && invoice.Status__c != 'Paid') {
        invoicesToUpdate.add(
          new Invoice__c(Id = invoice.Id, Status__c = 'Paid')
        );
      } else if (totalPayments < invoiceAmount && invoice.Status__c == 'Paid') {
        invoicesToUpdate.add(
          new Invoice__c(Id = invoice.Id, Status__c = 'Sent')
        );
      }
    }

    if (!invoicesToUpdate.isEmpty()) {
      new DML()
        .identifier('PaymentService.updateInvoiceStatus')
        .toUpdate(invoicesToUpdate)
        .commitWork();
    }
  }

  public List<Payment__c> getPaymentsForInvoice(Id invoiceId) {
    return SOQL_Payment.query()
      .byInvoiceId(invoiceId)
      .mockId('PaymentService.getPaymentsForInvoice')
      .toList();
  }

  public Decimal getRemainingBalance(Id invoiceId) {
    List<Invoice__c> invoices = SOQL_Invoice.query()
      .with(Invoice__c.Amount__c)
      .byId(invoiceId)
      .mockId('PaymentService.getInvoiceForBalance')
      .toList();

    if (invoices.isEmpty()) {
      return 0;
    }

    Decimal invoiceAmount = invoices[0].Amount__c != null
      ? invoices[0].Amount__c
      : 0;
    Decimal totalPayments = getTotalPaymentsForInvoice(invoiceId);
    return invoiceAmount - totalPayments;
  }

  public Payment__c createPayment(Payment__c payment) {
    new DML()
      .identifier('PaymentService.createPayment')
      .toInsert(payment)
      .commitWork();
    return payment;
  }

  private void validatePayments(
    List<Payment__c> payments,
    Map<Id, SObject> oldPayments
  ) {
    Set<Id> invoiceIds = new Set<Id>();
    for (Payment__c payment : payments) {
      invoiceIds.add(payment.Invoice__c);
    }

    Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>(
      (List<Invoice__c>) SOQL_Invoice.query()
        .with(Invoice__c.Amount__c, Invoice__c.Status__c)
        .byIds(invoiceIds)
        .mockId('PaymentService.getInvoicesForValidation')
        .toList()
    );

    Map<Id, Decimal> paymentTotalsByInvoice = getPaymentTotals(invoiceIds);

    for (Payment__c payment : payments) {
      Invoice__c invoice = invoiceMap.get(payment.Invoice__c);
      if (invoice == null) {
        continue;
      }

      if (INVALID_STATUSES.contains(invoice.Status__c)) {
        payment.addError(
          'Payments cannot be made against invoices in ' +
            invoice.Status__c +
            ' status.'
        );
        continue;
      }

      Decimal invoiceAmount = invoice.Amount__c != null ? invoice.Amount__c : 0;
      Decimal existingTotal = paymentTotalsByInvoice.containsKey(invoice.Id)
        ? paymentTotalsByInvoice.get(invoice.Id)
        : 0;

      if (oldPayments != null && oldPayments.containsKey(payment.Id)) {
        Payment__c oldPayment = (Payment__c) oldPayments.get(payment.Id);
        Decimal oldAmount = oldPayment.Amount__c != null
          ? oldPayment.Amount__c
          : 0;
        existingTotal -= oldAmount;
      }

      Decimal remainingBalance = invoiceAmount - existingTotal;
      if (payment.Amount__c > remainingBalance) {
        payment.addError(
          'Payment amount cannot exceed the remaining balance of ' +
            remainingBalance +
            '.'
        );
      }
    }
  }

  private Map<Id, Decimal> getPaymentTotals(Set<Id> invoiceIds) {
    Map<Id, Decimal> totals = new Map<Id, Decimal>();
    List<SOQL.AggregateResultProxy> results = SOQL.of(Payment__c.SObjectType)
      .with(Payment__c.Invoice__c)
      .sum(Payment__c.Amount__c, 'totalAmount')
      .whereAre(SOQL.Filter.with(Payment__c.Invoice__c).isIn(invoiceIds))
      .groupBy(Payment__c.Invoice__c)
      .systemMode()
      .withoutSharing()
      .mockId('PaymentService.getPaymentTotals')
      .toAggregatedProxy();

    for (SOQL.AggregateResultProxy ar : results) {
      Id invoiceId = (Id) ar.get('Invoice__c');
      Decimal total = (Decimal) ar.get('totalAmount');
      totals.put(invoiceId, total != null ? total : 0);
    }
    return totals;
  }

  private Decimal getTotalPaymentsForInvoice(Id invoiceId) {
    Map<Id, Decimal> totals = getPaymentTotals(new Set<Id>{ invoiceId });
    return totals.containsKey(invoiceId) ? totals.get(invoiceId) : 0;
  }
}
