---
type: Skill Step
title: Step 6 — INSERT statements
description: Writes one catalog-ready INSERT INTO #CreateCatalogQueue formula per clean full-ref row, for the user to run themselves.
tags: [skills, brand-ref-agent, steps, insert-statements]
timestamp: 2026-10-31
---
# Step 6 — INSERT statements

**Built on the `<brand> final refs Variation` tab: one statement per variation row marked `Keep` in Step 4c.** Rows
with any other status (blank, `Duplicate of …`, `Not confirmed`, `Review`) get no statement. One
reference with three kept variations gives three statements. The manufacturer/ref/model/case/dial/image/
link come from that row.

**Purpose:** one `INSERT INTO #CreateCatalogQueue …` formula per kept variation row, in the last
column, ready for the user to run in their own DB tool. **The agent never runs these.**

## First: ask the scope

Before doing anything in this step, ask the user: run it for **(a) the rows currently visible under
their filter, (b) all rows, or (c) something else** (a list of refs / `VariationId`s, a range)? Wait for
the answer, then state the exact row count that scope gives and get it confirmed. Use that scope for
every dry run and write in the step. Never assume the filter, and never assume "all". For the filter scope add `--visible-only` to the command; for all rows leave it off. Only rows with status `Keep` get a statement either way.

## Do

1. Get the exact `ManufacturerName` (see `reference/config.md`; ask for brands not listed, then add
   them to the table).
2. Check readiness before writing:
   - Step 4c is settled (no `Review` rows left undecided) and the **final master-value check** (Step 5,
     run 3, on the `Keep` rows) is clean or accepted by the user: `DialColor`, `CaseMaterial` and `ModelName` are the values the user wants.
   - `FinalImageUrl` is filled for the rows that should have an image.
3. Dry run:

   ```
   python <skill>\scripts\build_insert_formulas.py --tab "<brand> final refs Variation" --key-header VariationId --status-header VariationStatus --manufacturer "<ManufacturerName>"
   ```

   It prints the formula template, the count of clean rows, the rows skipped (flagged rows get no
   statement), and how many clean rows have an empty `ModelName` / `CaseMaterial` / `DialColor` /
   `FinalImageUrl` (the statement is still written, with that field empty). Show these counts to the
   user.
4. After the user's OK, run again with `--write`. The script:
   - writes into the column that already holds `#CreateCatalogQueue` statements, or an
     `InsertStatement` column, or a new column after the last header
   - **refuses** to write over a column that holds anything else (pass `--statement-col` for a free
     column)
   - escapes single quotes inside values
   - uses `StatusId` 1 and `UserID` 6
5. Spot-check 3–5 rendered statements with the user.

`--verify` compares the formula's output with the statements already on a tab. It is read-only and
useful for checking against an older tab.

## Report

Statements written; rows skipped and why; the column used; the rendered text of a few rows.

## Checkpoint

**Stop.** The user takes the statements and runs them. Then update the brand's log file (see
`SKILL.md`, "Logging") and tell the user the brand is complete.
