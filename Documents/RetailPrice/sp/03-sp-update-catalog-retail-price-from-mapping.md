---
type: Document
title: sp_update_CatalogRetailPrice_FromMapping
description: Step-by-step of sp_update_CatalogRetailPrice_FromMapping, the daily update into the draft retail price table (20 steps).
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_update_CatalogRetailPrice_FromMapping.sql (~1116 lines)
---

# sp_update_CatalogRetailPrice_FromMapping

## In plain words

This is the heart of the flow, and the only place a retail price row is created. Each day it looks at what the crawler loaded since the last run, takes each linked listing's price history, and works out the real price changes: "on this date the price became X". It throws away prices that are noise (wrong currency, wrong reference, several on one day, the same as the previous one). A price that jumps more than 50% is not trusted: it is saved as "pending" so a person can check it, and it is not published. What is left is added to the draft retail price table. It then remembers how far it has read, so the next run only looks at newer data.

**Status:** **in use (confirmed).** (Its older sibling `sp_Insert_CatalogRetailPrice_FromMapping` is not in use.)

## Technical detail

**Parameters:** `@DryRun bit = 1` (preview only), `@SeedMaxTransactionId bigint = NULL` (used only if the SyncLog is empty), `@InsertedRowCount int OUTPUT`. `SET XACT_ABORT ON`.

**Reads:** `tbl_MAP_RawCatalog_CatalogCountry`, `tbl_RAW_Catalog`, Mirror, `tbl_CAT_Catalog_d`, `tbl_CAT_RawCatalogMapping`, `tbl_RAW_Source`, `tbl_CAT_Currency_d`, `tbl_sourceManufacturer_mapping`, `tbl_CAT_CatalogRetailPrice_d`, `tbl_cat_RetailPrice_SyncLog`.
**Writes:** `tbl_CAT_CatalogRetailPrice_d` (insert only), `tblTransaction`, `tbl_cat_RetailPrice_SyncLog`; indirectly MAP (through the two SPs it calls).

### Steps
1. **Run `sp_map_rawCatalog_catalogCountry` first** (unguarded). This happens even on a dry run, so a "dry run" still changes MAP and can abort on a tax-flag conflict.
2. **Read the watermark:** `MAX(MaxRawCatalogTransactionId)` over the whole SyncLog table (dates ignored). If the log is empty, use `@SeedMaxTransactionId` or 0.
3. **Find which catalog + country pairs already have a public draft price** (`StatusID = 1`, `IsPrivate = 0`).
4. **List active mapped pairs** (active MAP row, active catalog `StatusID = 1`, RAW row not deleted). A pair with no retail price yet is flagged "needs full history".
5. **Collect history from the Mirror.**
   - *Pairs that already have a price:* only mirror rows whose `TransactionId` is above the watermark, and only if the current RAW row's `TransactionId` is also above the watermark.
   - *New pairs:* the whole mirror history.
   - Mirror rows marked deleted are excluded.
6. **Work out each mirror row's EffectiveDate.**
   - *New pairs:* if the row has an `UpdatedDate` and an earlier row in the same (listing, location, currency) series also had one, use it; else if it is the first row use `CreatedDate`; else use the previous row's `MirrorDate`. (The crawler did not always fill `UpdatedDate`, so early rows are dated by the previous snapshot.)
   - *Existing pairs:* `UpdatedDate` only; rows with a NULL `UpdatedDate` are dropped.
7. **Add the current RAW row** if its `TransactionId` is above the watermark (or the pair needs full history). EffectiveDate = RAW `UpdatedDate`.
8. **Reference guard** (applied to every mirror and RAW row): the cleaned `ReferenceNo` must be non-empty and equal the catalog's cleaned `ReferenceNumber` or a spelling in `tbl_CAT_RawCatalogMapping` for that catalog. Failing rows are dropped silently.
9. **Validity, currency and source gate:** country present; `Price` > 0; currency present and found in `tbl_CAT_Currency_d` (`StatusID = 1`, matched on name); EffectiveDate present; the source must exist in `tbl_sourceManufacturer_mapping` (inner join; unmapped sources are dropped) and, if that mapping has a `Currency`, the row's currency must equal it.
10. **Keep only real price changes.** Per (catalog, country, currency) in date order, keep the first row and any row whose price differs from the previous one.
11. **Drop what already exists:** same catalog, country, currency and price with `CreatedAt` on the same calendar day as the candidate (rows with StatusID 1, 2 or 3, `IsPrivate = 0`). This makes re-runs safe.
12. **Baseline for comparison:** the latest existing public **verified** draft price (`StatusID = 1`, `IsPrivate = 0`, `IsVerified = 1`) for the (catalog, country, currency); if none exists, the newest surviving candidate in this run.
13. **Outlier rule:** `% difference = (price - baseline) / baseline * 100`. If the absolute value is **strictly greater than 50** the row gets StatusID 2 (pending), otherwise 1. A baseline of 0 or missing gives no percentage and StatusID 1. No currency conversion; the comparison is within one currency.
14. **Same-day collapse:** per (catalog, country, currency, calendar day) keep only the row with the latest timestamp.
15. **Duplicate chain removal:** a StatusID 1 row with the same price as the previous accepted row in this run is dropped. A StatusID 1 row equal to the latest catalog price that follows an unresolved outlier in this run is itself set to StatusID 2.
    - Example (from the SP header): catalog price 5000; an outlier 50000 arrives; then 5000 again. The 5000 is inserted as StatusID 2 until someone resolves the outlier.
16. **Merge with the existing latest row** on one timeline and keep a candidate only if its calendar day is strictly later than the previous point **and** its price differs from it.
17. **Dry run:** return the watermark used, then the rows that would be inserted; write nothing.
18. **Real run** (one transaction):
    - Take the new watermark: `MAX(TransactionId)` of the **whole** `tbl_RAW_Catalog` table.
    - Insert a `tblTransaction` row (type 1, user 1).
    - Insert the rows into `tbl_CAT_CatalogRetailPrice_d` with: `CreatedAt = EffectiveDate`, `StatusID` 1 or 2, `IsPrivate = 0`, `IsSeenInLastRun = 0`, `PriceLastSeenDate = NULL`, **`IsVerified = 1`**, `TransactionId` = the batch transaction. `IsPriceTaxIncluded` is not written.
    - Insert a SyncLog row: `Success`, `RowsInserted`, new watermark. This happens **even when 0 rows were inserted**, so the watermark always moves forward.
    - Commit.
19. **After commit,** run `sp_UpdateMap_PriceLastSeen`. The call to `sp_Sync_PriceLastSeenDate_isSeenInLastRun` is commented out.
20. **On error:** roll back, write a `Failed` SyncLog row carrying the old watermark, and re-throw.

## Behaviour worth knowing
- It only inserts. It never updates or soft-deletes existing retail rows.
- A candidate on the same calendar day as the latest existing row is never inserted (a same-day correction is lost for that day).
- Prices flow only from official sources (via MAP) and only for pairs that are mapped.
