# Grill: Invoice Due Date auto-calculation from Account payment terms

## Input

> As an account manager, when a new Invoice is created, I want its Due Date to be automatically calculated from the related Account's payment terms (e.g. Net 30 means Invoice Date + 30 days), so I don't have to set it manually and it's always consistent with the customer's agreement.

## Codebase snapshot (evidence gathered up front)

- `Invoice__c` currently has fields: `Account__c` (Lookup to Account, not required, SetNull on delete), `Amount__c` (required Currency), `Due_Date__c` (required Date), `Status__c` (required Picklist: Draft/Sent/Paid/Overdue/Cancelled — `Draft` is default).
- **No `Invoice_Date__c` field exists on Invoice.** The user story references "Invoice Date + N days" — this anchor field does not yet exist.
- **No `Payment_Terms__c` field exists on Account.** No `AccountTrigger`, no `SOQL_Account`, no Account customization whatsoever in the repo.
- No `InvoiceTrigger` / `InvoiceTriggerHandler` exist yet — `InvoiceService` exists but only holds `getOverdueInvoiceSummary`.
- `Payment__c` pattern is the blueprint: trigger delegates to `PaymentTriggerHandler extends TriggerHandler`, which calls `PaymentService` resolved via `InstanceProvider.provide(...)`. Selector is `SOQL_Payment` / `SOQL_Invoice`. Tests live in `force-app/test/classes/{handlers,services,selectors}/`.
- `InvoiceUser` permission set grants CRUD on Invoice/Payment and explicitly lists `Invoice__c.Account__c` field permission. Standard fields (`Name`, `Amount__c`, `Status__c`, `Due_Date__c`) are not listed — they inherit admin visibility but any new custom fields must be added explicitly per CLAUDE.md Deployment Checklist.
- CLAUDE.md hard rules: no raw SOQL/DML, selector pattern, `InstanceProvider`, `TriggerHandler` framework, bulk-safe, `Assert` class, 95% coverage, no `@TestSetup`, mock every dependency.

---

## Decision tree (dependency-ordered)

### 1. Where does "payment terms" live?

**Q:** Does an Account field already exist for payment terms, or must one be created?
**A:** Create a new custom field `Account.Payment_Terms__c`. Grep for `Payment_Terms` returned zero hits, and `force-app/main/objects/` has only `Invoice__c` and `Payment__c` folders (no Account folder at all).
**Reasoning:** Nothing in the repo defines this concept. Salesforce's standard Account object has no out-of-the-box payment terms field. We need to introduce it.
**Unlocks:** 2, 3, 4.

### 2. What data type should `Account.Payment_Terms__c` be?

**Q:** Picklist of canonical terms (Net 15 / Net 30 / Net 45 / Net 60 / Net 90 / Due on Receipt), Number of days, or free text?
**A:** **Restricted picklist** with values `Due on Receipt`, `Net 15`, `Net 30`, `Net 45`, `Net 60`, `Net 90`. Default value: `Net 30`.
**Reasoning:** The user story literally says "e.g. Net 30" — it's the industry vocabulary account managers already use. A restricted picklist eliminates typos, makes reporting clean, and gives the calculation service a closed value set to map. A Number(days) field would be more flexible but less discoverable in the UI and not what account managers talk to customers about. Free text is a non-starter (unparseable). `Net 30` as default matches the story's example and the most common B2B term.
**Unlocks:** 5 (mapping logic), 8 (default behavior).

### 3. Is `Payment_Terms__c` required on Account?

**Q:** Required field, or optional with a default?
**A:** Optional, with `Net 30` as default.
**Reasoning:** Making it required would force backfill on every existing Account and break Account creation flows elsewhere. A default keeps new Accounts sensible; existing Accounts with null terms are handled by the fallback rule in decision 8.
**Unlocks:** 8.

### 4. Do we need an `Invoice_Date__c` anchor field, or do we anchor on `CreatedDate` / today?

