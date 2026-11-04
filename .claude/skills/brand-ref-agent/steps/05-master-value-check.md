---
type: Skill Step
title: Step 5 — Master-value check
description: Reports which DialColor, CaseMaterial and ModelName values on the tab are not in the master list, for the user to fix.
tags: [skills, brand-ref-agent, steps, master-values]
timestamp: 2026-10-31
---
# Step 5 — Master-value check

**Runs on the `<brand> final refs Variation` tab, three times:**

1. **Before Step 4b:** on the pasted values, so the user can decide replacements before blanks are filled.
2. **Right after Step 4b:** on the same scope, to check the filled values. (It also covers `ModelName`,
   which Step 4b does not touch.)
3. **Final, before Step 6:** on the `Keep` rows only (`--status-header VariationStatus`). Step 6 does not
   start until this run is clean or the user has accepted what is left.

Runs 1 and 2 have no status to filter on yet, so they check the rows in the chosen scope.

**Purpose:** tell the user which `DialColor`, `CaseMaterial` and `ModelName` values on the tab are
not in the master list, so they can fix them. **The agent never changes a value on its own.**

## First: ask the scope

Before doing anything in this step, ask the user: run it for **(a) the rows currently visible under
their filter, (b) all rows, or (c) something else** (a list of refs / `VariationId`s, a range)? Wait for
the answer, then state the exact row count that scope gives and get it confirmed. Use that scope for
every dry run and write in the step. Never assume the filter, and never assume "all". The tab is read in full, so for the filter scope add `--visible-only` to the command; for all rows leave it off.

## Do

1. The master list location is in `reference/config.md`. If it still says **TBD**, ask the user for
   the link (a sheet or a doc) and add it to `config.md` once given. Don't invent a master list from
   the tab's own values.
2. The master list must have a header row with one column each for `DialColor`, `CaseMaterial` and
   `ModelName` (aliases like `Dial Color` or `Model` work). If it's a different shape, ask the user
   how it is laid out.
3. Run (read-only):

   ```
   python <skill>\scripts\master_value_check.py --tab "<brand> final refs Variation" --status-header VariationStatus --master-sheet "<tab or spreadsheetId:tab>" [--out <scratchpad>\mismatches.csv]
   # or, for an exported file
   python <skill>\scripts\master_value_check.py --tab "<brand> final refs Variation" --status-header VariationStatus --master-csv <file>
   ```

   With `--status-header VariationStatus` only rows whose status starts with `Keep` are checked. (On an
   old-style final-refs tab without variations, drop that flag: clean full refs are checked, unless
   `--include-flagged` is given.)
4. Hand the user the lists: for each field, the values **not in the master**, with row counts and a
   suggestion when a close master value exists. Also mention values that match only after ignoring
   case or spacing.

## Applying fixes (only on the user's instruction)

When the user says which replacements to make, apply them with
`sheets_client.safe_batch_write(...)` with `key_header="VariationId"`: dry run first, then `--write` after their OK. Remember the
edge-case rules: web-verify a non-standard `CaseMaterial` instead of just re-casing it, and
`DialColor` follows the Skeletonized > Paved > Multi-colored > dominant colour order.

## Report

Per field: unique values, blanks, values in master, values **not** in master (the list).

## Checkpoint

**Stop.** The user edits values or tells the agent which replacements to make. Re-run the check
until the lists are as the user wants. Then read `steps/06-insert-statements.md`.
