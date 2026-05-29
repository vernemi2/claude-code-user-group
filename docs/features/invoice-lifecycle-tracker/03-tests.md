# Tests: Invoice Lifecycle Progress Tracker

## Scope

LWC-only feature. No Apex classes were added or modified, so no new Apex tests
were required. All testing is Jest-based and covers the new
`c/invoiceLifecycleTracker` component.

## New test artifacts

| File                                                                                   | Purpose                                  |
| -------------------------------------------------------------------------------------- | ---------------------------------------- |
| `force-app/main/lwc/invoiceLifecycleTracker/__tests__/invoiceLifecycleTracker.test.js` | Jest suite for the lifecycle tracker LWC |

## Jest test coverage

The suite (`c-invoice-lifecycle-tracker`) exercises every render branch
described in `02-architecture.md`:

- **Loading state** — verifies the fixed-height skeleton renders (3 muted
  step placeholders + 2 connector placeholders, `aria-hidden="true"`) and
  the live stepper is absent.
- **Error state** — emits `getRecord.error()` and asserts that neither the
  skeleton nor the rendered stepper is present (component yields an empty
  DOM, mirroring `invoiceDueChip`).
- **Draft branch** — step 1 has `lifecycle-step_current` + `aria-current="step"`;
  steps 2 and 3 are upcoming; both connectors upcoming.
- **Sent branch** — step 1 completed, step 2 current with
  `aria-current="step"`, step 3 upcoming; connector 1 completed,
  connector 2 upcoming.
- **Paid branch** — steps 1 and 2 completed; step 3 current with
  `aria-current="step"`; both connectors completed.
- **Overdue branch** — step 2 carries the `lifecycle-step_current-error`
  variant class and `aria-current="step"`.
- **Cancelled branch** — every step muted, no `aria-current` on any step,
  every connector muted, cancelled overlay rendered with
  `aria-label="Cancelled"`.
- **Unknown / null status fallback** — both `null` and `"Unexpected"` fall
  back to Draft behavior; cancelled overlay is not rendered.
- **Accessibility aria-label content** — verifies the exact `aria-label`
  strings on the `role="group"` root for Draft, Sent, Paid, Overdue, and
  Cancelled (including the special "Sent (overdue)" and "Invoice
  cancelled. Lifecycle halted." wordings).

`flushPromises` is imported from `c/testUtils` per project convention
(never inlined). The `@wire(getRecord)` adapter is driven via
`getRecord.emit(...)` / `getRecord.error()` from
`@salesforce/sfdx-lwc-jest`.

## Results

### Jest

- Suites: **7 passed, 7 total**
- Tests: **66 passed, 66 total** (includes the 14 new
  `invoiceLifecycleTracker` cases plus all previously existing suites)
- Failures: 0

### Apex

- Test level: `RunLocalTests`
- Tests Ran: **590**
- Pass Rate: **100%**
- Failures: 0

No new Apex test classes were required (LWC-only feature). Existing org
test suite continued to pass after deployment.

## Deployment

- `sf project deploy start --source-dir force-app/main --source-dir force-app/test`
  completed successfully on first attempt — the new
  `invoiceLifecycleTracker` LWC bundle was created and the existing
  flexipage `Invoice_Record_Page` was updated with the new `itemInstances`
  entry.

## Self-healing

- **Cycles used: 0** — Jest suite passed on first run; deployment and the
  full local Apex test run also passed on first execution.

## Outstanding TODOs

None.