**Q:** What does "Invoice Date" mean in the calculation?
**A:** Add a new `Invoice__c.Invoice_Date__c` field, type `Date`, required, default = `TODAY()`.
**Reasoning:** The story explicitly says "Invoice Date + 30 days." `CreatedDate` is a DateTime shown in user timezone and is not editable — account managers may back-date or forward-date invoices (e.g., cut an invoice dated the 1st of the month on the 3rd). A dedicated editable `Invoice_Date__c` is the canonical billing anchor and matches real accounting practice. Defaulting to today covers the common case; editability covers back/forward dating.
**Unlocks:** 6 (trigger logic), 9 (layout placement).

### 5. How do picklist values map to day offsets?

**Q:** Where does the `Net X → X days` mapping live?
**A:** Private `Map<String, Integer>` constant inside `InvoiceService` (e.g., `TERM_TO_DAYS`): `Due on Receipt → 0`, `Net 15 → 15`, `Net 30 → 30`, `Net 45 → 45`, `Net 60 → 60`, `Net 90 → 90`.
**Reasoning:** The mapping is business logic owned by the service. Custom Metadata would be over-engineering for six closed values that match a restricted picklist that itself requires a deploy to change. If a future story asks for per-customer custom day counts, we can migrate to CMDT then.
**Unlocks:** 6.

### 6. What triggers the calculation — Flow, trigger, or formula field?

**Q:** Where does the auto-population happen?
**A:** **Apex trigger** on `Invoice__c`, `before insert` context, calling `InvoiceService.applyDueDateFromPaymentTerms(List<Invoice__c>)`.
**Reasoning:**

- **Formula field:** rejected — `Due_Date__c` is an editable Date (users may need to override per decision 10), and formula fields are read-only.
- **Flow:** rejected — CLAUDE.md prescribes Apex trigger handler pattern; the project has no Flows and uses `TriggerHandler` framework for every automation (`PaymentTrigger`).
- **Trigger (before insert):** ✓ fits the pattern, lets us set the field before the required-field validation runs, no extra DML, bulk-safe by design, easy to unit test with mocked selector.

**Unlocks:** 7, 10, 11.

### 7. What pattern for the trigger/handler/service?

**Q:** Replicate the Payment pattern?
**A:** Yes, exactly. Create:

- `force-app/main/default/triggers/InvoiceTrigger.trigger` (before insert; leave other contexts out until a second use case needs them)
- `force-app/main/default/classes/handlers/InvoiceTriggerHandler.cls` extending `TriggerHandler`, resolves `InvoiceService` via `InstanceProvider.provide`
- Extend existing `InvoiceService` with `applyDueDateFromPaymentTerms(List<Invoice__c>)` — do NOT create a new service; the method belongs with the existing Invoice business logic.
- Use existing `SOQL_Invoice` if we need to re-read anything; create `SOQL_Account` selector for fetching `Payment_Terms__c` in bulk.

**Reasoning:** CLAUDE.md states one trigger per object, services are instance-based, selectors extend `SOQL`. Keeping all Invoice logic in `InvoiceService` honors cohesion.
**Unlocks:** 12, 13.

### 8. What happens when `Payment_Terms__c` is null, the Account lookup is empty, or the term is unrecognized?

**Q:** Fallback behavior?
**A:** **Default to Net 30 (+30 days from Invoice Date).**
**Reasoning:** The story's goal is "always consistent" and "I don't have to set it manually" — throwing a validation error would violate that. Net 30 is the safe industry default and matches the Account field's default value. Unrecognized term (shouldn't happen because picklist is restricted) → also Net 30 (defensive).
**Unlocks:** 10.

### 9. Should the trigger overwrite a `Due_Date__c` the user typed manually on insert?

**Q:** Preserve user-entered Due Date, or force-calculate every time?
**A:** **Preserve user input.** On `before insert`, only set `Due_Date__c` when it is null.
**Reasoning:** The story says "so I don't have to set it manually" — implying if the user _does_ set it manually (e.g., a one-off custom due date negotiated with the customer), that intent must win. Always-overwrite would destroy data entered in the UI or via integration. The override flag for this feature is simply "set Due Date yourself = no auto-calc."
**Unlocks:** 10.

