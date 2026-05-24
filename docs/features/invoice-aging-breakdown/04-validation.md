# Invoice Aging Breakdown - Validation

## Scope

User story: "As an account manager, I want to see an aging breakdown of unpaid
invoices (Current, 1-30, 31-60, 61-90, 90+ days overdue) on the Account page, so
I can prioritize collections and assess credit risk at a glance."

## Environment

- Org: `michal.verner.mv.2c9372c8c8fb@agentforce.com` (Developer Edition)
- Deployment: `0AfdL00000ZUVztSAH` - Succeeded
- Flexipage `Account_Record_Page` was already assigned as the org default; the
  new `accountInvoiceAgingBreakdown` component shows without additional
  activation.

## Seeded Test Data

Seeded via anonymous Apex (`/tmp/seed_aging_data.apex`):

| Account                      | Invoices                                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------------------------- |
| `Aging Test - With Invoices` | Current $500, two 1-30 day ($1,000 + $250), one 31-60 $2,000, one 61-90 $3,000, one 90+ $5,000 |
| `Aging Test - No Invoices`   | none                                                                                           |

All invoices created with `Status__c = Sent` and explicit `Due_Date__c` values
calculated from today's date (2026-04-22) to land in the intended bucket.

## Steps Performed & Results

### AC (a) - Populated account renders five tiles

- Navigated to `Aging Test - With Invoices`.
- "Invoice Aging" card rendered with all five tiles in order.
- Values observed matched seeded data exactly:

| Tile       | Count      | Remaining Balance |
| ---------- | ---------- | ----------------- |
| Current    | 1 invoice  | $500.00           |
| 1-30 days  | 2 invoices | $1,250.00         |
| 31-60 days | 1 invoice  | $2,000.00         |
| 61-90 days | 1 invoice  | $3,000.00         |
| 90+ days   | 1 invoice  | $5,000.00         |

- High and 90+ buckets render the warning icon; severity-based accent styling
  visible on each tile.
- Accessible names are well-formed (e.g. `Current: 1 invoice totaling $500.00.
Open related invoices.`).

Status: **PASS**. Screenshot: `screenshots/01-account-with-invoices-full.png`

### AC (b) - Empty account renders empty state

- Navigated to `Aging Test - No Invoices`.
- Card rendered with a single "No outstanding invoices" message and a success
  icon - no tiles shown.

Status: **PASS**. Screenshot: `screenshots/03-empty-state.png`

### AC (c) - Clicking a bucket navigates to the Invoices related list

- Clicked the `1-30 days` tile.
- Browser navigated to
  `/lightning/r/Account/001dL000025pFKUQA2/related/Invoices__r/view`, i.e. the
  Account's Invoices related list.
- Six invoices listed (matches seeded data prior to the payment step).

Status: **PASS**. Screenshot: `screenshots/02-invoices-related-list.png`

### AC (d) - Paying an invoice removes it from its bucket

- Inserted a $500 `Payment__c` against `INV-00011` (the Current-bucket invoice,
  Amount $500). PaymentTriggerHandler flipped the invoice `Status__c` to `Paid`.
- Re-navigated to `Aging Test - With Invoices`.
- Current tile now shows `$0.00` / `0 invoices`. Other buckets unchanged.
- Total overdue chip still shows "5 overdue . $11,250.00 at risk" (the Current
  invoice was not overdue, so the overdue chip is consistent).

Status: **PASS**. Screenshot: `screenshots/04-after-payment.png`

## Console & Network

- `browser_console_messages level=error` returned 0 messages during the full
  flow. Only informational Lightning/Aura warnings present (25 warnings, all
  benign - Aura deprecation warnings, favicon 404).
- No failed Apex/UI API requests observed for the component's wire call.

## Issues Found

None. All four acceptance criteria passed on the first attempt; no code changes
required.

## Screenshots

- `screenshots/01-account-with-invoices-full.png` - full-page view of the
  populated account with the Invoice Aging card.
- `screenshots/02-invoices-related-list.png` - navigation result after clicking
  the 1-30 days tile.
- `screenshots/03-empty-state.png` - empty-state rendering on the account with
  no invoices.
- `screenshots/04-after-payment.png` - Current bucket showing 0 / $0.00 after
  recording a full payment.
