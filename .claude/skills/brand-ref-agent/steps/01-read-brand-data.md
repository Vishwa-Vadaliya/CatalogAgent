---
type: Skill Step
title: "Step 1 — Read the brand's data"
description: First step of the brand-ref-agent — find the brand's source tab, check the numbers, and agree scope with the user before validation.
tags: [skills, brand-ref-agent, steps]
timestamp: 2026-10-31
---
# Step 1 — Read the brand's data (runs AFTER Step 1b, the brand research)

**Purpose:** find the brand's source tab, read its data, test every structure in it against what Step 1b
learned about the brand, and **decide which reference structures to keep**. The data is not the source
of truth: the researched profile is. A structure that is common in the data is not thereby valid.

**Prerequisite:** a draft `<Brand>_Reference_Profile.md` from Step 1b exists and the user has reviewed it.
If it does not, stop and run Step 1b first (unless the user explicitly says to skip it; then the report
must say the brand rules were not researched).

## Do

1. Resolve the brand name to its source tab. Tabs are named like the brand (`Jacob & Co.`,
   `Girard-Perregaux`); the script lists similar tabs if there's no exact match. Ask the user which
   tab if it's unclear. Don't guess between two plausible tabs.
2. Run (read-only):

   ```
   python <skill>\scripts\read_brand_data.py --tab "<source tab>"
   ```

3. Check that the numbers make sense:
   - **Rows visible under the current filter** should match what the user says they see. If the
     user quoted a count and it differs, stop and sort that out first.
   - **`ReferenceNumberId` set vs NULL** gives the two populations. Set = Phase A (workflow Step 1).
     NULL = Phase B (workflow Step 4).
   - Note an existing `FinalRef` or `PartialRefFlag` column, and an existing `<brand> final refs`
     tab. If any exist, this brand is a **resume**, not a fresh start: ask which workflow step to
     continue from.
4. **Inventory the structures in the data** (read-only):

   ```
   python <skill>\scripts\ref_structures.py --tab "<source tab>" --col ReferenceNumber   # Phase A population
   python <skill>\scripts\ref_structures.py --tab "<source tab>" --col RawReferenceNumber --out <scratchpad>\structures_raw.csv
   ```

   It lists every **structure** (digits → `9`, letters → `A`, separators kept) with counts and examples,
   and highlights values that are often not references (long digit runs, hex hashes, joined values,
   lowercase).
5. **Test each structure against the profile.** For every structure take at least 3 real values and
   match them to the profile from Step 1b. Classify the structure as exactly one of:
   - **valid current format** / **valid vintage format** (say which models or eras);
   - **valid but alias** (a second spelling or old/new number of a ref in another structure; record the
     mapping rule);
   - **not a reference** (caseback / case / serial / movement / warranty / other, with the evidence that
     tells it apart from a ref);
   - **unknown**: the profile does not cover it, or its profile entry is only `likely` / `unconfirmed`.
     "Not found" is **not** the same as invalid (Standing Rule 5).
6. **Cross-model verification for the structures that are not settled.** Every structure that is
   `unknown`, or whose profile confidence is `likely` / `unconfirmed`, gets the same independent
   cross-model check as in Step 1b section 3 (a fresh Sonnet 5.5 subagent that is asked the question
   without being told the earlier answer; promotion to confirmed only with a link you opened; a
   disagreement stays open and is listed for the user). Use real values from this brand's data as the
   examples. Opus 5.5 does the first research pass for any structure that needs new research (rule 16).
7. **Decide which structures to keep**, as a proposal for the user:
   - **Keep:** valid current, valid vintage, valid alias (aliases are mapped, not dropped).
   - **Exclude from the reference set:** not a reference (case serials and the like). This is a scope
     decision, not a deletion: the rows stay in the data and are flagged in Step 2.
   - **Open:** unknown or conflicting after the cross-check. These are listed for the user to rule on,
     with the evidence from both models. Nothing is flagged as invalid on the strength of "not found".
8. Add the verdicts and the per-structure counts to the profile, and say what changed from the draft.
9. Ask for anything Step 2 will need that isn't known yet:
   - the brand's `Sheet4` catalog column (see `reference/config.md`), or confirmation that there is
     none
   - the exact `ManufacturerName` spelling, if the brand isn't in `reference/config.md`

## Report

Total rows; visible rows; RNId set / NULL; unique `ReferenceNumber` (Phase A); unique
`RawReferenceNumber` (Phase B); unique `ModelName` count; any existing final-refs tab or flags; the
live filter and any live sort. Then the **structure table**: every structure in the data, its class,
unique values, rows, and the keep / exclude / open verdict. Include how many structures were
cross-checked, how many were promoted to confirmed, and where the models disagreed.

## Checkpoint

**Stop.** The user confirms the scope, the resume point (if any), and which structures to keep (and
rules on the open ones). Then read `steps/02-validate-and-build-final-refs.md`. Step 2 must follow the
profile; if it meets a structure the profile does not cover, stop and extend the profile first.
