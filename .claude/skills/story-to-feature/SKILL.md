---
name: story-to-feature
description: "Autonomous pipeline: user story → production-ready Salesforce feature. Architects, implements, tests, validates in the browser, reviews, and commits."
argument-hint: "<user story description>"
allowed-tools: Skill Bash TodoWrite Read Write Edit
---

You orchestrate an autonomous Salesforce delivery pipeline. Your job is sequencing — each phase's work lives in its own skill. Do not re-do their work here.

When a skill runs, its output becomes part of the conversation. Use that output as the input context for the next phase.

Each producing skill writes an artifact to `docs/features/<slug>/`, where `<slug>` is the current branch name with the `feature/` prefix stripped. The orchestrator doesn't write these files directly — each skill does so at the end of its own run.

## User Story

$ARGUMENTS

## Phase 0 — Feature branch

1. Verify working tree is clean (`git status`). If dirty, stop and report.
2. `git fetch origin main`
3. `git checkout -b feature/<short-kebab-description> origin/main` — derive the slug from the user story.

## Phase 1 — Self-grill the story (required)

Invoke `Skill(grill-me, "$ARGUMENTS")`. Use the resolved story from the output as the input to Phase 2.

## Phase 2 — Architecture

Invoke `Skill(architect, <resolved story>)`. Turn the returned plan into a TodoWrite list so the rest of the pipeline can track progress.

## Phase 3 — Implementation

Invoke `Skill(implement, <architecture plan>)`. Mark todos complete as items land.

## Phase 4 — Testing

Invoke `Skill(test, <list of new/changed Apex classes and LWCs>)`.

## Phase 5 — UI validation (required)

Do not skip this phase under any circumstance. Green tests are not a substitute for in-browser validation.

First verify that the Playwright MCP tools are available — check that `mcp__plugin_playwright_playwright__browser_navigate` (and siblings) are loaded. If they are not, stop the pipeline and report that Playwright MCP must be enabled before shipping. Do not proceed to review or commit.

Once confirmed, invoke `Skill(validate, <user story>)`.

## Phase 6 — Review & ship

1. Invoke `Skill(review)` on the changeset.
2. Invoke `Skill(commit-commands:commit-push-pr)` to commit, push the branch, and open a PR against `main`.

## Meta-rules

- Fully autonomous — make decisions, do not pause for human input.
- Self-healing loops inside a phase may retry up to 3 times; if a phase still fails after that, stop the pipeline and report (don't run later phases against broken output).
- If you catch yourself restating rules that belong to a sub-skill, stop and delegate instead.
