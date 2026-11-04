---
type: Skill Step
title: "Step 4b — Fill the missing DialColor and CaseMaterial"
description: "Step 4b of the brand-ref-agent: fill blank DialColor and CaseMaterial on the Variation tab from the image first (web only if needed), using master values only."
tags: [skills, brand-ref-agent, steps]
timestamp: 2026-10-31
---
# Step 4b — Fill the missing DialColor and CaseMaterial

**Runs on the `<brand> final refs Variation` tab, after the best image is picked (Step 4) and before duplicates
are looked for (Step 4c).** Duplicates can only be judged once every variation has a dial colour and
a case material, so filling them is the first goal.

**Purpose:** every variation row gets a `DialColor` and a `CaseMaterial` taken from the **master
values**, wherever the evidence allows it. Nothing is guessed.

## First: ask the scope

Before doing anything in this step, ask the user: run it for **(a) the rows currently visible under
their filter, (b) all rows, or (c) something else** (a list of refs / `VariationId`s, a range)? Wait for
the answer, then state the exact row count that scope gives and get it confirmed. Use that scope for
every dry run and write in the step. Never assume the filter, and never assume "all". If the scope is the filter, only visible rows with a blank dial and/or case are touched.

## Master-value check around this step

The master-value check (Step 5) runs **before** and **right after** the filling, so the values are
standardised first and only master values are written:

1. **Before filling:** run Step 5 on the pasted `DialColor` / `CaseMaterial` (in the chosen scope) and
   show the user the values that are not in master. The user decides the replacements first; blanks are
   then filled with master values.
2. **While filling:** every value written is a master value (rules below).
3. **Right after filling:** run Step 5 again on the same scope. It must come back clean for the filled
   cells, and any leftover non-master value is shown to the user.

## Where the values come from (in this order)

1. **The image.** Download the row's `FinalImageUrl` (and, if it is not enough, the other candidate
   images) into the scratchpad, look at it, and identify the dial colour and the case material. The
   agent never writes a value it cannot see.
2. **Web search, only if the image cannot settle it** (dial hidden, glare, caseback or strap shot,
   case material not visible). Before searching, tell the user "N rows still need a web search for
   dial / case, should I go ahead?" and wait for the yes. Use dealer, auction and official pages for
   the exact reference. The model for this research is set by standing rule 16.
3. **Still unknown:** leave the cell blank and list the row. Never fill from the reference's other
   rows or from the model name.

Record the source of every filled cell in `FilledNote` (`dial: image`, `case: web <page>`, `dial: user`).

## Master values only

- Read the master lists (`reference/config.md`, "Master values"): tabs `DialColor`, `Material`.
- A value is written only if it is **exactly a master value** (master spelling).
- If the right value is **not in the master list, stop and ask the user whether to write it**, with the
  row, the value, and the closest master value. Don't write it, don't swap it for a near match, until
  the user answers.

## Dial colour rules

- **Skeletonized or semi-skeletonized dial: that wins over every other colour.** If the watch is
  skeletonized or semi-skeletonized, `DialColor` is the master value for that, whatever the dial
  base colour is. If the master list has only one of the two, use it for both (they count as the same
  "other colour"); if it has neither, ask the user.
- Otherwise the order is Paved > Multi-colored > the dominant colour (see `rules/edge-cases.md`).
- Visual review, not pixel classification. Blank for a corrupt or wrong image.
- For comparing dials later, these count as **one** dial: **White / Silver / Cream**, **Black / Gray**,
  **Golden / Champagne / Yellow**, **Red / Burgundy**, **Brown / Copper**. Write the specific master
  colour you see; the grouping is used only when looking for duplicates.

## Case material rules

- **Any gold counts as plain gold:** the karat or purity (9k, 14k, 18k, 750 …) is ignored.
  Look the value up in the master list. If, say, `9K Yellow Gold` is not in master, **generalise**
  it (drop the karat → `Yellow Gold`) and use that if it is in master.
- If even the generalised value is not in master, ask the user (see above).
- A non-standard material (not on the master list at all) is web-verified, not just re-cased.
- Case material must be something the image or a source actually shows; a "gold" case on a steel-only
  model is a data error to report, not to copy.

## Dry run, then write

1. Build the list of rows to fill: blank `DialColor` and/or blank `CaseMaterial` (literal `NULL` was
   cleared in Step 3).
2. Work through them, image first. Put the proposed values in a scratchpad CSV
   (`VariationId, DialColor, CaseMaterial, source, evidence`). Don't write to the sheet yet.
3. Show the user: counts filled from the image, counts needing a web search (ask), counts needing a
   value that is **not in master** (ask), counts left blank, and 10 sample rows.
4. After the user's OK, write with `sheets_client.safe_batch_write("<brand> final refs Variation", writes,
   key_header="VariationId", write=True)`. Only blank cells are filled. A cell that already has a value
   is never overwritten here. Save a backup CSV of the old values.

## Report

Rows that needed filling; filled by image / by web / by user answer; blank still; values asked about
and the answers; backup path.

## Checkpoint

**Stop.** The user confirms the filled values and the second master-value check. Then read
`steps/04c-unique-variations.md`.
