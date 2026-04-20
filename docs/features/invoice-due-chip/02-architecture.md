# Architecture: Invoice Due-Date Urgency Chip

## 1. Summary

Presentation-only Lightning Web Component `invoiceDueChip` surfacing a color-coded `lightning-badge` on the Invoice record page header. Reads `Due_Date__c` and `Status__c` via `lightning/uiRecordApi.getRecord`, computes whole-day delta between today (local wall-clock) and the due date using `Date.UTC` normalization, and renders:

- **red / `variant="error"`** — `"N day overdue"` / `"N days overdue"` when `daysUntilDue < 0`
- **amber / `variant="warning"`** — `"Due today"` when `daysUntilDue === 0`; `"Due in N day(s)"` when `1 <= daysUntilDue <= 7`
- **green / `variant="success"`** — `"Due in N day(s)"` when `daysUntilDue > 7`

The chip renders **nothing** when Status is `Paid` or `Cancelled`, when `Due_Date__c` is null, while the wire is loading, or on wire error.

No Apex, no selector, no service, no permission-set changes. Only new LWC bundle plus one edit to the existing `Invoice_Record_Page` flexipage.

## 2. Data Model

No changes. Feature consumes existing fields:

| Object       | Field         | Type                                             | Required | Notes                            |
| ------------ | ------------- | ------------------------------------------------ | -------- | -------------------------------- |
| `Invoice__c` | `Due_Date__c` | Date                                             | Yes      | Read-only here; drives the delta |
| `Invoice__c` | `Status__c`   | Picklist (Draft, Sent, Paid, Overdue, Cancelled) | Yes      | Gates chip visibility            |

## 3. Apex Architecture

None. This is a pure client-side presentation feature. Confirmed in the grill (Q6, Q13, Q20).

- No trigger
- No handler
- No service
- No SOQL selector changes
- No DML
- No `@AuraEnabled` controller

## 4. Component Architecture

### Component: `invoiceDueChip`

- **Location**: `force-app/main/lwc/invoiceDueChip/`
- **Placement**: `Invoice_Record_Page` flexipage, `header` region, directly after `force:highlightsPanel`
- **Target**: `lightning__RecordPage`, `object = Invoice__c`, `isExposed = true`
- **Data acquisition**: `@wire(getRecord, { recordId: '$recordId', fields: [DUE_DATE_FIELD, STATUS_FIELD] })`
- **No imperative Apex**, **no NavigationMixin**, **no CRUD**, non-interactive.

### State machine (derived in getters)

```
status in {Paid, Cancelled} -> render nothing
dueDate == null             -> render nothing
wire loading (no data)      -> render nothing
wire error                  -> render nothing
dueDate < today (days < 0)  -> variant=error,  label="|days| day(s) overdue"
dueDate == today (days = 0) -> variant=warning, label="Due today"
1 <= days <= 7              -> variant=warning, label="Due in N day(s)"
days > 7                    -> variant=success, label="Due in N day(s)"
```

### Day-delta computation (client-side)

```js
const AMBER_THRESHOLD_DAYS = 7;
const MS_PER_DAY = 86_400_000;

// today at local wall-clock, normalized via UTC
const now = new Date();
const todayUtc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());

// due at local wall-clock for Salesforce Date field (YYYY-MM-DD)
const [y, m, d] = dueDateIso.split("-").map(Number);
const dueUtc = Date.UTC(y, m - 1, d);

const daysUntilDue = Math.round((dueUtc - todayUtc) / MS_PER_DAY);
```

### Getters (for testability and template declarative use)

- `isHidden` — boolean, combines loading/error/null/Paid/Cancelled
- `daysUntilDue` — integer or null
- `chipVariant` — `'success' | 'warning' | 'error'`
- `chipLabel` — visible text
- `ariaLabel` — screen-reader sentence mirroring the visible state and urgency

### Accessibility

- `lightning-badge` wrapped in a `<span role="status" aria-label={ariaLabel}>` so the color-only signal has a text equivalent (WCAG).
- Non-interactive — no button, no tabindex.

