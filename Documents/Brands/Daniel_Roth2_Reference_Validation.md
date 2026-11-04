---
type: Document
title: Daniel Roth (2) — Reference Validation Notes
description: Reconstructed notes on Daniel Roth watch reference-number validation in the RawRefsToAssign sheet, including observed reference shapes and sheet state.
tags: [documents, daniel-roth, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Daniel Roth (2) — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Daniel roth2` (3,145 rows) — **no working/"final refs" tab exists for this brand**,
unlike every other brand covered in this workbook.

> **Important caveat**: this brand's work was done in a session with no record available to
> this document — everything below is **reconstructed purely from the current sheet state**,
> not from any research log, search history, or stated reasoning.

## What the data shows

- Header: `WatchId, ModelId, ModelName, RawReferenceNumber, ReferenceNumberId, ReferenceNumber,
  IsValidDanielRothRef, FinalRef, '', Stage1Valid` — this is the **only brand in the workbook
  with an explicit per-row `IsValidDanielRothRef` / `Stage1Valid` validity pair of columns on
  the *source* tab itself**, rather than deferring validity tracking to a separate working tab.
- `ReferenceNumberId` is populated (not null) for 1,870 of 3,145 rows.
- `FinalRef` is populated for 2,278 of 3,145 rows, collapsing to **402 unique values**.
- `IsValidDanielRothRef`: **1,849 "Valid" / 1,296 "Invalid"**.
- `Stage1Valid`: **1,824 TRUE / 25 FALSE / 1,296 blank** — the blanks line up closely with the
  1,296 "Invalid" `IsValidDanielRothRef` rows, suggesting `Stage1Valid` was only populated for
  rows that passed the initial `IsValidDanielRothRef` gate (i.e. a two-stage validity check,
  consistent with the general workflow's "Stage 1 individual validity, Stage 2 deeper check"
  framework, even though this predates that document).
- No work appears to have progressed to a dedicated final-refs tab, `WatchIds` population,
  duplicate/partial detection, or image picking for this brand — it looks like work stopped
  after the initial per-ref validity pass (Steps 1–3 equivalent in the general workflow).

## Reference shapes observed

Two coexisting, plausible conventions show up in the `FinalRef` values:

1. **Letter + 3-digit codes**: `S247` (204 occurrences, the single most common value in the
   whole tab), `C187`, `T157`, `S177`, `207` (bare 3-digit, 25 occurrences). This short-code
   style is consistent with Daniel Roth's known vintage reference convention (the brand, now
   part of the Bulgari/LVMH group's watch portfolio, historically used single-letter + number
   codes for its early collections).
2. **Dot-separated segmented codes**: `807.L.10` (129 occurrences), `447.X.60`, `857.ST`,
   `208.X.60`, `857.X.10`, `247.X.10`, `368.X.60`, `197.X.60`, `447.X.40`, and a long compound
   form `318.Y.60.350.CN.BD` (26 occurrences) — this is the same general style of dot-notation
   case/dial/material segmentation seen in Piaget's `G0A` era and Jacob & Co.'s modern
   dot-notation, suggesting a shared Richemont-group-era reference system convention.

## What is not recoverable from the sheet alone

- The exact criteria used to mark a reference `Invalid` in `IsValidDanielRothRef` — whether
  individually source-confirmed or pattern-based.
- Why 1,870 rows have a non-null `ReferenceNumberId` but only 2,278 rows (a larger number) have
  a populated `FinalRef` — implying some `FinalRef` values came from a `RawReferenceNumber`
  extraction pass (Phase B equivalent) even without matching this document's later-established
  two-phase naming, but the specific extraction logic used is not recorded.
- Whether any duplicate detection, final-refs tab creation, `WatchIds` population, or image
  picking was ever planned/attempted for this brand.

**Recommendation**: this brand is the least complete of the six in this workbook relative to
the general workflow (no Step 6 final-refs tab exists at all). If picked back up, Step 6
onward (create `Daniel roth2 final refs`, populate `ReferenceNumberId`/`WatchIds`, run the
Step 5 duplicate/invalid-ref sweep as now formally documented in the main workflow doc) would
be the natural next step, treating the existing `FinalRef`/`Stage1Valid` columns as the
Step 1–4 output to build on rather than re-deriving them from scratch.
