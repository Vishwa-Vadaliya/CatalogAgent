---
type: Knowledge Fact
title: Retail price
description: The retail price chain in EWMaster — tables, ids, the definitions and conditions (public/private, PriceLastSeenDate, IsSeenInLastRun, outliers), and the daily job order with what each stored procedure does.
tags: [knowledge, retail-price, pricing, crawl, mapping, outliers]
db: EWMaster (syncs into EveryWatch)
keywords: [retail price, MSRP, PriceLastSeenDate, IsSeenInLastRun, IsSeen, IsPrivate, IsVerified, private price, public verified, tbl_CAT_CatalogRetailPrice_d, tbl_RAW_Catalog, tbl_MAP_RawCatalog_CatalogCountry, outlier, DiscontinuedDate, production status, currency, country, AP, sp_map_rawCatalog_catalogCountry]
timestamp: 2026-11-04
---

# Retail price (EWMaster)

The whole retail price chain in one file: where the data sits, what the ids mean, the business
definitions, and the daily jobs that move it. Deep background and the case write-ups are in
[../Documents/RetailPrice/](../Documents/RetailPrice/index.md) — start there with `CONTEXT.md`.

## Tables

- `tbl_CAT_CatalogRetailPrice_d` (working, history table — one row per price change per CatalogID/CountryId/CurrencyId): CatalogRetailPriceID, CatalogID, Price (money), CurrencyId, CountryId (nullable), CreatedAt, StatusID, TransactionId, IsPrivate, IsVerified, IsSeenInLastRun, PriceLastSeenDate datetime2(3), IsPriceTaxIncluded. No IsActive column.
- `tbl_CAT_CatalogRetailPrice` (published): no StatusID, id not identity, column `isPriceTaxIncluded`.
- Currency `tbl_CAT_Currency_d` (CurrencyId, CurrencyName, CurrencyCode); country `tbl_CAT_Country_d`. Take country/currency **from the retail row**, and **LEFT JOIN** them (unverified prices often have no CountryId).
- Filter currency by **name** (`CurrencyName = 'CHF'`), not code.
- `tbl_RAW_Catalog` (crawler rows: Id, ReferenceNo, Manufacturer, SourceId, Location, Price float, Currency text, IsSeenInLastRun, IsDeleted, CreatedDate, UpdatedDate, TransactionId, URL…). Mirror `Mirror.EWMaster.tbl_RAW_Catalog_m` = older versions; full history = mirror + live row.
- `tbl_MAP_RawCatalog_CatalogCountry`: RawCatalogId, CatalogId, CountryId, IsSeenInLastRun, IsDeleted, PriceLastSeenDate, IsPriceTaxIncluded… Read directly per (CatalogId, CountryId), no MAX/GROUP BY per pair, and no `IsDeleted` filter. Ambiguous matches → `…_Ambiguous`.
- `tbl_sourceManufacturer_mapping`: SourceId → brand, location, expected currency. `CatSourceName` starting 'OFFICIAL' / 'Official Website' = official source. `tbl_RAW_Source` = source label only.
- `tbl_CAT_RawCatalogMapping` (CatalogId, RawReferenceNumber) = manual raw-ref overrides used by the reference guard.
- `tbl_cat_RetailPrice_SyncLog` = watermark for the incremental job (row 3 is a 'Dummy' seed).
- `RawCatalogUpdatedDate` is unused — ignore it.
- `tblPriceHistory` (EveryWatch DB, ~158M rows) is **dual-purpose**: it's an append-only audit table (price changes written during marketplace sync) **and** a live read source for the website's price-history feature. Don't exclude it from analytical joins as if it were disposable log noise.

## Ids

- StatusID 1 = active, 2 = outlier / pending review, 3 = deleted.
- IsPrivate 0 = public, 1 = private. IsVerified 1 = from the manufacturer's official website.
- CurrencyId 14 = CAD (CountryId 39 Canada); 133 = SGD (199 Singapore); 9 = USD, 8 = CHF, 13 = EUR (?); CountryId 214 = Switzerland, 233 = USA (?).
- AP crawl SourceIds 13989, 15096–15105. Rolex raw SourceIds 13987, 15032–15043. Other sources 14112–14135.

## Definitions & conditions

- **Public verified price** = `IsPrivate = 0 AND IsVerified = 1 AND StatusID = 1`. **Private** = `IsPrivate = 1 AND StatusID = 1`.
- **PriceLastSeenDate** = last time the source showed exactly the price we publish.
  - Older price in a series → `CreatedAt` of the next newer price.
  - Latest public price of a (CatalogID, CountryId) → the map's PriceLastSeenDate; if the map has none, leave it (never overwrite with NULL).
  - Non-public-verified fill → scope `IsPrivate = 1 OR IsVerified = 0`; never touch public verified rows there.
  - Compare CreatedAt vs PriceLastSeenDate as `date`. Flag per row (`CreatedAfterLastSeen`) and per pair (`PairHasIssue`).
