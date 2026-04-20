# Grill: Invoice Due-Date Urgency Chip

Input: "As an account manager, on the Invoice record page I want a small chip showing 'Due in N days' (green), 'Due in N days' amber if <= 7, or 'N days overdue' in red, so I can see urgency at a glance without computing from the Due Date."

## Resolved decisions

### 1. Which object is the chip bound to, and does `Due_Date__c` exist?

- Question: What object and field underpin the chip?
- Answer: `Invoice__c.Due_Date__c` (Date, required).
- Reasoning: Confirmed at `force-app/main/objects/Invoice__c/fields/Due_Date__c.field-meta.xml`. The field is required, so the chip can assume non-null in steady state but must defensively handle null during record creation previews.

### 2. Should the chip surface for every invoice, or should Status gate it?

- Question: The story implies urgency, but "Paid" or "Cancelled" invoices have no urgency. Do we render the chip for them?
- Answer: Hide the chip when `Status__c` is `Paid` or `Cancelled`. Show it for `Draft`, `Sent`, and `Overdue`.
- Reasoning: Status picklist values are `Draft | Sent | Paid | Overdue | Cancelled` (`Invoice__c/fields/Status__c.field-meta.xml`). `SOQL_Invoice.overdue()` already excludes `Paid` and `Cancelled` from the overdue-risk calculation — applying the same exclusion here keeps UI semantics consistent with the existing data model. An "amber/red" urgency chip on a Paid invoice would be misleading.

### 3. Exact thresholds — green vs amber vs red?

- Question: The story specifies amber "<= 7" and red for overdue, but the green threshold is unstated.
- Answer:
  - Red: `daysUntilDue < 0` → label `"N days overdue"` (absolute value of days).
  - Amber: `0 <= daysUntilDue <= 7` → label `"Due in N days"`.
  - Green: `daysUntilDue > 7` → label `"Due in N days"`.
- Reasoning: The story explicitly pins amber at `<= 7`, so green is the complement (`> 7`). Red is "overdue" which by definition is `< 0`. This leaves `daysUntilDue == 0` (due today) unambiguous — it falls into amber as an edge of the `<= 7` range, which matches the "urgent but not yet overdue" intent.

### 4. How is the "due today" case labeled?

- Question: "Due in 0 days" reads awkwardly. Should today get a dedicated label?
- Answer: Render `"Due today"` in amber.
- Reasoning: First principles / UX — "Due in 0 days" is grammatically correct but jarring for a glance chip. "Due today" is idiomatic and keeps the amber semantic (it is the most urgent pre-overdue state).

### 5. How is "1 day" pluralization handled?

- Question: "Due in 1 days" and "1 days overdue" are wrong.
- Answer: Singular/plural:
  - `1` → `"Due in 1 day"` / `"1 day overdue"`.
  - `N != 1` → `"Due in N days"` / `"N days overdue"`.
- Reasoning: Basic English grammar. The existing `accountOverdueInvoiceBadge.js` already does the same singular/plural switch for the word "invoice" (`invoiceWord`), so we follow precedent.

### 6. Where does the days-until-due calculation live — Apex or JS?

- Question: Compute server-side (Apex controller) or client-side (LWC from the Date field)?
- Answer: Client-side in the LWC, using `getRecord` on `Invoice__c.Due_Date__c` and `Status__c`.
- Reasoning: (a) Zero business logic beyond date subtraction — no SOQL, no aggregation, no cross-record computation. (b) The existing `invoicePayments` LWC already reads the invoice via `getRecord` + `getFieldValue`, establishing the precedent. (c) Avoids a round-trip and an @AuraEnabled controller for a pure presentational concern. (d) Keeps the chip reactive to inline edits of Due_Date without a controller refresh.

### 7. Timezone semantics — whose "today"?

- Question: Due_Date\_\_c is a Date (no time). If the user is in Sydney and the server is in UTC, which "today" defines "0 days until due"?
- Answer: Use the user's local browser date. Compute today as `new Date()` normalized to midnight local time, then subtract from the Due_Date at midnight local.
- Reasoning: Date fields in Salesforce are timezone-agnostic (stored as a wall-clock date). The user's perception of "due today" is their local calendar day. Using `new Date()` with local normalization matches what the user sees in the Detail panel.

### 8. How to normalize the date subtraction to whole days?

- Question: JS Date arithmetic is millisecond-based and DST-sensitive. How do we get integer days?
- Answer: Build both endpoints as `Date` objects at local midnight, diff via `(dueMs - todayMs) / 86_400_000`, then `Math.round` (not floor/ceil).
- Reasoning: DST transitions make the diff 23h or 25h on two days per year. `Math.round` of a value near an integer absorbs the ±1h drift cleanly. Alternatively `UTC` normalization sidesteps DST entirely — acceptable because we already pinned "today" to local wall-clock in Q7; using `Date.UTC(y, m, d)` for both endpoints is the cleanest implementation. Decision: use `Date.UTC(y, m, d)` for both endpoints.

### 9. What is the component name and directory?