## 5. File Manifest

### New files

| Path                                                                 | Purpose                                                                                    |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js`                | Component class, wire, getters                                                             |
| `force-app/main/lwc/invoiceDueChip/invoiceDueChip.html`              | Template: `<template lwc:if={isVisible}>` wrapping `lightning-badge`                       |
| `force-app/main/lwc/invoiceDueChip/invoiceDueChip.css`               | Optional spacing tweaks (may be empty)                                                     |
| `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js-meta.xml`       | `apiVersion=66.0`, `isExposed=true`, target `lightning__RecordPage` scoped to `Invoice__c` |
| `force-app/main/lwc/invoiceDueChip/__tests__/invoiceDueChip.test.js` | Jest covering all states and day boundaries                                                |

### Edited files

| Path                                                               | Change                                                                                                                               |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml` | Add a second `itemInstances` entry to the existing `header` region referencing `c:invoiceDueChip` with identifier `c_invoiceDueChip` |

### Untouched (explicit)

- `force-app/main/classes/**` — no Apex changes
- `force-app/main/permissionsets/InvoiceUser.permissionset-meta.xml` — `Due_Date__c` and `Status__c` are already readable via object-level access (both are required fields, no fieldPermissions suppress them)
- `force-app/main/objects/Invoice__c/**` — no object/field changes

## 6. Task List (ordered by dependency)

### Phase 1 — Metadata (none)

_No object or field changes._

### Phase 2 — Apex (none)

_No Apex work._

### Phase 3 — LWC

1. **Create `invoiceDueChip.js-meta.xml`**
   - File: `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js-meta.xml`
   - `<apiVersion>66.0</apiVersion>`, `<isExposed>true</isExposed>`
   - `<masterLabel>Invoice Due Chip</masterLabel>` with a short `<description>`
   - Target: `lightning__RecordPage` with `targetConfig` scoped to `Invoice__c`
   - **Acceptance**: Deploys without error; component appears in the Lightning App Builder component palette on an Invoice record page.

2. **Create `invoiceDueChip.js`**
   - File: `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js`
   - Imports: `LightningElement, api, wire` from `lwc`; `getRecord, getFieldValue` from `lightning/uiRecordApi`; `@salesforce/schema/Invoice__c.Due_Date__c` and `Invoice__c.Status__c`.
   - `@api recordId`
   - `@wire(getRecord, { recordId: '$recordId', fields: [DUE_DATE_FIELD, STATUS_FIELD] }) invoice`
   - Module-level constant `AMBER_THRESHOLD_DAYS = 7`
   - Getters: `dueDate`, `status`, `isLoading`, `hasError`, `isTerminalStatus` (Paid/Cancelled), `isVisible`, `daysUntilDue`, `chipVariant`, `chipLabel`, `ariaLabel`
   - No static methods, no side effects outside getters, no DOM manipulation
   - **Acceptance**: All getters return deterministic values given the `invoice` wire result and current date; no raw SOQL/DML references.

3. **Create `invoiceDueChip.html`**
   - File: `force-app/main/lwc/invoiceDueChip/invoiceDueChip.html`
   - Single root `<template>` containing `<template lwc:if={isVisible}>` → `<span role="status" aria-label={ariaLabel}><lightning-badge label={chipLabel} variant={chipVariant}></lightning-badge></span>`
   - No loading or error placeholder (silent per grill Q14)
   - **Acceptance**: Renders nothing when `isVisible` is false; renders a single `lightning-badge` otherwise.

4. **Create `invoiceDueChip.css`** (optional)
   - File: `force-app/main/lwc/invoiceDueChip/invoiceDueChip.css`
   - Minimal — `:host { display: inline-block; }` and optional small left margin so the chip sits cleanly under the highlights panel. May be empty if the default spacing looks correct; leave the file in the bundle for consistency with sibling LWCs.
   - **Acceptance**: Deploys; no visual regressions on the highlights panel.

### Phase 4 — Tests

