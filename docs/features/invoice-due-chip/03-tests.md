# Test Phase — invoice-due-chip

## Summary

Test coverage added for the new `invoiceDueChip` LWC component. No Apex source
changed in this feature, so no new Apex test classes were required; the full
`RunLocalTests` suite was executed as a safety check after deploying the LWC.

## New test files

| File                                                                 | Purpose                                                                                       |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `force-app/main/lwc/invoiceDueChip/__tests__/invoiceDueChip.test.js` | Jest specs for hidden states, variant boundaries, pluralization, and aria-label accessibility |

No new Apex test classes were needed.

## Jest results

- Suite: `c-invoice-due-chip`
- Tests: **19 passed / 0 failed**
- Groups covered:
  - Hidden states: loading, wire error, null due date, `Paid` status, `Cancelled` status
  - Variant boundaries: overdue -1d (error), due today 0d (warning), due soon
    +1d (warning, lower amber bound), +7d (warning, upper amber bound), +8d
    (success, just past amber)
  - Pluralization: singular `day` vs. plural `days` for both overdue and
    upcoming, inside the badge label
  - Accessibility: `role="status"` container present, `aria-label` wording
    covers overdue singular/plural, due today, due in 1 day, due in N days

Deterministic "today" is achieved by replacing `global.Date` with a subclass
whose zero-arg constructor and `Date.now()` return a fixed timestamp
(2026-04-20). `jest.useFakeTimers` is intentionally **not** used because it
would stall `flushPromises` (which relies on `setTimeout`).

All tests use `flushPromises` imported from the shared `c/testUtils` service
component per project conventions.

## Apex safety run

- Command: `sf apex run test --test-level RunLocalTests --result-format human --wait 10`
- Outcome: **Passed**
- Tests ran: **561**
- Pass rate: **100%**
- Fail rate: 0%
- Coverage: not reported in this phase (no Apex changes in this feature)

## Deployment

- Command: `sf project deploy start --source-dir force-app/main/lwc/invoiceDueChip`
- Status: **Succeeded** (4 files changed: css, html, js, js-meta.xml)
- Deploy ID: `0AfdL00000ZNyLvSAL`

## Self-heal cycles

**1 iteration.** Initial Jest run timed out on every test because
`jest.useFakeTimers()` was faking `setTimeout`, which caused the shared
`flushPromises` helper to hang indefinitely. Replaced the fake-timers approach
with a `global.Date` subclass that only pins the current time, leaving
`setTimeout` untouched. Second run: 19/19 passing.

## Remaining TODOs

None.
