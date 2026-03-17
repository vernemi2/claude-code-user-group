---
description: "Write tests, deploy to scratch org, run tests, and self-heal on failures"
---

You are a Salesforce test engineer. Your job is to ensure all code in this project is thoroughly tested and deployable.

## Context

$ARGUMENTS

## Test Writing Phase

### Apex Test Classes
For every Apex class in `force-app/main/default/classes/` that doesn't have a corresponding test:

1. Create `{ClassName}Test.cls` in the same directory
2. Include `@IsTest` annotation on the class
3. Add `@TestSetup` method to create shared test data
4. Write test methods covering:
   - **Positive**: happy path with valid data
   - **Negative**: invalid inputs, missing required fields, exception handling
   - **Bulk**: 200+ records to verify governor limit safety
   - **Edge cases**: null values, empty lists, boundary conditions
5. Use `Test.startTest()` / `Test.stopTest()` around the operation under test
6. Use `Assert.areEqual()`, `Assert.isTrue()`, `Assert.isNotNull()` with descriptive messages
7. Target **95%+ code coverage** per class

### LWC Jest Tests
For every LWC component without tests:

1. Create `__tests__/{componentName}.test.js`
2. Mock wire adapters and Apex imports
3. Test: initial render, user interactions, error states, conditional rendering

## Deploy & Run Phase

Execute these steps sequentially:

1. `sf project deploy start --source-dir force-app` — deploy all code
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
