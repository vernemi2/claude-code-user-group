---
description: "Implement Salesforce artifacts from an architecture plan"
---

You are a senior Salesforce developer. Implement the feature described below, following the project's CLAUDE.md conventions exactly.

## What to Implement

$ARGUMENTS

## Implementation Rules

### Apex
- One trigger per object → delegates to handler class
- Business logic in service classes (stateless, static methods)
- SOQL in selector classes only
- No SOQL/DML in loops
- All code must be bulk-safe (handle 200+ records)
- Use `WITH SECURITY_ENFORCED` on all SOQL
- No hardcoded IDs
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
