---
type: Document
title: Credor — Reference Validation Notes
description: Reconstructed notes on Credor watch reference-number validation in the RawRefsToAssign sheet, including observed reference shapes and sheet state.
tags: [documents, credor, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Credor — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Credor` (7,918 rows) · Working tab: `credor final refs` (1,110 rows)

> **Important caveat**: this brand's work was done in a session with no record available to
> this document — everything below is **reconstructed purely from the current sheet state**,
> not from any research log, search history, or stated reasoning.

## What the data shows

- Source tab has `FinalRef` populated for 7,336 of 7,918 rows, collapsing to **1,153 unique
  values**.
- Working tab columns: `ReferenceNumber, ReferenceNumberId, WatchIds, '', TotalWatchCount,
  SourceRowId, ReferenceNumberId, FirstWatchId, FirstWatchPublishWatchId, DialColor,
  CaseMaterial, ModelName, Images, FinalPrimaryImageUrl, FinalImage` — **1,106 of 1,110 rows
  have `FinalPrimaryImageUrl` populated**, i.e. the Step 8-equivalent image-picking pass is
  effectively complete.
- No `PartialRefFlag` or `ValidFullRef` column exists on this tab — unlike Louis Vuitton/
  Jacob & Co./Piaget (which carry an explicit partial-flag column) or Bovet (which carries an
  explicit TRUE/FALSE validity column), suggesting either no duplicate/partial pass was run for
  this brand, or it was done by removing rows outright rather than flagging them.

## Reference shapes observed

Credor (Seiko's prestige/luxury watch brand) shows two dominant, genuine-looking conventions:

1. **4 letters + 3 digits** (shape `AAAA999`) — by far the dominant pattern, **4,555 of 7,336**
   populated `FinalRef` values fit this shape exactly, e.g. `GBBD998`, `GCBG997`, `GCBP997`,
   `GCCR997`, `GCBT995`, `GCBK997`, `GCAY992`. This looks like Credor's own internal reference
   code — plausibly `G` (brand/era marker) + 3-letter line code + 3-digit variant number.
2. **Caliber-case dash format** (shape `9999-9999`, i.e. 4 digits + dash + 4 digits) —
   **1,070 occurrences**, e.g. `8J81-6A30`. This matches the well-known, standard **Seiko-group
   convention** of `<caliber number>-<case number>` (the `8J81` portion is a recognizable Seiko
   movement caliber code), which is consistent with Credor being a Seiko sub-brand.
3. Smaller mixed-shape buckets also exist (`9A99-9999`, `9A99-9A99`, `9A99-9AA9`, etc. — a few
   hundred to a few dozen each), likely minor formatting variants of the caliber-case style
   (e.g. a letter substituted somewhere in the case-number segment) rather than a third
   genuinely distinct convention, but this was not individually verified.

## What is not recoverable from the sheet alone

- Whether the two dominant shapes (`AAAA999` and caliber-case `9999-9999`) were both
  individually confirmed as valid, or accepted by pattern alone.
- Whether any duplicate/partial-ref detection was performed, and with what result — the
  absence of a `PartialRefFlag` column suggests either this step wasn't done, or any
  duplicates found were deleted rather than flagged (which would be inconsistent with the
  "never delete, always flag" convention established for other brands in this workbook).
- Any specific invalid/excluded values and the reasoning behind excluding them.

**Recommendation**: if this brand needs the same rigor applied to Jacob & Co./Piaget (explicit
duplicate detection with a `PartialRefFlag`-style audit trail, individually-confirmed-vs-
pattern-matched confidence tracking), it should be treated as a fresh pass, since no reliable
record of prior reasoning exists to build on.
