# Validation: Outstanding Balance Tile

## Feature

As an account manager, I want to see the total outstanding balance (sum of all unpaid invoices) as a single tile on the Account page, so I can grasp the customer's open exposure at a glance.

Component `c/accountOutstandingBalanceTile` is placed at the top of the Account record page main region (above the overdue badge and aging breakdown). It renders an "Outstanding Balance" `lightning-card` with a large currency amount and a pluralized count line, and navigates to the Account's Invoices related list when clicked.

## Environment

- Org: `00DdL00000rTQv3UAG` (Developer Edition, default org)
- User: `michal.verner.mv.2c9372c8c8fb@agentforce.com`
- Branch: `feature/outstanding-balance-tile`
- Locale/currency: `en-US` / `USD`

## Test data

| Account                             | Account Id           | Expected state       |
| ----------------------------------- | -------------------- | -------------------- |
| Edge Communications                 | `001dL00001yv25FQAQ` | Populated (1 unpaid) |
| Burlington Textiles Corp of America | `001dL00001yv25GQAQ` | Zero state           |

Edge Communications has 2 invoices: `INV-00005` (`Sent`, $500) and `INV-00006` (`Cancelled`, $250). Only the `Sent` invoice counts as unpaid, so the expected tile reads `$500.00` / `1 open invoice`.

## Steps performed

1. Generated a fresh frontdoor login URL via `sf org open --url-only` and navigated Playwright to it.
2. Waited for Lightning Experience to finish loading on the default landing page.
3. Navigated to the Edge Communications account record page (`/lightning/r/Account/001dL00001yv25FQAQ/view`).
4. Waited for the "Outstanding Balance" card to appear, then verified amount/count line via accessibility snapshot.
5. Took screenshot `01-populated-state-edge-communications.png`.
6. Clicked the Outstanding Balance tile (`button[aria-label*="Outstanding balance"]`). Page URL changed to `/lightning/r/Account/001dL00001yv25FQAQ/related/Invoices__r/view`. Captured `02-navigation-to-invoices-related-list.png`.
7. Navigated to Burlington Textiles (`/lightning/r/Account/001dL00001yv25GQAQ/view`) and waited for the text "No open invoices".
8. Captured `03-zero-state-burlington-textiles.png`.
9. Clicked the tile in the zero state — page navigated to `/lightning/r/Account/001dL00001yv25GQAQ/related/Invoices__r/view`, confirming click target remains active even with no open invoices.
10. Checked console for errors after both record pages.

## Screenshots

- `screenshots/01-populated-state-edge-communications.png` — populated state, `$500.00` / `1 open invoice`, rendered above the overdue badge and Invoice Aging card.
- `screenshots/02-navigation-to-invoices-related-list.png` — Invoices related list page reached by clicking the tile on Edge Communications.
- `screenshots/03-zero-state-burlington-textiles.png` — zero state, `$0.00` / `No open invoices`, no overdue badge or aging tiles.

## Results

| Step                                                  | Status | Notes                                                                                                        |
| ----------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| Tile renders on Account page (Edge Communications)    | Pass   | Card titled "Outstanding Balance", `standard:currency` icon, `$500.00` and `1 open invoice`                  |
| Placement above overdue badge and Invoice Aging       | Pass   | Accessibility tree confirms the order: Outstanding Balance article -> overdue badge -> Invoice Aging article |
| Pluralization (`1 open invoice`)                      | Pass   | Singular form rendered for count of 1                                                                        |
| Currency formatting honors `en-US` / `USD`            | Pass   | Displayed as `$500.00`                                                                                       |
| Click navigates to Invoices related list (populated)  | Pass   | URL `/related/Invoices__r/view`                                                                              |
| Zero state (Burlington Textiles)                      | Pass   | `$0.00` and `No open invoices`                                                                               |
| Click navigates to Invoices related list (zero state) | Pass   | URL `/related/Invoices__r/view` — tile remains actionable                                                    |
| Accessible label                                      | Pass   | `aria-label="Outstanding balance $500.00 across 1 open invoice. Open related invoices."`                     |
| Console errors                                        | Pass   | 0 errors on both record pages (warnings only)                                                                |
| Network errors                                        | Pass   | No failed Apex calls observed                                                                                |
| Toast errors                                          | Pass   | None displayed                                                                                               |

## Issues found

None. All three scenarios (populated, zero-state, navigation) behave per the story.

## Cleanup

`browser_close` invoked at end of run.
