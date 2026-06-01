# Architecture: Invoice Lifecycle Progress Tracker

## Source story

`docs/features/invoice-lifecycle-tracker/01-grill.md` — resolved.

## Scope at a glance

Pure-LWC feature. Adds a new component `invoiceLifecycleTracker` that displays a horizontal 3-step stepper (Draft → Sent → Paid) in the header of the Invoice record page, directly after `c:invoiceDueChip`. Reads `Invoice__c.Status__c` via `@wire(getRecord)`. No Apex, no SOQL, no DML, no new objects/fields, no permission set changes. One flexipage edit. Tests are Jest-only.

## What already exists (do not re-create)

- `Invoice__c` custom object with `Status__c` restricted picklist (`Draft | Sent | Paid | Overdue | Cancelled`, default `Draft`).
  - `force-app/main/objects/Invoice__c/fields/Status__c.field-meta.xml`
- `c:invoiceDueChip` LWC — same record-page placement pattern, same read strategy (`@wire(getRecord)` + `getFieldValue`), same color tokens we will reuse.
  - `force-app/main/lwc/invoiceDueChip/`
- `Invoice_Record_Page` flexipage with a `header` region containing `force:highlightsPanel` then `c:invoiceDueChip`.
  - `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`
- `InvoiceUser` permission set already grants object/field access on `Invoice__c`.
- `c/testUtils` shared `flushPromises` helper (`jest-utils/testUtils/testUtils.js`).

## What we will NOT create

- No custom object, no custom field, no permission set change. `Status__c` is a restricted picklist on an already-permissioned object; FLS is implicit via object Read.
- No Apex trigger, handler, service, selector, or controller. UI API supplies all data.
- No new tab or page layout. Only a flexipage edit to add the component instance to the header region.
- No DML or SOQL anywhere — component is read-only by design (per grill Q15).

## Data model

Unchanged. The tracker is driven entirely by:

| Field                  | Type                | Source                                       |
| ---------------------- | ------------------- | -------------------------------------------- |
| `Invoice__c.Status__c` | Restricted picklist | Existing field — read via `@wire(getRecord)` |

## Component architecture

### `c:invoiceLifecycleTracker` — new LWC

- **Target**: `lightning__RecordPage`, object `Invoice__c`, API 66.0.
- **Placement**: Header region of `Invoice_Record_Page.flexipage-meta.xml`, as the third `itemInstance` after `force:highlightsPanel` (1st) and `c:invoiceDueChip` (2nd).
- **Public API**: `@api recordId` (record-page injected).
- **Data fetch**: `@wire(getRecord, { recordId: "$recordId", fields: [STATUS_FIELD] })` where `STATUS_FIELD = "@salesforce/schema/Invoice__c.Status__c"`. No Apex.
- **Read-only**: no event handlers, no click targets, no editing.
- **Reactivity**: standard `@wire` reactivity — when the record is updated elsewhere (e.g. Quick Action), the tracker re-renders automatically.

### State machine (status → render)

| `Status__c` value | Step 1 (Draft)       | Step 2 (Sent)        | Step 3 (Paid)        | `aria-current` on | Variant               |
| ----------------- | -------------------- | -------------------- | -------------------- | ----------------- | --------------------- |
| `Draft`           | current (brand ring) | upcoming             | upcoming             | step 1            | default               |
| `Sent`            | completed            | current (brand ring) | upcoming             | step 2            | success               |
| `Paid`            | completed            | completed            | current (brand ring) | step 3            | success-terminal      |
| `Overdue`         | completed            | current (brand ring) | upcoming             | step 2            | **error**             |
| `Cancelled`       | muted                | muted                | muted                | none              | **cancelled overlay** |
| any other / null  | treat as `Draft`     | —                    | —                    | step 1            | default               |

### Render states

- **Loading** (`!data && !error`): fixed-height skeleton (3 muted circles + 2 connectors) to reserve layout space. Prevents header reflow when the wire resolves.
- **Error** (`error` truthy): render nothing (empty template). Mirrors `invoiceDueChip` error handling.
- **Data**: render the stepper per the state machine above.

### Accessibility

