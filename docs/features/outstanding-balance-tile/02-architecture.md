# Architecture: Account Outstanding Balance Tile

## Summary

A presentational Lightning Web Component (`c-account-outstanding-balance-tile`)
placed at the top of the `main` region of the Account record page. The tile
shows the total outstanding balance and the count of open invoices for the
Account, computed by the existing `InvoiceService.getAgingBreakdown` aggregation
and surfaced through the existing `AccountInvoiceAgingController.getAgingBreakdown`
`@AuraEnabled(cacheable=true)` endpoint. Clicking the tile navigates to the
Account's `Invoices__r` related list. **No new Apex, no new DTOs, no new
permission-set entries** — only one new LWC bundle and an updated flexipage.

## Data Flow (Reused, Unchanged)

```
@wire getAgingBreakdown (cacheable=true, dedupes with sibling LWC)
        |
        v
AccountInvoiceAgingController.getAgingBreakdown(Id accountId)
        |
        v
InvoiceService.getAgingBreakdown(accountId)
   - SOQL_Invoice.query().unpaid().byAccount(accountId)  // selector
   - PaymentService.getPaymentTotals(invoiceIds)         // aggregate
   - returns InvoiceAgingBreakdown { buckets, totalUnpaidCount, totalUnpaidAmount }
        |
        v
LWC reads totalUnpaidAmount + totalUnpaidCount, ignores buckets.
```

The LWC consumes **only** `totalUnpaidAmount` and `totalUnpaidCount` from the
existing DTO. The `buckets` array is read by the sibling
`accountInvoiceAgingBreakdown` LWC and ignored here.

## Salesforce Artifacts

| Artifact                         | Status      | Reason                                                                |
| -------------------------------- | ----------- | --------------------------------------------------------------------- |
| Custom objects / fields          | None        | All data sourced from existing `Invoice__c` + `Payment__c`.           |
| Apex trigger                     | None        | No DML side effects.                                                  |
| Apex handler                     | None        | No trigger.                                                           |
| Apex service                     | None        | Reuses `InvoiceService.getAgingBreakdown`.                            |
| Apex selector (`SOQL_*`)         | None        | Reuses `SOQL_Invoice.unpaid()` via the service layer.                 |
| Apex controller (`@AuraEnabled`) | None        | Reuses `AccountInvoiceAgingController.getAgingBreakdown`.             |
| LWC                              | **NEW**     | `accountOutstandingBalanceTile` bundle.                               |
| Permission set                   | None        | `InvoiceUser` already grants the required reads (sibling components). |
| Page layout                      | None        | Not used; modern record page uses flexipage.                          |
| Lightning page (flexipage)       | **UPDATED** | `Account_Record_Page.flexipage-meta.xml` gains the new tile at top.   |
| Tab                              | None        | LWC is record-page only.                                              |

## LWC Architecture

### Component: `c-account-outstanding-balance-tile`

- **Directory:** `force-app/main/lwc/accountOutstandingBalanceTile/`
- **Target:** `lightning__RecordPage`, restricted to `<object>Account</object>`
- **Inputs:** `@api recordId` (populated by the page binding)
- **Data acquisition:** `@wire(getAgingBreakdown, { accountId: '$recordId' })`
  imported from `@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown`.
  The wire dedupes with the sibling `accountInvoiceAgingBreakdown` LWC because
  the Apex method is `cacheable=true` and both bind the same `recordId`.
- **Derived state (getters):**
  - `isLoading` — `!data && !error`
  - `hasError` — `!!error`
  - `hasData` — `!!data`
  - `totalAmount` — `data?.totalUnpaidAmount ?? 0`
  - `openCount` — `data?.totalUnpaidCount ?? 0`
  - `formattedAmount` — `Intl.NumberFormat(LOCALE, { style:'currency', currency:CURRENCY }).format(totalAmount)`
  - `countLabel` —
    - `openCount === 0` → `'No open invoices'`
    - `openCount === 1` → `'1 open invoice'`
    - else → `${openCount} open invoices`
  - `ariaLabel` — synthesized from the resolved state:
    - loading → `'Loading outstanding balance'`
    - error → `'Outstanding balance unavailable'`
    - data → `'Outstanding balance ${formattedAmount} across ${countLabel}. Open related invoices.'`
- **User interactions:**
  - Card body is a `<button type="button">` (always clickable when `hasData` is
    true, even when `openCount === 0`).
  - `handleNavigate()` calls `NavigationMixin.Navigate` with
    `type: 'standard__recordRelationshipPage'`,
    `objectApiName: 'Account'`,
    `relationshipApiName: 'Invoices__r'`,
    `actionName: 'view'`,
    `recordId: this.recordId`.

### Template structure (`.html`)

