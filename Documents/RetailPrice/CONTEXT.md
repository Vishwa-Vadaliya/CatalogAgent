---
type: Document
title: Retail price (catalog side) — context for a new chat
description: Short context to hand to a new chat before working on catalog retail price: scope, flow, tables, procedures, flag rules, known gaps and where everything lives.
tags: [documents, retail-price, catalog, context]
timestamp: 2026-10-28
---

# Retail price (catalog side): context for a new chat

Paste or point the new chat at this file, then at [index.md](index.md) for detail.

## Scope
Catalog side only: crawler -> `tbl_RAW_Catalog` (+ Mirror `tbl_raw_catalog_m`) -> MAP `tbl_MAP_RawCatalog_CatalogCountry` -> draft `tbl_CAT_CatalogRetailPrice_d` -> publish into `tbl_CAT_CatalogRetailPrice`. Out of scope: the EveryWatch app DB, `tblReferenceNumberMSRP*`, views/feeds, `tbl_CAT_RetailPriceUSD` (not in use). The documents describe the flow **as it runs today**, not proposals. They are a draft: the owner has not reviewed all of them, so do not assume every statement is correct.

## Flow and procedures
1. `sp_SYNC_SyncWatchesCatalog`: crawler -> RAW (job schedule to confirm).
2. `sp_map_rawCatalog_catalogCountry`: RAW -> MAP (Rolex `m` strip; a tax-flag conflict aborts the whole run). Called by the update SP.
3. `sp_update_CatalogRetailPrice_FromMapping` (**in use, confirmed**): daily incremental into the draft. Watermark = `MAX(MaxRawCatalogTransactionId)` in `tbl_cat_RetailPrice_SyncLog`; reference guard; currency/source gate (`tbl_sourceManufacturer_mapping`); outlier rule over 50% -> `StatusID` 2 (pending); same-day collapse; inserts with `IsVerified=1`, `IsPrivate=0`, `IsSeenInLastRun=0`, `PriceLastSeenDate` NULL; advances the watermark even with 0 rows; calls the map SP first and `sp_UpdateMap_PriceLastSeen` last.
4. `sp_UpdateMap_PriceLastSeen`: sets `PriceLastSeenDate` on MAP.
5. `sp_Sync_PriceLastSeenDate_isSeenInLastRun`: copies MAP `IsSeenInLastRun` to retail rows. Its `PriceLastSeenDate` part is commented out in live (owner confirmed) because the date rule changed; the ew-db copy is stale and still shows it active. It is called by the insert SP; the call is commented out only while the owner dry-runs it by hand. See [10-last-seen-seen-flag-production-status.md](10-last-seen-seen-flag-production-status.md).
6. `sp_PublishAllDataNew` step 7: update/insert `StatusID=1`, delete `StatusID=3`, by `TransactionID`.
Not in use: `sp_Insert_CatalogRetailPrice_FromMapping` (confirmed). Others to confirm (see `sp/07`).

## Scope of the current work (owner, 2026-10-28)
- Only **public verified** prices (`IsPrivate=0`, `IsVerified=1`). Private and non-verified prices are not handled by these SPs.
- `PriceLastSeenDate` target rule: an older price = `CreatedAt` of the next price; the latest price = the crawl date (MAP `PriceLastSeenDate`). The old rule (one date on all rows of a pair) is dropped.
- Reference production status and `DiscontinuedDate` are a **later, separate phase** (catalog, not retail price).

## Key meanings
- `StatusID` (draft): 1 active, 2 pending outlier, 3 deleted. The published table has no `StatusID`.
- Public verified = `IsPrivate=0 AND IsVerified=1 AND StatusID=1`. Stream = (`CatalogID`, `CountryId`, `CurrencyId`, `IsPrivate`, `IsVerified`). Pair = (`CatalogID`, `CountryId`).
- Production status: `tbl_CAT_Catalog_d.RefProductionStatusID` -> `tbl_CAT_Reference_ProductionStatus_d` (1 In Production, 2 Out of Production, 3 Phasing Out, NULL none).
- `PriceLastSeenDate` = last day the watch was on the website or had the price. `IsSeenInLastRun` = still listed at the last collection.

## Rules the team states about the data
- Verified public: `IsSeenInLastRun` is per country; Seen = 0 always has a last-seen date.
- Non-verified: always Seen = 1; a date exists only if the reference has a discontinued date (from WatchBase and WatchCharts, the later date wins). Shown publicly only if verified prices are not available.
- Private: always `IsVerified=1` and Seen = 1.
- History: an older price's last-seen date is the next price's created date; the latest price often has none.
- Sources of prices: the manufacturer's website, other sources, or an external trusted person (for example Thomas) who gives us a price.
- No production status: many brands have no crawled data; Richard Mille and F.P. Journe have only non-verified prices; Parmigiani is the only Phasing Out brand.

## Points to discuss and known gaps
- About 3,000 to 4,000 non-verified retail prices have `PriceLastSeenDate` earlier than the price's created date (the date is the discontinued date, created is when we collected it). Fixed only for WatchBase.
- WatchCharts shows 2026 dates even for references still in production.
- Private prices of Out of Production watches have no last-seen date and there is no discontinued-date data to fill it.
- To confirm: SQL Agent job names/schedule/order, whether the sync SP runs as its own step, which one-time SPs are used, who fills `tbl_RAW_Catalog.IsPriceTaxIncluded`, and where the "older date = next created date" rule is applied (the daily update SP does not do it).

## Where things are
- Documents: this folder. Cases for management: `06`, `09`; technical: `07`; mixed: `08`; counts: `05`.
- Queries: `../../Queries/Janvi/RetailPrice/` (group counts, latest-only, edge cases).
- A published page of the simple cases (artifact): https://claude.ai/artifact/XBchsy6yzdF7iA8TStbJ7Q

## Working rules (from `Rules/00-core.md` and `Rules/10-sql-style.md`)
Never run SQL yourself: write the script, the user runs it. No `DECLARE` variables (use a `#Params` temp table). Temp tables, not CTEs. `WITH (NOLOCK)` after the alias, never inside `UPDATE ... FROM`. Check the table schema in `D:\EW\ew-db\MasterDB` first. Do not edit anything in `ew-db` unless told to.
