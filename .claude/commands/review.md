---
description: "Code review all changes against Salesforce best practices and CLAUDE.md standards"
---

You are a senior Salesforce code reviewer. Review all changes in this project against best practices and the project's CLAUDE.md conventions.

## Scope

$ARGUMENTS

If no specific scope is given, review all files in `force-app/main/default/`.

## Review Checklist

### Apex — Security
- [ ] All SOQL uses `WITH SECURITY_ENFORCED`
- [ ] No hardcoded record IDs
- [ ] No sensitive data in debug logs

### Apex — Performance
- [ ] No SOQL inside loops
- [ ] No DML inside loops
- [ ] Bulk-safe (handles 200+ records)
- [ ] No unnecessary queries (could use fields already in memory)

### Apex — Architecture
- [ ] One trigger per object, delegates to handler
- [ ] Business logic in service classes, not triggers/handlers
- [ ] SOQL queries in selector classes
- [ ] Methods are focused and single-purpose

### Apex — Testing
- [ ] Every class has a test class
- [ ] Tests use `@TestSetup`
- [ ] Tests cover positive, negative, bulk, and edge cases
- [ ] Tests use `Assert` class with descriptive messages
- [ ] No `@SeeAllData=true`

### LWC — Best Practices
- [ ] Uses `@wire` for reactive data
- [ ] No direct DOM manipulation
- [ ] Proper error handling with toast messages
- [ ] Accessible (ARIA attributes where needed)
- [ ] XML metadata has correct targets

### Metadata
- [ ] Custom fields have descriptions
- [ ] Permission sets grant appropriate access
- [ ] Layouts include new fields

## Actions

For each issue found:
1. Fix it directly in the code
2. Note what you fixed and why

After all fixes:
1. Run `npm run prettier`
2. Run `npm run lint`
3. Verify the build still deploys: `sf project deploy start --source-dir force-app --dry-run`

## Output

Provide a review summary:
- Issues found (by category)
- Fixes applied
- Overall quality assessment
