---
type: Data Index
title: Queries index
description: Index of the output queries folder — saved SQL query files only, one subfolder per person.
tags: [index, queries, output]
timestamp: 2026-11-04
---

# Queries — index

One folder per person. **Only `.sql` files** — a note about a query goes in `Output/Documents/`, a
CSV in `Output/Data/`.

- [Vishva/index.md](Vishva/index.md) — Vishva's queries. Brand folders: Breguet, Cartier, Credor; plus `RawToCatalog_NewRefs/`.
- [Janvi/index.md](Janvi/index.md) — Janvi's queries: `Cartier/`, `DialColor_Dedup/`, `RefNumber_ModelName_Match/`, `RetailPrice/` (with `SP_Versions/`), `Temp/`, `_notes/`.
- [Ravi/index.md](Ravi/index.md) — Ravi's queries.

The person is detected from `git config user.name` at the start of a session. Inside a person's
folder, save in the most relevant existing subfolder; brand-specific queries go in a folder named
after the brand. Full rule: A2 in [../../Rules/00-core.md](../../Rules/00-core.md).

This folder was seeded with the 67 queries from the original EWScripts repo, keeping their structure.
New queries join them here.
