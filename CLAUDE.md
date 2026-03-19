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

One trigger per object, delegating to a handler class:

- Trigger: `{Object}Trigger.trigger` in `force-app/main/default/triggers/`
- Handler: `{Object}TriggerHandler.cls` in `force-app/main/default/classes/`

```apex
// Trigger - thin, only delegates
trigger AccountTrigger on Account(before insert, before update, after insert, after update) {
    new AccountTriggerHandler().run();
}
```

### Service Layer

Business logic lives in `{Feature}Service.cls` classes. Services are stateless with static methods.

### Selector Pattern

SOQL queries isolated in `{Object}Selector.cls` classes. Never write SOQL inline in services or handlers.

### Hard Rules

- **No SOQL or DML inside loops** — ever
- **Bulk-safe**: all code must handle 200+ records
- **No hardcoded record IDs**
- **Use `WITH SECURITY_ENFORCED`** on all SOQL queries for FLS enforcement
- **Use `Assert` class** (not legacy `System.assert`): `Assert.areEqual(expected, actual, 'message')`

## LWC Conventions

- Component naming: `camelCase` directory (e.g., `overdueInvoiceBanner`)
- Use `@wire` for data reads, `lightning/uiRecordApi` for CRUD
- Use `lightning-record-*` base components where possible
- `@api` for public properties, reactive tracking is automatic (no `@track` needed)
- Import Apex methods with `@salesforce/apex/{ClassName}.{methodName}`

## Test Conventions

### Apex Tests

- Class naming: `{ClassName}Test.cls`
- Minimum **95% coverage** per class
- Always use `@TestSetup` for shared test data
- Test scenarios: positive, negative, bulk (200+ records), edge cases
- Use `Test.startTest()` / `Test.stopTest()` around the operation under test
- Never use `@SeeAllData=true`

### LWC Jest Tests

- Test file: `{componentName}/__tests__/{componentName}.test.js`
- Mock wire adapters and Apex calls
- Test rendering, user interactions, and error states

## Project Structure

```
force-app/main/default/
├── classes/         # Apex classes + test classes
├── triggers/        # One trigger per object
├── lwc/             # Lightning Web Components
├── objects/         # Custom objects and fields
├── permissionsets/  # Permission sets
├── layouts/         # Page layouts
├── flexipages/      # Lightning record/app pages
└── tabs/            # Custom tabs
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
