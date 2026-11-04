---
type: Data Index
title: Queries/Janvi/RetailPrice index
description: Janvi's saved retail price (catalog side) queries: flag-group counts and the edge-case inventory.
tags: [index, queries, janvi, retail-price]
timestamp: 2026-10-28
---

# Queries/Janvi/RetailPrice — index

All read-only (SELECT / temp tables), no `DECLARE` variables, one result set in the last step. Documented in [../../../Documents/RetailPrice/index.md](../../../Documents/RetailPrice/index.md).

- `RetailPrice_DistinctGroups_Simple.sql` — `tbl_CAT_CatalogRetailPrice_d` rows with `StatusID = 1` grouped by production status, `IsSeenInLastRun`, `IsVerified`, `IsPrivate` and has-`PriceLastSeenDate`, with rows, catalogs, catalog + country pairs, and pairs with a single row versus history.
- `RetailPrice_DistinctGroups_LatestOnly.sql` — the same groups using only the latest active row per catalog + country pair. Appended steps: catalogs with no production status by manufacturer; a picker listing catalog, reference number and manufacturer for any flag group (`#PickGroup`); non-verified rows with `PriceLastSeenDate` later than `CreatedAt`.
- `RetailPrice_DistinctGroups_Catalog.sql` — the larger version with nine group sets (G1–G9). Kept for reference; the Simple and LatestOnly versions are the ones in use.
- `RetailPrice_PLS_Sync_Checks.sql` — checks for the new `sp_Sync_PriceLastSeenDate_isSeenInLastRun` rules on public verified rows (older = next `CreatedAt`, latest = map date, seen flag per map state), with a one-time backup step. Plan: [../../../Plans/janvi/retail_price_last_seen_date_continuous.plan.md](../../../Plans/janvi/retail_price_last_seen_date_continuous.plan.md).
- `RetailPrice_Rolex_Guard_Diagnostic.sql` — every active Rolex map row: current vs Rolex-aware reference guard result, pair has retail, RAW row behind the watermark. Plan: [../../../Plans/janvi/retail_price_rolex_reference_guard.plan.md](../../../Plans/janvi/retail_price_rolex_reference_guard.plan.md).
- `RetailPrice_PLS_MapDateBeforeCreatedAt_Diagnostic.sql` — pairs whose map `PriceLastSeenDate` is before the latest price's `CreatedAt`, with the RAW/Mirror price timeline (stale `UpdatedDate` cause). Plan: [../../../Plans/janvi/retail_price_last_seen_date_continuous.plan.md](../../../Plans/janvi/retail_price_last_seen_date_continuous.plan.md) section 10.
- `RefProductionStatus_BrandAnalysis.sql` — one row per brand plus a TOTAL row. It shows the crawl sources and whether the brand is in the map table, current status counts, what the daily rule would change for mapped catalogs, and for not-mapped catalogs: status, variations (parent), new catalogs and retail presence. It also covers DiscontinuedDate against status. Plan: [../../../Plans/janvi/ref_production_status_continuous.plan.md](../../../Plans/janvi/ref_production_status_continuous.plan.md).
- `RefProductionStatus_NoMapSource_Diagnostic.sql` — read-only. For brands with catalogs but no map rows (Nomos, Junghans, Ball, Glycine, …), one row per source with the counts at each gate of `sp_map_rawCatalog_catalogCountry` (source mapping, Official name, manufacturer/country, RAW rows, reference match, map rows) and the first gate that fails.
- `SP_Versions/` — copies of `sp_update_CatalogRetailPrice_FromMapping` for the Rolex fix: `_00_original` (ew-db master, before any change), `_v1_rolex_catchup` (guard fix + sync call + one-time `@RolexCatchUpFromTransactionId`), `_v2_final` (guard fix + sync call). Plan: [../../../Plans/janvi/retail_price_rolex_reference_guard.plan.md](../../../Plans/janvi/retail_price_rolex_reference_guard.plan.md).
- `RetailPrice_EdgeCases_Catalog.sql` — edge-case inventory, one category per insert (E01–E45), with thresholds in `#Params` and an empty Reason column in the summary for the team to fill.
- `RefProductionStatus_01_MapCountryNull_IsReconfigured.sql` — one-time setup before deploying the reference production status SPs: map `CountryId` → NULL (FK and filtered unique index dropped and recreated) and new `tbl_sourceManufacturer_mapping.IsReconfigured` filled from the Master Collection sheet. Plan: [../../../Plans/janvi/ref_production_status_continuous.plan.md](../../../Plans/janvi/ref_production_status_continuous.plan.md).
- `MapRawCatalog_WhyCatalogNotMapped.sql` — read-only. For one catalog (step 0, e.g. 230412), repeats the checks of `sp_map_rawCatalog_catalogCountry`: same-key catalogs, `tbl_CAT_RawCatalogMapping` matches, and per RAW row with the same key the map / ambiguous state and the first check that stops the mapping.
- `MapRemap_DeletedCatalog_Preview.sql` — read-only. Preview of the remap step in `sp_map_rawCatalog_catalogCountry`: active map rows on draft / deleted catalogs (StatusID 2, 3) and their outcome (Move / PairTaken / Ambiguous / NoMatch / BlankKey), with a per-brand summary.