- Root container: `role="group"` + dynamic `aria-label` (e.g. `"Invoice lifecycle: Sent. Step 2 of 3."` or `"Invoice cancelled. Lifecycle halted."`).
- Active step element: `aria-current="step"`.
- Each step has a visible label below the circle plus the same text as the circle's accessible name. Labels truncate with ellipsis on narrow widths and full text is exposed via `title` and the parent aria-label.
- Cancelled state: no `aria-current`; the overlay carries `aria-label="Cancelled"`.

### Styling

- Color tokens lifted from `invoiceDueChip.css`:
  - Completed/current success fill: `#2e844a`
  - Brand ring (current step emphasis): `#0176d3`, 2px
  - Error fill (Overdue current): `#ea001e`
  - Muted upcoming/cancelled: background `#dddbda`, text `#747474`
  - Cancelled overlay badge: background `#3e3e3c`, text `#ffffff`
- Layout: flexbox row, 3 circle nodes connected by 2 horizontal line segments. Labels stacked below each circle. CSS allows label wrap/truncate; no media queries required beyond base.
- Fixed `min-height` on root to keep skeleton + rendered states identical in vertical footprint.

## Apex architecture

None. No triggers, handlers, services, or selectors are added or modified.

## Implementation task list (dependency-ordered)

### 1. LWC component bundle — new

**File**: `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js-meta.xml`

- Create. API version 66.0. `isExposed=true`. Target `lightning__RecordPage`. `targetConfig` restricts to `Invoice__c`. Master label "Invoice Lifecycle Tracker", short description.
- **Acceptance**: deploys without error; component is visible to Lightning App Builder when editing an `Invoice__c` record page.

**File**: `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js`

- Create. `@api recordId`. `@wire(getRecord, { recordId: "$recordId", fields: [STATUS_FIELD] })` imports `STATUS_FIELD` from `@salesforce/schema/Invoice__c.Status__c`.
- Getters:
  - `isLoading` — `!data && !error`
  - `hasError` — truthy `error`
  - `status` — `getFieldValue(data, STATUS_FIELD)` or `null`
  - `effectiveStatus` — `status` if in `{Draft, Sent, Paid, Overdue, Cancelled}` else `Draft`
  - `isCancelled` — `effectiveStatus === "Cancelled"`
  - `steps` — array of 3 objects `{ key, label, classes, ariaCurrent, srOnly }` derived from `effectiveStatus`. Class names follow `lifecycle-step lifecycle-step_{state}` with state in `{completed, current, current-error, upcoming, muted}`.
  - `connectorClasses` — array of 2 connector class strings (`completed` / `upcoming` / `muted`).
  - `groupAriaLabel` — derived sentence per status.
  - `showCancelledOverlay` — boolean.
- No mutation methods. No imperative Apex.
- **Acceptance**: getters produce the matrix above for each of `{Draft, Sent, Paid, Overdue, Cancelled, null, "Unexpected"}`.

**File**: `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.html`

