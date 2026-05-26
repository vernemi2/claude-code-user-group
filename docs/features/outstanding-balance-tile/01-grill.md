# Grill: Account Outstanding Balance Tile

## Input

> As an account manager, I want to see the total outstanding balance (sum of all unpaid invoices) as a single tile on the Account page, so I can grasp the customer's open exposure at a glance.

---

## Decision Tree (Resolved)

### 1. What is "outstanding balance"? Invoice face value, or face value minus payments?

- **Answer:** Outstanding balance = sum of `(Invoice__c.Amount__c - sum(Payment__c.Amount__c))` for every invoice on the account whose `Status__c` is NOT in `('Paid','Cancelled')`. Only invoices with a positive remaining balance contribute.
- **Reasoning:** The codebase already encodes this exact definition. `InvoiceService.getAgingBreakdown` (force-app/main/classes/services/InvoiceService.cls:50-108) computes `remainingBalance = invoiceAmount - paid` per unpaid invoice and exposes `totalUnpaidAmount` as the sum. Reusing this definition keeps a single source of truth across the aging breakdown and the new tile, avoiding the bug where two components on the same page show different "outstanding" numbers. The existing overdue badge uses face-value-only because it counts at-risk exposure; the tile asks for "open exposure," which the aging breakdown's net-of-payments figure already represents.

### 2. Which invoice statuses count as "unpaid"?

- **Answer:** All statuses except `Paid` and `Cancelled` — meaning `Draft`, `Sent`, and `Overdue` all contribute.
- **Reasoning:** `SOQL_Invoice.unpaid()` (force-app/main/classes/selectors/SOQL_Invoice.cls:25-31) is the project convention and already excludes `Paid` and `Cancelled`. Including `Draft` matches the aging breakdown semantics — an account manager's "open exposure" includes drafted-but-not-yet-sent commitments. Anything else would diverge from the aging card sitting directly above it.

### 3. Should the tile reuse the existing `InvoiceAgingBreakdown` payload or expose its own DTO?

- **Answer:** Reuse `InvoiceService.getAgingBreakdown(accountId).totalUnpaidAmount` and `totalUnpaidCount`. No new service method, no new DTO.
- **Reasoning:** The data the tile needs is already computed and returned by `InvoiceService.getAgingBreakdown`. Adding a parallel service method would duplicate the unpaid-invoice query and the payment-totals aggregation — a violation of DRY and a guaranteed source of drift. The LWC can call the existing `AccountInvoiceAgingController.getAgingBreakdown` Apex method and ignore the `buckets` collection.

### 4. Then do we need a new Apex controller / service method at all?

- **Answer:** No new Apex. The new component is purely a presentational LWC bound to the existing `@AuraEnabled(cacheable=true)` method `AccountInvoiceAgingController.getAgingBreakdown`.
- **Reasoning:** Zero Apex changes means zero new test classes, zero new permissions on Apex, and the wire adapter's client-side cache is shared with the sibling `accountInvoiceAgingBreakdown` LWC — both calls dedupe to a single server roundtrip per page render. This is a meaningful perf and consistency win.

### 5. What is the LWC name?

- **Answer:** `accountOutstandingBalanceTile`.
- **Reasoning:** Naming convention in this repo is `{object}{Feature}{Shape}`: `accountOverdueInvoiceBadge`, `accountInvoiceAgingBreakdown`, `invoiceDueChip`. The story explicitly calls it a "tile," so the suffix becomes `Tile`. CamelCase directory per CLAUDE.md LWC conventions.

### 6. Where on the Account page does the tile go?

- **Answer:** Top of the `main` region of `Account_Record_Page.flexipage-meta.xml`, above `accountOverdueInvoiceBadge` and above `accountInvoiceAgingBreakdown`.
- **Reasoning:** The story says "at a glance" — the tile must be the first piece of financial signal a user sees. The current flexipage main region order is: badge → aging breakdown → detail panel → related list (force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml:17-44). Putting the tile first puts the headline number above the at-risk-only badge and above the bucket grid. The badge stays because it answers a different question ("how much is past due?"), and the aging card stays because it answers "how is the exposure distributed across age?". The tile answers "what's the total?".

### 7. What does the tile look like visually?

- **Answer:** A single `lightning-card` with `icon-name="standard:currency"`, a large bold currency amount, and a secondary line "N open invoices" beneath it. No bucket breakdown, no list. Visually it's a "KPI tile" — analogous to the existing aging tiles' `tile-amount` + `tile-count` layout but as a standalone card spanning the full region width.
- **Reasoning:** "Single tile…at a glance" rules out lists or tables. The existing aging breakdown CSS in accountInvoiceAgingBreakdown.css:59-67 already defines the `tile-amount` / `tile-count` typographic hierarchy (1.125rem bold for the amount, 0.8125rem muted for the count) — reusing that visual language keeps the page coherent. `standard:currency` is the SLDS icon that semantically maps to money totals; `standard:invoice` is already taken by the sibling aging card.

