---
type: Skill Step
title: "Step 4c — Unique variations"
description: "Step 4c of the brand-ref-agent: find the unique variations per reference using images, watch counts and web checks, and record the result in VariationStatus."
tags: [skills, brand-ref-agent, steps]
timestamp: 2026-10-31
---
# Step 4c — Unique variations

**Runs on the `<brand> final refs Variation` tab after Step 4 (images) and Step 4b (dial / case filled).**

**Purpose:** for every reference, decide which of its variation rows are real, **unique** variations.
Only those go on to Steps 5 and 6. The catalog must hold true data and **no duplicate variation**.

Status goes in `VariationStatus` (+ the reason in `VariationNote`). **Rows are never deleted.**

**Every unique variation is marked `Keep`.** After this step each reviewed reference has one `Keep` row per
unique variation; the repeats are `Duplicate of <VariationId>`, and the doubtful ones are `Not confirmed` or
`Review`. A variation that is not web-checked because its reference has many variations is still marked
`Keep` (note: `accepted, many variations`), so it is clear which `Keep`s were individually confirmed and
which were accepted by pattern.

| `VariationStatus` | Meaning |
|---|---|
| blank | not reviewed yet |
| `Keep` | unique variation, confirmed (or accepted, see below) |
| `Duplicate of <VariationId>` | same variation as the named row |
| `Not confirmed` | web check could not confirm that this variation exists |
| `Review` | unsure, left for the user (do not guess) |

## First: ask the scope

Before doing anything in this step, ask the user: run it for **(a) the rows currently visible under
their filter, (b) all rows, or (c) something else** (a list of refs / `VariationId`s, a range)? Wait for
the answer, then state the exact row count that scope gives and get it confirmed. Use that scope for
every dry run and write in the step. Never assume the filter, and never assume "all". Uniqueness is judged **within a reference**, so if the scope is the filter and the filter shows only some of a reference's variations, say so and ask whether to widen the scope to whole references. Never judge a reference from part of its rows without telling the user.

## Why dial + case alone is not enough

`DialColor` and `CaseMaterial` in the pasted data can be **wrong**: e.g. a row says yellow dial / rose
gold although the reference never came in rose gold. So the dial and case of a row are **a hint, not
proof**. Uniqueness is decided from several signals together:

1. the normalized **dial + case** (below)
2. the **image**, looked at side by side for rows that look the same on paper
3. the **watch count** (the per-variation watch-count column from Step 3, plus how many variation rows
   the reference has)
4. a **web check** for low-evidence variations (below)

## Normalization used when comparing two rows (comparison only: do not rewrite the cells)

- **Dial groups, each counts as one dial:** White / Silver / Cream · Black / Gray ·
  Golden / Champagne / Yellow · Red / Burgundy · Brown / Copper. Skeletonized and semi-skeletonized
  count as the same dial (and beat any other colour, per Step 4b). Any other colour is its own dial.
- **Case material:** karat/purity ignored, so any gold = gold for the comparison. Different gold
  colours (yellow / rose / white) stay separate, and gold vs steel is a different case.
- Compare after trimming and case-folding.

## Do

1. **Group by reference** (by `ReferenceNumberId` where present, else normalized ref text). A
   reference with more than one `ReferenceNumberId` is reported, not merged.
2. **Exact duplicates first.** Within a reference, rows with the same normalized dial **and** the same
   normalized case are duplicate candidates. Look at their images. If they show the same watch
   variant, keep one (prefer the row with the larger watch count, then the better image) and mark the
   others `Duplicate of <VariationId>`. If the images show different watches (e.g. a different dial that
   the data labelled the same), do not mark: set `Review`.
3. **Near duplicates the data hides.** Rows with different labels but the same watch (a wrong dial or
   case label, e.g. the same image under "Yellow / Rose Gold" and "Golden / Gold") are found by
   comparing images and watch counts within the reference. Mark `Review`, never `Duplicate`, unless the
   images are clearly identical and the user agreed.
4. **Decide how much to research, by variation count.** Show the user the distribution first (how many
   references have 1, 2, 3 … 10+ variations after step 2) and **propose a cut-off**.
   - **References with many variations (above the cut-off): no research or review is needed.** The
     rows that survive step 2 are marked `Keep` (note: `accepted, many variations`).
   - **References with few variations (at or below the cut-off): web-check them**, because here each
     variation matters and a wrong one is easy to spot. Check **all of them or a sample**, whichever the
     user says. If they say "a few", agree the sample size and how it is chosen before starting.
   - Use the watch count to order the work: a variation backed by several watches is strong evidence;
     a variation with a single watch is the weakest and is checked first.
5. **Ask before every web search.** Say plainly: "N references (M variations) are at or below the
   cut-off and would need a web search. Should I check all of them, or a sample of K?" Stop and wait.
   Don't search before the yes.
6. **Web check** (after the yes): for each variation, search brand + exact reference (+ dial / case) on
   the official site, dealer and auction pages; see standing rule 5 (several angles; one missed search
   proves nothing; accept a claim only if a returned link backs it). The model for this research is set
   by standing rule 16. Per variation:
   - the reference really exists in that dial / case → `Keep`, note the page
   - evidence shows the data label is wrong (the watch exists, but with another dial or case) → don't
     change the cell here; set `Review` with the evidence so the user can decide
   - nothing found after several angles → `Not confirmed` (say how many angles, don't overclaim)
7. **Dry run** (scratchpad CSV: `VariationId, status, note, evidence`) and show the user the counts per
   status and 10 examples of each. After the user's OK, write with `safe_batch_write(..., key_header=
   "VariationId", write=True)`, only into blank `VariationStatus` cells, never over an existing status.
   Save a backup.

## Report

Per status: counts. References reviewed by web vs accepted without research, the cut-off used and who
chose it, how many rows were individually confirmed vs accepted by pattern, the `Review` list, backup path.

## Checkpoint

**Stop.** The user decides the `Review` and `Not confirmed` rows (each stays flagged until they do).
Then read `steps/05-master-value-check.md` for the **final** master-value check on the `Keep` rows, and
only after that `steps/06-insert-statements.md`. Steps 5 (final run) and 6 use only rows whose status is
`Keep`.
