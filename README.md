# The Developer Who Wasn't There

**Autonomous Salesforce Development with Claude Code**

What if you could hand Claude Code a user story and come back to a working, tested, code-reviewed feature? No babysitting. No copy-pasting. No "AI-assisted" — fully AI-driven.

This repo powers a live demo of a complete autonomous workflow: from user story to git commit. Specialized AI agents architect the solution, write Apex and LWC, generate unit tests, validate in the Salesforce UI with Chrome, run code review, and iterate until it's production-ready.

## The Pipeline

```
User Story
    │
    ▼
┌─────────────┐
│  /grill-me   │  Stress-test the story for gaps and edge cases
└──────┬──────┘
       ▼
┌─────────────┐
│  /architect  │  Design data model, Apex layers, LWC components
└──────┬──────┘
       ▼
┌─────────────┐
│  /implement  │  Write Apex, LWC, and metadata (parallel agents)
└──────┬──────┘
       ▼
┌─────────────┐
│  /test       │  Write tests → deploy → run → self-heal on failures
└──────┬──────┘
       ▼
┌─────────────┐
│  /validate   │  Chrome browser automation against the live org
└──────┬──────┘
       ▼
┌─────────────┐
│  /review     │  Code review against best practices → fix → commit
└──────┬──────┘
       ▼
  Git Commit
```

Or run the entire pipeline with a single command:

```
/story-to-feature As a sales rep, I want to see a warning banner on
Opportunity when the Account has overdue invoices
```

## How It Works

| Layer | What | Why |
|---|---|---|
| `CLAUDE.md` | Project brain | Coding standards, Apex patterns, SF CLI commands — Claude follows these autonomously |
| `.claude/skills/` | Specialized agents | Each pipeline phase is a skill with focused instructions |
| `.claude/hooks/` | Automated guardrails | Post-edit hooks catch Apex anti-patterns and lint LWC in real-time |
| `.claude/settings.json` | Hook configuration | Wires guardrails to file edit events |
| Chrome extension | UI validation | Claude controls a real Chrome browser to test the feature end-to-end |

## Skills

| Skill | Description |
|---|---|
| `/story-to-feature` | Master orchestrator — runs the full pipeline end-to-end |
| `/grill-me` | Relentlessly interviews you about a plan until every decision branch is resolved |
| `/architect` | Analyzes a user story and designs the Salesforce solution |
| `/implement` | Writes all Apex, LWC, and metadata from an architecture plan |
| `/test` | Writes tests, deploys, runs them, self-heals up to 3 iterations |
| `/validate` | Navigates Salesforce in Chrome to verify the feature works |
| `/review` | Reviews code against best practices, fixes issues, commits |

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) (`sf`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.0.73+
- [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) (for UI validation)
- A Salesforce Developer Edition org
- Node.js 18+

## Quick Start

```bash
# Clone the repo
git clone git@github.com:vernemi2/claude-code-user-group.git
cd claude-code-user-group

# Install dependencies
npm install

# Set your default org
sf config set target-org=claude-demo

# Launch Claude Code with Chrome
claude --chrome

# Run the full pipeline
/story-to-feature <your user story here>
```

## Salesforce Conventions

This project follows strict patterns enforced by CLAUDE.md and hooks:

- **Trigger Handler Pattern** — one trigger per object, delegates to handler class
- **Service Layer** — stateless business logic in `{Feature}Service.cls`
- **Selector Pattern** — SOQL isolated in `{Object}Selector.cls`
- **No SOQL/DML in loops** — enforced by post-edit hooks
- **FLS enforcement** — `WITH SECURITY_ENFORCED` on all queries
- **95% test coverage** — positive, negative, bulk, and edge cases