### 8. Is the tile clickable, and if so where does it navigate?

- **Answer:** Yes — clicking the tile navigates to the Account's `Invoices__r` related list, same as the badge and the aging buckets.
- **Reasoning:** Consistency. Both `accountOverdueInvoiceBadge.js:63-73` and `accountInvoiceAgingBreakdown.js:86-96` use `NavigationMixin` to open the `standard__recordRelationshipPage` with `relationshipApiName: "Invoices__r"`. The expected user journey from "I see open exposure" is "show me the invoices that make it up." Diverging would surprise the user.

### 9. How is the currency formatted?

- **Answer:** `Intl.NumberFormat(LOCALE, { style: 'currency', currency: CURRENCY })` using `@salesforce/i18n/locale` and `@salesforce/i18n/currency`.
- **Reasoning:** Direct pattern match with both sibling components (accountOverdueInvoiceBadge.js:35-40, accountInvoiceAgingBreakdown.js:79-84). No `lightning-formatted-number` because the existing components do not use it — consistency outweighs the alternative.

### 10. What happens when the account has zero unpaid invoices?

- **Answer:** Render the tile with `$0.00` as the amount and "No open invoices" as the secondary line. The tile remains clickable to view the related list.
- **Reasoning:** The story is "grasp open exposure at a glance" — hiding the tile when exposure is zero would force the manager to _check_ whether it rendered, which defeats the at-a-glance goal. Showing a green/neutral zero state is the explicit "all clear" signal. The aging card uses a "No outstanding invoices" empty state with a success icon (accountInvoiceAgingBreakdown.html:18-28); the tile should mirror that confidence — a muted icon and explicit zero rather than a placeholder.

### 11. Loading and error states?

- **Answer:** Loading shows a small `lightning-spinner` inside the card body. Error shows a `lightning-badge` labeled "Outstanding balance unavailable" with `utility:warning`.
- **Reasoning:** Both sibling components use this exact tri-state pattern (`isLoading` / `hasError` / `hasData`). Re-applying it is a no-brainer.

### 12. Where does the `recordId` come from?

- **Answer:** Standard Lightning page binding — `@api recordId` populated by the platform when the LWC is on a record page.
- **Reasoning:** Mirrors both sibling components and is the only mechanism available given the `lightning__RecordPage` target in `js-meta.xml`.

### 13. Does the LWC need to be exposed on any target besides Account record pages?

- **Answer:** No. `<targets>lightning__RecordPage</targets>` constrained to `<object>Account</object>`.
- **Reasoning:** The story is scoped to the Account page. Exposing to other targets without a use case adds surface area to test and document. Match the badge's meta (accountOverdueInvoiceBadge.js-meta.xml:8-17) verbatim except for the labels.

### 14. Permissions — do we need to update `InvoiceUser`?

- **Answer:** No permission set changes.
- **Reasoning:** The tile reads `Invoice__c.Amount__c`, `Invoice__c.Status__c`, `Invoice__c.Due_Date__c`, and `Payment__c.Amount__c` via the existing `AccountInvoiceAgingController` → `InvoiceService.getAgingBreakdown` path, which runs `.systemMode().withoutSharing()` in the selector and aggregate query. The selector + service already work for users who have only the `InvoiceUser` permset assigned (proven by the existing aging card). No new fields are introduced.

### 15. Are LWC Jest tests required, and what do they cover?

- **Answer:** Yes — `accountOutstandingBalanceTile/__tests__/accountOutstandingBalanceTile.test.js`. Cases: (a) loading state renders spinner; (b) error state renders error badge; (c) populated state renders formatted amount and pluralized count; (d) zero state renders `$0.00` and "No open invoices"; (e) click invokes navigation to the `Invoices__r` related list.
- **Reasoning:** Project convention (CLAUDE.md "LWC Jest Tests"). Use `flushPromises` from `c/testUtils` per CLAUDE.md, mock `@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown` with `createApexAdapter` / wire emit pattern used by the sibling tests.

### 16. Are Apex tests required?