### 10. Do we recalc on `before update` when Account or Invoice Date changes?

**Q:** Scope — insert only, or update too?
**A:** **Insert only for v1.** No update recalculation.
**Reasoning:** The story is scoped to "when a new Invoice is created." Recalculating on update introduces ambiguity (user manually edited Due Date → should changing Invoice Date overwrite that? the answer is unclear without talking to the PO). Ship the insert case cleanly; a follow-up story can add update behavior with explicit rules. Trigger only declares `before insert` — keeps blast radius minimal.
**Unlocks:** (none — scope locked).

### 11. Is `Due_Date__c` still `required=true`?

**Q:** Required field on the metadata?
**A:** **Keep it required.** Trigger runs in `before insert` _before_ the required-field system validation, so auto-population happens in time. Additionally, keeping it required is a belt-and-braces safeguard: if the trigger were ever bypassed (`TriggerHandler.bypass('InvoiceTriggerHandler')`), the platform would still enforce a non-null due date.
**Reasoning:** `before insert` handler firing order guarantees we set the value before DB validation. `PaymentTrigger` uses the same pattern. Removing `required` would silently allow null due dates if the handler is bypassed.
**Unlocks:** 12.

### 12. Bulk-safety: how do we fetch Account payment terms for N invoices?

**Q:** Query strategy?
**A:** Build `SOQL_Account` selector (`force-app/main/default/classes/selectors/SOQL_Account.cls`) with `byIds(Set<Id>)` and default fields `Id, Payment_Terms__c`. In `InvoiceService.applyDueDateFromPaymentTerms`:

1. Collect `Set<Id>` of `Account__c` values from invoices missing `Due_Date__c` (skip invoices with Due Date already set — decision 9 — and invoices with null Account).
2. One SOQL via `SOQL_Account.query().byIds(...).mockId('InvoiceService.getPaymentTerms').toList()` → `Map<Id, Account>`.
3. Loop invoices, compute `Invoice_Date__c + termDays`, set `Due_Date__c`.

**Reasoning:** One query regardless of batch size. CLAUDE.md forbids SOQL in loops. `.mockId()` enables `SOQL.mock(...).thenReturn(...)` in unit tests without DB.
**Unlocks:** 13, 14.

### 13. What about invoices with null `Account__c`?

**Q:** Skip, or still default?
**A:** **Still default to Net 30** (+30 days from Invoice Date). Don't error.
**Reasoning:** `Account__c` is not required on the Invoice object. Treat "no account" the same as "account with no terms" — fall back to Net 30 (decision 8). Keeps the required Due Date satisfied and stays consistent with the fallback principle.
**Unlocks:** (none).

### 14. What about null `Invoice_Date__c`?

**Q:** Can a user submit an invoice with no Invoice Date?
**A:** No — `Invoice_Date__c` is required with default `TODAY()` (decision 4). But the trigger must still be defensive: if `Invoice_Date__c` is null in the trigger (e.g., integration bypasses defaults), use `Date.today()` as the anchor for calculation. Don't throw.
**Reasoning:** Defensive coding for bulk integrations. Required + default handles the UI case; the fallback covers the edge.
**Unlocks:** (none).

### 15. Permission set updates?

**Q:** What needs adding to `InvoiceUser`?
**A:** Add field permissions:

- `Invoice__c.Invoice_Date__c` (editable, readable)
- `Account.Payment_Terms__c` (editable, readable)

**Reasoning:** CLAUDE.md Deployment Checklist §1 — new fields must be added to the permission set explicitly or they are invisible. `Invoice__c.Due_Date__c` already works today and stays as-is. We do NOT add Account object CRUD because Account is a standard object with admin-defaulted permissions; we only add the new field perm.
**Unlocks:** 16.

