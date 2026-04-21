# Validation: Invoice Due Date auto-calculation from Account payment terms

Browser-based end-to-end validation against the default org
(`michal.verner.mv.2c9372c8c8fb@agentforce.com`), executed 2026-04-21.

## Scenarios covered

| #   | Scenario                                                 | Expected Due Date                          | Actual       | Status |
| --- | -------------------------------------------------------- | ------------------------------------------ | ------------ | ------ |
| 1   | New Invoice, Account has `Net 45`, Due Date left blank   | Invoice Date + 45 = `2026-06-05`           | `2026-06-05` | PASS   |
| 2   | New Invoice, Account has `Net 45`, Due Date set manually | User value preserved = `2026-12-31`        | `2026-12-31` | PASS   |
| 3   | New Invoice, Account has null `Payment_Terms__c`         | Invoice Date + 30 (fallback)= `2026-05-21` | `2026-05-21` | PASS   |

All three scenarios passed. The green urgency chips ("Due in 45 days",
"Due in 254 days", "Due in 30 days") rendered correctly on each record page.

## Defect found and fixed during validation

The architecture spec assumed the `before insert` trigger would satisfy
`Due_Date__c.<required>true</required>` because the trigger fires before
the platform's required-field enforcement. That is correct for API/Apex
DML — Scenario 1 succeeds via `sf data create record` — but the Lightning
standard New Invoice form validates required fields _client-side_ before
submitting the record, and the `Invoice Layout` marked `Due_Date__c` with
`<behavior>Required</behavior>`. Leaving Due Date blank in the UI produced
"We hit a snag. Review the following fields: Due Date" (screenshot
`02b-invoice-save-result.png`) and the trigger never ran.

### Fix applied

Two metadata changes, deployed mid-validation:

1. `force-app/main/objects/Invoice__c/fields/Due_Date__c.field-meta.xml`:
   `<required>true</required>` -> `<required>false</required>`.
2. `force-app/main/layouts/Invoice__c-Invoice Layout.layout-meta.xml`:
   `<behavior>Required</behavior>` -> `<behavior>Edit</behavior>` for
   the `Due_Date__c` layout item.

After redeploy the New Invoice dialog renders "Due Date" with no asterisk
(screenshot `03-new-invoice-after-layout-fix.png`) and the trigger
populates the value on save.

Re-ran `InvoiceServiceTest` + `InvoiceTriggerHandlerTest` after the
metadata change — all 16 tests still pass (100%).

## Test data created

| Record                    | Id                   | Notes                                  |
| ------------------------- | -------------------- | -------------------------------------- |
| Account Validate Net45 Co | `001dL000025aoonQAA` | Payment_Terms\_\_c = Net 45 (new)      |
| Invoice INV-00008         | `a00dL000037Z7NeQAK` | UI create, blank Due Date -> +45 days  |
| Invoice INV-00009         | `a00dL000037agBGQAY` | UI create, manual Due Date preserved   |
| Invoice INV-00010         | `a00dL000037at3eQAA` | UI create on Acme Corp -> +30 fallback |

INV-00007 was the initial API-level verification that the trigger works
independent of the UI layer (created via `sf data create record` while
diagnosing the UI defect).

## Screenshots

All under `docs/features/invoice-due-date-auto-calc/screenshots/`:

- `01-account-new-net45.png` - Account form with Payment Terms = Net 45 selected.
- `02-invoice-new-blank-duedate.png` - first UI attempt; Due Date field marked required (defect state).
- `02b-invoice-save-result.png` - "We hit a snag" validation error (defect reproduced).
- `03-new-invoice-after-layout-fix.png` - same dialog after layout fix; Due Date no longer required.
- `04-invoice-filled-no-duedate.png` - form filled, Due Date blank, ready to save.
- `05-invoice-saved-net45.png` - INV-00008 record page showing Due Date 6/5/2026 and "Due in 45 days" chip.
- `06-invoice-manual-override.png` - form with manual Due Date 12/31/2026.
- `07-invoice-manual-override-saved.png` - INV-00009 record page showing Due Date 12/31/2026 preserved.
- `08-invoice-fallback-acme.png` - form on Acme Corp (no payment terms), Due Date blank.
- `09-invoice-fallback-saved.png` - INV-00010 showing Due Date 5/21/2026 and "Due in 30 days" chip.

## Console / network

No blocking JavaScript errors were observed during any of the three PASS
flows. The handful of console warnings visible in the snapshots are
standard Lightning platform advisory messages (LWC constructor hints,
performance telemetry) and are unrelated to this feature.

## Files changed during validation (require commit)

- `force-app/main/objects/Invoice__c/fields/Due_Date__c.field-meta.xml`
- `force-app/main/layouts/Invoice__c-Invoice Layout.layout-meta.xml`

The architecture document's Section 3.3 rationale ("Stays `required=true`.
The `before insert` trigger fires before the platform's required-field
check") held true for Apex/API DML but missed the client-side Lightning
form validation path. The grill assumption that "belt-and-braces" keeping
`required=true` was safe turned out to block the primary user-visible
flow. These two metadata edits are the minimal fix that preserves
trigger-level protection (the trigger still runs on every insert path)
while unblocking the UI.
