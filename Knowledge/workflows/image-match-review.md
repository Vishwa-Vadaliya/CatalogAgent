---
type: Knowledge
title: Image match review workflow (per brand)
description: How to run the manufacturer-wide image match and multiple-ENR image similarity review for any brand — which queries to hand out, how to ask before writing them, and the Google Sheet template that turns the pasted results into the summary tables.
tags: [knowledge, enrichment, image-match, multiple-enr, google-sheets, workflow]
timestamp: 2026-10-30
---

# Image match review workflow (per brand)

Used when the user names a brand and wants to **review the manufacturer-wide image match** and
the **multiple-ENR image similarity** for it. The result is always the same sheet layout, so every
brand is read the same way. Claude never runs the queries (see `Rules/00-core.md` A1) — it writes
them, the user runs them and pastes the results into the sheet.

## 1. Ask before writing any query

Ask the user, once per brand, before writing the first query:

1. **Brand** — the exact `tblManufacturer.ManufacturerName` (e.g. `Jaeger-LeCoultre`, `Louis Vuitton`).
2. **Current manufacturer-wide threshold** — usually 0.89, but ask; it is not the same for every brand.
3. **Review sample size per 0.01 band** — and the band range to review (default 0.60 up to the threshold).
4. **Person folder** (Rules A2): Ravi, Vishva or Janvi.
5. **"Earlier" enrichment %** — the earlier figure shown in `FINAL SUMMARY` section 1. It is a typed
   input; never invent it.

## 2. The queries (one `.sql` file each, saved in `Queries/<Person>/<Brand>/`)

Adapt the existing reference queries by changing only `#Params` (brand, threshold, sample size, enrichment type).

| File to write | Adapt from | Result goes to tab |
|---|---|---|
| `Enrichment_Overview_Counts.sql` | `JaegerLeCoultre_Enrichment_Overview.sql` | `Enrichment Overview` (Draft row, Published row) |
| `Enrichment_Overview_Threshold_Impact.sql` | `LouisVuitton_Enrichment_Overview.sql` | `Overview Data` columns A:I |
| `MultipleENR_ImageSimilarity_Bands.sql` | `JaegerLeCoultre_MultipleENR_ImageSimilarity_Bands.sql` | `Overview Data` columns L:Q |
| `ImageMatch_Review_ManufacturerWide.sql` | `LouisVuitton_ImageMatch_Review.sql` (type 5) | `ManufacturerWide` |
| `ImageMatch_Review_MultipleENR.sql` | `LouisVuitton_ImageMatch_Review.sql` with `EnrichmentType` changed from 5 to 1 | `Multiple ENR` |

`JaegerLeCoultre_MultipleENR_Type1_Count.sql` is an optional extra count; not used by the sheet.

Query definitions (see [../enrichment.md](../enrichment.md) for the enrichment tables):

- **Enrichment type:** 1 = Image Similarity (multiple-ENR review), 5 = Manufacturer-Wide Image Match.
- **Multiple ENR:** active draft watch with `ReferenceEnrichmentId IS NULL` and candidate rows in `tbl_RE_DataToFix`.
  `tbl_RE_DataToFix` has no score or type; the score is `tbl_RE_DiscardedWatch.ImageMatchScore` of the type-1 rows.
- **Counts query columns:** `TotalWatches, WithEnrichment, WithoutEnrichment, WithoutEnr_WithReferenceNumber,
  WithoutEnr_NullReferenceNumber, NullRef_WithRawReference, NullRef_WithoutRawReference, NullRef_UniqueRawReferences`.
  Published watches take the raw reference from the linked draft.

## 3. The Google Sheet template

- **Template:** `ManufacturerWideImageMatch - TEMPLATE`, id `1it3jlCafeNQMyQwqI1Sodfijdt9pf8kgGTcUGtgV9hc`.
  Copy it for each brand (Drive `copy_file`) and name the copy `ManufacturerWideImageMatch <Brand>`. Confirm with the
  user before creating the copy. **Always clear the copy's data right after creating it** and set the brand name:
  run `PythonScripts/prepare_review_sheet.py <key.json> <new sheet id> <Brand>` (the user must share the new copy
  with the service account as Editor first). Headers, formulas and the section 5 reason labels stay.
- **Never change the layout per brand** — same tabs, same columns, same section order every time.
- The sheet is filled by the user pasting results; Claude does not run the queries. Claude can read the sheet
  through the Drive connector (values only; the Google Sheets API with a read-only service account shows formulas).

### Tabs

| Tab | Content |
|---|---|
| `ManufacturerWide` | Result of the type-5 review query, one paste into A:M. Query columns: A WatchId, B WatchReferenceNumber, C CandidateEnrichmentId, D CandidateReferenceNumber, E ImageMatchScore, F MatchConfidence, G WatchImage, H EnrichmentImage, I/J blank preview columns, K BandStart, L rn, M Review (0 correct, 1 incorrect). Put `=IMAGE(G2)` in I and `=IMAGE(H2)` in J. `O` = difference reason for incorrect rows (typed during review). |
| `Multiple ENR` | Result of the type-1 review query, **same layout as `ManufacturerWide`** (A:M, previews in I and J, Review in M, difference reason in O). Formulas only read E (score), M (review) and O. |
| `Summary Table for Manufacturer Wide` | Formulas only. Left block cumulative (`>=0.89` … `>=0.60`), right block per band; `COUNTIFS` on score column E and review column M of `ManufacturerWide`. |
| `Summary Table for Multiple enr` | Same, reading `Multiple ENR`. |
| `Enrichment Overview` | Paste of the counts query: header in row 1, Draft in row 2, Published in row 3. Columns A:I in the order of the query. |
| `Overview Data` | Paste of the threshold-impact query at A1 (30 Draft rows then 30 Published rows, 0.89 down to 0.60) and the bands query at L1. (Was named after Jaeger-LeCoultre in the template; the prepare script renames it.) |
| `Extra Review 1`, `Extra Review 2` | Unused by any formula (were brand-named in the template). Left empty. |
| `FINAL SUMMARY` | Written report, all formulas (below). |

