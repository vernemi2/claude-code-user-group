# Review — Invoice Due Chip

Reviewer: Claude (senior Salesforce code reviewer)
Branch: `feature/invoice-due-chip`
Scope: all uncommitted changes in `force-app/main/` and the new `force-app/main/lwc/invoiceDueChip/`.

## Summary

| Area                 | Verdict               |
| -------------------- | --------------------- |
| Apex — security      | N/A (no Apex changed) |
| Apex — performance   | N/A (no Apex changed) |
| Apex — architecture  | N/A (no Apex changed) |
| Apex — testing       | N/A (no Apex changed) |
| LWC — best practices | Pass                  |
| Metadata             | Pass                  |
| Prettier             | Clean                 |
| ESLint               | Clean                 |
| Deploy dry-run       | Succeeded             |
| Jest                 | 38/38 pass            |

No issues required code fixes. This review validates the existing implementation against the CLAUDE.md checklist and confirms nothing regressed.

## Files Reviewed

- `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js`
- `force-app/main/lwc/invoiceDueChip/invoiceDueChip.html`
- `force-app/main/lwc/invoiceDueChip/invoiceDueChip.css`
- `force-app/main/lwc/invoiceDueChip/invoiceDueChip.js-meta.xml`
- `force-app/main/lwc/invoiceDueChip/__tests__/invoiceDueChip.test.js`
- `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml`

## Checklist Results

### Apex

Not applicable — this feature introduces no Apex. All Apex conventions in CLAUDE.md (TriggerHandler pattern, service layer, SOQL Lib, DML Lib, InstanceProvider, UniversalMocker, no `@TestSetup`, no `@SeeAllData`) are untouched.

### LWC — Best Practices

- [x] Uses `@wire(getRecord, …)` for reactive reads — no imperative Apex, no custom controller.
- [x] Uses `lightning/uiRecordApi` primitives (`getFieldValue`) — FLS enforced by the UI API.
- [x] No direct DOM manipulation — template is fully declarative, driven by getters.
- [x] Proper error handling — `hasError`/`isVisible` gate suppresses the chip on wire errors; silent degradation is the right UX for a purely informational badge (validated by product in `02-architecture.md`).
- [x] Accessible — wraps the badge in a `<span role="status" aria-label={ariaLabel}>`, with pluralization-aware wording for screen readers.
- [x] `@api recordId` used correctly; reactive tracking is automatic (no `@track`).
- [x] Constants are module-scoped (`AMBER_THRESHOLD_DAYS`, `MS_PER_DAY`, `TERMINAL_STATUSES`) — no magic numbers in getters.
- [x] UTC-anchored day math avoids DST-edge off-by-one bugs.
- [x] Component styling uses SLDS/SDS `--*-c-badge-*` custom-property hooks — the sanctioned extension point, not CSS leakage into shadow-DOM internals.
- [x] XML metadata has correct target (`lightning__RecordPage`), object scoping (`Invoice__c`), `masterLabel`, `description`, and `isExposed=true`.

### LWC — Jest Tests

- [x] Test file lives in `__tests__/` next to the component.
- [x] Imports `flushPromises` from `c/testUtils` per convention — no inline redefinition.
- [x] Covers hidden states: loading, wire error, null due date, status `Paid`, status `Cancelled`.
- [x] Covers variant boundaries at the exact thresholds: overdue -1, due today 0, +1, +7, +8. Both amber edges are explicit.
- [x] Covers pluralization singular/plural for both overdue and upcoming.
- [x] Covers accessibility aria-label wording for all states.
- [x] Time is deterministically frozen via a `MockDate` subclass of the global `Date`, restoring in `afterEach` — tests won't drift with the wall clock.
- [x] 22 component tests, 38/38 tests pass across the whole project.

### Metadata

- [x] Flexipage edit adds a single `itemInstance` in the header region, mirroring the existing `force_highlightsPanel` pattern and matching how `accountOverdueInvoiceBadge` was wired in.
- [x] `Due_Date__c` and `Status__c` are `required=true` on `Invoice__c`, so the UI API grants implicit read access — no permission-set edit required.
- [x] No new custom fields or objects introduced — existing permission-set grants remain valid.
- [x] Layouts unaffected — the chip lives in the Lightning record page header, not the classic layout.

## Issues Found

None.

## Fixes Applied

None required.

## Verification

```bash
npm run prettier          # all files unchanged
npx eslint 'force-app/**/lwc/**/*.js'   # clean
npm run test:unit -- --testPathPattern invoiceDueChip
# -> 4 suites, 38 tests passed
sf project deploy start --source-dir force-app/main --source-dir force-app/test --dry-run
# -> Dry-run complete, 0 errors
```

## Notes / Non-Blocking Observations

- Jest emits `Unknown public property "variant" of element <lightning-badge>` warnings. This is a known `sfdx-lwc-jest` stub limitation — the base component mock doesn't declare every public property. It has no bearing on runtime behavior (the live-org validation in `04-validation.md` confirms the variant attribute is honored). Not worth silencing, since doing so would mask real prop-name typos in future tests.
- `Due_Date__c.field-meta.xml` has no `<description>` element — this predates this feature and is out of scope for the chip review, but worth cleaning up in a follow-up when other Invoice fields get descriptions.

## Overall Quality Assessment

Production-ready. The implementation is small, focused, declarative, fully covered by boundary-conscious unit tests, and uses the LWC platform primitives correctly (UI API for reads, SLDS styling hooks for theming, `role="status"` for a11y). It cleanly ships a single user-visible feature — color-coded invoice due-date urgency — with no side effects on other layers of the stack.