```
<lightning-card title="Outstanding Balance" icon-name="standard:currency">
  <div class="slds-p-horizontal_medium slds-p-bottom_medium">
    <template lwc:if={isLoading}>
      <lightning-spinner size="small" alternative-text="Loading outstanding balance">
    </template>
    <template lwc:elseif={hasError}>
      <lightning-badge label="Outstanding balance unavailable" icon-name="utility:warning">
    </template>
    <template lwc:elseif={hasData}>
      <button type="button" class="tile" aria-label={ariaLabel} onclick={handleNavigate}>
        <span class="tile-amount">{formattedAmount}</span>
        <span class="tile-count">{countLabel}</span>
      </button>
    </template>
  </div>
</lightning-card>
```

### Styling (`.css`)

Self-contained; mirrors the typography of the sibling aging tiles:

- `.tile` — flex column, transparent background, `cursor: pointer`,
  inherits font/color, no border (the card already provides the chrome),
  `:focus-visible` outline using `--lwc-colorBrand`.
- `.tile-amount` — `font-size: 2rem; font-weight: 700;` (KPI emphasis, larger
  than the bucket tiles' 1.125rem because this is the headline number).
- `.tile-count` — `font-size: 0.875rem; color: var(--lwc-colorTextWeak);`

### Metadata (`.js-meta.xml`)

```xml
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/metadata">
    <apiVersion>66.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>Account Outstanding Balance Tile</masterLabel>
    <description
  >KPI tile showing total outstanding balance and open invoice count for an Account.</description>
    <targets>
        <target>lightning__RecordPage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <objects>
                <object>Account</object>
            </objects>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

## Apex Architecture

**No changes.** The end-to-end Apex path the LWC depends on already exists and
is covered by tests:

- `AccountInvoiceAgingController.getAgingBreakdown(Id accountId)` — controller
- `InvoiceService.getAgingBreakdown(Id accountId)` — service (instance-resolved)
- `SOQL_Invoice.query().unpaid().byAccount(accountId)` — selector
- `PaymentService.getPaymentTotals(Set<Id> invoiceIds)` — aggregate

## Flexipage Change

`force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml` — insert a
new `<itemInstances>` block at the **top** of the `main` region (before the
existing `c:accountOverdueInvoiceBadge` instance):

```xml
<itemInstances>
    <componentInstance>
        <componentName>c:accountOutstandingBalanceTile</componentName>
        <identifier>c_accountOutstandingBalanceTile</identifier>
    </componentInstance>
</itemInstances>
```

The badge and aging-breakdown components are preserved in their existing
positions. The detail panel and related-list container remain untouched.

## Tests

### LWC Jest

**File:** `force-app/main/lwc/accountOutstandingBalanceTile/__tests__/accountOutstandingBalanceTile.test.js`

Mocks:

- `lightning/navigation` — fake `NavigationMixin` that records calls to a
  `mockNavigate` `jest.fn()` (mirror the sibling test).
- `@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown` — wrap with
  `createApexTestWireAdapter` so the test can call `.emit(data)` / `.error()`.
- `flushPromises` imported from `c/testUtils` per CLAUDE.md.

Test cases:

1. **Loading state** — before `emit`, expect `lightning-spinner` rendered and no
   `button.tile`.
2. **Error state** — call `getAgingBreakdown.error()`, then assert the
   `lightning-badge` is rendered with label `"Outstanding balance unavailable"`
   and `iconName="utility:warning"`.
3. **Populated state** — emit
   `{ buckets: [], totalUnpaidCount: 3, totalUnpaidAmount: 4250 }`,
   assert `.tile-amount` text contains `"4,250"` (not just `4250`) and
   `.tile-count` reads `"3 open invoices"`.
4. **Singular state** — emit
   `{ buckets: [], totalUnpaidCount: 1, totalUnpaidAmount: 100 }`,
   assert `.tile-count` reads `"1 open invoice"`.
5. **Zero state** — emit
   `{ buckets: [], totalUnpaidCount: 0, totalUnpaidAmount: 0 }`,
   assert `.tile-amount` text contains `"0"`, `.tile-count` reads
   `"No open invoices"`, and the tile button is still present and clickable.
6. **Navigation** — after a populated emit, click the tile button and assert
   `mockNavigate` was called once with `type: 'standard__recordRelationshipPage'`,
   `attributes.objectApiName: 'Account'`,
   `attributes.relationshipApiName: 'Invoices__r'`,
   `attributes.actionName: 'view'`,
   `attributes.recordId: '001000000000001'`.
7. **Accessibility** — after a populated emit, assert the tile button has a
   non-empty `aria-label`.

### Apex

None added. Existing tests run on deploy:

- `InvoiceServiceTest` (covers `getAgingBreakdown` returning
  `totalUnpaidAmount` + `totalUnpaidCount`).
- `AccountInvoiceAgingControllerTest` (covers the `@AuraEnabled` boundary).

## Task List (Dependency-Ordered)

### Phase 1 — LWC bundle

1. **Create** `force-app/main/lwc/accountOutstandingBalanceTile/accountOutstandingBalanceTile.js-meta.xml`
   - **Acceptance:** `isExposed=true`, `apiVersion=66.0`, target
     `lightning__RecordPage` restricted to `<object>Account</object>`,
     masterLabel `"Account Outstanding Balance Tile"`.

2. **Create** `force-app/main/lwc/accountOutstandingBalanceTile/accountOutstandingBalanceTile.js`
   - Import `LightningElement`, `api`, `wire` from `lwc`.
   - Import `NavigationMixin` from `lightning/navigation`.
   - Import `LOCALE` from `@salesforce/i18n/locale`, `CURRENCY` from `@salesforce/i18n/currency`.
   - Import `getAgingBreakdown` from `@salesforce/apex/AccountInvoiceAgingController.getAgingBreakdown`.
   - Export default class extending `NavigationMixin(LightningElement)`.
   - Declare `@api recordId`, `@wire(getAgingBreakdown, { accountId: '$recordId' }) breakdown`.
   - Implement getters: `isLoading`, `hasError`, `hasData`, `totalAmount`,
     `openCount`, `formattedAmount`, `countLabel`, `ariaLabel`.
   - Implement `handleNavigate()` that calls `NavigationMixin.Navigate` with
     the related-list page reference.
   - **Acceptance:** ESLint passes; no `lightning-formatted-number` used; the
     `formattedAmount` uses `Intl.NumberFormat(LOCALE, …)`.

3. **Create** `force-app/main/lwc/accountOutstandingBalanceTile/accountOutstandingBalanceTile.html`
   - Single `<lightning-card title="Outstanding Balance" icon-name="standard:currency">` wrapping the
     tri-state body described in the LWC Architecture section.
   - The data state must use `<button type="button" class="tile" aria-label={ariaLabel} onclick={handleNavigate}>`.
   - **Acceptance:** No `<div>` is used in place of the button; spinner has
     `alternative-text`; error badge has `icon-name="utility:warning"`.

4. **Create** `force-app/main/lwc/accountOutstandingBalanceTile/accountOutstandingBalanceTile.css`
   - `.tile` button reset + focus styles; `.tile-amount` 2rem bold;
     `.tile-count` 0.875rem muted.
   - **Acceptance:** No hard-coded brand colors outside SLDS CSS variables
     (fall back to literal hex only inside `var(--…, fallback)`).

### Phase 2 — Tests

5. **Create** `force-app/main/lwc/accountOutstandingBalanceTile/__tests__/accountOutstandingBalanceTile.test.js`
   - Implement the seven test cases in the Tests section above.
   - Use `flushPromises` from `c/testUtils` (do NOT redefine inline).
   - **Acceptance:** `npm run test:unit -- accountOutstandingBalanceTile`
     passes all cases.

### Phase 3 — Flexipage

6. **Modify** `force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml`
   - Insert a new `<itemInstances>` block at the **top** of the `main`
     `<flexiPageRegions>` (above the existing `accountOverdueInvoiceBadge`
     instance).
   - **Acceptance:** XML is well-formed; new instance has
     `componentName=c:accountOutstandingBalanceTile` and unique
     `identifier=c_accountOutstandingBalanceTile`; the badge and aging
     breakdown instances remain unchanged in their existing order.

### Phase 4 — Deploy & verify

7. **Deploy** `sf project deploy start --source-dir force-app/main/lwc/accountOutstandingBalanceTile --source-dir force-app/main/flexipages/Account_Record_Page.flexipage-meta.xml`
   - **Acceptance:** Deploy succeeds; no metadata errors.

8. **Run existing Apex tests** `sf apex run test --test-level RunLocalTests --result-format human --wait 10`
   - **Acceptance:** All tests pass (no regression from the reused
     `InvoiceService` / `AccountInvoiceAgingController` path).

9. **Verify flexipage activation** — open the Account list, then any Account
   record (`sf org open -p "/lightning/o/Account/list"`), and confirm the new
   tile renders at the top of the page above the badge and aging breakdown.
   - **Acceptance:** The Account record page is still the active org default
     (no manual activation needed because the same flexipage was already active);
     the new tile renders with a real value or the zero-state copy.

### Phase 5 — Permissions

None. `InvoiceUser` already grants the required reads through the existing
controller/service path.

## Risks & Mitigations

| Risk                                                                        | Mitigation                                                                                                                                                            |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tile and aging-breakdown drift if `totalUnpaidAmount` semantics ever change | Both LWCs source from the same Apex call; any change to the DTO updates both atomically.                                                                              |
| Wire `cacheable=true` may return stale data after off-page DML              | Out of scope per grill decision #17 (no live-refresh in this story). If needed later, add `refreshApex` plumbing across all three components at once.                 |
| Flexipage redeploy resets activation                                        | The flexipage is already active; redeploy preserves activation. Verify per CLAUDE.md deployment checklist rule #3.                                                    |
| Locale/currency mismatch in tests                                           | Assertions check substring (`"4,250"`) rather than full currency string, so they pass under any locale Jest happens to run in (mirroring the sibling test's pattern). |