### FINAL SUMMARY — formulas

Published rows only. `ES` = `'Enrichment Overview'`, `SJ` = `'Overview Data'`,
`SM` = `'Summary Table for Manufacturer Wide'`.

**Section 1 — Where we are today** (rows 6–8)

| Cell | Formula |
|---|---|
| B7 total published | `=ES!B3` |
| D7 with enrichment | `=ES!C3` |
| F7 enrichment % | `=D7/B7` |
| H7 without enrichment | `=ES!D3` |
| F8 "Earlier" (typed % number, e.g. 32.23; number format `"Earlier: "0.00"%"`) | typed |
| J7 improvement (points) | `=ROUND(F7*100-F8,2)` |

**Section 2 — Why not enriched** (rows 12–16)

| Cell | Formula |
|---|---|
| G12 | `=ES!D3` |
| G13 with ref, not matched | `=ES!E3` |
| G14 without ref | `=ES!F3` |
| G15 raw ref available | `=ES!G3` |
| G16 no raw ref | `=ES!H3` |
| H12 | `=IF(G12=0,0,G12/$G$12)` |
| H13, H14 | `=IF($G$12=0,0,G13/$G$12)` |
| H15, H16 (share of "without a reference number") | `=IF($G$14=0,0,G15/$G$14)` |

**Section 3** — threshold input in `F20`; formulas are `INDEX/MATCH` on section 4. Before the review is done `J22` must show `"not reviewed"` instead of an error: `=IF(INDEX($G$28:$G$41,MATCH($F$20,$B$28:$B$41,0))=0,"not reviewed",1-INDEX($I$28:$I$41,MATCH($F$20,$B$28:$B$41,0)))`, and the sentence in `B24` wraps the "Based on manual review…" part in `IF(ISNUMBER(J22), …, "Not manually reviewed yet, so the accuracy is unknown.")`.

**Section 4 — Scenario comparison** (rows 28–41; column B = threshold, typed, highest first)

| Col | Formula (row 28) |
|---|---|
| C additional watches | `=SUMIFS(SJ!$F:$F,SJ!$A:$A,"Published",SJ!$B:$B,$B28)` |
| D total after | `=$D$7+C28` |
| E enrichment % after | `=D28/$B$7` |
| F increase (pts) | `=(E28-$F$7)*100` |
| G reviewed sample | `=INDEX(SM!$C$3:$C$32,MATCH(">="&TEXT($B28,"0.00"),SM!$B$3:$B$32,0))` |
| H incorrect in sample | `=INDEX(SM!$E$3:$E$32,MATCH(">="&TEXT($B28,"0.00"),SM!$B$3:$B$32,0))` |
| I incorrect % | `=IF(G28=0,0,H28/G28)` |
| J est. incorrect | `=ROUND(I28*C28,0)` |
| K est. correct | `=C28-J28` |

Columns I, J, K are `""` until the threshold's review exists: `=IF(G28=0,"",…)`. Rows are 0.88 down to 0.75 (14 rows); the review columns fill in as the review completes.

**Section 5 — Incorrect matches: difference reasons.** The reasons change every time, so the list is **not fixed**.
Build it from the review itself: in the first reason cell of each block use
`=SORT(UNIQUE(FILTER(ManufacturerWide!$O$2:$O,(ManufacturerWide!$M$2:$M=1)*(ManufacturerWide!$O$2:$O<>""))))`
(`'Multiple ENR'` for the second block) with the cells below left empty for the spill, and per row
`=IF($B54="","",COUNTIFS(ManufacturerWide!$O:$O,$B54,ManufacturerWide!$M:$M,1))`, share `=IF($G$72=0,0,G54/$G$72)`,
total `=SUM(G54:G71)`.

**Section 6 — Examples** and the **Notes** (rows 45–48) are written by hand from the review; the note on the
sample size must state the per-band count actually used in the query.

## 4. Rules of thumb

- **No brand names left in a new brand's sheet.** After copying, `prepare_review_sheet.py` renames brand-named tabs,
  adds the `Enrichment Overview` tab (the template may not have it), clears the data and sets the title. Then read
  the new sheet back and confirm: tab names match section 3, no other brand's name appears in any tab or cell, and
  every tab the queries refer to exists. Fix anything missing before telling the user to paste.
- Tab names used in the query header comments must be the neutral names above.

- Same format for every brand; only the data and the typed inputs change.
- Hand the queries over; never run them. Ask the section 1 questions before writing, not after.
- The columns `Band watches`, `Expected enr percentage` and `ExpectedWatchCount` in the two summary-table tabs
  are informational (pasted values); `FINAL SUMMARY` does not read them.
