---
type: Document
title: Bovet — Reference Validation Notes
description: Reconstructed notes on Bovet watch reference-number validation in the RawRefsToAssign sheet, including observed reference shapes and sheet state.
tags: [documents, bovet, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Bovet — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Bovet` (2,780 rows) · Working tab: `Bovet Final Refs` (909 rows)

> **Important caveat**: this brand's work was done in a session with no record available to
> this document — everything below is **reconstructed purely from the current sheet state**
> (column headers, populated values, flag columns), not from any research log, search
> history, or stated reasoning. Treat this as an observational summary of *what the data shows
> was done*, not a record of *why* each call was made.

## What the data shows

- Source tab has `FinalRef` populated for 2,546 of 2,780 rows, collapsing to **898 unique
  values**.
- The working tab (`Bovet Final Refs`) carries a `ValidFullRef` boolean column:
  **672 TRUE / 237 FALSE** out of 909 rows — i.e. a validity call was made and recorded per
  row, unlike the simpler tabs for other brands that only keep valid rows.
- The working tab's schema also includes `DialColor`, `CaseMaterial`, `ModelName`, `Images`,
  and `FinalImageUrl` — **908 of 909 rows have a `FinalImageUrl`**, meaning Step 8-equivalent
  image picking is effectively complete for this brand.

## Reference shapes observed (this brand's formats are unusually heterogeneous)

Bovet's references are visibly **far more varied in structure** than the other brands in this
workbook — multiple distinct, seemingly genuine formats coexist:

- **Simple letter + 3-digit codes**: `C803`, `C800`, `C801`, `C804`, `G800` (high frequency —
  `C803` alone accounts for 48 rows).
- **Compound dash/slash codes**: `R12C2-0004`, `R12C2-0001` (29 and 20 occurrences).
- **Word-prefix codes**: `CHPIN001`, `NTT0011`, `NTS0001`, `NTS0015`, `SP0477`.
- **Letter+digit codes with embedded dashes**: `AF43003`, `AF39015-SD123-LT04` (this one
  already shows a multi-segment case/dial-code style similar to the dot-notation brands).
- **Bare numeric**: `5347`.
- **Very long, highly structured compound refs** appear in the *working* tab specifically,
  e.g. `A800.0.00/L1105/1A.00/0`, `DTR12-42RG-000-B1-01`, `DT7-HS-002/10.09-013`,
  `ACQPR016-G12346-PU`. These mix dots, dashes, and slashes within a single reference and are
  **far longer** than typical references in other brands (length distribution for this tab
  runs from 2 up to 81 characters, with a long tail past 15 — a shape this workbook hasn't
  needed to handle for any other brand).
- Rows flagged `ValidFullRef = FALSE` include things like `R120004-31, 025180` (comma-joined,
  looks like two values merged), `Q800`, `D505`, `D816`, `815.1`, `QA0003` — some of these look
  structurally plausible on their own, so the FALSE calls likely reflect a check against an
  external/authoritative source rather than pure shape, but that reasoning is not recoverable
  from the sheet alone.

## What is not recoverable from the sheet alone

- Why specific values were marked `ValidFullRef = FALSE` versus TRUE when several (e.g. `D505`,
  `D816`, `AF39029`) look shape-plausible compared to confirmed-valid entries.
- Whether duplicate/partial-ref detection (equivalent to Step 5 in the general workflow) was
  run, and if so what methodology or findings resulted.
- Any brand-convention research (equivalent to Step 2) establishing which of the several
  observed shapes are genuinely distinct Bovet lines versus which might be data-entry noise.

**Recommendation**: if further confidence is needed on this brand, it should be treated as
needing a fresh Step 2–5 pass under the general workflow, since no reliable record of the
original reasoning exists to build on.