- **IsLatest** is derived: newest by `CreatedAt DESC, CatalogRetailPriceID DESC`, partitioned by (CatalogID, CountryId, CurrencyId) for private; (CatalogID, CountryId) in the public fix.
- **IsSeenInLastRun** = still listed on the official site in the last crawl. **NULL ≠ 0** — count only 0 and 1. `= 0` = dropped out of the last run.
- Raw seen-status categories: Never seen / Always seen / Flips – latest seen / Flips – latest not seen / No 0/1 data, plus FirstZeroDate, LastZeroDate, FlipPattern (`0 > 1 > 0`).
- Production status from crawl: `MAX(IsSeenInLastRun)` over active map rows per CatalogId. Status 2 with max 1 → should be 1; status 1 with max 0 → report only.
- Ref in production in month M → latest public price's PriceLastSeenDate ≥ M (fall back to latest private; skip NULL).
- **DiscontinuedDate** (AP out-of-production) = MAX(PriceLastSeenDate) across public verified prices in any currency/country.
- Latest-flag check → active + public + verified with `PriceLastSeenDate IS NULL`.
- Retail analysis → `StatusID = 1`, then per currency and per country (distinct catalogs/refs, verified vs not, private vs public).
- Automation rule: add a raw price only if CreatedAt > catalog's latest price and the price differs (latest 5000; incoming 5000, 5600, 5700 → add 5600, 5700; a later return to 5000 is added again).
- Outliers: compare each row with previous and next price in the same catalog/currency/country (LAG/LEAD), flag PREV/NEXT/BOTH when > 45%. Don't use the first price as a fixed base. The insert SP uses ~50% → StatusID 2.
- A deviation > 30% from the USD median can be genuine → verify on the official site in that currency.
- Precomputed temp values (Median…) → use only for rows in that temp table, NULL otherwise; include all currencies.
- EUR vs USD competing (no country, unverified) → keep EUR, else USD, else manual review (KeepFlag).
- Same-day duplicates → group on date(CreatedAt) + CatalogID + CurrencyId + CountryId, `StatusID = 1`.
- `tbl_RAW_Catalog` "has price" → main table first, mirror only for 0/NULL rows; any non-zero non-null value; no `IN` against the mirror.
- Tax indication lock: once the map's `IsPriceTaxIncluded` is 0/1, a later raw flip or NULL is a crawl problem → abort.

## Jobs (daily order)

map (`sp_map_rawCatalog_catalogCountry`) → insert/update retail (`sp_update_CatalogRetailPrice_FromMapping`) → `sp_UpdateMap_PriceLastSeen` → `sp_Sync_PriceLastSeenDate_isSeenInLastRun` → `sp_PublishAllDataNew @validate = 0`.

- `sp_map_rawCatalog_catalogCountry`: maps raw → (CatalogId, CountryId), updates IsSeenInLastRun/IsDeleted/tax, strips Rolex 'm', parks ambiguous rows. Doesn't write PriceLastSeenDate.
- `sp_update_CatalogRetailPrice_FromMapping`: incremental by TransactionId watermark; gates: currency, reference guard (does **not** strip Rolex 'm' → blocks ~21,400 Rolex raws), same-day dedup, 50% outlier. Advances the watermark even with 0 inserts.
- `sp_Insert_CatalogRetailPrice_FromMapping`: full backfill (`@DryRun`).
- `sp_UpdateMap_PriceLastSeen`: live raw price = published price → raw UpdatedDate; else last mirror snapshot with same price+currency (window by Id, Location). Skips same-date updates.
- `sp_Sync_PriceLastSeenDate_isSeenInLastRun`: now syncs only IsSeenInLastRun (PriceLastSeenDate part commented out); one-time scripts fill dates.
- `ResyncCatalogRetailPriceToEW` (EveryWatchDDL): MERGE into `tblReferenceNumberMSRP_d` → published; `usp_ConvertReferenceNumberMSRPCurrency` fills converted currencies.
- `sp_SYNC_SyncWatchesCatalog` (~hourly) loads crawler data into `tbl_RAW_Catalog` — upstream of this whole chain. Full detail: [../Documents/RetailPrice/11-mirror-effective-date-and-upstream-sync.md](../Documents/RetailPrice/11-mirror-effective-date-and-upstream-sync.md).

## See also

- [references-and-models.md](references-and-models.md) — the Rolex leading-'m' exception that the reference guard trips over.
- [databases.md](databases.md) — the mirror DB and how to read it by id.
