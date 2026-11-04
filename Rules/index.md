---
type: Data Index
title: Rules index
description: Index of the Rules folder — the always-applied working rules and the SQL style rules.
tags: [index, rules]
timestamp: 2026-11-04
---

# Rules — index

- [00-core.md](00-core.md) — **Part A, how to work.** Imported by `CLAUDE.md`, so it is in context
  from the start of every session: session requirement capture and the decision log (A0), execution
  safety and the never-run-SQL rule (A1), where files go (A2), chat vs file (A3), append (A4),
  sheets (A5), the `ew-db` edit scope and schema checks (A6), start simple (A7), show diffs (A8),
  no publish calls in handed-off scripts (A9).
- [10-sql-style.md](10-sql-style.md) — **Part B, how to write SQL.** Load for any task that writes
  SQL: temp tables not CTEs (B1), no `DECLARE` variables (B2), NOLOCK (B3), headers (B4), images
  (B5), TransactionID (B6), updates (B7), staging `tblWatch` (B8), matching on ids (B9), the
  `IsDeleted` scope (B10), no `DISTINCT` in a windowed aggregate (B11).

Facts about the data are **not** rules — they live in [../Knowledge/index.md](../Knowledge/index.md).

Keep what is auto-loaded small: `CLAUDE.md` plus `00-core.md` should stay near 200 lines, because
adherence falls as that block grows. If Part A outgrows it, move the lower-traffic rules into the
playbooks that need them rather than letting the file sprawl.

Recurring corrections are promoted here from
[../Feedback/session-corrections-log.md](../Feedback/session-corrections-log.md) via the
`retro-feedback` skill — never without the user's go-ahead.
