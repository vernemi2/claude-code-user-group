# Architecture: Invoice Due Date auto-calculation from Account payment terms

Input: `docs/features/invoice-due-date-auto-calc/01-grill.md` (25 branches resolved).

## 1. Scope recap

On `Invoice__c` `before insert`, when `Due_Date__c` is null, auto-populate it as `Invoice_Date__c + N days`, where `N` is derived from the related `Account.Payment_Terms__c` picklist. Fallbacks: `Date.today()` anchor if `Invoice_Date__c` is null; `Net 30` (+30) if Account is null, Payment_Terms**c is null, or the term is unrecognized. User-entered `Due_Date**c` is always preserved. Insert-only for v1 — no update recalc.

No LWC or flexipage work; no validation rules; no controller/Aura entry points.

## 2. Codebase evidence relied on

- Metadata root is `force-app/main/` (no `default/` subdirectory — CLAUDE.md's path examples are slightly stale; real layout confirmed). Tests live under `force-app/test/classes/{handlers,selectors,services}/`.
- `Invoice__c` object exists with fields `Account__c` (Lookup, optional, SetNull), `Amount__c` (required Currency), `Due_Date__c` (required Date), `Status__c` (required restricted picklist). No `Invoice_Date__c` today.
- No `Account` folder under `force-app/main/objects/` — the Account object has no repo customizations yet. `Account-Account Layout.layout-meta.xml` exists and is the target layout for the new Account field.
- No `AccountTrigger`, no `SOQL_Account`, no `InvoiceTrigger`, no `InvoiceTriggerHandler`. `InvoiceService` exists with one method (`getOverdueInvoiceSummary`) — we extend it, not replace it.
- `PaymentTrigger` + `PaymentTriggerHandler` + `PaymentService` is the reference pattern (verified in `/Users/michal/Documents/personal/salesforce/repos/claude-code-user-group/force-app/main/triggers/PaymentTrigger.trigger`, `/Users/michal/Documents/personal/salesforce/repos/claude-code-user-group/force-app/main/classes/handlers/PaymentTriggerHandler.cls`). Tests follow the mirror pattern in `force-app/test/classes/`.
- `SOQL_Payment` and `SOQL_Invoice` both use `.systemMode().withoutSharing()` in the private constructor — `SOQL_Account` will match for consistency with trigger context (Account may not be shared to the running user but we still need its payment terms to compute due date).
- `InvoiceUser` permission set currently grants CRUD on `Invoice__c` and `Payment__c` plus three field perms (`Invoice__c.Account__c`, `Payment__c.Payment_Method__c`, `Payment__c.Reference_Number__c`) and the `Invoice__c` tab. No Account object perms (intentional — Account is standard). We add two field perms only.
- `Invoice Layout` has two columns in "Information" — `Name | Account__c | Amount__c` and `Status__c | Due_Date__c`. `Invoice_Date__c` goes into the right column directly above `Due_Date__c`.
- `Account Layout` has an "Account Information" section where `Payment_Terms__c` logically belongs (next to `Industry`, `AnnualRevenue`, etc.).
- Flexipages (`Account_Record_Page`, `Invoice_Record_Page`) render standard record details — no flexipage edit needed (per grill decision 17).

## 3. Data model changes

### 3.1 `Account.Payment_Terms__c` (new)

- Path: `force-app/main/objects/Account/fields/Payment_Terms__c.field-meta.xml`
- Type: Picklist, `restricted=true`, not required
- Values (sorted by days asc; default = `Net 30`):
  - `Due on Receipt` (maps to 0 days)
  - `Net 15`
  - `Net 30` (default)
  - `Net 45`
  - `Net 60`
  - `Net 90`
- Default picklist value set via `<default>true</default>` on the `Net 30` entry, so UI-created Accounts pre-populate it. Existing Accounts with null remain null (grill decision 3) and are handled by the service fallback.
- The `Account/` object folder does not yet exist under `force-app/main/objects/` — this is the first Account customization in the repo. We add just the `fields/Payment_Terms__c.field-meta.xml` file; no `Account.object-meta.xml` is needed because Account is a standard object (Salesforce does not accept `CustomObject` metadata for Account unless customizing other non-field aspects).

### 3.2 `Invoice__c.Invoice_Date__c` (new)

- Path: `force-app/main/objects/Invoice__c/fields/Invoice_Date__c.field-meta.xml`
- Type: Date, `required=true`
- Default value formula: `TODAY()`
- Rationale: required anchors the calc to a deterministic Date and prevents null in the UI; default `TODAY()` covers the common case without breaking bulk insert (grill decisions 4, 14). Service defends against null at runtime via `Date.today()` fallback.

### 3.3 `Invoice__c.Due_Date__c` (unchanged)

Stays `required=true`. The `before insert` trigger fires before the platform's required-field check, so the auto-calculated value satisfies the constraint (grill decision 11). Keeping `required` is belt-and-braces in case the handler is ever bypassed via `TriggerHandler.bypass(...)`.

## 4. Apex architecture

### 4.1 Layering

```
InvoiceTrigger (before insert)
  -> InvoiceTriggerHandler.beforeInsert(List<SObject>)
       -> invoiceService.applyDueDateFromPaymentTerms(List<Invoice__c>)
            -> SOQL_Account.query().byIds(Set<Id>).mockId(...).toList()
            -> Map<String,Integer> TERM_TO_DAYS (private constant on InvoiceService)
```

- No DML in this feature (we mutate `Trigger.new` records in `before insert`; platform persists them).
- One SOQL across the whole batch (grill decision 12). No SOQL in loops; bulk-safe for 200+.
- `InstanceProvider.provide(InvoiceService.class)` in the handler constructor — no `new InvoiceService()` outside of tests.

### 4.2 Trigger

Path: `force-app/main/triggers/InvoiceTrigger.trigger` (+ `-meta.xml`).

Only declares contexts we actually need (grill decision 10):

```apex
trigger InvoiceTrigger on Invoice__c(before insert) {
  new InvoiceTriggerHandler().run();
}
```

Contexts for `before update`, `after *`, etc., are intentionally omitted so there is no accidental future recalc path. A follow-up story can widen the trigger when required.

### 4.3 Handler

Path: `force-app/main/classes/handlers/InvoiceTriggerHandler.cls` (+ `-meta.xml`).

```apex
public class InvoiceTriggerHandler extends TriggerHandler {
  private final InvoiceService invoiceService;

  public InvoiceTriggerHandler() {
    this.invoiceService = (InvoiceService) InstanceProvider.provide(
      InvoiceService.class
    );
  }

  protected override void beforeInsert(List<SObject> triggerNew) {
    invoiceService.applyDueDateFromPaymentTerms((List<Invoice__c>) triggerNew);
  }
}
```

Matches the shape of `PaymentTriggerHandler` exactly. No recursion guard needed (insert-only, no DML back on `Invoice__c`).

### 4.4 Service extension

File: `force-app/main/classes/services/InvoiceService.cls` (existing — extend in place).

New members:

- `private static final String DEFAULT_TERM = 'Net 30';`
- `private static final Integer DEFAULT_DAYS = 30;`
- `private static final Map<String, Integer> TERM_TO_DAYS` = `{ 'Due on Receipt' => 0, 'Net 15' => 15, 'Net 30' => 30, 'Net 45' => 45, 'Net 60' => 60, 'Net 90' => 90 }`.
- Field reference: the service currently uses no selector other than `SOQL_Invoice`; it now also uses `SOQL_Account` (resolved by static call, no DI needed — selectors are stateless query builders).

New public method:

```apex
public void applyDueDateFromPaymentTerms(List<Invoice__c> invoices) {
  // 1. collect candidate invoices: Due_Date__c is null
  // 2. from those, collect non-null Account__c ids
  // 3. one query: SOQL_Account.query().byIds(ids)
  //                    .mockId('InvoiceService.getPaymentTerms').toList()
  // 4. build Map<Id, Account> by Id
  // 5. for each candidate invoice:
  //      anchor = invoice.Invoice_Date__c != null ? invoice.Invoice_Date__c : Date.today()
  //      term   = (invoice.Account__c != null && accountMap.containsKey(invoice.Account__c))
  //                 ? accountMap.get(invoice.Account__c).Payment_Terms__c
  //                 : null
  //      days   = (term != null && TERM_TO_DAYS.containsKey(term))
  //                 ? TERM_TO_DAYS.get(term)
  //                 : DEFAULT_DAYS
  //      invoice.Due_Date__c = anchor.addDays(days)
}
```

Early-return when the candidate list is empty (all invoices have user-set Due_Date\_\_c) — saves the SOQL entirely. This also covers the "bulk 200 with all preset" edge case with zero queries (grill decision 9 reinforcement).

Keep the existing `getOverdueInvoiceSummary` and `OverdueInvoiceSummary` inner class untouched.

### 4.5 Selector (new)

Path: `force-app/main/classes/selectors/SOQL_Account.cls` (+ `-meta.xml`).

```apex
public inherited sharing class SOQL_Account extends SOQL implements SOQL.Selector {
  public static SOQL_Account query() {
    return new SOQL_Account();
  }

  private SOQL_Account() {
    super(Account.SObjectType);
    with(Account.Id, Account.Name, Account.Payment_Terms__c)
      .systemMode()
      .withoutSharing();
  }

  public SOQL_Account byIds(Set<Id> accountIds) {
    whereAre(SOQL.Filter.with(Account.Id).isIn(accountIds));
    return this;
  }
}
```

Rationale for `systemMode().withoutSharing()`: matches `SOQL_Invoice` and `SOQL_Payment`; a user creating an invoice may not own the related Account record but we still must be able to read `Payment_Terms__c` to compute Due Date server-side. This is a read-only internal selector — not exposed to clients.

## 5. Permissions

File: `force-app/main/permissionsets/InvoiceUser.permissionset-meta.xml` (existing — modify in place).

Add two `<fieldPermissions>` entries, keeping the alphabetical-ish grouping already present:

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Account.Payment_Terms__c</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>true</editable>
    <field>Invoice__c.Invoice_Date__c</field>
    <readable>true</readable>
</fieldPermissions>
```

No Account object CRUD entry is added — Account is standard and grant policy is out of scope here (grill decision 15).

Post-deploy CLI (per CLAUDE.md Deployment Checklist §2): `sf org assign permset --name InvoiceUser` (idempotent; safe even though perm set is already assigned, because new field perms require reapplication in some orgs).

## 6. Layouts

### 6.1 Invoice Layout

File: `force-app/main/layouts/Invoice__c-Invoice Layout.layout-meta.xml` (existing — modify in place).

Insert a new `<layoutItems>` entry in the second `<layoutColumns>` of the "Information" section, **above** `Due_Date__c`:

```xml
<layoutItems>
    <behavior>Required</behavior>
    <field>Invoice_Date__c</field>
</layoutItems>
<layoutItems>
    <behavior>Required</behavior>
    <field>Due_Date__c</field>
</layoutItems>
```

Result column order: `Status__c | Invoice_Date__c | Due_Date__c`. `Due_Date__c` stays `Required` (behavior) — user can still override before save, satisfying grill decision 9.

### 6.2 Account Layout

File: `force-app/main/layouts/Account-Account Layout.layout-meta.xml` (existing — modify in place).

Add a new `<layoutItems>` for `Payment_Terms__c` inside the "Account Information" section's right column (the one with `Rating`, `Phone`, etc.). Position near the bottom of that column, next to other business-related fields — placement choice:

```xml
<layoutItems>
    <behavior>Edit</behavior>
    <field>Payment_Terms__c</field>
</layoutItems>
```

Place it after `Sic` (last item in the right column) so the layout's pairing with the left column remains balanced; exact position is non-functional, just needs to be inside `Account Information`.

### 6.3 Flexipages

No changes. Both `Invoice_Record_Page` and `Account_Record_Page` rely on the standard record detail component, which picks up layout changes automatically (grill decision 17).

## 7. Tests

All tests follow existing project conventions: mock SOQL via `.mockId()` + `SOQL.mock(...).thenReturn(...)`, mock services via `UniversalMocker` + `InstanceProvider.injectMock`, no `@TestSetup`, no real DML, `Assert` class only.

### 7.1 `InvoiceServiceTest` (extend existing)

Path: `force-app/test/classes/services/InvoiceServiceTest.cls` (existing — add scenarios).

Do not touch the four existing `getOverdueInvoiceSummary` tests. Add the 8 scenarios below for `applyDueDateFromPaymentTerms`. All use `SOQL.mock('InvoiceService.getPaymentTerms').thenReturn(accounts)` to stub the selector, and construct `Invoice__c` + `Account` in memory (no DML).

Shared helper (local private static to the test class, not a utility class):

```apex
private static Id newAccountId() {
  return SOQL.IdGenerator.get(Account.SObjectType);
}
```

Scenarios:

1. **`shouldSetDueDateToInvoiceDatePlus30WhenAccountHasNet30Terms`** — Account with `Payment_Terms__c = 'Net 30'`, Invoice with `Invoice_Date__c = Date.newInstance(2026, 4, 1)`, `Due_Date__c = null`. Assert `Due_Date__c == 2026-05-01`.
2. **`shouldSetDueDateToInvoiceDatePlus15WhenAccountHasNet15Terms`** — Net 15 → +15 days. Proves mapping.
3. **`shouldSetDueDateEqualToInvoiceDateWhenDueOnReceipt`** — `Due on Receipt` → 0 days offset → `Due_Date__c == Invoice_Date__c`.
4. **`shouldDefaultToNet30WhenPaymentTermsIsNull`** — Account returned by mock has `Payment_Terms__c = null`. Expect `Invoice_Date__c + 30`.
5. **`shouldDefaultToNet30WhenAccountIsNull`** — Invoice has `Account__c = null`. Expect `Invoice_Date__c + 30`. Selector mock returns empty list; assert no NPE.
6. **`shouldPreserveDueDateWhenAlreadySetByUser`** — Invoice comes in with `Due_Date__c = Date.newInstance(2026, 12, 31)`. Mock stubbed but not required to fire. Assert `Due_Date__c` unchanged. Bonus: the service short-circuits before SOQL; verify by asserting `Limits.getQueries() == 0` inside `Test.startTest/stopTest` window.
7. **`shouldUseTodayWhenInvoiceDateIsNull`** — Invoice has `Invoice_Date__c = null`, Account has `Net 30`. Expect `Due_Date__c == Date.today().addDays(30)`.
8. **`shouldBulkProcess200InvoicesInOneQuery`** — Build 200 invoices (mix of accounts and nulls), assert `Limits.getQueries() <= 1` across the call and all 200 get Due_Date\_\_c set correctly (spot-check first and last).

Coverage target: every branch of the new method (candidate collection, empty-candidate short-circuit, account-map lookup hit/miss, null-term fallback, null-Account fallback, null-invoice-date fallback). Each TERM_TO_DAYS entry is touched by at least one of scenarios 1/2/3 (Net 30, Net 15, Due on Receipt); Net 45/60/90 are covered indirectly by scenario 4's fallback path — intentional trade-off, if we want explicit coverage we add two more tests but project convention is "cover branches, not data values," so 8 total suffices for 95%+.

### 7.2 `InvoiceTriggerHandlerTest` (new)

Path: `force-app/test/classes/handlers/InvoiceTriggerHandlerTest.cls` (+ `-meta.xml`).

Mirror `PaymentTriggerHandlerTest`:

1. **`shouldResolveDependencyViaInstanceProvider`** — Mock `InvoiceService`, inject via `InstanceProvider.injectMock`, instantiate handler, assert non-null (proves DI wiring).
2. **`shouldDelegateToApplyDueDateFromPaymentTermsOnBeforeInsertContext`** — Mock `InvoiceService.applyDueDateFromPaymentTerms` via `UniversalMocker.when('applyDueDateFromPaymentTerms').thenReturnVoid()`, inject mock, call `handler.beforeInsert(new List<SObject>{ new Invoice__c() })` directly (simulating framework dispatch), assert `mockInstance.assertThat().method('applyDueDateFromPaymentTerms').wasCalled(1)`.

Note: we cannot invoke the trigger end-to-end without a DML insert (which project rules forbid in tests), but calling the protected `beforeInsert` via a subclass shim is not needed — `beforeInsert` is `protected`, so we expose it by making the test call the handler's public `run()` in a constructed trigger context. **Simpler approach:** we test the _wiring_ (scenario 1) the same way `PaymentTriggerHandlerTest` does, and rely on `InvoiceServiceTest` to cover the business logic. If we want stronger delegation verification, we do a single real insert in scenario 2 (one DML is acceptable in the handler test specifically because the point is proving the trigger fires — this is an exception the project already accepts for `PaymentTriggerHandlerTest`-style tests; however the existing Payment test does _not_ insert). Decision: **follow the Payment precedent exactly — two wiring-level tests, no DML**. The bulk-200 branch in `InvoiceServiceTest` scenario 8 proves the handler path is bulk-safe end-to-end.

### 7.3 `SOQL_AccountTest` (new)

Path: `force-app/test/classes/selectors/SOQL_AccountTest.cls` (+ `-meta.xml`).

Mirror `SOQL_InvoiceTest`:

1. **`shouldQueryWithDefaultFields`** — `SOQL.mock('SOQL_Account').thenReturn(new List<Account>())`; assert `SOQL_Account.query().mockId('SOQL_Account').toList()` returns empty.
2. **`shouldFilterByIds`** — Mock returns one Account with a generated Id; call `SOQL_Account.query().byIds(new Set<Id>{ acctId }).mockId('SOQL_AccountTest.byIds').toList()`; assert size 1.
3. **`shouldFilterByEmptyIdSet`** — Defensive: pass `new Set<Id>()`; assert no exception, mock returns empty list.

Selectors need light coverage because their behavior is declarative and the SOQL library itself is already tested.

### 7.4 LWC tests

None — no LWC touched.

## 8. Numbered task list (dependency-ordered)

1. **Create `Account.Payment_Terms__c` field metadata** — `force-app/main/objects/Account/fields/Payment_Terms__c.field-meta.xml`. Restricted picklist with 6 values, `Net 30` default, not required. AC: `sf project deploy validate` passes; picklist values match §3.1.
2. **Create `Invoice__c.Invoice_Date__c` field metadata** — `force-app/main/objects/Invoice__c/fields/Invoice_Date__c.field-meta.xml`. Required Date, default formula `TODAY()`. AC: deploy passes; inserting an Invoice in the UI without setting Invoice Date populates today.
3. **Create `SOQL_Account` selector** — `force-app/main/classes/selectors/SOQL_Account.cls` + `-meta.xml`. Extends `SOQL`, implements `SOQL.Selector`, default fields `Id, Name, Payment_Terms__c`, `systemMode().withoutSharing()`, single filter method `byIds(Set<Id>)`. AC: class compiles; `SOQL_AccountTest` passes (task 9).
4. **Extend `InvoiceService` with `applyDueDateFromPaymentTerms`** — modify `force-app/main/classes/services/InvoiceService.cls`. Add `TERM_TO_DAYS` constant, `DEFAULT_DAYS = 30` constant, and the method described in §4.4. AC: existing `getOverdueInvoiceSummary` tests still pass; new scenarios in task 8 pass.
5. **Create `InvoiceTriggerHandler`** — `force-app/main/classes/handlers/InvoiceTriggerHandler.cls` + `-meta.xml`. Extends `TriggerHandler`, resolves `InvoiceService` via `InstanceProvider.provide`, overrides `beforeInsert` only. AC: compiles; wiring test (task 7) passes.
6. **Create `InvoiceTrigger`** — `force-app/main/triggers/InvoiceTrigger.trigger` + `-meta.xml`. `before insert` only; body is `new InvoiceTriggerHandler().run();`. AC: deploy succeeds; inserting Invoice without `Due_Date__c` auto-populates it.
7. **Create `InvoiceTriggerHandlerTest`** — `force-app/test/classes/handlers/InvoiceTriggerHandlerTest.cls` + `-meta.xml`. Two wiring tests per §7.2. AC: both pass; handler class coverage ≥95%.
8. **Extend `InvoiceServiceTest` with 8 new scenarios** — `force-app/test/classes/services/InvoiceServiceTest.cls`. Add scenarios per §7.1 without removing existing ones. AC: all 12 tests pass; `InvoiceService` coverage ≥95%; asserts include `Limits.getQueries()` on bulk and user-override tests.
9. **Create `SOQL_AccountTest`** — `force-app/test/classes/selectors/SOQL_AccountTest.cls` + `-meta.xml`. Three tests per §7.3. AC: all pass; selector coverage ≥95%.
10. **Update `InvoiceUser` permission set** — modify `force-app/main/permissionsets/InvoiceUser.permissionset-meta.xml` to add `Account.Payment_Terms__c` and `Invoice__c.Invoice_Date__c` field permissions (editable + readable). AC: deploy succeeds; running user can see both fields in the UI.
11. **Update Invoice layout** — modify `force-app/main/layouts/Invoice__c-Invoice Layout.layout-meta.xml` to insert `Invoice_Date__c` (Required) above `Due_Date__c` in the right column. AC: record detail/edit page shows `Invoice Date` above `Due Date`.
12. **Update Account layout** — modify `force-app/main/layouts/Account-Account Layout.layout-meta.xml` to add `Payment_Terms__c` (Edit behavior) in the "Account Information" section's right column. AC: Account edit page shows `Payment Terms` dropdown with `Net 30` selected by default on new records.
13. **Deploy all + assign perm set + run tests** — `sf project deploy start --source-dir force-app/main --source-dir force-app/test` then `sf org assign permset --name InvoiceUser` then `sf apex run test --test-level RunLocalTests --result-format human --wait 10`. AC: deploy green; all tests pass; `InvoiceService`, `InvoiceTriggerHandler`, and `SOQL_Account` all ≥95% coverage.

## 9. Risks & trade-offs

- **Net 45/60/90 not directly asserted in unit tests** — the map entries exist but only Net 15, Net 30, Due on Receipt are covered by explicit scenarios; other values rely on the same branch. If a reviewer wants explicit coverage, adding three one-line tests is trivial. Trade-off chosen: fewer tests, same branch coverage.
- **SOQL_Account uses `withoutSharing`** — consistent with `SOQL_Invoice` / `SOQL_Payment`, but means an invoice creator who cannot see the Account still gets its payment terms applied. That is correct behavior for the feature (we want the due date to reflect the customer agreement regardless of sharing), but is worth flagging in the review phase.
- **`Payment_Terms__c` default = `Net 30`** via picklist `<default>true</default>` only applies to new Account records created after deploy; existing Accounts with null terms will fall through to the service default (also Net 30). No data migration needed.
- **No update-time recalc** — explicit scope limit. If a user changes the Account on an existing invoice later, Due Date is not recalculated. Acceptable per story and grill decision 10; revisit in a follow-up.
- **Invoice Date default `TODAY()`** — this is evaluated at the moment the UI loads the new-record page. Bulk integrations must explicitly populate `Invoice_Date__c` or rely on the service's `Date.today()` fallback; behavior is identical either way.
- **No LWC / no flexipage changes** — feature is purely backend + layout. Validation phase will exercise it through the standard record create UI.

## 10. Files to create / modify (quick index)

Create:

- `force-app/main/objects/Account/fields/Payment_Terms__c.field-meta.xml`
- `force-app/main/objects/Invoice__c/fields/Invoice_Date__c.field-meta.xml`
- `force-app/main/classes/selectors/SOQL_Account.cls` (+ `-meta.xml`)
- `force-app/main/classes/handlers/InvoiceTriggerHandler.cls` (+ `-meta.xml`)
- `force-app/main/triggers/InvoiceTrigger.trigger` (+ `-meta.xml`)
- `force-app/test/classes/handlers/InvoiceTriggerHandlerTest.cls` (+ `-meta.xml`)
- `force-app/test/classes/selectors/SOQL_AccountTest.cls` (+ `-meta.xml`)

Modify:

- `force-app/main/classes/services/InvoiceService.cls`
- `force-app/main/permissionsets/InvoiceUser.permissionset-meta.xml`
- `force-app/main/layouts/Invoice__c-Invoice Layout.layout-meta.xml`
- `force-app/main/layouts/Account-Account Layout.layout-meta.xml`
- `force-app/test/classes/services/InvoiceServiceTest.cls`

Ready for implement phase.