- **Answer:** No new Apex tests; the existing `InvoiceServiceTest` and `AccountInvoiceAgingControllerTest` already cover the data path.
- **Reasoning:** No new Apex was added (decision #4). Re-running existing tests as part of the deploy is sufficient.

### 17. Should the tile auto-refresh when a payment or invoice changes elsewhere on the page?

- **Answer:** No — rely on `@wire`'s `cacheable=true` invalidation and the standard Lightning page lifecycle. No `refreshApex` plumbing, no platform events.
- **Reasoning:** The sibling components don't subscribe to changes either. Adding live-refresh here without doing it for the badge and aging card would create inconsistent freshness across three components reading the same data. If real-time refresh is needed, it should be added as a separate cross-cutting story for all three components.

### 18. Bulk safety / governor limits?

- **Answer:** N/A for the LWC layer. The Apex path already handles 200+ invoices via aggregate SOQL in `PaymentService.getPaymentTotals` (one aggregate query) and a single selector call in `InvoiceService.getAgingBreakdown`.
- **Reasoning:** No new queries are introduced.

### 19. Accessibility?

- **Answer:** Tile button has `aria-label` synthesized from state — e.g. "Outstanding balance $4,250.00 across 3 open invoices. Open related invoices." Loading and error states also expose appropriate `aria-label`s. The clickable tile is a `<button type="button">`, never a `<div>`.
- **Reasoning:** Matches the existing pattern (`accountOverdueInvoiceBadge.js:50-61`, `accountInvoiceAgingBreakdown.js:75`). Keyboard and screen-reader parity with the rest of the page is non-negotiable.

### 20. Does the singular "1 open invoice" vs plural "N open invoices" need handling?

- **Answer:** Yes — pluralize: `count === 1 ? "1 open invoice" : `${count} open invoices``. Zero state uses "No open invoices."
- **Reasoning:** The badge already does this (accountOverdueInvoiceBadge.js:42-44). Trivial UX polish; absence would look unprofessional in screenshots.

### 21. Naming: "Outstanding balance" vs "Open exposure" vs "Total unpaid"?

- **Answer:** Card title: "Outstanding Balance". Secondary label inside the tile: none (the big number is self-explanatory) — only the count line. ARIA label uses "Outstanding balance".
- **Reasoning:** The story uses the words "total outstanding balance" and "open exposure" interchangeably. "Outstanding Balance" is the more conventional finance term, scans shorter, and avoids redefining "exposure" for users.

### 22. Should the tile show a trend or comparison (e.g. vs. last month)?

- **Answer:** No.
- **Reasoning:** The story explicitly scopes to "a single tile" with "the total." No historical data is in scope, no `created_date`-windowed snapshot is being asked for, and adding it would balloon scope and require schema additions.

### 23. Should the tile be guarded behind a permission/feature flag?

- **Answer:** No.
- **Reasoning:** Visibility on the flexipage is already gated by the user having read access to Account, Invoice**c, and Payment**c — which is exactly what the `InvoiceUser` permission set grants. Anyone not in the permset will see the spinner-then-empty-state harmlessly because the controller returns an empty breakdown when the underlying query returns nothing in user-accessible scope (but in fact runs in system mode and returns the real total). This matches the precedent set by the sibling components.

### 24. What is the deploy/activation checklist?

- **Answer:** Deploy LWC bundle + updated flexipage. No permset changes. After deploy, verify the flexipage is the active org default for Account (per CLAUDE.md deployment checklist).
- **Reasoning:** CLAUDE.md "Deployment Checklist" rule #3 — flexipage deployment does not auto-activate. The page is already active in the org since the badge and aging card render today, so a redeploy of the same flexipage will keep activation. Activation is therefore only a verification step, not an action.

---

## Settled Plan (Handoff to Architect)

Add a new presentational Lightning Web Component `accountOutstandingBalanceTile` placed at the top of the `main` region of `Account_Record_Page.flexipage`. The component is a single `lightning-card` titled "Outstanding Balance" (icon `standard:currency`) containing a large bold currency amount and a pluralized secondary line ("N open invoices" / "1 open invoice" / "No open invoices"). The amount is the sum of `(Invoice__c.Amount__c − sum(Payment__c.Amount__c))` across the account's invoices whose `Status__c` is not `Paid` or `Cancelled`, filtered to invoices with a positive remaining balance — i.e. the existing `InvoiceService.InvoiceAgingBreakdown.totalUnpaidAmount`. The LWC reuses the existing `@AuraEnabled(cacheable=true)` Apex endpoint `AccountInvoiceAgingController.getAgingBreakdown`, ignoring the `buckets` payload; **no new Apex, no new DTO, no permission-set changes**. Currency is formatted via `Intl.NumberFormat` with `@salesforce/i18n/locale` and `@salesforce/i18n/currency`. Tri-state UI (loading spinner / error badge / data) mirrors the sibling components. The card body is a `<button type="button">` that uses `NavigationMixin` to open the Account's `Invoices__r` related list on click, with an `aria-label` synthesized from the current amount and count. LWC Jest tests cover loading, error, populated, zero, and click-navigation states using `flushPromises` from `c/testUtils`. Deploy is `force-app/main/lwc/accountOutstandingBalanceTile/*` + the updated `Account_Record_Page.flexipage-meta.xml`; verify the flexipage remains the active org default for Account.
