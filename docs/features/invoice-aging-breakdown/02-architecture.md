# Architecture: Invoice Aging Breakdown on Account Page

## Summary

Read-only, on-demand aging breakdown of unpaid invoices per Account, rendered as five clickable tiles (Current, 1-30, 31-60, 61-90, 90+) in a `lightning-card` injected into the Account record page just below the existing overdue-invoice badge. Server-side bucketing in Apex over a single unpaid-invoice SOQL plus a single aggregate `Payment__c` sum — no per-record queries, no schema changes, no triggers, no scheduled jobs.

## Scope boundaries (non-changes)

- No new custom objects or fields. `Invoice__c` and `Payment__c` already have everything required.
- No trigger work. Aging is a read-time derivation.
- No permission set edits. `InvoiceUser` already grants read on `Invoice__c` and `Payment__c`.
- No DML. This feature is read-only.
- No DML Lib use (no writes).
- Flexipage activation step is manual after deploy (per CLAUDE.md checklist item 3).

## Data model

Reused only; no changes:

| Object       | Field         | Purpose                                        |
| ------------ | ------------- | ---------------------------------------------- |
| `Invoice__c` | `Account__c`  | Filter scope                                   |
| `Invoice__c` | `Amount__c`   | Gross invoice total                            |
| `Invoice__c` | `Due_Date__c` | Bucket classification key (nullable → Current) |
| `Invoice__c` | `Status__c`   | Unpaid filter + Draft → Current override       |
| `Payment__c` | `Invoice__c`  | Parent link for aggregate SUM                  |
| `Payment__c` | `Amount__c`   | Subtracted from gross to get remaining balance |

## Aging algorithm (single in-memory pass)

Inputs per Account:

1. `SOQL_Invoice.query().unpaid().byAccountId(id)` returning Id, Amount**c, Due_Date**c, Status\_\_c.
2. `PaymentService.getPaymentTotals(Set<Id> invoiceIds)` returning `Map<Id, Decimal>`.

For each unpaid invoice:

- `remainingBalance = Amount__c - (payments.get(Id) ?? 0)`
- If `remainingBalance <= 0` → skip (defensive, handles status-sync race).
- If `Status__c == 'Draft'` OR `Due_Date__c == null` → `Current`.
- Else `daysOverdue = Date.today().daysBetween(...)` logic via `Due_Date__c.daysBetween(Date.today())`:
  - `<= 0` → `Current`
  - `1..30` → `1-30`
  - `31..60` → `31-60`
  - `61..90` → `61-90`
  - `> 90` → `90+`

Bucket list is emitted in fixed order regardless of emptiness; the LWC decides whether to render all-zero as empty-state.

## Apex architecture

### Layers and flow

```
LWC (accountInvoiceAgingBreakdown)
   │  @wire(getAgingBreakdown, { accountId: $recordId })
   ▼
AccountInvoiceAgingController.getAgingBreakdown(Id)        [cacheable=true]
   │  InstanceProvider.provide(InvoiceService.class)
   ▼
InvoiceService.getAgingBreakdown(Id)
   ├─ SOQL_Invoice.query().unpaid().byAccountId(id).toList()
   └─ PaymentService.getPaymentTotals(invoiceIds)           [now public]
   ▼
InvoiceService.InvoiceAgingBreakdown (DTO)
```

### DTO shape

```apex
public class InvoiceAgingBreakdown {
    @AuraEnabled public List<AgingBucket> buckets;
    @AuraEnabled public Decimal totalUnpaidAmount;
    @AuraEnabled public Integer totalUnpaidCount;
}

public class AgingBucket {
    @AuraEnabled public String label;       // 'Current', '1-30 days', '31-60 days', '61-90 days', '90+ days'
    @AuraEnabled public String severity;    // 'current' | 'low' | 'medium' | 'high' | 'critical'
    @AuraEnabled public Integer count;
    @AuraEnabled public Decimal totalAmount;
}
```

Severity mapping (returned from service, not LWC):

| Bucket     | Severity   | SLDS badge variant (LWC)    |
| ---------- | ---------- | --------------------------- |
| Current    | `current`  | `inverse` (neutral)         |
| 1-30 days  | `low`      | `warning`                   |
| 31-60 days | `medium`   | `warning`                   |
| 61-90 days | `high`     | `error`                     |
| 90+ days   | `critical` | `error` (with warning icon) |

## LWC architecture

### Component: `accountInvoiceAgingBreakdown`

