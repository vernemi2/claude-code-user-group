# Autonomous Salesforce Development with Claude Code

## Project Overview

Salesforce DX project demonstrating fully autonomous AI-driven development.
Developer Edition org. API version 66.0.

## Salesforce CLI

- Set default org: `sf config set target-org=claude-demo`
- Deploy: `sf project deploy start --source-dir force-app`
- Run Apex tests: `sf apex run test --test-level RunLocalTests --result-format human --wait 10`
- Run specific test: `sf apex run test --class-names MyClassTest --result-format human --wait 10`
- Open org: `sf org open`
- Open specific page: `sf org open -p "/lightning/o/Account/list"`

## Deployment Checklist

When creating new custom objects or fields:

1. **Permission sets** — Add all new objects and fields to the relevant permission set (Read/Create/Edit/Delete on objects, Read/Edit on fields). Without this, fields are invisible even to admins.
2. **Assign permission set** — After deploying, assign the permission set to the current user: `sf org assign permset --name PermSetName`
3. **Flexipage activation** — Deploying a flexipage does NOT activate it. After deploying, activate it as the org default via Setup > Lightning App Builder, or through the browser.

## Code Quality Tools

- ESLint: `npm run lint`
- Prettier: `npm run prettier`
- Jest (LWC): `npm run test:unit`
- Pre-commit hooks via Husky + lint-staged are configured

## Apex Conventions

### Trigger Handler Pattern

