# Validation — Invoice Due Chip

Validated the `invoiceDueChip` LWC in the org's Invoice record page header via Playwright against the live Lightning Experience. Today's reference date: 2026-04-20.

## Test Matrix

| Scenario           | Invoice   | Status    | Due Date   | Expected                     | Actual                                                                    | Status |
| ------------------ | --------- | --------- | ---------- | ---------------------------- | ------------------------------------------------------------------------- | ------ |
| Overdue (red)      | INV-00001 | Overdue   | 2026-03-09 | Red chip, "42 days overdue"  | Red chip `rgb(234, 0, 30)`, label "42 days overdue", variant `error`      | PASS   |
| Due soon (amber)   | INV-00002 | Sent      | 2026-04-23 | Amber chip, "Due in 3 days"  | Orange chip `rgb(254, 147, 57)`, label "Due in 3 days", variant `warning` | PASS   |
| Due later (green)  | INV-00005 | Sent      | 2026-05-15 | Green chip, "Due in 25 days" | Green chip `rgb(46, 132, 74)`, label "Due in 25 days", variant `success`  | PASS   |
| Paid (hidden)      | INV-00003 | Paid      | 2026-03-14 | Chip not rendered            | Empty shadow DOM, no badge in page                                        | PASS   |
| Cancelled (hidden) | INV-00006 | Cancelled | 2026-04-25 | Chip not rendered            | Empty shadow DOM, no badge in page                                        | PASS   |

## Screenshots

- `screenshots/01-overdue-red.png` — INV-00001, red "42 days overdue" chip
- `screenshots/02-due-soon-amber.png` — INV-00002, amber "Due in 3 days" chip
- `screenshots/03-due-later-green.png` — INV-00005, green "Due in 25 days" chip
- `screenshots/04-paid-hidden.png` — INV-00003, header has no chip (status Paid)
- `screenshots/05-cancelled-hidden.png` — INV-00006, header has no chip (status Cancelled)

## Issue Found and Fixed During Validation

The initial implementation relied solely on the `lightning-badge` `variant` property to color the chip. In this org (API 66.0) `lightning-badge` does not translate `variant="error"` / `"warning"` / `"success"` into visible theme styling — it leaves the host as a default gray `slds-badge` span. The RED chip was rendering as gray `rgb(229, 229, 229)` instead of red.

**Fix applied** in `force-app/main/lwc/invoiceDueChip`:

- Added a `badgeClass` getter that emits `invoice-due-chip invoice-due-chip_{variant}` based on the computed variant.
- Bound that class to the `lightning-badge` in the template via `class={badgeClass}`.
- Added SLDS/SDS styling hooks in `invoiceDueChip.css` (`--slds-c-badge-color-background`, `--slds-c-badge-text-color`, plus `--sds-*` aliases) for `_success`, `_warning`, and `_error` modifiers.

After redeploy the three variants render with the intended colors (green `#2e844a`, amber `#fe9339`, red `#ea001e`) and the existing 22 jest tests and 16 other component tests all still pass (`38/38`).

## Console / Network Observations

- 0 browser-console errors across all five record pages (`browser_console_messages` level=error).
- A single non-blocking LWC engine warning in jest output about passing `class` to a child component; no functional impact, no runtime errors, all assertions pass.
- No failed XHR / network requests observed.

## Notes

- Validation was performed against the live org using the `sf org open --url-only` frontdoor URL, no credentials typed in-browser.
- Two supporting records were created through the CLI to cover the green (`Sent`, due 2026-05-15) and cancelled (`Cancelled`, due 2026-04-25) buckets that were missing from the seed data.
- Browser session closed at end of run.
