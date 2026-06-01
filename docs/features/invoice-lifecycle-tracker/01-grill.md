# Grill: Invoice Lifecycle Progress Tracker

Input: "As an account manager, I want to see a visual progress tracker on the Invoice page showing Draft → Sent → Paid with the current step highlighted, so I can instantly understand where each invoice is in its lifecycle."

## Resolved decisions

### 1. Which object and field drives the tracker?

- Question: What is the source of truth for the lifecycle step?
- Answer: `Invoice__c.Status__c` — a required, restricted picklist.
- Reasoning: Confirmed at `force-app/main/objects/Invoice__c/fields/Status__c.field-meta.xml`. The picklist values are `Draft | Sent | Paid | Overdue | Cancelled` with `Draft` as default. Status is required and restricted, so the tracker can rely on a known finite set of values and never has to render an "unknown" step.

### 2. The picklist has 5 values but the story names 3. What about Overdue and Cancelled?

- Question: How does the tracker behave when `Status__c` is `Overdue` or `Cancelled`, which fall outside the canonical Draft → Sent → Paid path?
- Answer:
  - `Overdue` is treated as the **Sent** step (sent-but-not-paid), with an additional error/warning visual treatment indicating the invoice is overdue. The path still renders as Draft → Sent → Paid; the Sent step is highlighted but styled to communicate the negative state.
  - `Cancelled` is treated as a **terminal off-path state**: the tracker renders a single-line "Cancelled" indicator (or a fully greyed-out path with a "Cancelled" badge) rather than the 3-step progression. Showing a half-progressed path for a cancelled invoice would be misleading.
- Reasoning: The existing `invoiceDueChip` already classifies `Paid` and `Cancelled` as `TERMINAL_STATUSES` and hides itself for them (`invoiceDueChip.js:8,40-41`). Overdue is semantically "Sent but past due" — the data model treats it as a live, working invoice (`SOQL_Invoice` overdue logic excludes Paid/Cancelled, per the prior grill). Mapping Overdue → Sent step keeps the 3-step narrative coherent while letting the urgency be expressed visually. Cancelled is a true off-path terminal; treating it as "Paid" would be wrong (no money received) and treating it as "Draft" would be wrong (it cannot progress further). A distinct cancelled treatment is the only honest option.
- Follow-on: This unlocks decisions on visual variants per step (Q5) and on the Cancelled-state UI (Q6).

### 3. Should the tracker be a new LWC or embedded inside an existing component?

- Question: Where does this live?
- Answer: New LWC, named `invoiceLifecycleTracker`, exposed to `lightning__RecordPage` with object `Invoice__c`.
- Reasoning: Project convention places one purpose per LWC (e.g. `invoiceDueChip`, `invoicePayments`, `overdueInvoiceBanner`). A progress tracker is visually and semantically distinct from the due-date chip. Naming follows the `camelCase` convention noted in `CLAUDE.md` and the existing components.

### 4. Where on the Invoice record page does it sit?

- Question: Header, main body, or sidebar region of `Invoice_Record_Page.flexipage-meta.xml`?
- Answer: Header region, **after** the existing `c:invoiceDueChip` (so it sits beneath the highlights panel + chip, above the detail panel).
- Reasoning: A progress tracker is a status-at-a-glance summary, which is the purpose of the header region. The flexipage currently has `force:highlightsPanel` and `c:invoiceDueChip` in the header (`Invoice_Record_Page.flexipage-meta.xml:3-22`). Placing the tracker in the header keeps all "where is this invoice right now?" signals co-located. Ordering it after the chip preserves the existing user's mental model and limits visual churn.

### 5. What is the visual representation?

