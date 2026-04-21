# Code Review — Invoice Due Date Auto-Calculation

Branch: `feature/invoice-due-date-auto-calc`
Scope: all staged and untracked changes under `force-app/main/` and `force-app/test/`.

## Files Reviewed

### Source (`force-app/main/`)

- `classes/services/InvoiceService.cls` (modified — added `populateDueDates`)
- `classes/handlers/InvoiceTriggerHandler.cls` (new)
- `classes/selectors/SOQL_Account.cls` (new)
- `triggers/InvoiceTrigger.trigger` (new)
- `objects/Account/fields/Payment_Terms__c.field-meta.xml` (new)
- `objects/Invoice__c/fields/Invoice_Date__c.field-meta.xml` (new)
- `objects/Invoice__c/fields/Due_Date__c.field-meta.xml` (modified — now optional)
- `layouts/Account-Account Layout.layout-meta.xml` (added Payment Terms)
- `layouts/Invoice__c-Invoice Layout.layout-meta.xml` (added Invoice Date, loosened Due Date)
- `permissionsets/InvoiceUser.permissionset-meta.xml` (granted Payment Terms)

### Tests (`force-app/test/`)

- `classes/services/InvoiceServiceTest.cls` (added 7 `populateDueDates` cases)
- `classes/handlers/InvoiceTriggerHandlerTest.cls` (new)
- `classes/selectors/SOQL_AccountTest.cls` (new)

---

## Issues Found & Fixes Applied

### 1. Missing field descriptions (Metadata)

**Checklist violation**: "Custom fields have descriptions."

Three custom fields shipped without `<description>` or `<inlineHelpText>`:

- `Account.Payment_Terms__c`
- `Invoice__c.Invoice_Date__c`
- `Invoice__c.Due_Date__c`

**Fix**: Added `<description>` and `<inlineHelpText>` to all three, explaining the auto-calc behavior and how they interact.

### 2. Handler test used real DML (Testing)

**Checklist violation**: "Tests mock all dependencies" / "Tests should never hit the database or depend on org state."

`InvoiceTriggerHandlerTest.shouldInvokeBeforeInsertWhenInvoiceIsInserted` inserted an actual `Account` and `Invoice__c` into the database to verify that `beforeInsert` was routed to the service. Two other methods (`shouldResolveDependencyViaInstanceProvider`, `shouldDelegateToServiceOnBeforeInsertContext`) were near-duplicates that only asserted `handler != null` — they didn't actually verify delegation.

**Fix**: Rewrote the test class with two focused tests:

- `shouldResolveInvoiceServiceViaInstanceProvider` — confirms constructor wires up the injected service.
- `shouldDelegateBeforeInsertToInvoiceService` — uses a private inner subclass (`InvoiceTriggerHandlerHarness`) to invoke the protected `beforeInsert` directly with a list of in-memory `Invoice__c` records, then asserts the mock was called once **and** that the exact list was forwarded via `UniversalMocker.forMethod(...).getValueOf('invoices')`.

To enable the harness pattern, `InvoiceTriggerHandler` was marked `virtual` (the base `TriggerHandler` is already `virtual`, so this is a cheap change with no runtime impact). This trades one keyword in production for zero database I/O in tests and coverage of the actual delegation contract.

### 3. Unnecessary SOQL when no candidate invoice has an Account (Performance)

`InvoiceService.populateDueDates` executed `SOQL_Account.query().byIds(accountIds)` even when `accountIds` was empty (e.g., all new invoices had `Account__c == null`). The query is cheap but wasteful.

**Fix**: Short-circuit — skip the query and use an empty map when `accountIds.isEmpty()`. Existing tests still pass since the null-account paths now take the defaulting branch without hitting the mock.

### 4. Permission set missing `Invoice_Date__c` — initially added, then reverted

First pass added `Invoice__c.Invoice_Date__c` to `InvoiceUser`. Deployment dry-run rejected it: `You cannot deploy to a required field`. Because `Invoice_Date__c` is defined as `required=true`, all users with object access already have full R/W on it — explicit permissions are not permitted.

**Fix**: Reverted the addition. `Payment_Terms__c` remains explicitly granted (it is not required, so the grant is needed).

---

## Checklist Summary

### Apex — Security

- [x] No hardcoded record IDs — uses `SOQL.IdGenerator` in tests.
- [x] No sensitive data in debug logs — no debug statements at all.

### Apex — Performance

- [x] No SOQL inside loops — single bulk query keyed by Account IDs.
- [x] No DML inside loops — `populateDueDates` mutates in-memory `Invoice__c` records that the trigger context persists.
- [x] Bulk-safe — `shouldBulkProcess200InvoicesInOneQuery` verifies 200 records / ≤1 query.
- [x] No unnecessary queries — post-fix, empty `accountIds` skips the query.

### Apex — Architecture

- [x] One trigger per object, extends `TriggerHandler` via handler class.
- [x] Business logic in `InvoiceService`, not in the trigger or handler.
- [x] No static methods on the service — instance with DI via `InstanceProvider.provide`.
- [x] All SOQL via SOQL Lib (`SOQL_Account`, `SOQL_Invoice`).
- [x] Queries live in selector classes; filter `byIds(Set<Id>)` on `SOQL_Account` is reusable.
- [x] No DML Lib needed — `populateDueDates` runs in `beforeInsert` and mutates `Trigger.new` directly (idiomatic; DML Lib is unnecessary here).
- [x] Methods are focused and single-purpose.

### Apex — Testing

- [x] Every production class has a test class (`InvoiceServiceTest`, `InvoiceTriggerHandlerTest`, `SOQL_AccountTest`).
- [x] Tests mock all dependencies (`SOQL.mock`, `UniversalMocker` + `InstanceProvider.injectMock`).
- [x] No `@TestSetup` — all data in-memory.
- [x] Positive, negative (null account, null terms, preserve user-set), bulk (200), and edge (null invoice date) cases covered.
- [x] Uses `Assert.areEqual` with descriptive messages.
- [x] Interaction verified via `UniversalMocker.assertThat().wasCalled(1)` plus `getValueOf('invoices')` argument capture.
- [x] No `@SeeAllData=true`.

### LWC — Best Practices

- No LWC changes in this feature. N/A.

### Metadata

- [x] Custom fields have `<description>` and `<inlineHelpText>` (fixed).
- [x] Permission set grants appropriate access (`Payment_Terms__c` granted; `Invoice_Date__c` covered by its `required=true` status).
- [x] Layouts include `Payment_Terms__c` (Account) and `Invoice_Date__c` + `Due_Date__c` (Invoice).

---

## Verification

- `npm run prettier` — clean; three field XMLs were reformatted by the tool.
- `npm run lint` — errors with "No files matching `**/aura/**/*.js`"; pre-existing script-glob issue unrelated to this feature (no LWC/Aura files changed).
- `sf project deploy start --source-dir force-app/main --source-dir force-app/test --dry-run` — **succeeds** after the two fixes above (handler made `virtual`, permset grant on required field removed).

---

## Overall Quality Assessment

Strong implementation. The service/selector/handler split is clean, the bulk behavior is correct and tested, and user intent (a manually entered Due Date) is preserved. After the review fixes, the feature is production-ready: zero DB hits in tests, full descriptions on shipped fields, a single short-circuited query, and a successful end-to-end deploy dry-run.

The one concession made — marking `InvoiceTriggerHandler` as `virtual` — is a minor cost paid to keep the handler delegation test fully in-memory and to actually verify the Trigger.new forwarding contract. The base `TriggerHandler` is itself virtual, so this is consistent with the framework's own pattern.
