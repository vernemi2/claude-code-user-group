---
name: validate
description: "Validate the feature in the org using Playwright browser automation — navigates the Salesforce UI, tests the user story end-to-end, captures screenshots and console output."
argument-hint: "<feature or user story to validate>"
allowed-tools: Bash Write mcp__plugin_playwright_playwright__browser_navigate mcp__plugin_playwright_playwright__browser_snapshot mcp__plugin_playwright_playwright__browser_click mcp__plugin_playwright_playwright__browser_type mcp__plugin_playwright_playwright__browser_fill_form mcp__plugin_playwright_playwright__browser_select_option mcp__plugin_playwright_playwright__browser_press_key mcp__plugin_playwright_playwright__browser_hover mcp__plugin_playwright_playwright__browser_wait_for mcp__plugin_playwright_playwright__browser_take_screenshot mcp__plugin_playwright_playwright__browser_console_messages mcp__plugin_playwright_playwright__browser_network_requests mcp__plugin_playwright_playwright__browser_evaluate mcp__plugin_playwright_playwright__browser_tabs mcp__plugin_playwright_playwright__browser_close
---

You are a QA engineer. Use the Playwright MCP browser tools to validate the implemented feature works in the Salesforce UI.

## Feature to Validate

$ARGUMENTS

## Setup

1. Get the org login URL (includes the session token, so Playwright's fresh browser can auto-login):
   ```bash
   sf org open --url-only
   ```
2. Use `browser_navigate` to open that URL.
3. Use `browser_wait_for` / `browser_snapshot` until Lightning Experience has finished loading.

## Validation Steps

1. **Navigate** to the relevant object/page where the feature lives (`browser_navigate`).
2. **Create test data** through the UI if needed (`browser_fill_form`, `browser_click`) — or verify data already present.
3. **Walk through the user story** step by step:
   - Interact as an end user would (`browser_click`, `browser_type`, `browser_select_option`, `browser_press_key`, `browser_hover`).
   - Use `browser_snapshot` between actions to orient yourself — it gives you the accessibility tree and stable element refs.
   - Verify the LWC component renders correctly.
   - Verify data changes are reflected on screen.
4. **Capture screenshots** at each key step via `browser_take_screenshot`.
5. **Check for errors** — `browser_console_messages` for JS errors, `browser_network_requests` for failed API calls, plus watch for Salesforce toast messages in the UI.

GIF capture isn't natively supported by Playwright MCP. A sequence of screenshots is the pragmatic substitute.

## Handling Failures

If validation reveals issues:

1. Document expected vs. actual.
2. Take a failure screenshot.
3. Fix the underlying code (Apex, LWC, or metadata).
4. Redeploy: `sf project deploy start --source-dir force-app/main --source-dir force-app/test`.
5. Re-run the validation flow (max 3 attempts).

## Cleanup

Call `browser_close` when done so the Playwright browser instance is released.

## Persist the artifact

Write a summary to `docs/features/<slug>/04-validation.md` before calling `browser_close`:

```bash
SLUG=$(git rev-parse --abbrev-ref HEAD | sed 's|^feature/||')
mkdir -p "docs/features/$SLUG"
```

Save screenshots to `docs/features/$SLUG/screenshots/` and reference them from the markdown.

## Output

The `docs/features/$SLUG/04-validation.md` file should include:

- Steps performed
- Screenshots captured (list file paths under `screenshots/`)
- Pass/fail status per step
- Console / network errors observed
- Any issues found and how they were resolved
