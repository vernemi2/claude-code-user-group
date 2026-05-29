# Code Review: Invoice Lifecycle Tracker

## Scope reviewed

- `force-app/main/lwc/invoiceLifecycleTracker/` (new LWC: js, html, css, meta, tests)
- `force-app/main/flexipages/Invoice_Record_Page.flexipage-meta.xml` (header region edit)

No Apex, no objects/fields, no permission set changes. Pure-LWC feature.

## Issues found

None. The implementation matches the architecture doc and follows the established sibling pattern (`invoiceDueChip`).

### Apex — Security, Performance, Architecture, Testing

Not applicable — no Apex in this feature.

### LWC — Best Practices

| Check                                      | Status | Notes                                                                                                                                                                                             |
| ------------------------------------------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Uses `@wire` for reactive data             | Pass   | `@wire(getRecord, ...)` with `lightning/uiRecordApi`; reactive `$recordId`.                                                                                                                       |
| No direct DOM manipulation                 | Pass   | Purely template-driven via `for:each` and class getters.                                                                                                                                          |
| Proper error handling                      | Pass   | Renders empty template on wire error, mirroring `invoiceDueChip`. No toast is appropriate for a passive header decoration.                                                                        |
| Accessibility                              | Pass   | `role="group"` + dynamic `aria-label`, `aria-current="step"` on active step, `aria-hidden` on decorative skeleton & connectors, `slds-assistive-text` per step, overlay `aria-label="Cancelled"`. |
| XML metadata targets                       | Pass   | `lightning__RecordPage`, scoped to `Invoice__c`, API 66.0, `isExposed=true`, description present.                                                                                                 |
| No `@track` overuse                        | Pass   | All derived state via getters; wire drives reactivity.                                                                                                                                            |
| Single-responsibility, focused module      | Pass   | State-machine mapping (`stepStates`), connector logic, and aria text are each isolated getters.                                                                                                   |
| Imports `flushPromises` from `c/testUtils` | Pass   | Per CLAUDE.md convention; no inline redefinition.                                                                                                                                                 |

### Metadata

| Check                           | Status | Notes                                                                                  |
| ------------------------------- | ------ | -------------------------------------------------------------------------------------- |
| Flexipage edit                  | Pass   | Adds `c_invoiceLifecycleTracker` to existing `header` region after `c_invoiceDueChip`. |
| Custom fields have descriptions | N/A    | No new fields.                                                                         |
| Permission sets grant access    | N/A    | `Status__c` already granted on `InvoiceUser`. Object Read implies picklist FLS.        |
| Layouts include new fields      | N/A    | No new fields.                                                                         |

### Testing

| Check                                    | Status | Notes                                                                                                    |
| ---------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------- |
| Jest coverage of new LWC                 | Pass   | 14 tests across loading, error, 5 status branches, unknown/null fallback, and accessibility aria-labels. |
| Uses `c/testUtils` `flushPromises`       | Pass   |                                                                                                          |
| Wire adapter mocked via standard adapter | Pass   | `getRecord.emit(...)` / `getRecord.error()`.                                                             |
| All tests passing                        | Pass   | 14/14 green locally.                                                                                     |

## Fixes applied

None — no code changes were necessary.

## Verification

| Step                                                  | Result                                                                                                                          |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `npm run prettier`                                    | Pass — all files unchanged (already formatted).                                                                                 |
| `npm run lint`                                        | Pre-existing config issue (`eslint` script globs `**/aura/**/*.js`, but no `aura/` directory exists). Unrelated to this change. |
| `npx jest force-app/main/lwc/invoiceLifecycleTracker` | Pass — 14/14 tests passing.                                                                                                     |
| `sf project deploy start --dry-run`                   | Pass — dry-run completes successfully against the default org.                                                                  |

## Overall quality assessment

Strong. The feature is implemented exactly as designed in `02-architecture.md`: a small, read-only, presentational LWC that derives its render state from a single picklist value via `@wire(getRecord)`. The status → render mapping is centralized in one getter (`stepStates`), connector classes are derived deterministically from adjacent step states, and accessibility is treated as a first-class concern rather than an afterthought (group role, dynamic aria-label, per-step `aria-current`, screen-reader text, decorative-element `aria-hidden`).

Pattern reuse with `invoiceDueChip` is high: same `@wire` shape, same loading/error/data tri-state, same color tokens, same XML structure. This keeps the header region visually and behaviorally coherent.

No deviations from CLAUDE.md conventions. No issues to flag. Ready to commit.
