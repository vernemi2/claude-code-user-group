# Code Review — Outstanding Balance Tile

Branch: `feature/outstanding-balance-tile`

## Scope Reviewed

- `force-app/main/lwc/accountOutstandingBalanceTile/` (new)
  - `accountOutstandingBalanceTile.html`
  - `accountOutstandingBalanceTile.js`
  - `accountOutstandingBalanceTile.css`
  - `accountOutstandingBalanceTile.js-meta.xml`
  - `__tests__/accountOutstandingBalanceTile.test.js`
- `force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml` (added tile to existing region)

No Apex changes on this branch. The tile reuses `AccountInvoiceAgingController.getAgingBreakdown` from the prior aging-breakdown feature.

## Issues Found

### Apex — Security / Performance / Architecture / Testing

None. No Apex changes in this branch. The reused controller, selector, and service layers were validated in the prior feature's review.

### LWC — Best Practices

| Check                      | Status | Notes                                                                                                                                               |
| -------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@wire` for reactive data  | Pass   | `@wire(getAgingBreakdown, { accountId: '$recordId' })`                                                                                              |
| No direct DOM manipulation | Pass   | All rendering via templates and getters                                                                                                             |
| Error handling             | Pass   | Dedicated error branch via `hasError` getter renders `lightning-badge` with warning icon and a11y label                                             |
| Accessibility              | Pass   | Real `<button>` with dynamic `aria-label`; `lightning-spinner` `alternative-text`; visible `:focus-visible` outline; covered by a jest test         |
| Localization               | Pass   | Uses `@salesforce/i18n/locale` and `@salesforce/i18n/currency` via `Intl.NumberFormat` — no hardcoded currency symbol                               |
| Navigation                 | Pass   | `standard__recordRelationshipPage` with `relationshipApiName: 'Invoices__r'` (verified against `Invoice__c.Account__c.relationshipName = Invoices`) |
| XML meta targets           | Pass   | Exposes only `lightning__RecordPage` scoped to `Account`                                                                                            |
| Render branches            | Pass   | Clean `lwc:if` / `lwc:elseif` chain for loading / error / data; no flash of empty state                                                             |
| Zero state                 | Pass   | Renders "No open invoices" with the tile still clickable so users can navigate to the empty related list                                            |

### Tests — LWC

| Check                                                                    | Status                   |
| ------------------------------------------------------------------------ | ------------------------ |
| `flushPromises` imported from `c/testUtils` (per CLAUDE.md)              | Pass                     |
| Wire adapter mocked via `createApexTestWireAdapter`                      | Pass                     |
| `NavigationMixin` mocked with assertable spy                             | Pass                     |
| Positive, error, loading, singular, plural, zero, navigation, a11y cases | Pass — 7 tests, all pass |

### Metadata

| Check                                                                                             | Status                                                     |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Flexipage update places component in existing region with proper `componentInstance`/`identifier` | Pass                                                       |
| Permission sets                                                                                   | N/A — no new Apex/objects/fields introduced on this branch |

## Fixes Applied

None — implementation meets project conventions and the checklist as-is.

## Verifications Run

- `npm run prettier` — clean (no files changed)
- `npx eslint force-app/main/lwc/accountOutstandingBalanceTile/**/*.js` — clean
- `npm run test:unit` — 6 suites / 52 tests pass (new tile: 7 tests)
- `sf project deploy start --source-dir force-app/main --source-dir force-app/test --dry-run` — succeeded

## Overall Quality Assessment

Ship it. The component is small, focused, accessible, locale-aware, fully covered by unit tests, and follows project LWC conventions. It leverages the existing aging controller without expanding the server surface, so there is no new attack/perf surface to evaluate. Flexipage wiring is minimal and correct.