- Question: SLDS path component, custom progress bar with circles, breadcrumb, or stepper?
- Answer: Custom HTML/CSS horizontal stepper built from three pill/circle nodes connected by lines, styled with SLDS tokens — NOT `lightning-progress-indicator` and NOT a raw SLDS Path.
- Reasoning:
  - `lightning-progress-indicator` with `type="path"` is the natural built-in candidate, but it expects the user to click steps to advance and is designed for guided processes, not read-only state display. It also doesn't gracefully express the "Overdue → Sent step in error variant" requirement.
  - `lightning-progress-indicator` with `type="base"` is closer (read-only) but its visual styling is for wizards (numbered steps, completed checkmarks) which is heavier than the "instantly understand" intent in the story.
  - A custom stepper using SLDS design tokens (matching the chip's variant colors: success/warning/error in `invoiceDueChip.css:6-25`) gives precise control over the overdue-as-error treatment and aligns visually with the chip already in the header.
  - Steps to the **left** of current are filled with a "completed" color (SLDS success green `#2e844a`); the **current** step is highlighted (filled + larger or with a ring); steps to the **right** are an "upcoming" muted state (SLDS neutral grey).

### 6. How does the Cancelled state render?

- Question: Concrete UI for Cancelled — the off-path terminal state.
- Answer: Render the 3-step path in a fully muted/greyed style with a strikethrough or `Cancelled` badge overlay, and a screen-reader-friendly label "Invoice cancelled". No step is highlighted as "current". The tracker is still rendered (not hidden) so the user sees the lifecycle was halted.
- Reasoning: Hiding the tracker on Cancelled would leave a hole in the page header layout and remove a useful signal (the user wants to know an invoice is cancelled, not just that nothing is showing). The existing `invoiceDueChip` hides itself on Cancelled because urgency is irrelevant — but lifecycle is still relevant to display, just in a halted form.

### 7. Should the tracker show on Paid invoices?

- Question: Once an invoice is Paid, do we still render the tracker?
- Answer: Yes — render with all three steps in "completed" state and the Paid step highlighted as current/terminal-success. This is the user's reward state and a confirmation that the lifecycle is complete.
- Reasoning: Unlike the urgency chip, which is meaningless once paid, the lifecycle tracker's job is to communicate "where is this invoice in its lifecycle?" — "fully done" is a valid answer worth showing. First principles: the story is about lifecycle visibility, not just open-invoice tracking.

### 8. Should the component fetch data via @wire or Apex?

- Question: Read pattern.
- Answer: `@wire(getRecord)` from `lightning/uiRecordApi`, requesting only `Status__c`.
- Reasoning: `CLAUDE.md` directs "Use `@wire` for data reads, `lightning/uiRecordApi` for CRUD". The existing `invoiceDueChip.js` uses exactly this pattern (`invoiceDueChip.js:13-17`). Only one field is needed, so no Apex controller is justified. No DML, no SOQL needed — therefore no service/selector layer changes.

### 9. Does this require any Apex?

- Question: New controller, service, or selector?
- Answer: No.
- Reasoning: All required data (`Status__c`) is reachable via UI API. Following the "minimal surface area" principle and the precedent of `invoiceDueChip` (zero Apex), the feature should remain pure LWC. This also keeps the test surface small and means no permission set changes.

### 10. Does this require permission set updates?

- Question: New fields or objects added?
- Answer: No.
- Reasoning: `Invoice__c.Status__c` is a standard restricted picklist on an already-permissioned object (`InvoiceUser.permissionset-meta.xml:4-12`). Picklist fields don't need explicit field-level security entries in the permission set when the parent object grants Read. No new metadata is being introduced.

### 11. Loading and error states?

- Question: How do we render while `getRecord` is pending or errors?
- Answer:
  - Loading (`!data && !error`): render a skeleton — three muted circles + connectors at fixed dimensions — to reserve the layout space. This avoids layout shift on the Invoice header.
  - Error: render nothing (return `null` template). The record page itself shows its own error surface, and a broken tracker adds no signal.
- Reasoning: `invoiceDueChip.js:19-25` chose "render nothing" for both loading and error, but that component is a small inline badge. The lifecycle tracker is larger and would cause a visible layout reflow when it appears after the wire resolves; a fixed-height skeleton is the standard mitigation. Error parity with the chip keeps overall behavior consistent.

### 12. Accessibility?

- Question: How does a screen-reader user understand the tracker?
- Answer:
  - Wrap the tracker in a `role="group"` with an `aria-label` describing the lifecycle (e.g. "Invoice lifecycle: Sent. 2 of 3 steps complete.").
  - Each step has a visually hidden label and an `aria-current="step"` on the active one.
  - Cancelled state: `aria-label="Invoice cancelled. Lifecycle halted at Sent."` (or whichever step was last reached, if derivable — see Q13).
- Reasoning: SLDS path/stepper accessibility patterns + the existing component's accessibility precedent (`invoiceDueChip.html:3` uses `role="status"` + `aria-label`). The story says "instantly understand" — accessibility users deserve the same instant comprehension.

### 13. For the Cancelled state, do we know which step the invoice was at before cancellation?

- Question: Cancelled is a "last reached step" history question. Can we recover it?
- Answer: No — and we won't try. The Cancelled visual simply shows all three steps in a muted state with "Cancelled" overlay; we do NOT attempt to highlight the pre-cancellation step.
- Reasoning: There is no audit field (`Last_Status__c`, history tracking) modelled. Adding one would scope-creep the story significantly. The user story's intent is "where is this invoice in its lifecycle?" — "Cancelled" is a complete answer on its own. Showing a fake "last known" step risks lying to the user.

### 14. What if `Status__c` somehow resolves to an unexpected value?

- Question: Defensive handling.
- Answer: Treat any value not in `{Draft, Sent, Paid, Overdue, Cancelled}` as Draft (the picklist's default) and log nothing. The picklist is restricted so this is theoretically impossible, but defensive default-to-first-step prevents a blank tracker.
- Reasoning: Status is a restricted picklist — practically a closed set. But LWC code defending against a future picklist value addition is cheap insurance. Defaulting to Draft is the least surprising fallback.

### 15. Should the tracker be clickable / interactive?

- Question: Click to advance status?
- Answer: No — read-only display. Clicking a step does nothing.
- Reasoning: The story says "see" and "instantly understand" — pure observation. Status transitions belong to the existing record edit flow / Quick Actions, not a glance widget. Making it interactive would invite users to bypass validation rules and downstream automation.

### 16. Mobile / narrow viewport behaviour?

- Question: How does the horizontal stepper handle narrow widths?
- Answer: Use CSS to allow the connectors to shrink and the labels to wrap below each circle. At the smallest widths, the labels truncate with `text-overflow: ellipsis` and the full label is exposed via `title` and aria-label.
- Reasoning: Lightning record pages render in both Salesforce Mobile and narrow split-view layouts. Horizontal-only layouts that overflow horizontally look broken in those contexts. SLDS responsive utility classes are sufficient — no media queries past base CSS.

### 17. Testing strategy?

- Question: What does "tested" mean for this component?
- Answer: Jest tests in `force-app/main/lwc/invoiceLifecycleTracker/__tests__/invoiceLifecycleTracker.test.js`. Coverage:
  - Loading state renders skeleton (3 placeholder nodes).
  - Error state renders nothing.
  - Each status (`Draft`, `Sent`, `Paid`, `Overdue`, `Cancelled`) renders the expected highlighted step + variant.
  - Overdue renders the Sent step with error variant.
  - Cancelled renders the muted/cancelled layout with no `aria-current`.
  - Accessibility: `aria-label` on the group container, `aria-current="step"` on the active step.
  - Defensive: unknown status defaults to Draft.
  - Uses `flushPromises` from `c/testUtils` per `CLAUDE.md`.
- Reasoning: Pure-LWC component → Jest is sufficient; no Apex tests needed because no Apex was written. Test scenarios mirror `invoiceDueChip.test.js` structure (loading/error/variant boundaries/pluralization sections). Coverage targets each branch of the status → step mapping.

### 18. Flexipage activation reminder?

- Question: Will adding the component to the flexipage take effect on deploy?
- Answer: The flexipage edit will deploy, but the flexipage must already be the org-default Invoice record page (it is, per prior features). No additional activation step needed if it's already active. Otherwise, follow the `CLAUDE.md` "Flexipage activation" checklist post-deploy.
- Reasoning: `CLAUDE.md` Deployment Checklist step 3 — deploying a flexipage does NOT activate it. The Invoice flexipage is already active from prior features (`invoiceDueChip`, `invoicePayments`).

### 19. Naming conventions for files?

- Question: Exact paths.
- Answer:
  - `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js`
  - `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.html`
  - `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.css`
  - `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js-meta.xml` (`lightning__RecordPage` target, `Invoice__c` object, API 66.0)
  - `force-app/main/lwc/invoiceLifecycleTracker/__tests__/invoiceLifecycleTracker.test.js`
  - Flexipage edit: `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`
- Reasoning: Project structure section of `CLAUDE.md` + existing component file layouts.

### 20. Colors / design tokens?

- Question: Specific palette.
- Answer: Reuse the chip palette (SLDS-aligned):
  - Completed step fill: `#2e844a` (SLDS success).
  - Current step fill: same as completed but with a 2px ring in `#0176d3` (SLDS brand) for emphasis.
  - Overdue current step fill: `#ea001e` (SLDS error) — matches `invoiceDueChip.css:21`.
  - Upcoming step fill: `#dddbda` (SLDS neutral border-color) with `#747474` text.
  - Cancelled palette: all steps muted (`#dddbda`) with a `#3e3e3c` "Cancelled" badge overlay.
- Reasoning: Reusing the chip's color tokens keeps the header visually unified. Token values lifted from `invoiceDueChip.css` and SLDS palette references.

---

## Summary

Build a new LWC `invoiceLifecycleTracker` exposed to `lightning__RecordPage` for `Invoice__c`, placed in the header region of `Invoice_Record_Page.flexipage-meta.xml` directly after `c:invoiceDueChip`. The component reads `Invoice__c.Status__c` via `@wire(getRecord)` (no Apex). It renders a horizontal 3-step custom stepper (Draft → Sent → Paid) using SLDS-aligned colors that match the existing due-chip palette. Status mapping: `Draft` highlights step 1; `Sent` highlights step 2 with success styling; `Paid` highlights step 3 and shows all three steps as completed; `Overdue` highlights step 2 with error styling; `Cancelled` renders all steps muted with a "Cancelled" overlay and no active step. Loading shows a fixed-height skeleton to prevent layout shift; errors render nothing. The component is read-only (no click handlers), fully accessible (`role="group"`, `aria-label`, `aria-current="step"`), and gracefully handles unknown picklist values by defaulting to Draft. Tests are Jest-only, covering each status branch, loading, error, accessibility attributes, and the unknown-status fallback. No Apex, no DML, no SOQL, no permission set updates, no new fields — pure LWC + one flexipage edit.
