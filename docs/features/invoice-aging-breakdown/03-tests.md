# Tests — Invoice Aging Breakdown

## New / Updated Test Artifacts

- `force-app/test/classes/controllers/AccountInvoiceAgingControllerTest.cls` — new
- `force-app/test/classes/services/InvoiceServiceTest.cls` — extended with `getAgingBreakdown` coverage
- `force-app/test/classes/services/PaymentServiceTest.cls` — added direct `getPaymentTotals` coverage
- `force-app/test/classes/selectors/SOQL_InvoiceTest.cls` — added `unpaid()` filter tests
- `force-app/main/lwc/accountInvoiceAgingBreakdown/__tests__/accountInvoiceAgingBreakdown.test.js` — new

## Apex Results

- Run: `sf apex run test --test-level RunLocalTests --code-coverage`
- Tests Ran: 590
- Passed: 590
- Failed: 0
- Org-wide coverage: 88%

### Coverage for target classes

| Class                           | Coverage |
| ------------------------------- | -------- |
| `InvoiceService`                | 100%     |
| `SOQL_Invoice`                  | 100%     |
| `PaymentService`                | 95%      |
| `AccountInvoiceAgingController` | 100%     |

All feature classes meet or exceed the 95% bar.

### InvoiceService aging-breakdown scenarios covered

- Null `accountId` short-circuits without SOQL and returns five empty buckets
- Empty account (no unpaid invoices) returns five empty buckets
- Draft invoice always classified as Current regardless of due date
- Null due date classified as Current
- Boundary days covered: 0, 1, 30, 31, 60, 61, 90, 91
- Partial payments subtract from remaining balance before bucketing
- Fully paid invoices excluded from breakdown
- Null invoice amount handled gracefully (excluded)
- Severity assignment validated for every bucket
- Bulk aggregation of 200 invoices in a single invocation

### SOQL_Invoice scenarios covered

- `unpaid()` filter returns mocked unpaid invoices
- `unpaid()` chains with `byAccountId()` filter

### AccountInvoiceAgingController scenarios covered

- Returns service breakdown for valid account id (delegates via `InstanceProvider`)
- Null accountId returns five empty buckets without invoking the service

### PaymentService scenarios covered (new)

- `getPaymentTotals` maps aggregate totals per invoice id
- `getPaymentTotals` coerces null aggregate sums to zero

## Jest Results

- Run: `npm run test:unit`
- Test suites: 5 passed
- Tests: 45 passed, 0 failed

### accountInvoiceAgingBreakdown coverage

- Loading state (spinner before wire emits)
- Data state with five bucket tiles
- Empty state rendered when `totalUnpaidCount === 0`
- Error state shows `Aging breakdown unavailable` badge
- Currency formatting (locale-aware amount, singular/plural count labels, zero-count label)
- Navigation to `Account.Invoices__r` related list on tile click
- Accessibility (non-empty `aria-label` on every tile)

## Self-Heal Cycles

- 0 iterations — deploy succeeded on the first attempt and all tests passed on the first run.

## Remaining TODOs

- None.
