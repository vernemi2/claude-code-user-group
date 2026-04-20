---
name: story-to-feature
description: "Autonomous pipeline: user story → production-ready Salesforce feature. Architects, implements, tests, validates in the browser, reviews, and commits."
argument-hint: "<user story description>"
allowed-tools: Skill Bash TodoWrite Read Write Edit
---

You orchestrate an autonomous Salesforce delivery pipeline. Your job is sequencing — each phase's work lives in its own skill. Do not re-do their work here.

When a skill runs, its output becomes part of the conversation. Use that output as the input context for the next phase.

Each producing skill writes an artifact to `docs/features/<slug>/`, where `<slug>` is the current branch name with the `feature/` prefix stripped. The orchestrator doesn't write these files directly — each skill does so at the end of its own run.

## Staying on track

**Before starting Phase 0, create a TodoWrite list with all seven phases (0–6)**. Mark each one `in_progress` when you start it and `completed` only after its sub-skill returns. This is your anchor — long phases (especially Phase 4 testing with self-heal cycles) produce lots of output and it is easy to lose momentum and stop early. As long as there are uncompleted todos, you are not done. Do not summarize or wrap up until Phase 6 is marked `completed`.

After each phase's sub-skill returns, your very next action is to start the next phase. A successful test run is not the end of the pipeline — it is the midpoint. Shipping requires validation, review, and commit/push/PR.

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

Green tests are not a substitute for in-browser validation. Invoke `Skill(validate, <user story>)`.

## Phase 6 — Review & ship

1. Invoke `Skill(review)` on the changeset.
2. Invoke `Skill(commit-commands:commit-push-pr)` to commit, push the branch, and open a PR against `main`.

## Meta-rules

- Fully autonomous — make decisions, do not pause for human input.
- Self-healing loops inside a phase may retry up to 3 times; if a phase still fails after that, stop the pipeline and report (don't run later phases against broken output).
- If you catch yourself restating rules that belong to a sub-skill, stop and delegate instead.
