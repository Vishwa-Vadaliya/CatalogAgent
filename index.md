---
type: Data Index
title: CatalogAgent bundle index
description: Agent-facing entry point — links to every folder's own index.
tags: [index, bundle-root, catalogagent, navigation]
timestamp: 2026-11-04
---

# CatalogAgent — bundle index

The EveryWatch catalog agent: rules, database knowledge, task playbooks, domain documents, skills
and the team's saved work. [README.md](README.md) is the human-facing guide.

This file is the agent-facing navigation entry point: it links to each folder's own `index.md` so an
agent can see what exists without opening every file.

## Start here on a task

1. [CLAUDE.md](CLAUDE.md) — loaded automatically; the run loop.
2. [Playbooks/ROUTER.md](Playbooks/ROUTER.md) — classify the task, open the right playbook.

## Folders

- [Rules/index.md](Rules/index.md) — how to work (always on) and how to write SQL.
- [Knowledge/index.md](Knowledge/index.md) — the database facts, by topic. **The lookup table.**
- [Playbooks/index.md](Playbooks/index.md) — the router, the contracts, one playbook per task type.
- [Documents/index.md](Documents/index.md) — deep background by domain.
- [Data/index.md](Data/index.md) — the Google Sheets index and reference CSVs.
- [PythonScripts/index.md](PythonScripts/index.md) — standalone scripts.
- [Templates/index.md](Templates/index.md) — the output formats.
- [Output/index.md](Output/index.md) — everything produced: queries, plans, documents, data, reports.
- [Skills/index.md](Skills/index.md) — the skills (they live in `.claude/skills/`).
- [Feedback/index.md](Feedback/index.md) — the corrections log.
- [Archive/index.md](Archive/index.md) — superseded material, kept for history.
- [PPT/index.md](PPT/index.md) — presentations (empty).

## The corrections log

[Feedback/session-corrections-log.md](Feedback/session-corrections-log.md) is the chronological,
append-only history of corrections. Recurring patterns get promoted into
[Rules/](Rules/index.md) or [Knowledge/](Knowledge/index.md) via the `retro-feedback` skill — never
without the user's go-ahead.