All triggers use the [TriggerHandler](https://github.com/bluez-io/trigger-framework) framework (source in `libs/trigger-framework/`). One trigger per object, delegating to a handler that extends `TriggerHandler`.

- Trigger: `{Object}Trigger.trigger` in `force-app/main/default/triggers/`
- Handler: `{Object}TriggerHandler.cls` in `force-app/main/default/classes/`

```apex
trigger AccountTrigger on Account(
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new AccountTriggerHandler().run();
}

public class AccountTriggerHandler extends TriggerHandler {
    private final AccountService accountService;

    public AccountTriggerHandler() {
        this.accountService = (AccountService) InstanceProvider.provide(AccountService.class);
    }

    protected override void beforeInsert(List<SObject> triggerNew) {
        accountService.validateAccounts(triggerNew);
    }

    protected override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
        accountService.processChanges(triggerNew, triggerOld);
    }
}
```

Override only the contexts you need: `beforeInsert(List<SObject>)`, `beforeUpdate(Map, Map)`, `beforeDelete(Map)`, `afterInsert(Map)`, `afterUpdate(Map, Map)`, `afterDelete(Map)`, `afterUndelete(Map)`. Use `TriggerHandler.bypass('HandlerName')` / `.clearBypass()` to disable handlers programmatically. Use `this.setMaxLoopCount(n)` to prevent recursion.

### Service Layer

Business logic lives in `{Feature}Service.cls` classes. **No static methods** — services are instance-based, resolved via `InstanceProvider.provide()`.

```apex
public class AccountService {
  private final AccountSelector selector;

  public AccountService() {
    this.selector = (AccountSelector) InstanceProvider.provide(
      AccountSelector.class
    );
  }

  public List<Account> getByIndustry(String industry) {
    return SOQL_Account.query().byIndustry(industry).toList();
  }
}
```

### SOQL Lib (Query Builder)

All SOQL queries use the [SOQL Lib](https://soql.beyondthecloud.dev/) fluent API (source in `libs/soql-lib/`). **Never write raw SOQL strings.** Handles variable binding, FLS, and sharing automatically. Read `libs/soql-lib/classes/SOQL.cls` for full API.

**Selector pattern** — each queried SObject gets `SOQL_{Object}.cls` extending `SOQL` implementing `SOQL.Selector`:

```apex
public inherited sharing class SOQL_Account extends SOQL implements SOQL.Selector {
  public static SOQL_Account query() {
    return new SOQL_Account();
  }

  private SOQL_Account() {
    super(Account.SObjectType);
    with(Account.Id, Account.Name).systemMode().withoutSharing();
  }

  public SOQL_Account byIndustry(String industry) {
    whereAre(Filter.with(Account.Industry).equal(industry));
    return this;
  }
}
```

- Keep selectors lightweight — only default fields, security config, and reusable filter methods
- Add fields dynamically at the call site with `.with()`
- Build business-specific queries inline — most queries are one-time
- Tag queries with `.mockId('id')` for test mocking via `SOQL.mock('id').thenReturn(records)`
- Security: user mode by default; use `.systemMode()` to bypass FLS, `.withSharing()` / `.withoutSharing()` for sharing

### DML Lib (Unit of Work)

All DML operations use the [DML Lib](https://dml.beyondthecloud.dev/) fluent API (source in `libs/dml-lib/`). **Never use raw `insert`/`update`/`delete`.** Handles transaction batching, relationship resolution, FLS, and sharing. Read `libs/dml-lib/classes/DML.cls` for full API.

```apex
new DML()
    .toInsert(account)
    .toInsert(DML.Record(contact).withRelationship(Contact.AccountId, account))
    .toUpdate(existingCase)
    .commitWork();
```

- Batched: `.toInsert()`, `.toUpdate()`, `.toUpsert()`, `.toDelete()`, `.toUndelete()`, `.toPublish()` — execute on `.commitWork()`
- Immediate: `.insertImmediately()`, `.updateImmediately()`, etc. — returns `OperationResult`
- Relationships: `DML.Record(child).withRelationship(field, parent)` — auto-resolves parent IDs
- Dynamic fields: `DML.Record(record).with(Field, value)` or `DML.Records(list).with(Field, value)`
- Transaction safety: `.commitTransaction()` for savepoint + rollback; `.allowPartialSuccess()` for partial commits
- Security: user mode by default; `.systemMode()`, `.withSharing()`, `.withoutSharing()`
- Tag with `.mockId('id')` for test mocking via `DML.mock('id').allInserts()`

### UniversalMocker (Test Stubs)

[UniversalMocker](https://github.com/surajp/universalmock) (source in `libs/universal-mocker/`) creates test stubs via the Apex Stub API. Read the source for full API.

```apex
UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
mockInstance.when('charge').thenReturn(true);
PaymentService stub = (PaymentService) mockInstance.createStub();
```

- `.when('method').thenReturn(value)` / `.thenThrow(exception)` / `.thenReturnVoid()`
- `.withParamTypes(List<Type>)` for overloaded methods
- `.thenReturnUntil(n, value).thenReturn(fallback)` for sequential returns
- `.assertThat().method('name').wasCalled(n)` / `.wasNeverCalled()` for verification
- `.forMethod('name').andInvocationNumber(n).getValueOf('param')` for argument inspection

### Instance Provider (Dependency Injection)

[InstanceProvider](https://github.com/bluez-io/instance-provider) (source in `libs/instance-provider/`) provides constructor-free DI. **Never directly instantiate service dependencies.**

```apex
// Production — resolve via provider
this.paymentService = (PaymentService) InstanceProvider.provide(PaymentService.class);

// Test — inject mock
InstanceProvider.injectMock(PaymentService.class, mockStub);
```

### Hard Rules

- **No SOQL or DML inside loops** — ever
- **Bulk-safe**: all code must handle 200+ records
- **No hardcoded record IDs**
- **No raw SOQL strings** — use SOQL Lib fluent API for all queries
- **No raw DML statements** — use DML Lib fluent API for all database operations
- **No static methods on services/handlers** — full OOP, resolve dependencies via `InstanceProvider.provide()`
- **Use `Assert` class** (not legacy `System.assert`): `Assert.areEqual(expected, actual, 'message')`

## LWC Conventions

- Component naming: `camelCase` directory (e.g., `overdueInvoiceBanner`)
- Use `@wire` for data reads, `lightning/uiRecordApi` for CRUD
- Use `lightning-record-*` base components where possible
- `@api` for public properties, reactive tracking is automatic (no `@track` needed)
- Import Apex methods with `@salesforce/apex/{ClassName}.{methodName}`

## Test Conventions

### Apex Tests

**Unit test everything. Mock all dependencies.** Tests should never hit the database or depend on org state.

- Class naming: `{ClassName}Test.cls`
- Minimum **95% coverage** per class
- Test scenarios: positive, negative, bulk (200+ records), edge cases
- Use `Test.startTest()` / `Test.stopTest()` around the operation under test
- Never use `@SeeAllData=true`
- Never use `@TestSetup` — all data should be constructed in-memory via mocks

**Mocking strategy** — every dependency is mocked at its boundary:

| Layer              | Tool                                                | What it mocks                     |
| ------------------ | --------------------------------------------------- | --------------------------------- |
| SOQL queries       | `SOQL.mock('id').thenReturn(records)`               | Query results — no database read  |
| DML operations     | `DML.mock('id').allInserts()`                       | Database writes — no DML executed |
| Class dependencies | `InstanceProvider.injectMock()` + `UniversalMocker` | Service/selector instances        |

```apex
@IsTest
static void shouldCalculateTotalFromLineItems() {
    // Mock SOQL
    SOQL.mock('InvoiceService.getLineItems').thenReturn(mockLines);
    // Mock DML
    DML.mock('InvoiceService.updateInvoice').allUpdates();
    // Mock class dependency
    UniversalMocker taxMock = UniversalMocker.mock(TaxService.class);
    taxMock.when('calculateTax').thenReturn(35.00);
    InstanceProvider.injectMock(TaxService.class, taxMock.createStub());

    InvoiceService service = new InvoiceService();
    Test.startTest();
    Decimal total = service.calculateTotal(invoiceId);
    Test.stopTest();

    Assert.areEqual(385.00, total, 'Total should be line items + tax');
    taxMock.assertThat().method('calculateTax').wasCalled(1);
}
```

**Test guidelines:**

- One concern per test method — test a single behavior, not an entire flow
- Name tests descriptively: `shouldDoXWhenY`, `shouldThrowWhenInvalidInput`
- Construct SObjects in-memory — `new Account(Name = 'Test')` without insert
- Mock at the boundary — mock the direct dependency, not its transitive dependencies
- Verify interactions — use `UniversalMocker.assertThat()` to confirm call counts
- No test utility classes that insert records — build data inline or mock the query

### LWC Jest Tests

- Test file: `{componentName}/__tests__/{componentName}.test.js`
- Mock wire adapters and Apex calls
- Test rendering, user interactions, and error states
- Use `flushPromises` from the shared `c/testUtils` service component to await async re-renders:
  ```javascript
  import { flushPromises } from "c/testUtils";
  ```
  Do NOT define `flushPromises` inline in test files — always import from `c/testUtils`.

## Project Structure

```
force-app/main/default/          # Project code
├── classes/                     # Apex classes + test classes
├── triggers/                    # One trigger per object
├── lwc/                         # Lightning Web Components
├── objects/                     # Custom objects and fields
├── permissionsets/              # Permission sets
├── layouts/                     # Page layouts
├── flexipages/                  # Lightning record/app pages
└── tabs/                        # Custom tabs

libs/                            # Third-party libraries (separate package directories)
├── trigger-framework/classes/   # Trigger handler base class
├── universal-mocker/classes/    # Test stub/mock framework
├── instance-provider/classes/   # Dependency injection
├── soql-lib/classes/            # SOQL query builder
└── dml-lib/classes/             # DML unit of work
```

## Autonomous Agent Pipeline

When running `/story-to-feature`, execute these phases in order:

1. **Architect** — Analyze the story, design the solution
2. **Implement** — Write all code and metadata
3. **Test** — Write tests, deploy, run, iterate on failures
4. **Validate** — Playwright browser testing against the org
5. **Review** — Code review, fix issues, commit

Each phase passes its output as context to the next phase.
Self-healing: if tests or deployment fail, read errors and fix (max 3 iterations per phase).
