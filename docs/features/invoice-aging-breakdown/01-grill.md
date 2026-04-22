# Grill: Invoice Aging Breakdown on Account Page

Input: "As an account manager, I want to see an aging breakdown of unpaid invoices (Current, 1-30, 31-60, 61-90, 90+ days overdue) on the Account page, so I can prioritize collections and assess credit risk at a glance."

## Resolved decisions

### 1. What data model already exists for invoices, and does it support aging?

- Question: Does an Invoice object with Due Date, Amount, Status, and Account lookup already exist?
- Answer: Yes. `Invoice__c` has `Account__c` (Lookup → Account), `Amount__c` (Currency 18,2, required), `Due_Date__c` (Date), `Invoice_Date__c` (Date), `Status__c` (restricted picklist: Draft, Sent, Paid, Overdue, Cancelled). `Payment__c` child object exists for partial payments.
- Reasoning: Verified at `force-app/main/objects/Invoice__c/fields/`. All inputs required for bucket computation (amount + due date + status + account link) are present — no schema changes required.

### 2. What counts as an "unpaid" invoice for this feature?

- Question: "Unpaid" could mean (a) `Status__c != 'Paid' AND != 'Cancelled'`, (b) any invoice with non-zero remaining balance, (c) only `Sent` and `Overdue` statuses.
- Answer: `Status__c NOT IN ('Paid', 'Cancelled')`. That includes `Draft`, `Sent`, and `Overdue`.
- Reasoning: `PaymentService.syncInvoiceStatusAfterChange` already auto-promotes an invoice to `Paid` when cumulative payments >= `Amount__c` and back to `Sent` otherwise. So Status is an authoritative proxy for "has remaining balance". Using the same predicate as `SOQL_Invoice.overdue()` keeps semantics consistent across the existing overdue badge, overdue banner, and this new breakdown. `Draft` remains visible in the "Current" bucket because AMs still want forward visibility on invoices queued for send.

### 3. Should `Draft` invoices appear in the breakdown at all?

- Question: Draft invoices are not yet issued to the customer — is their amount at risk?
- Answer: Include `Draft` only in the `Current` bucket (never overdue). If `Draft` somehow has `Due_Date__c < today`, still place it in `Current`.
- Reasoning: Draft is pre-issuance; marking it "61-90 days overdue" would mislead collections. But excluding it entirely hides legitimate forward-looking exposure. Compromise: drafts always count as Current regardless of due date. This is a deliberate deviation from pure date math, documented here for the architect.
- Follow-on: Implementation must branch on Status when bucketing, not rely on date math alone.

### 4. Does "amount" mean total invoice amount or remaining balance after partial payments?

- Question: `Amount__c` is the full invoice total. Partial `Payment__c` records reduce the remaining balance. Which figure goes in each bucket?
- Answer: Remaining balance = `Invoice__c.Amount__c - SUM(Payment__c.Amount__c WHERE Invoice__c = this)`. Exclude invoices whose remaining balance is <= 0 even if Status hasn't synced yet.
- Reasoning: The whole point of collections prioritization is "how much money is still owed". Using the gross invoice total would overstate exposure when a customer paid half. `PaymentService.getPaymentTotals` and `getRemainingBalance` already implement this aggregation — we reuse the same pattern (aggregate SUM grouped by `Invoice__c`) to stay bulk-safe. The <=0 defensive filter handles the brief window between payment insert and status sync.

### 5. What defines an aging bucket — Due Date or Invoice Date?

- Question: "Days overdue" is ambiguous: days since invoice issue, days since due date, or days past now.
- Answer: `daysOverdue = today - Due_Date__c`. If `daysOverdue < 0` (due date is in future) or `Status__c == 'Draft'` → bucket = `Current`. Otherwise bucket by `daysOverdue` value.
- Reasoning: Industry-standard aging reports key off due date, not invoice date, because payment terms (Net 30/60/90) change the legitimate grace period. Uses the same `Due_Date__c < today` logic already baked into `SOQL_Invoice.overdue()`.

