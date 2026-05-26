# Tests: Account Outstanding Balance Tile

## New Test Artifacts

| File                                                                                               | Type     | Purpose                                                            |
| -------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------ |
| `force-app/main/lwc/accountOutstandingBalanceTile/__tests__/accountOutstandingBalanceTile.test.js` | LWC Jest | Covers loading, error, populated, singular, zero, navigation, a11y |

No new Apex test classes — the feature reuses
`AccountInvoiceAgingController.getAgingBreakdown` and `InvoiceService.getAgingBreakdown`,
both already covered by existing tests (`AccountInvoiceAgingControllerTest`,
`InvoiceServiceTest`).

## Deployment

- `sf project deploy start --source-dir force-app/main --source-dir force-app/test`
- Result: **Succeeded** on the first attempt — no self-heal cycles required.
- Created bundle: `accountOutstandingBalanceTile` (.css, .html, .js, .js-meta.xml).
- Flexipage `Account_Record_Page` updated to render the tile at the top of `main`.

## Apex Test Results

| Metric           | Value     |
| ---------------- | --------- |
| Outcome          | Passed    |
| Tests Ran        | 590       |
| Pass             | 590       |
| Fail             | 0         |
| Pass Rate        | 100%      |
| Total Time       | 10,206 ms |
| Self-heal cycles | 0         |

Command: `sf apex run test --test-level RunLocalTests --result-format human --wait 10`

Coverage targets for the reused classes (`AccountInvoiceAgingController`,
`InvoiceService`, `SOQL_Invoice`, `PaymentService`) are met by the pre-existing
test suite — no regressions from the LWC-only change.

## Jest Test Results

| Metric           | Value |
| ---------------- | ----- |
| Test Suites      | 1     |
| Tests Run        | 7     |
| Pass             | 7     |
| Fail             | 0     |
| Self-heal cycles | 0     |

Command: `npm run test:unit -- -- accountOutstandingBalanceTile`

### Test cases (all passing)

1. Renders a spinner while loading before the wire emits.
2. Renders an error badge (`utility:warning`, label "Outstanding balance unavailable") when the wire emits an error.
3. Renders the populated tile with locale-formatted amount containing `"4,250"` and plural count `"3 open invoices"`.
4. Renders the singular count `"1 open invoice"` for `totalUnpaidCount === 1`.
5. Renders the zero state — amount contains `"0"`, count reads `"No open invoices"`, tile button is still clickable.
6. Navigates to the Account `Invoices__r` related list via `NavigationMixin.Navigate` with the correct page reference.
7. Exposes a non-empty `aria-label` on the populated tile for accessibility.

## Remaining TODOs

None. All tests pass on the first deploy/run cycle. The IDE reports a
spurious `LWC1702` diagnostic on the test file's `lwc` import — this is a
known false positive from the LWC language server when it parses test files
that use `createElement` from `lwc`; the test executes correctly under
`sfdx-lwc-jest` (mirroring the sibling `accountInvoiceAgingBreakdown` test).
