---
type: Document
title: Louis Vuitton — Reference Validation Notes
description: Notes on Louis Vuitton watch reference-number validation — confirmed conventions, validation decisions, and image-picking status.
tags: [documents, louis-vuitton, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Louis Vuitton — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Louis vuitton` (29,560 rows) · Working tab: `louis vuitton final refs` (621 rows)

> Note: this brand's work happened mostly in an earlier session. The detail below combines
> that session's summary with a fresh inspection of the current sheet state — exact search
> queries/sources from the original research are not all individually re-traceable here.

## Reference convention confirmed valid

- **`Q`-prefix (and `W`-prefix) + 4 alphanumeric characters** (5 characters total), e.g.
  `Q1111`, `Q1131`, `Q1121`, `Q102D`, `Q1211`, `Q118F`. This is Tambour-line model reference
  format and is the dominant, confirmed-valid pattern (400 of 621 final refs are 5 characters).
  A small number of 6-character refs (218) and 4-character refs (3) also exist in the working
  set.
- **Explicitly ruled out as a reference**: Louis Vuitton's 2-letter + 4-digit codes (e.g. a
  factory/date-stamp style code) are a **universal date-code stamp system** used across all LV
  product categories (bags, accessories, watches alike), not a distinct watch model reference —
  confirmed by cross-referencing against LV's own published factory-code table. This was an
  important early distinction: a structurally similar-looking code is not automatically the
  same *kind* of code.

## Validation decisions

- **User-supplied source correction**: a specific reference, `Q11200`, was corrected based on
  a source the user provided directly — handled by fetching the exact link and quoting what it
  said before accepting the correction (per the "if the user supplies a specific link, fetch it
  directly" rule), rather than re-litigating the original classification from memory.
- Unique-ref computation for Stage 2 work was done **ignoring whitespace and punctuation**
  (normalize → strip non-alnum, uppercase → group), consistent with the general dedup approach
  later generalized into Step 7b of the main workflow.
- A full **structural-pattern partial/full-ref flagging pass** was run: **166 of 621 rows are
  flagged `PartialRefFlag`** in the current working tab, leaving **455 full, working refs**.

## Image picking (Step 8)

- **455 of 455 full refs have a `FinalImageUrl` populated** — the image-picking pass is
  complete for the current full-ref working set.
- Selection and recheck methodology matches the general Step 8 process later written up in the
  main workflow doc: prefer vertical/non-tilted images showing the full dial and strap, and
  run a tilt-recheck pass on any row where the picked position wasn't #1. At least one specific
  recheck cycle is on record for this brand (a row initially flagged as tilted, corrected,
  then reverted back to the original pick after a closer look confirmed the first image was
  actually fine).

## Column layout used (`louis vuitton final refs`)

`Referencenumbers, ReferenceNumberId, WatchIds, PartialRefFlag, TotalWatchCount, Length, '',
SourceRowId, ReferenceNumberId, FirstWatchId, FirstWatchPublishWatchId, DialColor,
CaseMaterial, ModelName, Images, FinalImageUrl, FinalImage`

## Gaps / what isn't captured here

The original session's exact batch-search queries, the full list of excluded/unconfirmed raw
values, and the specific reasoning for every individual partial-ref call are not reconstructed
in this document — only what's directly evidenced by the current sheet state and the
carried-over session summary.
