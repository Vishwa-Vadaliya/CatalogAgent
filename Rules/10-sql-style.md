---
type: Rule
title: SQL style rules
description: Part B — how to write SQL for EveryWatch: temp tables not CTEs, no DECLARE variables, NOLOCK, headers, images, TransactionID, updates, staging tblWatch, id matching, IsDeleted scope, windowed aggregates.
tags: [rules, sql, style]
timestamp: 2026-11-04
---

# SQL style rules

Load this file for any task that writes SQL. Always-applied working rules are in
[00-core.md](00-core.md); data facts are in [../Knowledge/index.md](../Knowledge/index.md).
These rules also apply to Python scripts that touch SQL.

## B1. Query structure

- **Temp tables, not CTEs.** Split every query into small steps, each one writing to a `#temp` table
  (`SELECT ... INTO #Step`). Do **not** use CTEs (`WITH x AS (...)`).
- Start each step with `DROP TABLE IF EXISTS #Step;` so the script can be re-run.
- **Indexes on temp tables** when later steps join or filter on them. Re-runnable scripts: drop
  indexes the script creates before recreating them.
- **Inspect from the temp table.** Do **not** put a `SELECT` after every step. Each step only fills
  its temp table (`INTO #Step`). The user reads the data at any step with `SELECT * FROM #Step` on
  their own. Only the **last** step returns a result set.
- **Large tables:** drive from the smallest filtered set, join name lookups only at the end.
  `TOP (N) … ORDER BY score DESC` when only top candidates are wanted.
- **Multi-value outputs** → distinct, comma-separated (STRING_AGG, cast to NVARCHAR(MAX)). Literal
  columns in `SELECT INTO` → cast to a wide enough type.

## B2. No `DECLARE` variables — independent steps

- Do **not** use `DECLARE @var` (thresholds, dates, ids, flags) at the top of a script. The user runs
  the steps **one by one**, and a variable declared at the start is gone when a single step is run
  on its own.
- Put every parameter or threshold in a small temp table instead, e.g.
  `DROP TABLE IF EXISTS #Params; SELECT 50.0 AS JumpPct, 90 AS PendingAgeDays INTO #Params;`, and
  read it in later steps with `CROSS JOIN #Params AS p`. A temp table survives between runs in the
  same session, so any step can be re-run independently.
- Make every step independent: it should depend only on earlier temp tables, never on a variable.
- If the user says "don't use declare variables", this rule applies without exception, including for
  dates and ids passed in from the request.
- **Every appended block re-resolves its own variables — never assume an earlier block already ran.**
  The user runs blocks in a file one at a time, not top-to-bottom, and often ran the earlier part in
  a previous session.
  - When a new block needs a value an earlier block computed (e.g. `@PP_ManufacturerId`, a resolved
    id, a looked-up name), do **not** reuse that earlier variable by name — re-resolve it inside the
    new block itself (its own `DECLARE` + `SELECT ... FROM ...`), so the block runs entirely alone.
  - This applies even though the same small lookup gets repeated across blocks — that repetition is
    the point. Applies to any variable, not just `TransactionID` (see B6).

## B3. NOLOCK

- Put `WITH (NOLOCK)` on every table read (SELECT, joins, INSERT…SELECT, DELETE join chains).
- Put it **after** the alias: `FROM dbo.tblX AS x WITH (NOLOCK)` and
  `INNER JOIN dbo.tblOther AS o WITH (NOLOCK) ON …`.
- Avoid legacy forms such as `FROM dbo.tbl WITH (NOLOCK) AS alias`; prefer `AS alias WITH (NOLOCK)`.
- Exception: no NOLOCK inside `UPDATE … FROM` (on the updated table or its joined sources).

## B4. Headers

- Start the file with a header block: purpose, DB, and the definitions/filters the user confirmed.
- Add a header comment above **every** temp-table step: step number, what the table holds, and its
  key filters or joins.

```sql
------------------------------------------------------------
-- 2. Open multiple-match candidate rows
--    tbl_RE_DataToFix.WatchId -> tblWatch_d (join via WatchListingDraftId)
------------------------------------------------------------
DROP TABLE IF EXISTS #MultipleEnrDetail;
SELECT ...
INTO #MultipleEnrDetail
FROM ...
```

## B5. Images — "take image" = the primary image only

- When the user says "take image", always take the **primary** image, `IsPrimary = 1`, in both
  databases, and in any other image table with `IsPrimary`. Table and column names:
  [../Knowledge/images.md](../Knowledge/images.md).
