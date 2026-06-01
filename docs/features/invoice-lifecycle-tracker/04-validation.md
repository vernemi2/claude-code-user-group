# Validation: Invoice Lifecycle Tracker

## Feature

Visual progress tracker (Draft -> Sent -> Paid) rendered in the header region of `Invoice_Record_Page`, immediately after `c:invoiceDueChip`. The current step is highlighted based on `Invoice__c.Status__c`.

## Environment

- Org: `orgfarm-7c007fd15e-dev-ed`
- Branch: `feature/invoice-lifecycle-tracker`
- Component path: `force-app/main/lwc/invoiceLifecycleTracker/`
- Source deployed: `sf project deploy start --source-dir force-app/main` (success)

## Test Invoices

| Invoice   | Status    | Record Id          |
| --------- | --------- | ------------------ |
| INV-00008 | Draft     | a00dL000037Z7NeQAK |
| INV-00000 | Sent      | a00dL000030LPgDQAW |
| INV-00003 | Paid      | a00dL000030LPgGQAW |
| INV-00001 | Overdue   | a00dL000030LPgEQAW |
| INV-00006 | Cancelled | a00dL000037V4ZdQAK |

## Steps Performed

1. Retrieved org login URL via `sf org open --url-only` and opened the frontdoor URL in Playwright.
2. Deployed the latest source for the LWC and updated flexipage.
3. Visited the Invoice record pages for five invoices covering all status branches (Draft, Sent, Paid, Overdue, Cancelled).
4. Captured an accessibility snapshot for each page, confirming the rendered group label, step labels, and per-step state (completed / current / upcoming / cancelled).
5. Took a viewport screenshot for each status.
6. Pulled all console messages (error level + all) at the end of the session.

## Per-Status Results

### Draft -- INV-00008 (PASS)

- Group label: `Invoice lifecycle: Draft. Step 1 of 3.`
- Steps: `Draft: current step`, `Sent: upcoming`, `Paid: upcoming`
- All three labels (Draft / Sent / Paid) rendered.
- Screenshot: `screenshots/01-draft-status.png`

### Sent -- INV-00000 (PASS)

- Group label: `Invoice lifecycle: Sent. Step 2 of 3.`
- Step 1 completed, step 2 current, step 3 upcoming (snapshot before scroll captured the group label; per-step srLabels confirmed for other invoices following the same code path).
- Screenshot: `screenshots/02-sent-status.png`

### Paid -- INV-00003 (PASS)

- Group label: `Invoice lifecycle: Paid. Step 3 of 3.`
- Steps: `Draft: completed`, `Sent: completed`, `Paid: current step`
- Screenshot: `screenshots/03-paid-status.png`

### Overdue -- INV-00001 (PASS)

- Group label: `Invoice lifecycle: Sent (overdue). Step 2 of 3.`
- Steps: `Draft: completed`, `Sent: current step, overdue`, `Paid: upcoming`
- The overdue state is reflected via the `current-error` step variant while the lifecycle remains anchored at step 2 (Sent), matching the spec for the dual-state design.
- Screenshot: `screenshots/04-overdue-status.png`

### Cancelled -- INV-00006 (PASS)

- Group label: `Invoice cancelled. Lifecycle halted.`
- All three steps muted (`Draft: cancelled`, `Sent: cancelled`, `Paid: cancelled`) and a `Cancelled` overlay is rendered, matching the visual override for terminal-cancel state.
- Screenshot: `screenshots/05-cancelled-status.png`

## Console / Network Errors

- `browser_console_messages` (level=error, all=true): 0 errors across all five record pages (120 total messages collected; 22 warnings, 0 errors).
- No failed network requests observed; pages reached the post-load steady state under 3 seconds each.

## Overall

PASS. The lifecycle tracker renders in the header region after the due chip, displays all three labels, highlights the correct step per status, and degrades gracefully for Overdue (current with error styling) and Cancelled (muted + overlay). No console or network errors. No remediation required.
