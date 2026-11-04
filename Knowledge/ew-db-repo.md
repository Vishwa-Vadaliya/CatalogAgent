---
type: Knowledge Fact
title: ew-db project layout
description: Where tables, stored procedures, functions, views and triggers live inside the D:\EW\ew-db schema repo, for the schema check required before writing any query.
tags: [knowledge, ew-db, repo-layout, schema-check]
db: repo
keywords: [ew-db, MasterDB, EveryWatchDDL, schema, table DDL, routine, stored procedures folder, function, view, trigger, where is the table]
timestamp: 2026-11-04
---

# `ew-db` project layout (`D:\EW\ew-db`)

Read the relevant file here **before** writing or modifying any query, join or procedure — rule A6
in [../Rules/00-core.md](../Rules/00-core.md). The edit scope and the read-only areas are in that
same rule.

- **MasterDB (Catalog DB):** `D:\EW\ew-db\MasterDB\dbo\` — tables in `table\` (`tbl_CAT_*`, `tblUser`, etc.), stored procedures in `stored procedures\` (`sp_*`), functions in `function\` (`fn_*`).
- **EveryWatchDDL (App DB):** `D:\EW\ew-db\EveryWatchDDL\dbo\` — tables in `table\` (`tblWatch`, `tblReferenceNumber*`, `tbl_PAY_*`, `tbl_RE_*`, etc.), routines (SPs) in `routine\` (`usp_*`, `sp_*`), views in `view\` (`vw_*`), triggers in `trigger\` (`tr_*`).

## Reminders

- If a column or table is not found, say so explicitly — do not assume it exists.
- `EveryWatchDDL/` is read-only. Only `MasterDB/` may be edited, and only when the user explicitly asks for an `ew-db` change.
- One-time or deploy SQL goes in `Output/Queries/<Person>/…`, never in `ew-db`.