- **Mount point**: Account record page, `main` region, between `c:accountOverdueInvoiceBadge` and `force:detailPanel`.
- **Target**: `lightning__RecordPage` constrained to `Account`.
- **Data**: `@wire` on `AccountInvoiceAgingController.getAgingBreakdown` with `$recordId`.
- **Navigation**: `NavigationMixin` → `standard__recordRelationshipPage` with `relationshipApiName: 'Invoices__r'`. Each bucket click fires the same navigation (v1 — per-bucket filter is v2).
- **Currency formatting**: `@salesforce/i18n/locale` + `@salesforce/i18n/currency` + `Intl.NumberFormat`.
- **Layout**: CSS grid `repeat(auto-fit, minmax(140px, 1fr))` for responsive stacking.

### States

| State                           | Rendered output                                                                      |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| Loading (no data, no error)     | `lightning-spinner size="small"` anchored top-right of the card                      |
| Error (wire error)              | Inline `lightning-badge` with `utility:warning` icon + "Aging breakdown unavailable" |
| Empty (`totalUnpaidCount == 0`) | Single success row: "No outstanding invoices" with `utility:success` icon            |
| Populated                       | Five tiles in fixed order, each a `<button>` with SLDS badge for severity            |

### Tile content per bucket

- Top severity accent bar (CSS, driven by `severity` class).
- Label (e.g. "31-60 days").
- Primary: currency-formatted `totalAmount` (bold, large).
- Secondary: `"N invoice"` / `"N invoices"` (pluralized).
- `aria-label` for a11y: `"31-60 days: 4 invoices totaling $12,340. Open related invoices."`

## Task plan

### Phase 1 — Apex selector (no dependencies)

1. **Modify** `force-app/main/classes/selectors/SOQL_Invoice.cls`
   - Add `public SOQL_Invoice unpaid()` method applying `SOQL.Filter.with(Invoice__c.Status__c).notIn(new List<String>{ 'Paid', 'Cancelled' })`.
   - Do NOT alter existing `overdue()` method.
   - **Acceptance**: Fluent chain `SOQL_Invoice.query().unpaid().byAccountId(id)` compiles and executes with correct `WHERE Status__c NOT IN ('Paid','Cancelled') AND Account__c = :id`.

### Phase 2 — Apex service (depends on 1)

2. **Modify** `force-app/main/classes/services/PaymentService.cls`
   - Change visibility of `getPaymentTotals(Set<Id>)` from `private` to `public`.
   - Keep existing signature and behavior unchanged (no callers need updating; existing tests continue to pass).
   - **Acceptance**: Method callable from `InvoiceService`; existing `PaymentServiceTest` remains green.

3. **Modify** `force-app/main/classes/services/InvoiceService.cls`
   - Inject `PaymentService` via `InstanceProvider.provide(PaymentService.class)` in constructor (introduce constructor if absent).
   - Add `public InvoiceAgingBreakdown getAgingBreakdown(Id accountId)`:
     - Null/invalid `accountId` → return an empty-but-well-formed DTO (five zero buckets, totals = 0/0).
     - Query unpaid invoices via `SOQL_Invoice.query().unpaid().byAccountId(accountId).mockId('InvoiceService.getUnpaidInvoices').toList()`.
     - Collect Ids, call `paymentService.getPaymentTotals(ids)`.
     - Bucket per algorithm above; accumulate running totals.
     - Populate five-element `List<AgingBucket>` in fixed order (even when a bucket is empty).
   - Add nested classes `InvoiceAgingBreakdown` and `AgingBucket` with `@AuraEnabled` fields as specified.
   - Introduce private helper `buildEmptyBreakdown()` for the null/empty short-circuit to keep bucketing logic testable.
   - **Acceptance**: Service callable without DI cycles; returns DTO with five buckets in fixed order; bulk-safe (no per-invoice queries); all existing InvoiceService behavior unchanged.

### Phase 3 — Apex controller (depends on 2)

4. **Create** `force-app/main/classes/controllers/AccountInvoiceAgingController.cls` (+ `-meta.xml` with `apiVersion=66.0`)
   - `public with sharing class AccountInvoiceAgingController`.
   - `@AuraEnabled(cacheable=true) public static InvoiceService.InvoiceAgingBreakdown getAgingBreakdown(Id accountId)`.
   - Null-`accountId` short-circuits to an empty DTO (mirrors `OverdueInvoiceController` pattern).
   - Delegates to `InvoiceService` via `InstanceProvider.provide(InvoiceService.class)`.
   - **Acceptance**: Method visible via `@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown`; cacheable.

### Phase 4 — LWC (depends on 3)

