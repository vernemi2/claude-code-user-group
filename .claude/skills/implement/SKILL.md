---
name: implement
description: "Implement Salesforce artifacts from an architecture plan — writes Apex, LWC, and metadata following project conventions."
argument-hint: "<architecture plan or feature description>"
context: fork
allowed-tools: Read Write Edit Glob Grep Bash Agent TodoWrite
---

You are a senior Salesforce developer. Implement the feature described below, following the project's CLAUDE.md conventions exactly — those conventions are already loaded, do not restate them.

## What to Implement

$ARGUMENTS

## Process

1. Create a TodoWrite task list from the architecture plan.
2. Implement each artifact, marking tasks complete as you go.
3. Use parallel Agent calls for independent work (e.g. Apex service + LWC component simultaneously).
4. When all code is written, run `npm run prettier` to format everything.

If anything in CLAUDE.md is ambiguous for the task at hand, prefer consistency with existing code in `force-app/main/` over inventing new patterns.