- Create. Outer `<template>` with `lwc:if={isLoading}` → skeleton block; `lwc:elseif={hasError}` → empty; `lwc:else` → stepper.
- Stepper root: `<div role="group" aria-label={groupAriaLabel} class="lifecycle-tracker">`.
- `<template for:each={steps} for:item="step">` rendering circle + label, applying `class={step.classes}`, `aria-current={step.ariaCurrent}` (undefined when not current — empty attribute won't render).
- Connectors rendered between steps using a sibling template iteration or hardcoded two `<span class={connectorClasses[0]}>` / `[1]` slots.
- Cancelled overlay: `<template lwc:if={showCancelledOverlay}>` renders a small badge absolutely positioned with `aria-label="Cancelled"`.
- **Acceptance**: each of the 5 status branches + loading + error renders the expected DOM (verified by Jest).

**File**: `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.css`

- Create. `:host { display:block; min-height: <fixed px> }`. Define classes `lifecycle-step_completed | _current | _current-error | _upcoming | _muted`, connector classes, skeleton classes, cancelled overlay, label truncation rules. Reuse the four color hex values from `invoiceDueChip.css`.
- **Acceptance**: loading skeleton and rendered tracker have identical outer height (no layout shift). Visual matches grill Q5/Q20 spec.

### 2. Flexipage edit

**File**: `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`

- Modify. Inside the existing `header` region, add a third `<itemInstances>` after the `c:invoiceDueChip` entry:
  ```xml
  <itemInstances>
      <componentInstance>
          <componentName>c:invoiceLifecycleTracker</componentName>
          <identifier>c_invoiceLifecycleTracker</identifier>
      </componentInstance>
  </itemInstances>
  ```
- Do not modify `main` or `sidebar` regions.
- **Acceptance**: flexipage deploys; opening an Invoice record in the org shows the tracker beneath the due chip in the highlights area.

### 3. Jest tests

**File**: `force-app/main/lwc/invoiceLifecycleTracker/__tests__/invoiceLifecycleTracker.test.js`

- Create. Mirror the structure of `invoiceDueChip.test.js`. Import `flushPromises` from `c/testUtils` (never inline).
- Helper `buildRecord({ status })` returning `{ apiName: "Invoice__c", fields: { Status__c: { value: status } } }`.
- Cases:
  1. **Loading state** — wire neither emits nor errors; expect skeleton DOM (3 placeholder circles, no `role="group"` stepper or `role="group"` present with skeleton class — pick one and assert consistently).
  2. **Error state** — emit `{ error: {...} }`; expect no rendered children for tracker (empty body).
  3. **Draft** — `aria-current="step"` on step 1; steps 2 and 3 in upcoming state.
  4. **Sent** — step 1 completed, step 2 current (success variant), step 3 upcoming.
  5. **Paid** — all three steps completed, step 3 carries `aria-current="step"`.
  6. **Overdue** — step 2 current with error variant class (`lifecycle-step_current-error`).
  7. **Cancelled** — all steps muted, no element has `aria-current`, cancelled overlay rendered.
  8. **Unknown status** (`"Foo"` and `null`) — falls back to Draft behavior.
  9. **Accessibility** — root has `role="group"` and a meaningful `aria-label` per status.
- Use the `@salesforce/sfdx-lwc-jest` `getRecord` adapter (`getRecord.emit(...)` / `getRecord.error(...)`).
- **Acceptance**: `npm run test:unit` passes with all cases green; coverage on `invoiceLifecycleTracker.js` ≥ 95%.

### 4. Permissions and layout — N/A

No changes. Validate during review that `InvoiceUser` already grants `Read` on `Invoice__c` (it does — see `force-app/main/permissionsets/InvoiceUser.permissionset-meta.xml`). `Status__c` is reachable via that object grant; no FLS entry needed for restricted picklist read.

### 5. Post-deploy verification (manual / Playwright)

- Deploy `force-app/main`.
- Open an Invoice record; confirm the tracker appears in the header beneath the due chip.
- Toggle `Status__c` through `Draft → Sent → Paid` via record edit and observe the highlighted step move.
- Set `Status__c = Overdue` and observe error styling on step 2.
- Set `Status__c = Cancelled` and observe muted layout + Cancelled overlay.
- Flexipage activation: the Invoice record page is already the org default (prior features), so no manual activation step is needed. If a fresh org is used, follow the activation checklist in `CLAUDE.md`.

## File inventory (final)

Created:

- `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js`
- `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.html`
- `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.css`
- `force-app/main/lwc/invoiceLifecycleTracker/invoiceLifecycleTracker.js-meta.xml`
- `force-app/main/lwc/invoiceLifecycleTracker/__tests__/invoiceLifecycleTracker.test.js`

Modified:

- `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml` (one new `itemInstances` block in the `header` region)

Untouched: all Apex, all selectors, all permission sets, all other LWCs, all triggers, all object/field metadata.

## Risk register

- **Layout shift on load** — mitigated by fixed-height skeleton matching rendered tracker height.
- **Unknown future picklist value** — mitigated by `effectiveStatus` defaulting to `Draft`.
- **Narrow viewport overflow** — mitigated by flex shrink + label ellipsis; no media queries required.
- **Status update propagation** — `@wire(getRecord)` invalidates automatically when the record changes via standard Salesforce mechanisms; no manual refresh wiring needed.
- **Flexipage not active** — addressed in the post-deploy step; flexipage is already the org default from earlier features.