5. **Create `invoiceDueChip.test.js`**
   - File: `force-app/main/lwc/invoiceDueChip/__tests__/invoiceDueChip.test.js`
   - Import the Jest wire adapter for `getRecord` via `@salesforce/sfdx-lwc-jest` (`import { getRecord } from 'lightning/uiRecordApi';`) and emit mock records with `getRecord.emit(mockRecord)`.
   - Import `flushPromises` from `c/testUtils` (per CLAUDE.md) — do not redefine inline.
   - Use `jest.useFakeTimers()` with `jest.setSystemTime(new Date('2026-04-20T12:00:00Z'))` so day math is deterministic.
   - Required test cases (from grill Q19, plus the day-boundary matrix -1/0/1/7/8 noted in the story summary):
     1. `renders nothing while wire is loading` — no `getRecord.emit` call; assert no `lightning-badge` in DOM.
     2. `renders nothing on wire error` — `getRecord.emitError()`; assert no badge.
     3. `renders nothing when status is Paid` — emit record with Status=Paid, any Due_Date; assert no badge.
     4. `renders nothing when status is Cancelled` — same pattern.
     5. `renders nothing when Due_Date is null` — Status=Draft, Due_Date=null.
     6. `renders red "1 day overdue" at days = -1` — Due_Date = 2026-04-19.
     7. `renders amber "Due today" at days = 0` — Due_Date = 2026-04-20.
     8. `renders amber "Due in 1 day" at days = 1` — Due_Date = 2026-04-21.
     9. `renders amber "Due in 7 days" at days = 7` (upper amber boundary) — Due_Date = 2026-04-27.
     10. `renders green "Due in 8 days" at days = 8` (lower green boundary) — Due_Date = 2026-04-28.
     11. `pluralization: "2 days overdue"` — Due_Date = 2026-04-18.
     12. `variant mapping`: assert `variant="error"` for overdue, `"warning"` for today/<=7, `"success"` for > 7.
     13. `aria-label reflects visible state` — assert the `<span role="status">` aria-label describes urgency (e.g., includes "overdue" / "due today" / "due in").
   - **Acceptance**: `npm run test:unit -- invoiceDueChip` passes all cases. Coverage for the component file is 100% of branches in the state machine.

### Phase 5 — Flexipage update

6. **Edit `Invoice_Record_Page.flexipage-meta.xml`**
   - File: `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`
   - In the existing `header` region, add a second `<itemInstances>` block directly after the `force_highlightsPanel` entry:
     ```xml
     <itemInstances>
       <componentInstance>
         <componentName>c:invoiceDueChip</componentName>
         <identifier>c_invoiceDueChip</identifier>
       </componentInstance>
     </itemInstances>
     ```
   - **Acceptance**: Deploy succeeds; chip visible in the header of an existing Invoice record page without requiring re-activation (page is the existing org default).

### Phase 6 — Permissions

_No changes._ `Due_Date__c` and `Status__c` are required fields on `Invoice__c`; the `InvoiceUser` permission set already grants object-level Read on `Invoice__c`. Field read is implicit.

## 7. Deployment Checklist

- [ ] `sf project deploy start --source-dir force-app/main/lwc/invoiceDueChip --source-dir force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`
- [ ] Deploy full test package: `sf project deploy start --source-dir force-app/main --source-dir force-app/test`
- [ ] `npm run test:unit -- invoiceDueChip` — all green
- [ ] `npm run lint` — clean
- [ ] `npm run prettier` — clean
- [ ] (Validation phase) Playwright: navigate to an Invoice record, verify chip renders in the header with the expected color and label for at least one overdue and one future-due record; verify chip disappears when the Invoice is marked Paid.

## 8. Out of Scope / Explicit Non-Goals

- No design-time attribute for the amber threshold (grill Q25) — hard-coded `7`.
- No exposure to `lightning__AppPage` or `lightning__RecordField` (grill Q24).
- No i18n / custom labels (grill Q23).
- No click navigation (grill Q16).
- No changes to `SOQL_Invoice` or any service/controller (grill Q6, Q13).
- No permission-set edits (grill Q21).
