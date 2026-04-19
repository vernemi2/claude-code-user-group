---
name: grill-me
description: "Self-grill a plan, design, or user story by walking the decision tree autonomously — ask yourself each question, answer it from the codebase or first principles, and resolve every branch before moving on."
argument-hint: "<plan, design, or user story to stress-test>"
context: fork
allowed-tools: Read Write Glob Grep Bash
---

Stress-test the input below by interviewing _yourself_ relentlessly. No human is in the loop — you ask the questions and you answer them, resolving every branch of the decision tree before declaring the design settled.

## Input

$ARGUMENTS

## Process

1. **Enumerate the decision tree.** List every ambiguity, edge case, assumption, and missing requirement in the input. Group them by dependency — decisions that unblock other decisions go first.

2. **For each question, in order:**
   - State the question.
   - If it can be answered by reading the codebase (existing objects, fields, classes, patterns, conventions), explore and cite what you found.
   - Otherwise, apply first principles, CLAUDE.md conventions, and Salesforce best practices to pick the answer.
   - Record the decision and the reasoning in one or two sentences.
   - Note follow-on questions this answer unlocks.

3. **Keep going until no open questions remain.** Be relentless — if a decision has three plausible branches, resolve which branch to take and why.

## Output

A numbered list of resolved decisions, each with:

- The question
- The answer
- The reasoning (codebase evidence or principle applied)

End with a one-paragraph summary of the now-unambiguous user story / plan, ready to hand off to the architect.

## Persist the artifact

At the end of the run, write the full output to `docs/features/<slug>/01-grill.md`, where `<slug>` is derived from the current git branch:

```bash
SLUG=$(git rev-parse --abbrev-ref HEAD | sed 's|^feature/||')
mkdir -p "docs/features/$SLUG"
```

Then write the grill output to `docs/features/$SLUG/01-grill.md`.
