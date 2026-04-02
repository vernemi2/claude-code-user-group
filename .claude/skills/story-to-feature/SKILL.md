---
name: story-to-feature
description: "Autonomous pipeline: user story → production-ready Salesforce feature. Architects, implements, tests, validates in the browser, reviews, and commits."
argument-hint: "<user story description>"
allowed-tools: "Agent, TodoWrite, Bash, Read, Write, Edit, Glob, Grep"
---

You are an autonomous Salesforce development pipeline. Take the user story below and deliver a complete, tested, code-reviewed feature with zero human intervention.

## User Story

$ARGUMENTS

## Pipeline Execution

Execute each phase sequentially. Each phase's output feeds into the next.

### Phase 0: Feature Branch

Create a feature branch from `main` before any work begins:

1. Ensure working tree is clean (`git status`). If not, stop and inform the user.
2. Fetch latest: `git fetch origin main`
3. Create and checkout a feature branch: `git checkout -b feature/<short-kebab-description> origin/main`
   - Derive the branch name from the user story (e.g., `feature/overdue-invoice-banner`, `feature/account-contact-validation`)
   - Keep it short, lowercase, kebab-case

### Phase 1: Story Grilling (optional but recommended)

Before designing anything, stress-test the user story for ambiguities, edge cases, and missing requirements. Act as a relentless interviewer:

- Walk through each branch of the design decision tree
- Identify assumptions that need validating
- For each question, provide your recommended answer
- If a question can be answered by exploring the codebase, explore the codebase instead
- Resolve all open questions before moving to architecture

This prevents rework by catching gaps early — before any code is written.

### Phase 2: Architecture & Planning

Launch an Agent (subagent_type: "Plan") to analyze the user story and design the solution:

- Identify all Salesforce artifacts needed (objects, fields, triggers, services, selectors, LWC components, permissions, layouts, flexipages)
- Read existing code in force-app/main/ to understand what already exists
- Design the technical approach following CLAUDE.md conventions (trigger handler pattern, service layer, selector pattern)
- Output a structured architecture document listing every file to create/modify with its purpose
- Break the implementation into ordered tasks with dependencies

After the agent returns, create a TodoWrite task list from the plan.

### Phase 3: Implementation

Execute the implementation plan. Use parallel Agent calls where tasks are independent:

**Metadata first** (if custom objects/fields are needed):

- Custom objects and fields (XML metadata)
- Permission sets
- Layouts and flexipages
- Tabs

**Then code** (can parallelize across layers):

- Agent 1: Apex triggers + handler classes
- Agent 2: Apex service + selector classes
- Agent 3: LWC components (JS + HTML + CSS + XML meta)

Each agent must follow CLAUDE.md conventions strictly. Mark each task complete as you finish it.

### Phase 4: Testing

Launch an Agent to handle the full test cycle:

1. Write Apex test classes for every new Apex class (95%+ coverage target)
2. Write Jest tests for every new LWC component
3. Deploy to org: `sf project deploy start --source-dir force-app/main --source-dir force-app/test`
4. Run Apex tests: `sf apex run test --test-level RunLocalTests --result-format human --wait 10`
5. Run Jest: `npm run test:unit`
6. **Self-healing loop** (max 3 iterations): if anything fails, read the error output, fix the code, redeploy, and rerun

### Phase 5: UI Validation

Validate in the browser using Chrome (Claude in Chrome extension must be connected — run `/chrome` if needed):

1. Get the org URL via `sf org open --url-only` (includes session token for auto-login)
2. Open a new Chrome tab and navigate to the org URL
3. Walk through the user story as an end user would
4. Take screenshots and record a GIF of the flow as evidence
5. Check browser console for errors
6. If validation fails: fix the issue, redeploy, and revalidate

### Phase 6: Code Review & Ship

Launch an Agent to review and finalize:

1. Review all changed files against CLAUDE.md standards — check for:
   - SOQL/DML in loops
   - Missing bulk handling
   - Hardcoded IDs
   - Raw SOQL/DML instead of SOQL Lib / DML Lib
   - Static methods instead of InstanceProvider
   - Test coverage gaps
   - LWC best practices
2. Fix any issues found
3. Run `npm run prettier` to format everything
4. Create a descriptive git commit
5. Push the feature branch and open a PR against `main`

## Rules

- Make autonomous decisions — do not ask for human input
- If something fails after 3 retries, document the issue as a code comment and move on
- Log key decisions as you go so the human can review your reasoning afterward
- Prioritize working code over perfect code — iterate later