- Just filter `IsPrimary = 1` in a plain LEFT JOIN or temp-table step. There is always exactly one
  primary image, so don't dedupe with ROW_NUMBER, MAX, TOP 1 or OUTER APPLY.
- **Raw images** (`tbl_RAW_Media`) have no IsPrimary: there, the primary is the row with the lowest
  `orderIndex`.
- Check the image table's schema in `D:\EW\ew-db` before using its columns.

## B6. TransactionID

- When asked to "change the transaction ID" (or bump/refresh it) for a set of rows, get the new id
  from `dbo.sp_Create_Transaction @TransactionTypeID = <type>` (also called `usp_CreateTransaction`;
  2 = Update) — never hand-pick a number. Stamp that TransactionId on the updated rows.
- Capture it with one `DECLARE @NewTransactionID BIGINT`, placed **immediately above the query that
  uses it**, via the `@OutTransactionID` OUTPUT parameter directly — no intermediate table:

```sql
------------------------------------------------------------
-- 0. New TransactionID for this step (2 = Update)
------------------------------------------------------------
DECLARE @NewTransactionID BIGINT;
EXEC dbo.sp_Create_Transaction @TransactionTypeID = 2, @OutTransactionID = @NewTransactionID OUTPUT;   -- 2 = Update
```

This is a deliberate exception to B2 — the user asked for this pattern specifically.

- A script that changes the TransactionID at more than one point declares a fresh
  `@NewTransactionID` (new name if more than one is live at once, e.g. `@NewTransactionID2`) right
  before each point that needs one — don't reuse one capture for two unrelated updates.
- Caveat to flag when handing off a script using this pattern: because `@NewTransactionID` is a local
  variable, not a temp table, it only survives for one batch. The capture line and every step that
  reads the variable must be selected and run **together as a single execution** (no `GO` between
  them) — unlike the temp-table steps elsewhere, this part can't be split into separate runs.

## B7. Updates

- Preview `SELECT` with an action flag first.
- `BEGIN TRAN` with COMMIT/ROLLBACK commented out (or an `@Apply = 0/1` switch).
- Stamp a TransactionId (B6).
- No publish call in the handed-off script (A9).

## B8. `tblWatch` / `tblWatch_d` — stage first

- Whenever pulling data from the EveryWatch app database that involves `tblWatch` or `tblWatch_d`,
  stage the necessary columns into a local temp table (`#tblWatch` / `#temp`) first, then
  join/aggregate off the temp table.
- Do not join or filter directly against `tblWatch` / `tblWatch_d` inline in the main query.

## B9. Match on ids, not on the denormalized text columns

- `tblWatch` / `tblWatch_d` carries denormalized text copies next to the FK (e.g. `ReferenceNumber`
  next to `ReferenceNumberId`, `ManufactureName`/`RawManufacturer` next to `ManufacturerId`,
  `ModelName` next to `ModelId`). These text columns are not the source of truth and aren't reliably
  indexed for lookups.
- When a request comes in as text (a reference number, a manufacturer/model name), resolve it to its
  id **first** — one lookup against the owning table (`tblReferenceNumber.ReferenceNumber` +
  `ManufacturerId` → `ReferenceNumberId`; `tblManufacturer.ManufacturerName` → `ManufacturerId`;
  similarly for `tblModel`) — then filter/join the watch table by that id only.
- Never join or filter `tblWatch`/`tblWatch_d` directly on `ReferenceNumber`, `ManufactureName`,
  `RawManufacturer`, `ModelName`, or similar display text. Keep the input text only for display in
  the final result, not for matching.

## B10. `IsDeleted` — only on `tblWatch` / `tblWatch_d`

- The `IsDeleted` flag is maintained **only** in `tblWatch` and `tblWatch_d`. Filter
  `IsDeleted = 0 OR IsDeleted IS NULL` on those two tables (when staging them, B8) and **nowhere
  else** — no other table, including image, reference-number and raw tables.
- Do not add an `IsDeleted` condition to any other table unless the user explicitly asks.

## B11. No `DISTINCT` inside a windowed aggregate

- SQL Server does not allow `DISTINCT` inside an `OVER(...)` aggregate —
  `COUNT(DISTINCT x) OVER (PARTITION BY ...)` fails with `Msg 10759`.
- For a distinct count partitioned by a key, aggregate into a separate `GROUP BY` temp table first
  (`SELECT Key, COUNT(DISTINCT x) AS Cnt INTO #Step FROM ... GROUP BY Key`), then join that back.
