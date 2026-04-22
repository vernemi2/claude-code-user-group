# Code Review — Invoice Aging Breakdown

Branch: `feature/invoice-aging-breakdown`
Reviewer: Senior Salesforce code reviewer (automated)
Scope: New Apex (SOQL_Invoice.unpaid, InvoiceService.getAgingBreakdown + DTOs, AccountInvoiceAgingController, PaymentService.getPaymentTotals visibility), LWC accountInvoiceAgingBreakdown, Account_Record_Page flexipage, and associated tests.

## Issues Found & Fixes Applied

### 1. Duplicated empty-breakdown construction between controller and service (Architecture / DRY)

**Issue.** `AccountInvoiceAgingController` declared its own `BucketSeed` inner class and a `buildEmptyBreakdown()` method that re-implemented the exact bucket/severity topology already owned by `InvoiceService` (private `buildEmptyBucketMap` + `buildEmptyBreakdown`). The controller also added a null-accountId short-circuit — but `InvoiceService.getAgingBreakdown` already handles `accountId == null` and returns an empty breakdown through the same canonical code path.

This is a SOLID / single-source-of-truth violation: if the bucket labels, ordering, or severity strings ever change, the controller and service would silently drift. The LWC `decorateBucket` logic and the Apex service are the bucket contract; the controller should be a thin pass-through.

**Fix.** Reduced `AccountInvoiceAgingController` to a minimal delegator. It now just resolves `InvoiceService` via `InstanceProvider` and calls `service.getAgingBreakdown(accountId)` — the service owns the null path and the bucket shape. Removed `BucketSeed`, `BUCKET_SEEDS`, and `buildEmptyBreakdown` from the controller.

**Test updated.** `AccountInvoiceAgingControllerTest.shouldReturnEmptyBreakdownAndSkipServiceWhenAccountIdIsNull` was renamed to `shouldDelegateToServiceWhenAccountIdIsNull` and rewritten to assert the service is now called exactly once for the null path (instead of asserting it is never called). Re-deployed and re-ran — both controller tests pass.

### 2. All other checklist items — PASS

#### Apex — Security

- No hardcoded record IDs. `SOQL.IdGenerator.get()` used in tests.
- No sensitive data in debug logs (no System.debug at all).
- `@AuraEnabled(cacheable=true)` used appropriately for a read-only wire.
- `PaymentService.getPaymentTotals` visibility widened from `private` to `public`. Justified: `InvoiceService.getAgingBreakdown` consumes it through the DI-resolved `paymentService` instance rather than reaching into a private helper or duplicating the aggregate query. The method's security posture (`.systemMode().withoutSharing()` for a single aggregate) is unchanged.

#### Apex — Performance / Bulk Safety

- `getAgingBreakdown` performs exactly 2 SOQL queries per invocation (unpaid invoices + aggregate payment totals) regardless of invoice count.
- No SOQL or DML inside loops.
- Existing bulk test `shouldBulkAggregateManyUnpaidInvoices` (200 invoices) demonstrates the loop is O(n) in memory only.
- Null `accountId` short-circuits before any query.
- Empty `unpaidInvoices` short-circuits before the aggregate query.

#### Apex — Architecture

- Service is instance-based, resolved via `InstanceProvider.provide()`. Dependency on `PaymentService` injected through the same mechanism.
- New `unpaid()` filter lives in `SOQL_Invoice` selector, not inline in the service.
- All SOQL via SOQL Lib fluent API (no raw SOQL strings). `.mockId()` tags attached to every query.
- No DML in this feature (read-only aggregation). Existing DML in `PaymentService` unchanged.
- DTOs (`InvoiceAgingBreakdown`, `AgingBucket`) live on `InvoiceService` with `@AuraEnabled` — correct layering.
- Controller is a thin `@AuraEnabled(cacheable=true)` pass-through after the fix above.

#### Apex — Testing

