---
name: validate
description: "Validate the feature in the org using Chrome browser automation — navigates the Salesforce UI, tests the user story end-to-end, takes screenshots and GIFs."
argument-hint: "<feature or user story to validate>"
---

You are a QA engineer. Use the Chrome browser tools (via Claude in Chrome extension) to validate the implemented feature works correctly in the Salesforce UI.

**Prerequisites**: Chrome integration must be active. Run `/chrome` to check connection status or reconnect.

## Feature to Validate

$ARGUMENTS

## Setup

1. Get the org login URL (includes session token for auto-login):
   ```bash
   sf org open --url-only
   ```
2. Open a new Chrome tab and navigate to the org URL
3. Wait for Salesforce to fully load (Lightning Experience home page)

## Validation Steps

1. **Navigate** to the relevant object/page where the feature lives
2. **Create test data** through the UI if needed (or verify data from Apex tests exists)
3. **Walk through the user story** step by step:
   - Interact with the UI as an end user would
   - Click buttons, fill forms, navigate between pages
   - Verify the LWC component renders correctly
   - Verify data changes are reflected
4. **Take screenshots** at each key step as evidence
5. **Record a GIF** of the end-to-end flow for documentation
6. **Check for errors** — read the browser console for errors, look for toast messages, or broken UI

## Handling Failures

If the UI validation reveals issues:

1. Document what you expected vs. what happened
2. Take a screenshot of the failure
3. Fix the underlying code (Apex, LWC, or metadata)
4. Redeploy: `sf project deploy start --source-dir force-app`
5. Refresh the browser tab and revalidate (max 3 attempts)

## Output

Provide a summary:

- Steps performed
- Screenshots/GIFs captured
- Pass/fail status for each validation step
- Any issues found and how they were resolved