- Question: Naming?
- Answer: `invoiceDueChip` in `force-app/main/lwc/invoiceDueChip/`.
- Reasoning: CLAUDE.md says LWC directories are `camelCase`. Existing precedent: `accountOverdueInvoiceBadge`, `overdueInvoiceBanner`, `invoicePayments`. `invoiceDueChip` reads naturally and matches the user's word choice ("chip").

### 10. Does "chip" mean `lightning-badge`, `lightning-formatted-text`, or a custom element?

- Question: SLDS has both "badge" and "pill"/"chip" patterns. Which do we use?
- Answer: `lightning-badge` with the `variant` attribute tuned to color, wrapped in SLDS color classes where `lightning-badge` variants fall short.
- Reasoning: `lightning-badge` supports `variant="success" | "warning" | "error" | "inverse" | "lightest"`. success = green, warning = amber, error = red — these map exactly onto the three states the story requests. It is the same primitive used by `accountOverdueInvoiceBadge`, preserving visual consistency across the invoice-related UI surfaces.

### 11. Where does the chip render on the page?

- Question: Header, detail panel, or sidebar of the Invoice record page?
- Answer: Add the component to the `header` region of `Invoice_Record_Page.flexipage-meta.xml`, directly after `force:highlightsPanel`.
- Reasoning: "At a glance" language in the story implies top-of-page visibility. The existing flexipage (`force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`) only has `force:highlightsPanel` in the header — room to add the chip beneath it without squeezing the detail panel. Matches the placement convention of `accountOverdueInvoiceBadge` which also targets a record-page header slot.

### 12. What fields does the LWC need from `getRecord`?

- Question: Minimum field set?
- Answer: `Invoice__c.Due_Date__c` and `Invoice__c.Status__c`.
- Reasoning: Due_Date drives the math; Status gates visibility (Q2). No other data needed.

### 13. Does the chip need an @AuraEnabled controller?

- Question: Any server round-trip required?
- Answer: No. Pure `lightning/uiRecordApi` consumer.
- Reasoning: Per Q6, all logic is in JS. No controller, no SOQL\_ selector changes, no service changes needed. This is a presentation-only feature.

### 14. How does the chip handle loading and error states?

- Question: What renders while `getRecord` is resolving or on error?
- Answer:
  - Loading (no data, no error): render nothing (empty template).
  - Error: render nothing (no stack trace to the user; errors in a glance-chip are noise).
  - Paid/Cancelled status: render nothing.
  - Due_Date null: render nothing.
- Reasoning: A chip that flashes "Checking..." in the header is noisier than a chip that simply materializes when data is available. Consistent with `overdueInvoiceBanner` which renders nothing until it has a confirmed overdue state. Differs intentionally from `accountOverdueInvoiceBadge`, which shows a loading badge because it is the only affordance for "no overdue invoices" too — our chip has more states and quiet failure is correct.

### 15. Does the chip need accessibility affordances?

- Question: Screen reader text, roles?
- Answer: Include an `aria-label` describing the full urgency state (e.g., "Payment due in 5 days, urgent"). Use `role="status"` so SR users get an update on refresh.
- Reasoning: Matches the pattern in `accountOverdueInvoiceBadge.js` (`ariaLabel` getter). Accessibility is non-negotiable for a UI element whose entire value is visual color-coding — color-only information fails WCAG.

### 16. Should the chip be clickable / navigate anywhere?

- Question: Tap target behavior?
- Answer: Non-interactive. Pure display.
- Reasoning: Story explicitly scopes "to see urgency at a glance." There is no second destination from an invoice page. `accountOverdueInvoiceBadge` navigates because it is on the Account page and the invoices live elsewhere — on the invoice page itself, navigation is redundant.

### 17. How does the chip react to inline edits of Due_Date?

- Question: When an admin changes Due_Date via the detail panel, does the chip update?
- Answer: Yes — automatically, because `getRecord` is wired and Lightning Data Service emits change notifications. No manual `refreshApex` / `notifyRecordChange` needed on the chip side.
- Reasoning: The detail panel uses LDS writes; wired `getRecord` consumers re-render. `invoicePayments.js` relies on the same mechanism for its Status read.

### 18. How does the chip behave on record create / when record page loads for a draft?

- Question: On a brand-new draft, is Due_Date\_\_c guaranteed populated?
- Answer: Yes — `Due_Date__c` has `<required>true</required>`. But the chip defends against null anyway and renders nothing when null.
- Reasoning: Confirmed in the field metadata. Defensive null check is cheap insurance against future admin changes that mark the field optional.

### 19. What are the test scenarios for the LWC?

- Question: What Jest cases are mandatory?
- Answer:
  1. Renders green "Due in N days" when > 7 days out.
  2. Renders amber "Due in N days" when 1–7 days out.
  3. Renders amber "Due today" when 0 days.
  4. Renders red "N days overdue" when < 0 days.
  5. Pluralization: "1 day" vs "N days" for both future and overdue.
  6. Renders nothing when Status is Paid.
  7. Renders nothing when Status is Cancelled.
  8. Renders nothing when Due_Date is null.
  9. Renders nothing while `getRecord` is loading.
  10. Uses correct `lightning-badge` variant (success/warning/error) per state.
  11. aria-label reflects the visible label and urgency.