### 16. Page layout / flexipage updates?

**Q:** Where should the new fields appear in the UI?
**A:**

- Add `Invoice_Date__c` to `Invoice__c-Invoice Layout` as Required, placed above `Due_Date__c` (logical billing order: date → due date).
- Add `Payment_Terms__c` to the existing `Account-Account Layout` in the main information section.
- `Due_Date__c` stays Required on the Invoice layout (user can still override before save).

**Reasoning:** Editable fields need to be on the layout to be usable. Keeping `Due_Date__c` editable on the layout is the mechanism for decision 9's "user override wins" rule.
**Unlocks:** 17.

### 17. Flexipage activation?

**Q:** Any flexipage work?
**A:** None. The existing `Invoice_Record_Page` and `Account_Record_Page` flexipages render detail fields via the standard record detail component; new fields appear automatically once on the page layout. No flexipage redeploy/reactivation required.
**Reasoning:** No XML changes in flexipages; CLAUDE.md Deployment Checklist §3 only applies when flexipage metadata itself changes.
**Unlocks:** (none).

### 18. LWC or UI component needed?

**Q:** Do we need a Lightning component?
**A:** No.
**Reasoning:** The story is 100% backend automation. User already sees `Due_Date__c` on the layout; it will simply arrive populated. No new screens.
**Unlocks:** (none).

### 19. Validation rule alternative?

**Q:** Should we add a validation rule "Due Date >= Invoice Date"?
**A:** Out of scope for this story. Noted as potential follow-up.
**Reasoning:** The story doesn't ask for it. Adding it could block legitimate manual overrides (e.g., Due on Receipt invoices where dates equal). Stay laser-focused on the ask.
**Unlocks:** (none).

### 20. Test coverage plan (Apex)

**Q:** What test classes and scenarios?
**A:**

- `InvoiceTriggerHandlerTest` (handler wiring — verify service called once per insert).
- `InvoiceServiceTest` (extend existing) with the following scenarios for `applyDueDateFromPaymentTerms`:
  1. `shouldSetDueDateFromNet30WhenAccountHasNet30Terms`
  2. `shouldSetDueDateFromNet15WhenAccountHasNet15Terms`
  3. `shouldSetDueDateToInvoiceDateWhenDueOnReceipt`
  4. `shouldDefaultToNet30WhenPaymentTermsIsNull`
  5. `shouldDefaultToNet30WhenAccountIsNull`
  6. `shouldPreserveDueDateWhenAlreadySetByUser`
  7. `shouldUseTodayWhenInvoiceDateIsNull`
  8. `shouldBulkProcess200InvoicesInOneQuery` (verifies no SOQL-in-loop: use `Limits.getQueries()` before/after or mock-assert single call via `.mockId`).
- `SOQL_AccountTest` for selector (byIds returns matching accounts).

All tests mock SOQL via `SOQL.mock('InvoiceService.getPaymentTerms').thenReturn(...)` and use `Assert.areEqual`. No `@TestSetup`, no real DML, no DB hits per CLAUDE.md.

**Reasoning:** Mirrors `PaymentServiceTest` conventions. 95% coverage requirement met by covering happy path + all fallbacks + bulk.
**Unlocks:** (none).

### 21. LWC Jest tests?

**Q:** Any JS tests needed?
**A:** No. No LWC touched.
**Reasoning:** Backend only.
**Unlocks:** (none).

### 22. Deployment order

**Q:** Any ordering constraints?
**A:** Single deploy is safe because dependencies resolve together. Order within the deploy package:

1. Custom fields (`Account.Payment_Terms__c`, `Invoice__c.Invoice_Date__c`).
2. Permission set update.
3. Selector (`SOQL_Account`).
4. Service change (`InvoiceService.applyDueDateFromPaymentTerms` + constant).
5. Handler (`InvoiceTriggerHandler`).
6. Trigger (`InvoiceTrigger`).
7. Layout updates.

