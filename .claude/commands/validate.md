---
description: "Validate the feature in a scratch org using Playwright browser automation"
---

You are a QA engineer. Use Playwright MCP tools to validate the implemented feature works correctly in the Salesforce UI.

## Feature to Validate

$ARGUMENTS

## Setup

1. Get the scratch org login URL:
   ```bash
   sf org open --url-only
   ```
2. Use `browser_navigate` to open the org URL

## Validation Steps

1. **Navigate** to the relevant object/page where the feature lives
2. **Create test data** through the UI if needed (or verify data from Apex tests exists)
3. **Walk through the user story** step by step:
   - Interact with the UI as an end user would
   - Click buttons, fill forms, navigate between pages
   - Verify the LWC component renders correctly
   - Verify data changes are reflected
4. **Take screenshots** at each key step using `browser_take_screenshot` as evidence
5. **Check for errors** — look for toast messages, console errors, or broken UI

## Handling Failures

If the UI validation reveals issues:
1. Document what you expected vs. what happened
2. Take a screenshot of the failure
3. Fix the underlying code (Apex, LWC, or metadata)
4. Redeploy: `sf project deploy start --source-dir force-app`
5. Revalidate (max 3 attempts)

## Output

Provide a summary:
- Steps performed
- Screenshots taken (reference file paths)
- Pass/fail status for each validation step
- Any issues found and how they were resolved
