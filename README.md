---
type: Document
title: CatalogAgent
description: Human-facing overview of CatalogAgent — what it is, how to start it, what each folder holds, and its relationship to the original EWScripts repo.
tags: [readme, overview, agent, catalogagent]
timestamp: 2026-11-04
---

# CatalogAgent

The EveryWatch catalog agent. It solves Jira tickets, enrichment corrections and reviews, retail
price work, and brand reference / raw-to-catalog work — using the team's own rules, database
knowledge and saved queries.

It **writes** SQL, documents and plans. It **never runs SQL** against a database. You run it.

## How to use it

Open a terminal in `D:\EW\CatalogAgent` and run `claude`. Then just say what you need:

```
ECH-409                            → fetches the ticket and routes it
the dial colour dedup for Cartier  → enrichment playbook
why is this ref not in production  → retail price playbook
/brand-ref-agent Breguet           → the full brand reference run
/image-match-review Piaget         → the per-brand image match review
/retro-feedback                    → turn recurring corrections into rules
```

The agent restates what it understood as numbered requirements before starting, and ends with a
decision log saying what each choice was based on.

## Folder guide

| Folder | What's in it |
|---|---|
| `CLAUDE.md` | The only file loaded automatically. Identity, the run loop, and an import of the core rules. |
| `Rules/` | `00-core.md` — how to work; always in context. `10-sql-style.md` — how to write SQL; loaded for SQL tasks. |
| `Knowledge/` | The database facts, one file per topic, with `index.md` as the lookup table. |
| `Playbooks/` | `ROUTER.md` plus one playbook per task type, and the output and MCP contracts. |
| `Documents/` | Deep background: Enrichment, RetailPrice, Brands, RawToCatalog. |
| `Data/` | `Sheets.md` (the Google Sheets index) and the reference CSVs. |
| `PythonScripts/` | `check_tilt.py`, `pick_best_image.py`, `prepare_review_sheet.py`. |
| `Templates/` | The requirement restatement, decision log, Jira comment and handoff note formats. |
| `Output/` | **Everything the agent produces** — `Queries/`, `Plans/`, `Documents/`, `Data/`, `Reports/`. Seeded with the team's existing work, so old and new sit together. |
| `Feedback/` | The corrections log: what went wrong, what you said, the right way. |
| `Archive/` | Superseded material kept for history only. |
| `.claude/skills/` | `brand-ref-agent`, `image-match-review`, `retro-feedback`. |
| `.claude/agents/` | Empty for now; subagents come later. |
| `PPT/` | Presentations. Empty. |

## Where does my file go?

- A SQL query → `Output/Queries/<your name>/<Brand or topic>/`. The agent detects the name from git.
- A written guide or note → `Output/Documents/`. A finished write-up → `Output/Reports/`.
- A plan → `Output/Plans/<owner>/`.
- A fact about a table or definition → the matching `Knowledge/` topic file.
- An instruction about how the agent should behave → `Rules/`.

## Working rules in short

- The agent never runs SQL. It writes the script; you run it in SSMS and paste results back.
  The one exception is a read-only `SELECT` through the everywatch MCP, and only after it shows you
  the exact query and you say yes — each time.
- Jira is read-only. Comments are drafted for you to post, never posted.
- Nothing in `D:\EW\ew-db` changes unless you explicitly ask. Only `MasterDB/` may be edited;
  `EveryWatchDDL/` is read-only.
- Each rule or fact lives in exactly one file, so nothing is repeated or contradicts itself.

## Relationship to EWScripts

This agent was built from `D:\EW\EWScripts` (CatalogBrain) and **is now the source of truth** for
the rules and the knowledge. Everything in EWScripts was carried across: the rules, the knowledge,
the documents, all 67 saved queries, the 11 plans, the report, the data files, the Python scripts
and the three skills.

**Write new rules and facts here, not there.** EWScripts stays in place as the original repo and as
history; the agent never writes to it.