Then: `sf org assign permset --name InvoiceUser` (idempotent — already assigned, but re-running is safe if field-level perm was just added).
**Reasoning:** Salesforce metadata deploy handles the dependency graph, but if we ever split deploys, this is the correct order (fields before classes that reference them).
**Unlocks:** (none).

### 23. Mock / injection strategy

**Q:** How are dependencies injected in the handler test?
**A:** `InstanceProvider.injectMock(InvoiceService.class, universalMockerStub)` in the handler test; verify `applyDueDateFromPaymentTerms` invoked with the triggerNew list. In service tests, mock the SOQL selector with `SOQL.mock('InvoiceService.getPaymentTerms').thenReturn(accountsList)`.
**Reasoning:** Standard project pattern (see `PaymentTriggerHandlerTest` and `PaymentServiceTest`).
**Unlocks:** (none).

### 24. Timezone / date arithmetic

**Q:** `Date + Integer` — any timezone gotchas?
**A:** None. `Invoice_Date__c` and `Due_Date__c` are `Date` (not DateTime). Apex `Date.addDays(Integer)` is timezone-agnostic.
**Reasoning:** Using Date (not DateTime) was the right data-type choice; no conversion needed.
**Unlocks:** (none).

### 25. Does `Date.today()` behave correctly in trigger context?

**Q:** Any concern with `Date.today()` fallback?
**A:** None. `Date.today()` returns the current date in the _user's_ timezone, which matches how the record is presented in the UI. Acceptable.
**Reasoning:** Standard platform behavior; not worth overengineering with `UserInfo` timezone juggling for a fallback case.
**Unlocks:** (none).

---

## Open questions remaining

**None.** All 25 branches resolved.

---

## Settled plan (handoff to architect)

**Scope:** Auto-populate `Invoice__c.Due_Date__c` on insert from the related `Account`'s payment terms.

**Data model changes:**

- New `Account.Payment_Terms__c` — restricted picklist (`Due on Receipt`, `Net 15`, `Net 30`, `Net 45`, `Net 60`, `Net 90`), default `Net 30`, not required.
- New `Invoice__c.Invoice_Date__c` — required Date, default `TODAY()`.

**Apex:**

- New trigger `InvoiceTrigger` (`before insert` only), delegating to new `InvoiceTriggerHandler extends TriggerHandler`.
- Extend `InvoiceService` with `applyDueDateFromPaymentTerms(List<Invoice__c>)` and a private `Map<String,Integer>` for term-to-days mapping.
- New `SOQL_Account` selector with `byIds(Set<Id>)`.

**Business rules (authoritative):**

1. Trigger runs `before insert` only.
2. Calculate only when `Due_Date__c` is null on the incoming invoice — user-entered due dates are preserved.
3. Anchor = `Invoice_Date__c`, falling back to `Date.today()` if null.
4. Days added = picklist mapping. Null / unknown / missing Account → Net 30.
5. Bulk-safe: one SOQL query for all accounts across the triggered batch.

**Permissions / UI:**

- Add `Account.Payment_Terms__c` and `Invoice__c.Invoice_Date__c` to `InvoiceUser` permission set (editable + readable).
- Add `Payment_Terms__c` to Account layout; add `Invoice_Date__c` above `Due_Date__c` on Invoice layout (both Required).
- No flexipage, LWC, or validation-rule changes.

**Testing:**

- `InvoiceTriggerHandlerTest` (handler wiring).
- Extend `InvoiceServiceTest` with 8 scenarios covering every branch (happy, fallback for null terms/account, user-override preserved, null Invoice Date fallback, bulk 200).
- `SOQL_AccountTest` for the new selector.
- All tests mock SOQL/DML/services via `SOQL.mock` / `InstanceProvider.injectMock` / `UniversalMocker`. No DB inserts, no `@TestSetup`. Target 95%+ coverage.

**Out of scope (explicit):** update-time recalculation, validation rule "Due Date >= Invoice Date", custom per-account day counts, any UI component work.

Ready for architect phase.
