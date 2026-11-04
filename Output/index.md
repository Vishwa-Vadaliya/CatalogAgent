---
type: Data Index
title: Output index
description: Everything the agent produces — queries, plans, documents, data exports and reports — seeded with the team's existing work.
tags: [index, output, queries, plans, reports]
timestamp: 2026-11-04
---

# Output — index

Everything the agent produces lands here, alongside the work the team had already done. Old and new
sit in the same folders on purpose: past queries are the best guide to how the next one should look.

| Folder | What goes in it |
|---|---|
| [Queries/](Queries/index.md) | `.sql` files only, under `<Person>/<Brand or topic>/`. `Ravi`, `Vishva`, `Janvi` — detected from `git config user.name`. |
| [Plans/](Plans/index.md) | Plan documents, under `<owner>/` — `janvi`, `ravi`, `vishwa`. |
| `Documents/` | Written guides, notes and analyses produced by the agent. |
| `Data/` | Data exports (`.csv`). |
| [Reports/](Reports/index.md) | Finished reports and write-ups. |

## Rules for this folder

- `Queries/` holds **only** `.sql`. A note about a query goes in `Documents/`, not next to it.
- Save in the most relevant existing subfolder; don't drop files in a person's folder root when a
  fitting subfolder exists. If none fits, ask before creating one.
- Brand-specific queries go in a folder named after the brand — create it without asking.
- Never put a query file in `Feedback/`.
- Short queries (3–4 lines) stay in the chat reply and get no file at all.

Full detail: A2 in [../Rules/00-core.md](../Rules/00-core.md) and
[../Playbooks/OUTPUT.md](../Playbooks/OUTPUT.md).

## Seeded content

This folder came pre-filled from the original EWScripts repo: 67 saved queries across the three
people's folders, 11 plan documents, and one finished report. Their folder structure was kept as it
was.