5. **Create** `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.js`
   - Extends `NavigationMixin(LightningElement)`.
   - `@api recordId`, `@wire(getAgingBreakdown, { accountId: '$recordId' }) breakdown`.
   - Getters: `isLoading`, `hasError`, `hasData`, `buckets` (normalized from DTO, computed only from `data`), `isEmpty` (`totalUnpaidCount == 0`).
   - `formatCurrency(amount)` helper using `Intl.NumberFormat(LOCALE, { style: 'currency', currency: CURRENCY })`.
   - Each bucket exposed to template with pre-computed `formattedAmount`, `countLabel` (`"N invoice(s)"`), `badgeVariant` (mapping severity → SLDS variant), `iconName`, `ariaLabel`, `cssClass`.
   - `handleBucketClick(event)` reads `data-bucket-label` and navigates via `NavigationMixin` to `standard__recordRelationshipPage` → `Invoices__r`.
   - **Acceptance**: No console errors; re-renders on `@wire` data change.

6. **Create** `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.html`
   - `lightning-card` title "Invoice Aging", icon `standard:invoice`.
   - Conditional blocks for `isLoading` / `hasError` / `isEmpty` / populated.
   - Populated: `<div class="grid">` with `template for:each` over `buckets` emitting `<button>` tiles.
   - Each tile contains severity accent bar + label + formatted amount + count line.
   - **Acceptance**: Renders five tiles when data present; collapses to empty row when zero; buttons are real `<button>` elements for a11y.

7. **Create** `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.css`
   - `.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: var(--lwc-spacingSmall, 0.75rem); }`.
   - Severity classes: `.severity-current`, `.severity-low`, `.severity-medium`, `.severity-high`, `.severity-critical` with border-top accent colors.
   - Tile button reset (no default browser button chrome).
   - **Acceptance**: Tiles render horizontally on desktop, stack on narrow viewports.

8. **Create** `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.js-meta.xml`
   - `apiVersion=66.0`, `isExposed=true`, `masterLabel="Account Invoice Aging Breakdown"`, target `lightning__RecordPage` scoped to `Account`.
   - **Acceptance**: Component addable to the Account page in Lightning App Builder.

### Phase 5 — Flexipage (depends on 8)

9. **Modify** `force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml`
   - Insert a new `itemInstances` block inside the `main` region **between** the existing `c_accountOverdueInvoiceBadge` block and the `force_detailPanel` block.
   - `componentName = c:accountInvoiceAgingBreakdown`, `identifier = c_accountInvoiceAgingBreakdown`.
   - **Acceptance**: After deploy + manual activation, the card appears between the badge and the detail panel.

### Phase 6 — Apex tests (depends on 1-4, ≥95% coverage)

10. **Modify** `force-app/test/classes/selectors/SOQL_InvoiceTest.cls`
    - Add test verifying `unpaid()` produces a query string containing the `Status__c NOT IN` clause and excluding due-date predicates.
    - **Acceptance**: Passes; selector behavior verified without live data.

11. **Modify** `force-app/test/classes/services/InvoiceServiceTest.cls`
    - Mock `SOQL.mock('InvoiceService.getUnpaidInvoices')` per scenario.
    - Mock `PaymentService` via `UniversalMocker` + `InstanceProvider.injectMock`, stubbing `getPaymentTotals(Set<Id>)` per scenario.
    - Scenarios:
      - Bucket boundaries: day 0 → Current; day 1 → 1-30; day 30 → 1-30; day 31 → 31-60; day 60 → 31-60; day 61 → 61-90; day 90 → 61-90; day 91 → 90+.
      - Draft with past due date → Current (status override).
      - Null `Due_Date__c` with Sent status → Current.
      - Invoice with fully-matching payments (remaining ≤ 0) → excluded from all buckets.
      - Invoice with partial payment → remaining balance used, not gross.
      - Cancelled/Paid invoices excluded (filtered by selector).
      - Empty account (no invoices) → DTO with five zero buckets, totals 0/0.
      - Null `accountId` → DTO with five zero buckets, totals 0/0, no SOQL/mock calls.
      - Totals: `totalUnpaidAmount` = sum of bucket amounts; `totalUnpaidCount` = sum of bucket counts.
      - Fixed bucket ordering: `[Current, 1-30 days, 31-60 days, 61-90 days, 90+ days]`.
    - **Acceptance**: ≥95% coverage on `InvoiceService`; all boundary cases green.

