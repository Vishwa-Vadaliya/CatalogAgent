---
type: Skill Step
title: Step 3 — Watch data layout
description: Lays out pasted watch data (dial color, case material, model name, images) onto the final-refs tab in the standard layout.
tags: [skills, brand-ref-agent, steps, watch-data]
timestamp: 2026-10-31
---
# Step 3 — Watch variations tab

**Purpose:** get the user's watch data into its **own tab**, `<brand> final refs Variation`, and prepare it for
the image pick. The user's query now returns the **maximum possible variations of each reference**
(dial colour / case material / images …), so one reference can have 2, 3 or more rows. Writing that
into the final-refs tab would be too messy, so **this step no longer writes watch data into the
final-refs tab.** The final-refs tab stays the list of validated references.

The agent doesn't run SQL.

## Do

1. Ask the user to run their watch-data query and **paste the output** (header row + data) into a
   **new tab** named `<brand> final refs Variation` (the user's "`<brand_name> final refs Variation`
   file). Ask the tab name if it differs. The scripts work on tabs of the RawRefsToAssign workbook; if the
   user means a separate spreadsheet file instead, ask for its link and sheet id first.
   - Expected columns: `ReferenceNumber` (or `Referencenumbers`), `ReferenceNumberId`, `FirstWatchId`,
     `FirstWatchPublishWatchId` (or `PublishWatchId`), `DialColor`, `CaseMaterial`, `ModelName`,
     `Images`, and the **per-variation watch count** (e.g. `WatchCount`).
   - Ask which header is the watch count. Step 4c depends on it.
2. Read `reference/final-refs-layout.md` (section "Variations tab") for the target layout.
3. Dry run:

   ```
   python <skill>\scripts\prepare_variations_tab.py --tab "<brand> final refs Variation"
   ```

4. Report to the user:
   - variation rows, unique references, and rows per reference (how many references have 1, 2, 3 … variations)
   - references with more than one `ReferenceNumberId` (report them, never pick one silently)
   - blank `DialColor` / `CaseMaterial` / `ModelName` / image counts
   - pasted references that are **not** in the `<brand> final refs` list, and clean final refs with
     **no** variation row (compare by normalized ref text, read-only). Report both lists, change nothing.
5. After the user's OK, run again with `--write`. It:
   - adds `VariationId` (unique per row), `VariationStatus`, `VariationNote`, `FilledNote`,
     `FinalImageUrl`, `SourceLink`, `FinalImage` to the right of the pasted columns
   - splits `Images` into up to 10 candidate columns, one URL each
   - clears the literal text `NULL` to blank
   - never overwrites existing values; `VariationId` is assigned only to rows that have none
   - re-reads the sheet before writing and aborts if any target row moved

## Why `VariationId`

The reference text repeats on this tab, so it cannot identify a row. **Every later step finds rows by
`VariationId`** (pass `--key-header VariationId` to the scripts that take it), never by row number and
never by reference text.

## Report

Rows prepared, unique references, rows-per-reference distribution, blanks per field, columns written
(letters), any warning.

## Checkpoint

**Stop.** The user confirms the tab. Then read `steps/04-pick-best-image.md`. The order from here is:
**4 pick best image → 4b fill missing dial colour / case material → 4c unique variations → 5 → 6.**