### 6. Exact bucket boundaries — are they inclusive or exclusive?

- Question: "1-30" is ambiguous at the edges. Is day 0 in Current or 1-30? Is day 30 in 1-30 or 31-60? Is day 90 in 61-90 or 90+?
- Answer:
  - `Current`: `Due_Date__c >= today` OR `Status__c == 'Draft'` (i.e. `daysOverdue <= 0` for non-Drafts).
  - `1-30`: `1 <= daysOverdue <= 30`.
  - `31-60`: `31 <= daysOverdue <= 60`.
  - `61-90`: `61 <= daysOverdue <= 90`.
  - `90+`: `daysOverdue > 90` (i.e. `>= 91`).
- Reasoning: The story labels the last bucket `90+` — this signals the "90" boundary belongs to `61-90` (inclusive upper), and `90+` means strictly greater. Applying the same inclusive-upper rule consistently to every bucket avoids one-day leakage. Day 0 (due today) is not overdue, so it sits in Current. This matches how AR aging reports are conventionally published (e.g. QuickBooks, NetSuite).

### 7. Should the breakdown show record count, total amount, or both?

- Question: Each bucket could show just `$X,XXX`, just `3 invoices`, or both.
- Answer: Both — total remaining amount (primary, large) and count (secondary, small) per bucket.
- Reasoning: The story says "prioritize collections and assess credit risk at a glance". Risk = dollars; prioritization effort = count of follow-ups needed. The existing `accountOverdueInvoiceBadge` already pairs count + amount (`3 overdue · $4,500 at risk`), so this matches precedent.

### 8. Where does the aging computation live — Apex or client?

- Question: Client-side bucketing from raw invoice records vs. server-side bucketing returning a summary DTO.
- Answer: Server-side in Apex. The LWC calls an `@AuraEnabled(cacheable=true)` method that returns a DTO containing five bucket entries, each with `label`, `count`, `totalAmount`.
- Reasoning: (a) Requires payment aggregation (`GROUP BY Invoice__c` on `Payment__c`) — already a server-side operation. (b) Avoids shipping every invoice record to the browser (accounts with hundreds of invoices). (c) Cacheable — buckets only change when invoices/payments change, so `@wire` refresh via `getRecordNotifyChange` or navigation is acceptable. (d) Matches the `OverdueInvoiceController.getOverdueInvoiceSummary` precedent exactly.

### 9. Which Apex layers are needed?

- Question: Controller? Service? New selector methods?
- Answer:
  - Controller: `AccountInvoiceAgingController.getAgingBreakdown(Id accountId)` returning `InvoiceService.InvoiceAgingBreakdown`.
  - Service: new method `InvoiceService.getAgingBreakdown(Id accountId)`.
  - Selector: extend `SOQL_Invoice` with `unpaid()` filter (`Status__c NOT IN ('Paid', 'Cancelled')`). Reuse `byAccountId`.
  - Payment totals: reuse `PaymentService.getPaymentTotals` (already private — promote to public/shared or extract to helper). Preferred: make `getPaymentTotals(Set<Id>)` public on `PaymentService` and call from `InvoiceService` via `InstanceProvider`.
- Reasoning: Mirrors the architecture of the overdue badge: one controller → service → selector, one DTO inner class. Keeps selectors lightweight (just the filter method) with business logic in the service. Promoting `getPaymentTotals` avoids duplicating the aggregate query in two services. DI via `InstanceProvider` aligns with CLAUDE.md "no static methods on services" rule.
- Follow-on: existing `PaymentService` tests that mock `getPaymentTotals` need to keep working — the visibility change is backward-compatible (private → public).

### 10. DTO shape — list or named fields?

