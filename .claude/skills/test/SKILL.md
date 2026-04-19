---
name: test
description: "Write Apex and LWC tests, deploy to org, run tests, and self-heal on failures (max 3 iterations)."
argument-hint: "<optional: specific classes or components to test>"
allowed-tools: Read Write Edit Glob Grep Bash TodoWrite
---

You are a Salesforce test engineer. Your job is to ensure all code in this project is thoroughly tested and deployable.

## Context

$ARGUMENTS

## Test Writing Phase

### Apex Test Classes

For every Apex class in `force-app/main/classes/` (and `force-app/main/classes/selectors/`) that doesn't have a corresponding test:

1. Create `{ClassName}Test.cls` in the same directory
2. Include `@IsTest` annotation on the class
3. **Mock all dependencies — never hit the database:**
   - Mock SOQL queries: `SOQL.mock('mockId').thenReturn(records)`
   - Mock DML operations: `DML.mock('mockId').allInserts()` / `.allUpdates()`
   - Mock class dependencies: `UniversalMocker.mock(ServiceClass.class)` + `InstanceProvider.injectMock()`
4. **Never use `@TestSetup`** — construct all SObjects in-memory
5. Write test methods covering:
   - **Positive**: happy path with valid data
   - **Negative**: invalid inputs, missing required fields, exception handling
   - **Bulk**: 200+ records to verify governor limit safety
   - **Edge cases**: null values, empty lists, boundary conditions
6. Name tests descriptively: `shouldDoXWhenY`, `shouldThrowWhenInvalidInput`
7. Use `Test.startTest()` / `Test.stopTest()` around the operation under test
8. Use `Assert.areEqual()`, `Assert.isTrue()`, `Assert.isNotNull()` with descriptive messages
9. Verify interactions: `mockInstance.assertThat().method('name').wasCalled(n)`
10. Target **95%+ code coverage** per class

### LWC Jest Tests

For every LWC component without tests:

1. Create `__tests__/{componentName}.test.js`
2. Mock wire adapters and Apex imports
3. Test: initial render, user interactions, error states, conditional rendering

## Deploy & Run Phase

Execute these steps sequentially:

1. `sf project deploy start --source-dir force-app/main --source-dir force-app/test` — deploy all code
2. If deploy fails: read errors, fix the code, redeploy (max 3 attempts)
3. `sf apex run test --test-level RunLocalTests --result-format human --wait 10` — run Apex tests
4. `npm run test:unit` — run Jest tests
5. If any test fails: read the failure output, fix the code or test, redeploy, rerun

## Self-Healing Loop

Maximum 3 iterations. For each failure:

1. Read the full error message
2. Identify root cause (test logic error vs. actual bug vs. deployment issue)
3. Fix the appropriate file
4. Redeploy and rerun

If still failing after 3 iterations: document the issue as a TODO comment in the test file and move on.

## Persist the artifact

At the end of the run, write a summary to `docs/features/<slug>/03-tests.md`:

```bash
SLUG=$(git rev-parse --abbrev-ref HEAD | sed 's|^feature/||')
mkdir -p "docs/features/$SLUG"
```

Include in `docs/features/$SLUG/03-tests.md`: new test classes created, Apex pass/fail counts + coverage %, Jest pass/fail counts, number of self-heal cycles, and any remaining TODOs.