12. **Create** `force-app/test/classes/controllers/AccountInvoiceAgingControllerTest.cls` (+ `-meta.xml`)
    - Mock `InvoiceService` via `UniversalMocker` + `InstanceProvider.injectMock`.
    - Scenarios:
      - Null `accountId` → returns empty DTO without invoking the service (`.wasNeverCalled()`).
      - Valid `accountId` → delegates to service exactly once (`.wasCalled(1)`) and returns the service's DTO.
    - **Acceptance**: ≥95% coverage on controller.

13. **Verify** existing `force-app/test/classes/services/PaymentServiceTest.cls` still passes after visibility change on `getPaymentTotals`.
    - No new test required (behavior unchanged).
    - **Acceptance**: `sf apex run test --class-names PaymentServiceTest` green.

### Phase 7 — Jest tests (depends on 8)

14. **Create** `force-app/main/lwc/accountInvoiceAgingBreakdown/__tests__/accountInvoiceAgingBreakdown.test.js`
    - Mock `getAgingBreakdown` wire adapter.
    - Import `flushPromises` from `c/testUtils` (do NOT inline).
    - Scenarios:
      - Renders spinner while wire has neither data nor error.
      - Renders error badge on wire error.
      - Renders "No outstanding invoices" when `totalUnpaidCount == 0`.
      - Renders exactly five tiles in the fixed order when populated.
      - Each tile formats `totalAmount` via user-locale currency.
      - Each tile uses correct SLDS badge variant per severity.
      - Click on a bucket button invokes `NavigationMixin.Navigate` with `standard__recordRelationshipPage` + `Invoices__r`.
      - `aria-label` correct for each state.
    - **Acceptance**: `npm run test:unit` passes for this component.

### Phase 8 — Code quality gates

15. `npm run lint` clean on all new/modified JS.
16. `npm run prettier` clean on all new/modified files.
17. `sf project deploy start --source-dir force-app/main --source-dir force-app/test` succeeds.
18. `sf apex run test --test-level RunLocalTests --result-format human --wait 10` succeeds; no regression.

### Phase 9 — Manual post-deploy

19. Activate `Account_Record_Page` flexipage as org default (Setup → Lightning App Builder or via the browser). CLAUDE.md deployment checklist item 3.

## File inventory (created / modified)

| Action | Path                                                                                             |
| ------ | ------------------------------------------------------------------------------------------------ |
| Modify | `force-app/main/classes/selectors/SOQL_Invoice.cls`                                              |
| Modify | `force-app/main/classes/services/PaymentService.cls`                                             |
| Modify | `force-app/main/classes/services/InvoiceService.cls`                                             |
| Create | `force-app/main/classes/controllers/AccountInvoiceAgingController.cls` (+ meta)                  |
| Create | `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.js`                |
| Create | `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.html`              |
| Create | `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.css`               |
| Create | `force-app/main/lwc/accountInvoiceAgingBreakdown/accountInvoiceAgingBreakdown.js-meta.xml`       |
| Modify | `force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml`                               |
| Modify | `force-app/test/classes/selectors/SOQL_InvoiceTest.cls`                                          |
| Modify | `force-app/test/classes/services/InvoiceServiceTest.cls`                                         |
| Create | `force-app/test/classes/controllers/AccountInvoiceAgingControllerTest.cls` (+ meta)              |
| Create | `force-app/main/lwc/accountInvoiceAgingBreakdown/__tests__/accountInvoiceAgingBreakdown.test.js` |

## Risk register

| Risk                                                   | Mitigation                                                                 |
| ------------------------------------------------------ | -------------------------------------------------------------------------- |
| Off-by-one at bucket edges                             | Explicit boundary tests at days 0/1/30/31/60/61/90/91                      |
| Race between payment insert and status sync            | Defensive `remainingBalance <= 0` exclusion in service                     |
| Null `Due_Date__c` producing NPE in date math          | Explicit null-check → Current bucket short-circuit                         |
| Large accounts (thousands of invoices)                 | Single SOQL + single aggregate + one in-memory pass; no loops with queries |
| Visibility change on `PaymentService.getPaymentTotals` | Backward-compatible (private → public); existing tests untouched           |
| Flexipage not showing new card post-deploy             | Manual activation step in post-deploy checklist                            |
| Multi-currency org                                     | Out of scope; single-currency assumed (matches existing badge)             |

## Non-goals (explicit v2 deferrals)

- Per-bucket filtered navigation (list view with filter params).
- Client-side refresh on payment creation (would need `getRecordNotifyChange` plumbing).
- Platform Cache layer.
- Scheduled aging materialization.
- Multi-currency support.