- Question: Return `List<Bucket>` in a fixed order, or a class with five named fields (`current`, `days1to30`, etc.)?
- Answer: `List<AgingBucket>` with deterministic ordering: `[Current, 1-30, 31-60, 61-90, 90+]`. Each `AgingBucket` has `@AuraEnabled` `String label`, `Integer count`, `Decimal totalAmount`, and `String severity` (one of `current | low | medium | high | critical`).
- Reasoning: List iteration maps cleanly to an LWC `template for:each` render, avoiding five hardcoded slots in the markup. Including `severity` as an enum-like string pushes the visual mapping (which bucket is red vs. amber vs. green) into the service where it is testable, rather than hardcoding color logic in JS. Fixed ordering is guaranteed server-side so the UI never mis-orders.

### 11. What severity/color does each bucket get?

- Question: Visual urgency mapping.
- Answer:
  - `Current` → `current` → neutral/base (inverse `lightning-badge` or subtle grey).
  - `1-30` → `low` → warning amber.
  - `31-60` → `medium` → warning amber (slightly darker) or warning with bolder icon.
  - `61-90` → `high` → error/red.
  - `90+` → `critical` → error/red with warning icon.
- Reasoning: Five distinct colors is noise; grouping 1-30/31-60 in amber and 61-90/90+ in red matches how `invoiceDueChip` already buckets urgency (green/amber/red). Icons and intensity differentiate within color family. SLDS offers `success`, `warning`, `error`, `inverse`, `base` `lightning-badge` variants — we map severity strings to these variants in the LWC.

### 12. What should the component render when there are zero unpaid invoices?

- Question: Collapse entirely, show "No outstanding invoices", or show five empty buckets?
- Answer: Render a single positive empty-state row: "No outstanding invoices" with a success icon. Do not show empty buckets.
- Reasoning: Five "$0.00 / 0 invoices" buckets waste page real estate and bury the positive signal. Matches the `accountOverdueInvoiceBadge` empty-state precedent ("No overdue invoices").

### 13. What should the component render on error?

- Question: DTO null, unauthorized, wire error.
- Answer: Show an inline `lightning-badge` with `utility:warning` icon and label "Aging breakdown unavailable". Do not block the rest of the page.
- Reasoning: Matches `accountOverdueInvoiceBadge` error handling. An AM glancing at the page should not see a broken layout; degrade gracefully.

### 14. What should the component render while loading?

- Question: Skeleton, spinner, or nothing?
- Answer: A single `lightning-spinner` of size `small` anchored top-right of the card, with the bucket grid rendered in a disabled/ghost state if prior data is cached, otherwise just the spinner centered.
- Reasoning: First wire-up is sub-second for cacheable calls; a small spinner avoids layout shift. Consistent with typical SLDS card patterns.

### 15. Should each bucket be clickable (drill-down)?

- Question: Click `61-90` to see those specific invoices, or is the summary enough?
- Answer: Yes — each non-zero bucket is a button that navigates to the Account's Invoices related list, with the breakdown summary tooltip. Full filtered-list navigation (to a list view filtered to those specific invoices) is out of scope v1.
- Reasoning: The story asks for "at a glance" prioritization — discovery is glance, action is drill. Following the existing `accountOverdueInvoiceBadge.handleNavigate` pattern (`standard__recordRelationshipPage` to `Invoices__r`) is low-cost and reuses infrastructure. A per-bucket filtered list view is a v2 enhancement (would require a dynamic list-view URL with filter params, nontrivial and orthogonal to the MVP).
- Follow-on: Keyboard/a11y — buckets must be actual `<button>` elements, not divs, so tabbing and Enter/Space activation work for free.

### 16. Layout — where on the Account record page does this live?