- Reasoning: Minimum coverage to satisfy the CLAUDE.md rule "positive, negative, bulk, edge cases" mapped onto an LWC (bulk doesn't apply; edge cases are day-boundary and status-boundary). Also satisfies the color-only-information WCAG concern from Q15 via test 11.

### 20. Apex test coverage impact?

- Question: Any Apex to test?
- Answer: None. No new Apex.
- Reasoning: Follows from Q6/Q13.

### 21. Permission set updates?

- Question: Do we need to adjust `InvoiceUser.permissionset-meta.xml`?
- Answer: No new permissions. Confirm that `Due_Date__c` and `Status__c` are readable by the target profile. Since both are `required=true` on the object and `InvoiceUser` already grants `allowRead` on Invoice\_\_c, field-level read is implicit for required fields, and there are no explicit fieldPermissions suppressing them. Audit confirms no change needed.
- Reasoning: CLAUDE.md's "Deployment Checklist" flags permission-set updates only for new objects/fields — we are introducing neither. Existing fields are read implicitly via object-level Read.

### 22. Does the flexipage need activation?

- Question: Will the new chip appear automatically once the flexipage is updated?
- Answer: `Invoice_Record_Page.flexipage-meta.xml` is an existing deployed flexipage. Redeploying the updated XML pushes the change to the already-active page — no re-activation needed as long as it remains the default.
- Reasoning: CLAUDE.md notes activation is required for new flexipages. This is an edit to an existing one that is presumably already assigned as the org default (per prior commit history adding the badge to the Account flexipage). Validation phase will confirm via Playwright that the chip renders on the live page.

### 23. What is the output contract of the getter chain — where do labels/variants come from?

- Question: Hard-code strings or externalize?
- Answer: Hard-code English strings in the component (consistent with `accountOverdueInvoiceBadge` which also hard-codes). Expose label and variant as computed getters (`chipLabel`, `chipVariant`, `ariaLabel`) so tests can assert declaratively.
- Reasoning: No i18n infrastructure exists in the project yet (sibling LWCs use hard-coded English). Introducing custom labels for three strings adds ceremony without value. Revisit if/when the project gains a translation workflow.

### 24. Does the chip need to be reusable on other pages (e.g., related list)?

- Question: Should `isExposed=true` with multiple `targetConfigs`?
- Answer: `isExposed=true`, target only `lightning__RecordPage` with `object=Invoice__c`.
- Reasoning: Story scope is explicit: "on the Invoice record page." Exposing it to `lightning__AppPage` or as a `lightning__RecordField` cell would be speculative gold-plating. Keeping the target narrow matches the sibling LWCs and the "don't gold-plate" guidance.

### 25. Design-time configurability?

- Question: Should admins be able to set the amber threshold (currently 7) in Lightning App Builder?
- Answer: No. Hard-code `AMBER_THRESHOLD_DAYS = 7`.
- Reasoning: Story specifies 7 as the boundary without qualification. Adding a design attribute expands the surface and the test matrix. If a future story demands it, the constant is trivial to extract.

### 26. Performance — any risk?

- Question: Any concern about repeated renders or heavy computation?
- Answer: None. Single `getRecord` wire, two-field projection, trivial arithmetic on change.
- Reasoning: `getRecord` with a bounded field list is cache-backed by LDS. The computation is O(1). No measurable perf impact.

### 27. File list — what gets added / touched?

- Question: Exhaustive file manifest?
- Answer:
  - `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js` (new)
  - `force-app/main/lwc/invoiceDueChip/invoiceDueChip.html` (new)
  - `force-app/main/lwc/invoiceDueChip/invoiceDueChip.css` (new, may be empty if badge defaults suffice)
  - `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js-meta.xml` (new)
  - `force-app/main/lwc/invoiceDueChip/__tests__/invoiceDueChip.test.js` (new)
  - `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml` (edit: add componentInstance in header region)
- Reasoning: Derived from Q6, Q9, Q11, Q13, Q19. No Apex, no selector, no service, no permission-set edits.

## Summary — unambiguous plan

Build a new presentation-only LWC `invoiceDueChip` targeting the Invoice record page. It wires `getRecord` for `Invoice__c.Due_Date__c` and `Invoice__c.Status__c`, computes whole-day delta between today (local midnight, via `Date.UTC` normalization) and the due date, and renders a `lightning-badge` whose variant and label follow the state machine: red "N day(s) overdue" when days < 0, amber "Due today" when days = 0, amber "Due in N day(s)" when 1 <= days <= 7, green "Due in N day(s)" when days > 7. The badge is hidden entirely when Status is Paid or Cancelled, when Due_Date is null, or while the record is loading or in error. It is non-interactive, provides an `aria-label` mirroring the visible state, and hard-codes English labels plus the 7-day amber threshold. The component is added to the existing `Invoice_Record_Page` flexipage header region directly after `force:highlightsPanel`. No Apex, selector, service, or permission-set changes. Jest tests cover all states, boundary days (-1, 0, 1, 7, 8), pluralization, and the hidden states. No deployment/activation steps beyond deploying the updated flexipage.
