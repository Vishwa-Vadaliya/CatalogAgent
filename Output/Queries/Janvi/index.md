---
type: Data Index
title: Queries/Janvi index
description: Index of Janvi's saved SQL query files.
tags: [index, queries, janvi]
timestamp: 2026-10-26
---

# Queries/Janvi — index

- `Temp/AP_ModelName_Check.sql` — checks AP model names against the catalog side (`tbl_CAT_Model_d`/`tbl_CAT_Manufacturer_d`, with StatusID) and, separately, a second list against the watch/app side (`EveryWatch.dbo.tblModel`, ManufacturerId = 142, with IsDeleted flag).
- `Temp/Rolex_Patek_AP_StartingRef_ModelConsistency.sql` — Rolex/Patek/AP active (`tbl_CAT_Catalog_d`, StatusID = 1) `EntityType = 'Watch'` rows grouped by starting ref (leading digit run); lists starting-ref groups with more than one distinct `ModelId`, and for those checks whether the matching `EntityType = 'PartialReference'` row has a `ModelId` assigned, with a case count and full group list. Appended block: AP starting-ref list vs. a hand-supplied "correct model name" list, listing every active reference per starting ref with current vs. correct model and a Match/No match flag.
- `Temp/Watch_MultipleEnrichment_ByRefAndManufacturer.sql` — generalized "going in multiple enrichment" check, parameterized by reference number + manufacturer: resolves `ReferenceNumberId`/`ManufacturerId` once up front, then filters `tblWatch_d` by those ids only (never by the text columns); draft watches with no assigned enrichment (`ReferenceEnrichmentId IS NULL`) joined to `tbl_RE_DataToFix` candidate rows (no `IsFixed` filter), returning one row per watch with comma-separated candidate `RefEnrichmentId`s, reference number, watch id, primary image, and candidate count.
- `Temp/Watch_Title_Description_BezelColors.sql` — for a hand-supplied list of draft WatchIds: `tblWatch_d.Title`/`Description`, plus comma-separated bezel color name(s) via `TblWatchToBezelColor_d` → `tblColor.ColorName` (LEFT JOIN, blank if none).
- [RetailPrice/index.md](RetailPrice/index.md) — retail price flag-group counts (simple and latest-only), and the edge-case inventory, all read-only.
- `DialColor_Dedup/DialColor_BrownOmbre_Diagnostic.sql` — ECH-409: read-only diagnostic for the 3 duplicate "Brown ombrè" dial color ids (app-side `tblColor`), with draft/published watch counts per id, overlap check (watches assigned to more than one duplicate id at once), and the matching catalog-side (`tbl_CAT_Color_d`) rows found both via `tblColor.CatalogId` and via name match, for comparison.
- `DialColor_Dedup/DialColor_BrownOmbre_CheckMissingIds.sql` — ECH-409 follow-up: the full diagnostic only returned ColorId 4524 of the ticket's 3 ids; this does an unfiltered existence check on 4524/4545/4549, a broad `%ombr%` name sweep, and checks `tblAttributeMergeQueue`/`tblColorSynonym` for whether 4545/4549 were already merged away via `sp_UT_MergeColor` before this ticket was picked up.
- `Cartier/ECH-251_Enrichment75099_StopManufacturerWideMatch.sql` — ECH-251: looks up the CatalogId behind ReferenceEnrichmentId 75099 via `sp_Get_CatalogDetails @EnrichmentIds` (result into a **global** `##` temp table — a local `#` doesn't survive the SP's dynamic-SQL scope), then sets `EnrichmentSimilarityScore = 2` on that catalog row in the **draft** table only (`tbl_CAT_Catalog_d` — publish propagates draft → publish automatically, so the published `tbl_CAT_Catalog` row isn't touched directly) to stop manufacturer-wide image match (EnrichmentTypeId 5) from matching this atypical-looking Cartier reference going forward. Already-mismatched watches aren't touched — they self-correct on the next enrichment sync.