- Every class has a test class.
- Tests mock all dependencies: `SOQL.mock('InvoiceService.getUnpaidInvoices')`, `UniversalMocker` for `PaymentService`, `InstanceProvider.injectMock`.
- No `@TestSetup`, no `@SeeAllData`, no inserts — all SObjects constructed in-memory with `SOQL.IdGenerator.get()`.
- Coverage scenarios: null accountId, empty account, Draft-as-Current, null-due-date-as-Current, boundary day values (0, -1, -30, -31, -60, -61, -90, -91), partial payments / remaining balance, fully paid exclusion, null amount, severity mapping, 200-invoice bulk, and the new selector has both a standalone and a chained filter test.
- `Assert.areEqual(expected, actual, 'message')` used throughout with descriptive messages.
- `UniversalMocker.assertThat().method(...).wasCalled(n)` / `.wasNeverCalled()` used to verify interactions.
- Query-count assertion (`Limits.getQueries()`) used to prove the null-short-circuit really skips SOQL — nice touch.

#### LWC — Best Practices

- `@wire(getAgingBreakdown, { accountId: '$recordId' })` — reactive, cacheable.
- No direct DOM manipulation. No imperative Apex calls.
- Error state renders a non-toast badge ("Aging breakdown unavailable") instead of crashing the page — correct for a secondary dashboard widget.
- Empty state rendered with `role="status"`. Buckets rendered as `<button>` with `role="listitem"` inside a `role="list"`, each with a full `aria-label` synthesized from label/count/amount.
- Currency formatted via `Intl.NumberFormat(LOCALE, { style: 'currency', currency: CURRENCY })` using `@salesforce/i18n/locale` and `@salesforce/i18n/currency` — locale-aware, no hardcoded "$".
- `NavigationMixin` used for the tile click → related list navigation (no hash-hacking).
- Jest test imports `flushPromises` from `c/testUtils` per CLAUDE.md convention, covers loading/error/empty/populated states, accessibility, and click navigation.
- `.js-meta.xml` exposes the component only to `lightning__RecordPage` with `Account` restriction — correct target scoping.

#### Metadata

- `Account_Record_Page.flexipage-meta.xml` adds a new `<itemInstances>` for `c:accountInvoiceAgingBreakdown`. No activation metadata is included — reminder from the CLAUDE.md Deployment Checklist: flexipage activation is a separate org step if this is a fresh flexipage, but this is an existing active flexipage so no action needed.
- No new custom fields or objects — the feature is derived from existing `Invoice__c`, `Payment__c`, and `Account` fields. No permission-set changes required, and none were made. Correct.
- `AccountInvoiceAgingController.cls-meta.xml` uses API 66.0, matching the project default.

## Verification

- `npm run prettier` — unchanged (all files already formatted).
- `npx eslint 'force-app/main/lwc/**/*.js'` — clean (the `npm run lint` script fails because its glob includes an `aura/` folder that does not exist in this project; that is a pre-existing issue unrelated to this feature).
- `sf project deploy start --source-dir force-app/main --source-dir force-app/test --dry-run` — **Succeeded**.
- `sf apex run test --class-names AccountInvoiceAgingControllerTest` after the controller simplification — **2/2 pass**.

## Overall Quality Assessment

**Ship it.** After the one DRY fix, this is production-ready.

Strengths:

- Clean layering: selector → service → thin controller → LWC. No logic leaked into the controller after the fix.
- Proper DI via `InstanceProvider`, proper mocking via `UniversalMocker` + `SOQL.mock`.
- Payment-aware aging — uses remaining balance, not gross invoice amount. Excludes fully-paid invoices even though they somehow pass the `unpaid()` filter (defensive and correct).
- Boundary-day test coverage is thorough (every edge of every bucket).
- LWC is accessible, locale-aware, and degrades gracefully on error.
- Zero raw SOQL / raw DML / static service methods — fully compliant with CLAUDE.md hard rules.

Minor notes (not blockers, not fixed):

- `InvoiceService.getOverdueInvoiceSummary` still sums gross `Amount__c` without subtracting payments, while `getAgingBreakdown` correctly uses remaining balance. Consistency cleanup for a future pass — out of scope for this review.
- `PaymentService.getPaymentTotals` is now public; consider if the existing private helper `getTotalPaymentsForInvoice` (single-invoice wrapper) should also be reshaped or dropped for consistency. Not blocking.
