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

## Code Quality Tools

- ESLint: `npm run lint`
- Prettier: `npm run prettier`
- Jest (LWC): `npm run test:unit`
- Pre-commit hooks via Husky + lint-staged are configured

## Apex Conventions

### Trigger Handler Pattern

All triggers use the [TriggerHandler](https://github.com/bluez-io/trigger-framework) framework. One trigger per object, delegating to a handler class that extends `TriggerHandler`.

- Trigger: `{Object}Trigger.trigger` in `force-app/main/default/triggers/`
- Handler: `{Object}TriggerHandler.cls` in `force-app/main/default/classes/`

```apex
// Trigger — thin, only delegates
trigger AccountTrigger on Account(
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    new AccountTriggerHandler().run();
}

// Handler — extends TriggerHandler, resolve services via InstanceProvider
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

#### Available Context Methods

| Method | Parameters |
|---|---|
| `beforeInsert` | `List<SObject> triggerNew` |
| `beforeUpdate` | `Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld` |
| `beforeDelete` | `Map<Id, SObject> triggerOld` |
| `afterInsert` | `Map<Id, SObject> triggerNew` |
| `afterUpdate` | `Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld` |
| `afterDelete` | `Map<Id, SObject> triggerOld` |
| `afterUndelete` | `Map<Id, SObject> triggerNew` |

#### Bypass and Loop Protection

```apex
// Bypass a handler programmatically
TriggerHandler.bypass('AccountTriggerHandler');
// ... do work without AccountTriggerHandler firing
TriggerHandler.clearBypass('AccountTriggerHandler');

// Prevent recursive triggers (set in handler constructor)
public AccountTriggerHandler() {
    this.setMaxLoopCount(1);
}
```

### Service Layer

Business logic lives in `{Feature}Service.cls` classes. **No static methods** — services are instance-based and resolved via `InstanceProvider.provide()` so they can be mocked in tests.

```apex
public class AccountService {
    private final AccountSelector selector;

    public AccountService() {
        this.selector = (AccountSelector) InstanceProvider.provide(AccountSelector.class);
    }

    public List<Account> getByIndustry(String industry) {
        return SOQL_Account.query()
            .byIndustry(industry)
            .toList();
    }
}
```

### SOQL Lib (Query Builder)

All SOQL queries use the [SOQL Lib](https://soql.beyondthecloud.dev/) fluent API. **Never write raw SOQL strings.** The library handles variable binding, FLS enforcement, and sharing automatically.

#### Selector Pattern

Each queried SObject gets a selector class: `SOQL_{Object}.cls` extending `SOQL` and implementing `SOQL.Selector`.

```apex
public inherited sharing class SOQL_Account extends SOQL implements SOQL.Selector {

    public static SOQL_Account query() {
        return new SOQL_Account();
    }

    private SOQL_Account() {
        super(Account.SObjectType);
        with(Account.Id, Account.Name)
            .systemMode()
            .withoutSharing();
    }

    public SOQL_Account byIndustry(String industry) {
        whereAre(Filter.with(Account.Industry).equal(industry));
        return this;
    }

    public SOQL_Account byParentId(Id parentId) {
        whereAre(Filter.with(Account.ParentId).equal(parentId));
        return this;
    }
}
```

**Selector rules:**
- Keep selectors lightweight — only default fields, security config, and reusable filter methods
- Add additional fields dynamically at the call site with `.with()`
- Build business-specific queries inline using the fluent API — most queries are one-time and don't belong in the selector

#### Building Queries

```apex
// Via selector (preferred for objects with a selector)
List<Account> accounts = SOQL_Account.query()
    .byIndustry('Technology')
    .with(Account.AnnualRevenue, Account.BillingCity)
    .orderBy(Account.AnnualRevenue).sortDesc()
    .setLimit(10)
    .toList();

// Inline for quick one-off queries
List<Lead> leads = SOQL.of(Lead.SObjectType)
    .with(Lead.Id, Lead.Name, Lead.Email)
    .whereAre(SOQL.Filter.with(Lead.Status).equal('Open'))
    .toList();
```

#### Filters

```apex
// Single condition
.whereAre(SOQL.Filter.with(Account.Industry).equal('Technology'))

// Multiple conditions (AND by default)
.whereAre(SOQL.FilterGroup
    .add(SOQL.Filter.with(Account.Industry).equal('IT'))
    .add(SOQL.Filter.with(Account.NumberOfEmployees).greaterOrEqual(10))
)

// OR logic
.whereAre(SOQL.FilterGroup
    .add(SOQL.Filter.name().contains('Acme'))
    .add(SOQL.Filter.with(Account.Type).equal('Partner'))
    .anyConditionMatching()
)

// Custom condition logic
.whereAre(SOQL.FilterGroup
    .add(SOQL.Filter.with(Account.Name).equal('My Account'))       // 1
    .add(SOQL.Filter.with(Account.NumberOfEmployees).greaterOrEqual(10)) // 2
    .add(SOQL.Filter.with(Account.Industry).equal('IT'))           // 3
    .conditionLogic('(1 AND 2) OR (1 AND 3)')
)

// Conditional filter — ignored when value is empty
.whereAre(SOQL.Filter.name().contains(searchTerm)
    .ignoreWhen(String.isEmpty(searchTerm)))

// Semi-join (IN subquery)
.whereAre(SOQL.Filter.with(Account.Id).isIn(
    SOQL.InnerJoin.of(Contact.SObjectType)
        .with(Contact.AccountId)
        .whereAre(SOQL.Filter.with(Contact.Email).endsWith('@acme.com'))
))
```

**Available filter operators:** `equal`, `notEqual`, `lessThan`, `greaterThan`, `lessOrEqual`, `greaterOrEqual`, `isIn`, `notIn`, `contains`, `notContains`, `startsWith`, `endsWith`, `isNull`, `isNotNull`, `isTrue`, `isFalse`, `includesAll`, `includesSome`, `excludesAll`, `excludesSome`

**Shortcut filters:** `Filter.id()`, `Filter.name()`, `Filter.recordType()`

#### Subqueries

```apex
SOQL.of(Account.SObjectType)
    .with(SOQL.SubQuery.of('Contacts')
        .with(Contact.Id, Contact.Name)
        .orderBy(Contact.Name)
        .setLimit(100)
    ).toList();
```

#### Result Methods

```apex
.toList()              // List<SObject>
.toObject()            // Single SObject
.toId()                // Single Id
.toIds()               // Set<Id> of record Ids
.toIdsOf(field)        // Set<Id> from a specific field
.toValuesOf(field)     // Set<String> from a specific field
.toMap()               // Map<Id, SObject>
.toMap(keyField)       // Map<String, SObject> by a field
.toAggregatedMap(field)// Map<String, List<SObject>> grouped by field
.doExist()             // Boolean existence check
.toQueryLocator()      // For batch Apex
.toInteger()           // COUNT result
.toAggregated()        // List<AggregateResult>
.toAggregatedProxy()   // List<SOQL.AggregateResultProxy>
```

#### Security Modes

- **User mode** (default for inline `SOQL.of()`) — enforces FLS and sharing rules
- **System mode** with `.systemMode()` — bypasses FLS, still respects sharing by default
- Control sharing explicitly: `.withSharing()`, `.withoutSharing()`
- Configure defaults in the selector constructor

#### Mocking in Tests

Tag queries with `.mockId()` and mock results in tests — no DML or `@TestSetup` needed for the queried data.

```apex
// In production code
public List<Account> getPartnerAccounts(String name) {
    return SOQL_Account.query()
        .whereAre(SOQL.Filter.name().contains(name))
        .mockId('AccountService.getPartnerAccounts')
        .toList();
}

// In test class
@IsTest
static void getPartnerAccounts() {
    List<Account> mockAccounts = new List<Account>{
        new Account(Name = 'Test 1'),
        new Account(Name = 'Test 2')
    };
    SOQL.mock('AccountService.getPartnerAccounts').thenReturn(mockAccounts);

    AccountService service = new AccountService();

    Test.startTest();
    List<Account> result = service.getPartnerAccounts('Test');
    Test.stopTest();

    Assert.areEqual(2, result.size());
}
```

### DML Lib (Unit of Work)

All DML operations use the [DML Lib](https://dml.beyondthecloud.dev/) fluent API. **Never use raw `insert`/`update`/`delete` statements.** The library handles transaction batching, relationship resolution, FLS enforcement, and sharing automatically.

#### Basic Operations

```apex
// Batch multiple operations — executes on commitWork()
new DML()
    .toInsert(account)
    .toInsert(DML.Record(contact).withRelationship(Contact.AccountId, account))
    .toUpdate(existingCase)
    .commitWork();

// Immediate execution (returns OperationResult)
DML.OperationResult result = new DML()
    .insertImmediately(account);
```

#### Available Operations

| Batched (commitWork) | Immediate | Purpose |
|---|---|---|
| `.toInsert()` | `.insertImmediately()` | Insert records |
| `.toUpdate()` | `.updateImmediately()` | Update records |
| `.toUpsert()` | `.upsertImmediately()` | Upsert records |
| `.toDelete()` | `.deleteImmediately()` | Delete records |
| `.toUndelete()` | `.undeleteImmediately()` | Undelete records |
| `.toPublish()` | `.publishImmediately()` | Publish platform events |

#### Relationship Handling

Parent-child IDs are resolved automatically — register in any order.

```apex
Account account = new Account(Name = 'Acme Corp');
Contact contact = new Contact(LastName = 'Smith');

new DML()
    .toInsert(account)
    .toInsert(DML.Record(contact).withRelationship(Contact.AccountId, account))
    .commitWork();
// contact.AccountId is auto-populated after account insert
```

#### Dynamic Field Assignment

```apex
// Single record
new DML()
    .toInsert(DML.Record(contact).with(Contact.Email, 'john@example.com'))
    .commitWork();

// Multiple records — set a field on all
new DML()
    .toInsert(DML.Records(contacts).with(Contact.LeadSource, 'Web'))
    .commitWork();
```

#### Transaction Safety

```apex
// commitWork() — no savepoint, standard DML behavior
new DML()
    .toInsert(account)
    .toUpdate(contact)
    .commitWork();

// commitTransaction() — sets a savepoint, rolls back ALL on any failure
new DML()
    .toInsert(account)
    .toUpdate(contact)
    .commitTransaction();

// Partial success — failed rows don't commit, successful rows do
new DML()
    .toInsert(accounts)
    .allowPartialSuccess()
    .commitWork();

// Duplicate handling — merge duplicate registrations instead of erroring
new DML()
    .toUpdate(record1)
    .toUpdate(record2)  // same Id as record1
    .combineOnDuplicate()
    .commitWork();
```

#### Security Modes

```apex
// User mode (default) — enforces FLS and sharing
new DML().toInsert(account).commitWork();

// System mode — bypasses FLS (use with caution)
new DML().toInsert(account).systemMode().commitWork();

// System mode + explicit sharing control
new DML().toInsert(account).systemMode().withSharing().commitWork();
new DML().toInsert(account).systemMode().withoutSharing().commitWork();
```

#### Mocking in Tests

Mock DML operations to avoid database hits in unit tests.

```apex
// In production code — tag with mockId
public void createAccounts(List<Account> accounts) {
    new DML()
        .toInsert(accounts)
        .mockId('AccountService.createAccounts')
        .commitWork();
}

// In test class
@IsTest
static void createAccounts() {
    // Mock all inserts (no database hit)
    DML.mock('AccountService.createAccounts').allInserts();

    AccountService service = new AccountService();

    Test.startTest();
    service.createAccounts(new List<Account>{
        new Account(Name = 'Test 1')
    });
    Test.stopTest();

    // Retrieve results
    DML.Result result = DML.retrieveResultFor('AccountService.createAccounts');
    DML.OperationResult opResult = result.insertsOf(Account.SObjectType);
    Assert.isFalse(opResult.hasFailures());
}

// Mock to simulate failures
DML.mock('identifier').exceptionOnInserts();
DML.mock('identifier').exceptionOnInsertsFor(Account.SObjectType);
```

### UniversalMocker (Test Stubs)

Use [UniversalMocker](https://github.com/surajp/universalmock) to create test stubs via the Apex Stub API. This is the project's standard mocking framework — use it whenever you need to mock a class dependency in tests.

#### Basic Setup

```apex
// Create mock, define return values, generate stub
UniversalMocker mockInstance = UniversalMocker.mock(PaymentService.class);
mockInstance.when('charge').thenReturn(true);
mockInstance.when('refund').thenThrow(new PaymentException('declined'));

PaymentService stub = (PaymentService) mockInstance.createStub();
```

#### Overloaded Methods

Use `.withParamTypes()` when the mocked class has overloaded methods.

```apex
mockInstance.when('getAccount').withParamTypes(new List<Type>{ Id.class })
    .thenReturn(mockAccount);
```

#### Sequential Return Values

```apex
// Return mockAccount1 for the first 2 calls, then mockAccount2 for all subsequent
mockInstance.when('getAccount')
    .thenReturnUntil(2, mockAccount1)
    .thenReturn(mockAccount2);
```

#### Verification

```apex
// Assert exact call count
mockInstance.assertThat().method('charge').wasCalled(1);

// Assert range
mockInstance.assertThat().method('charge').wasCalled(1, UniversalMocker.Times.OR_MORE);

// Assert never called
mockInstance.assertThat().method('refund').wasNeverCalled();
```

#### Inspecting Arguments

```apex
// Get the value of a parameter passed to the Nth invocation
Object acctArg = mockInstance.forMethod('doInsert')
    .andInvocationNumber(0)
    .getValueOf('acct');
```

### Instance Provider (Dependency Injection)

Use [InstanceProvider](https://github.com/bluez-io/instance-provider) for dependency injection in services and handlers. **Never directly instantiate service dependencies** — use `InstanceProvider.provide()` so they can be mocked in tests.

```apex
// Production code — resolve dependency via provider
public class InvoiceService {
    private final PaymentService paymentService;

    public InvoiceService() {
        this.paymentService = (PaymentService) InstanceProvider.provide(PaymentService.class);
    }
}

// Test code — inject a mock
@IsTest
static void shouldProcessInvoice() {
    UniversalMocker paymentMock = UniversalMocker.mock(PaymentService.class);
    paymentMock.when('charge').thenReturn(true);
    InstanceProvider.injectMock(PaymentService.class, paymentMock.createStub());

    // InvoiceService now uses the mock PaymentService
}
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

**Unit test everything. Mock all dependencies.** Tests should never hit the database or depend on org state. This keeps tests fast, isolated, and deterministic.

- Class naming: `{ClassName}Test.cls`
- Minimum **95% coverage** per class
- Test scenarios: positive, negative, bulk (200+ records), edge cases
- Use `Test.startTest()` / `Test.stopTest()` around the operation under test
- Never use `@SeeAllData=true`
- Never use `@TestSetup` — all data should be constructed in-memory via mocks

#### Mocking Strategy

Every dependency is mocked at its boundary. The three mocking tools each cover a different layer:

| Layer | Tool | What it mocks |
|---|---|---|
| SOQL queries | `SOQL.mock('id').thenReturn(records)` | Query results — no database read |
| DML operations | `DML.mock('id').allInserts()` | Database writes — no DML executed |
| Class dependencies | `InstanceProvider.injectMock()` + `UniversalMocker` | Service/selector instances |

#### Full Unit Test Example

```apex
@IsTest
private class InvoiceServiceTest {

    @IsTest
    static void shouldCalculateTotalFromLineItems() {
        // 1. Mock SOQL — return in-memory records
        List<InvoiceLineItem__c> mockLines = new List<InvoiceLineItem__c>{
            new InvoiceLineItem__c(Amount__c = 100),
            new InvoiceLineItem__c(Amount__c = 250)
        };
        SOQL.mock('InvoiceService.getLineItems').thenReturn(mockLines);

        // 2. Mock DML — no database writes
        DML.mock('InvoiceService.updateInvoice').allUpdates();

        // 3. Mock class dependency via InstanceProvider
        UniversalMocker taxMock = UniversalMocker.mock(TaxService.class);
        taxMock.when('calculateTax').thenReturn(35.00);
        InstanceProvider.injectMock(TaxService.class, taxMock.createStub());

        // 4. Execute
        InvoiceService service = new InvoiceService();

        Test.startTest();
        Decimal total = service.calculateTotal(invoiceId);
        Test.stopTest();

        // 5. Assert
        Assert.areEqual(385.00, total, 'Total should be line items + tax');

        // 6. Verify interactions
        taxMock.assertThat().method('calculateTax').wasCalled(1);
    }
}
```

#### Test Guidelines

- **One concern per test method** — test a single behavior, not an entire flow
- **Name tests descriptively**: `shouldDoXWhenY`, `shouldThrowWhenInvalidInput`
- **Construct SObjects in-memory** — `new Account(Name = 'Test')` without insert
- **Mock at the boundary** — mock the direct dependency, not its transitive dependencies
- **Verify interactions** — use `UniversalMocker.assertThat()` to confirm methods were called with expected frequency
- **No test utility classes that insert records** — if a test needs data, build it inline or mock the query

### LWC Jest Tests

- Test file: `{componentName}/__tests__/{componentName}.test.js`
- Mock wire adapters and Apex calls
- Test rendering, user interactions, and error states

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