- Question: Highlights panel, main column top, main column between detail and related lists, sidebar?
- Answer: Add a new component instance to the `main` region of `Account_Record_Page.flexipage-meta.xml`, placed immediately after `c:accountOverdueInvoiceBadge` and before `force:detailPanel`.
- Reasoning: The badge gives the one-liner summary; the aging breakdown is the next level of detail — sitting them adjacent respects information hierarchy. Sidebar is narrow (won't fit five buckets). Highlights panel is reserved for system-defined fields and the existing badge. Placing it above `force:detailPanel` ensures AMs see collections risk before they scroll into account details.
- Follow-on: After deploy, flexipage must be manually activated (per CLAUDE.md Deployment Checklist item 3).

### 17. Component display form — card, grid, stacked bars, pie?

- Question: How should the five buckets be visually arranged?
- Answer: A `lightning-card` titled "Invoice Aging" containing a horizontal flex row of five equal-width bucket tiles (stack to grid on narrow viewports via CSS grid `auto-fit, minmax(140px, 1fr)`). Each tile shows: severity color accent bar at top, bucket label (e.g. "31-60 days"), bold currency total, smaller "`N invoices`" below.
- Reasoning: Horizontal row makes bucket-to-bucket comparison trivial at a glance — the story's primary requirement. CSS-grid auto-fit handles responsive stacking without JS. Stacked bars and pies obscure exact amounts; a data-first tile grid shows both dimensions (amount + count) without chart chrome. No external charting library needed.

### 18. Bulk/volume — how many invoices per account is realistic?

- Question: Worst case record volume behind one account.
- Answer: Assume up to ~50k unpaid invoices per account (SOQL aggregate row limit territory). Perform all bucketing via a single SOQL aggregate and a single Payment aggregate; no per-invoice loops with queries.
- Reasoning: CLAUDE.md hard rule: "No SOQL or DML inside loops" and "Bulk-safe: all code must handle 200+ records". The natural implementation is: (a) one SOQL to fetch unpaid `Invoice__c` rows (Id, Amount, Due_Date, Status) for the account; (b) one aggregate SOQL to sum payments grouped by Invoice; (c) one in-memory loop to bucket. For 50k+ invoices per account we would need to switch to pure SOQL aggregation (`SUM(Amount__c) ... GROUP BY CASE WHEN ...`), which isn't natively supported in SOQL — a single-account realistic ceiling (<<50k) lets us keep the simpler in-memory bucketing. Document the limit as a known assumption.

### 19. Should results be cached?

- Question: Platform cache or just `@AuraEnabled(cacheable=true)`?
- Answer: `@AuraEnabled(cacheable=true)` only; no platform cache layer.
- Reasoning: Data freshness matters for collections — a stale aging breakdown after a payment is logged could mislead an AM. Lightning Data Service's built-in caching is sufficient; the LWC can force-refresh via `refreshApex` on user action or `getRecordNotifyChange` after a payment. Adding Platform Cache introduces invalidation complexity with negligible query cost (two small aggregates per call).

### 20. Does this require permission set updates?

- Question: New Apex class access, new fields, new objects?
- Answer: No new fields, no new objects. Apex classes default to the running user's access via `with sharing` (user mode). The existing `InvoiceUser` permission set already grants Read on `Invoice__c` and `Payment__c`. No permset edit required.
- Reasoning: CLAUDE.md deployment checklist item 1 flags this for new fields/objects — none added here. Controller `@AuraEnabled` methods don't require Apex class access permissions to be granted for standard internal users on this Developer Edition org.

### 21. Timezone — whose "today" defines the cutoff?

- Question: `Due_Date__c` is a Date (no time component). If the user is in Sydney and the server is UTC, whose today?
- Answer: Use `Date.today()` on the server, which returns the org user's local Date (Salesforce resolves this per user TZ). LWC displays the server-computed buckets as-is — no client-side date math.
- Reasoning: Because bucketing happens server-side, we only have one "today" to worry about. `Date.today()` in Apex returns the Date in the context user's TZ, which matches what the user would intuitively expect. This matches the approach used implicitly by `SOQL_Invoice.overdue()`.

### 22. Currency — multi-currency org?

- Question: Format in user locale currency or Org default?
- Answer: Use `@salesforce/i18n/currency` + `@salesforce/i18n/locale` in the LWC for formatting, as the existing badge does. Assume single-currency org (the object has no `CurrencyIsoCode` field).
- Reasoning: Consistent with `accountOverdueInvoiceBadge.js`. Multi-currency conversion is a separate feature; noting it here as an explicit non-goal.

### 23. Trigger integration — does anything need to fire on DML?

- Question: Aging changes automatically each day as dates roll. Do we need a scheduled job to recompute?
- Answer: No. Computation is on-demand at page load. No triggers, no scheduled Apex, no batch.
- Reasoning: Aging is a derived view, not a stored value. Computing at read time keeps the data model clean and avoids drift. If performance ever demands materialization, that's a v2 concern.

### 24. Testing strategy — what needs Apex unit tests?

- Question: Coverage targets and boundary cases.
- Answer: ≥95% on each new Apex class.
  - `InvoiceServiceTest` additions: bucket boundary tests (days 0, 1, 30, 31, 60, 61, 90, 91), Draft-always-Current, remaining-balance math with partial payments, fully-paid invoice excluded, Cancelled excluded, empty-account returns five empty buckets or the positive empty-state DTO, null accountId returns empty DTO.
  - `AccountInvoiceAgingControllerTest`: passes Id through, handles null → empty DTO, delegates to service (mock via `InstanceProvider.injectMock`).
  - `SOQL_InvoiceTest` additions: new `unpaid()` filter test.
  - Mock SOQL via `SOQL.mock('InvoiceService.getUnpaidInvoices').thenReturn(...)` and `SOQL.mock('PaymentService.getPaymentTotals').thenReturn(...)`.
- Reasoning: CLAUDE.md rule: "Unit test everything. Mock all dependencies." Boundary tests on every bucket edge catch off-by-one errors that are the single biggest risk of this feature.

### 25. Testing strategy — what needs Jest tests?

- Question: LWC coverage.
- Answer: Mock `getAgingBreakdown` wire adapter. Tests: renders five tiles with provided data, renders empty-state when all buckets are zero, renders error state on wire error, renders spinner while loading, fires navigation on tile click, formats currency via user locale, a11y label is correct per tile.
- Reasoning: Mirrors the `accountOverdueInvoiceBadge` test pattern. Use `c/testUtils` `flushPromises` per CLAUDE.md.

### 26. Validation — what does the Playwright pass verify?

- Question: End-to-end acceptance criteria.
- Answer: On an Account page with seeded invoices spanning all five buckets: (a) each bucket shows correct count and total, (b) empty-state Account shows "No outstanding invoices", (c) clicking a bucket navigates to the Invoices related list, (d) after logging a Payment that fully pays an overdue invoice and refreshing, the invoice moves out of its bucket. Screenshot each state.
- Reasoning: These cover the story's "at a glance" promise and the remaining-balance requirement (decision #4). Matches the validate skill's standard flow.

### 27. Naming — controller, service method, DTO, LWC?

- Question: Pick names that fit existing conventions.
- Answer:
  - Apex controller: `AccountInvoiceAgingController` (suffix `Controller`, matches `OverdueInvoiceController`, `PaymentController`).
  - Service method: `InvoiceService.getAgingBreakdown(Id accountId)`.
  - DTO: `InvoiceService.InvoiceAgingBreakdown` containing `List<AgingBucket> buckets` and `Decimal totalUnpaidAmount` and `Integer totalUnpaidCount` convenience totals. Inner class `InvoiceService.AgingBucket`.
  - LWC directory: `accountInvoiceAgingBreakdown` (matches camelCase, `account*` prefix for Account-page components, mirrors `accountOverdueInvoiceBadge`).
  - Master label: `"Account Invoice Aging Breakdown"`.
- Reasoning: Naming consistent with existing artifacts; `account*` prefix signals the mount object.

### 28. Do we reuse or create a new selector filter for "unpaid"?

- Question: The existing `SOQL_Invoice.overdue()` already filters `Status NOT IN ('Paid', 'Cancelled')` AND `Due_Date < today`. We want the first half only.
- Answer: Add `SOQL_Invoice.unpaid()` that filters only on `Status__c NOT IN ('Paid', 'Cancelled')`. Do not reuse `overdue()` because it excludes current invoices.
- Reasoning: "Unpaid" includes current (not yet overdue) invoices and overdue ones. A fresh filter method is the right granularity. Could refactor `overdue()` to `return this.unpaid().andWhere(...)` later, but out of scope — no behavior change.

### 29. What happens if an Account has only Draft invoices?

- Question: Edge case.
- Answer: Breakdown renders with non-zero `Current` bucket only, and zero in 1-30 through 90+. The empty-state ("No outstanding invoices") is only shown when every bucket including Current is zero.
- Reasoning: Draft invoices represent forward exposure; they should be visible. Follows from decision #3 and #12.

### 30. What happens if `Due_Date__c` is null?

- Question: The field is not required on `Invoice__c` (per field metadata), though in practice it's auto-populated by `InvoiceService.populateDueDates` on insert.
- Answer: Treat null `Due_Date__c` as `Current` regardless of status (except Paid/Cancelled which are already filtered out). Log nothing visibly; the defensive fallback.
- Reasoning: Field is technically nullable (the trigger back-fills, but not guaranteed for imported or API-created data). Placing unknown-date invoices in Current avoids overstating overdue exposure. Architect should double-check whether a validation-rule tightening is warranted separately — not this feature's scope.

---

## Unambiguous user story & plan (handoff summary)

Add an "Invoice Aging" lightning-card to the Account record page, placed in the main region immediately after the existing overdue-invoice badge. The card renders five horizontally-arranged tiles — `Current`, `1-30 days`, `31-60 days`, `61-90 days`, `90+ days` — each showing the total remaining balance (invoice `Amount__c` minus sum of related `Payment__c.Amount__c`) and the count of unpaid invoices (`Status__c NOT IN ('Paid', 'Cancelled')`) whose `today - Due_Date__c` falls in the bucket. Drafts and invoices with null Due_Date always bucket to `Current`; bucket upper bounds are inclusive; `90+` is strictly greater than 90. Tiles are clickable buttons that navigate to the Account's Invoices related list; severity drives SLDS badge variant (base → warning → error). Empty state collapses to a single "No outstanding invoices" row; error state shows an inline warning badge; loading shows a small spinner. Implementation: new `AccountInvoiceAgingController.getAgingBreakdown(Id)` (cacheable `@AuraEnabled`) delegating to a new `InvoiceService.getAgingBreakdown(Id)` method, which uses `SOQL_Invoice.unpaid().byAccountId()` (new filter method) and `PaymentService.getPaymentTotals` (promoted to public) to compute buckets in a single in-memory pass — bulk-safe, no per-record queries. DTO is `InvoiceService.InvoiceAgingBreakdown { List<AgingBucket> buckets, Decimal totalUnpaidAmount, Integer totalUnpaidCount }` with each `AgingBucket { String label, String severity, Integer count, Decimal totalAmount }` in fixed order. LWC `accountInvoiceAgingBreakdown` reads via `@wire`, formats currency via user locale, renders with CSS-grid `auto-fit` for responsiveness, and uses `NavigationMixin` for drill-down. No schema changes, no permission set edits, no triggers, no scheduled jobs. Apex tests ≥95% coverage with boundary tests at days 0/1/30/31/60/61/90/91 and full SOQL/DML/service mocking; Jest tests cover rendering, states, and interactions. Playwright validates the five-bucket rendering, empty state, and drill-down navigation against a seeded org. Flexipage must be manually activated after deploy.
