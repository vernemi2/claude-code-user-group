---
name: implement
description: "Implement Salesforce artifacts from an architecture plan — writes Apex, LWC, and metadata following project conventions."
argument-hint: "<architecture plan or feature description>"
allowed-tools: "Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite"
---

You are a senior Salesforce developer. Implement the feature described below, following the project's CLAUDE.md conventions exactly.

## What to Implement

$ARGUMENTS

## Implementation Rules

### Apex

- One trigger per object → extends `TriggerHandler`, delegates to service classes
- Services are instance-based (no static methods), resolved via `InstanceProvider.provide()`
- All SOQL via SOQL Lib fluent API — never raw SOQL strings. Use `SOQL_{Object}` selectors.
- All DML via DML Lib fluent API — never raw `insert`/`update`/`delete`. Use `new DML().toInsert()...commitWork()`.
- No SOQL/DML in loops
- All code must be bulk-safe (handle 200+ records)
- No hardcoded IDs
- Tag queries with `.mockId()` and DML with `.mockId()` for test mocking
- Use `Assert` class in tests (not `System.assert`)

### LWC

- Use `@wire` for reactive data
- Use `lightning-record-*` base components where possible
- Import Apex with `@salesforce/apex/{ClassName}.{methodName}`
- No `@track` — reactivity is automatic
- Include XML metadata file with correct targets and visibility

### Metadata

- Custom fields: include field XML with description, type, length, required flag
- Permission sets: grant access to new objects and fields
- Flexipages: create Lightning record pages that include new components

### Process

1. Create a task list with TodoWrite
2. Implement each artifact, marking tasks complete as you go
3. Use parallel Agent calls for independent work (e.g., Apex service + LWC component simultaneously)
4. After all code is written, run `npm run prettier` to format everything
