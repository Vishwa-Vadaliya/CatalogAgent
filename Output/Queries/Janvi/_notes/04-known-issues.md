---
type: Document
title: Known Issues and Risks in the Current Flow
description: 28 known issues in the current retail price SPs and process, grouped A-F with priority and location.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium (from reading code; none of these were reproduced by running SQL except where noted)
---

# Known Issues and Risks in the Current Flow

## In plain words

The flow works, but there are weak spots. The most important ones for the business: (a) some Rolex prices may never be added because of a reference mismatch, (b) the daily job can permanently skip data it could not use that day, (c) one inconsistent tax flag can stop all mapping, and (d) several comments in the code no longer match what the code does. Each issue below says what it is, why it matters, and where it is.

Priority: **High** = can lose or block price data; **Medium** = can give wrong or stale data; **Low** = maintenance.

## A. Price data can be skipped or blocked

| # | Priority | Issue | Where |
|---|---|---|---|
| 1 | High | **The watermark moves forward even when nothing was inserted.** The update SP sets the new watermark to the highest RAW `TransactionId` in the whole table and logs Success with 0 rows. Listings that were filtered out (unmapped, wrong reference, wrong currency, unmapped source) are never looked at again by the daily run, even if the cause is fixed later. Recovery needs a lower watermark in the log or a different SP. | update SP, ~1019-1022; `tbl_cat_RetailPrice_SyncLog` |
| 2 | High | **Rolex `m` prefix mismatch.** The map SP strips a leading `m` from Rolex references (and can rebuild a blank reference from `ArtworkId` or the Mirror). The update SP's reference guard does not, and requires a non-empty reference. A Rolex listing mapped via those rules fails the guard and is dropped silently unless `tbl_CAT_RawCatalogMapping` also holds that spelling. Observed case: USD 40900, CatalogId 210390, CountryId 233, RAW 384661. About 21,400 mapped raws were estimated to be affected (13 Rolex sources at 1,644 each, plus 64 from source 17168). The two reference-cleaning functions (`UDF_ExtractNumbersAndAlphabets` in EveryWatch vs `fn_ExtractNumbersAndAlphabets`) are also separate and could diverge. | map SP ~210-260; update SP guard ~239, 300, 450 |
| 3 | Medium | **Watermark race.** The new watermark is read after candidates were built. Crawler rows committed in between are skipped permanently. | update SP ~1019-1022 |
| 4 | Medium | **Sync step temporarily not called.** The Sync call in the update SP is commented out while the owner dry-runs it by hand; until it is re-enabled, new retail rows keep `IsSeenInLastRun = 0` unless the sync is run manually. | update SP ~1081-1082 |
| 5 | Medium | **A dry run is not side-effect free.** The update SP runs the map SP first even on a dry run, so MAP is changed and an error can occur. | update SP ~72 |
| 15 | Medium | **Same-day corrections are lost.** A candidate on the same calendar day as the latest existing row is never inserted; same-day collapse keeps only the last point of the day. | update SP |
| 16 | Medium | **Incremental mirror history is lossy.** For pairs that already have a price, mirror rows with NULL `UpdatedDate` are dropped and mirror rows are used only if the current RAW row is also above the watermark. Price changes visible only through such rows are never captured. | update SP ~182-243, 347 |
| 17 | Medium | **No date gate against the existing price in the incremental SP.** An older candidate could be inserted as a back-dated row (inferred from the logic, not tested). | update SP |
| 18 | Medium | **Failed row after a successful commit.** If `sp_UpdateMap_PriceLastSeen` throws after the commit, a `Failed` log row is written and the error re-thrown even though prices and the Success row were committed. | update SP ~1081 |
| 19 | Low | **Outlier edge cases.** Exactly 50.0% is not an outlier. A key with no baseline uses its own newest candidate as the baseline. A baseline of 0 gives no percentage and the row is StatusID 1. | update SP |

## B. The map

| # | Priority | Issue | Where |
|---|---|---|---|
| 6 | High | **One inconsistent tax flag aborts the whole mapping run.** If a locked `IsPriceTaxIncluded` on any active MAP row becomes NULL or different on RAW, the map SP raises an error and rolls back everything (refresh and inserts for all sources) until the data is fixed. Because the update SP runs the map SP first, it stops too. | map SP ~129-174 |
| 7 | Medium | **Only one listing per catalog + country is mapped.** If several official sources in the same country list the same watch, only the latest-updated RAW row is mapped; the others are skipped silently (not recorded as ambiguous). | map SP ~465-505 |
| 8 | Medium | **No re-matching.** A RAW row already mapped keeps its catalog even if its reference is corrected later. Refresh covers `IsDeleted` and `IsSeenInLastRun` only, and is not limited to official sources. | map SP ~105-117 |
| 20 | Medium | **Manual mapping lookup ignores the manufacturer.** Two manufacturers with the same cleaned reference could cross-match; the catalog fallback does filter by manufacturer. | map SP ~334 |
| 14 | Low | **Performance.** A scalar function runs per row on three tables, and correlated string aggregation re-runs it for every ambiguous row. `NOLOCK` allows dirty reads. The mirror and linked server are used inside the same transaction. | map SP |

## C. Loading and history

| # | Priority | Issue | Where |
|---|---|---|---|
| 9 | Medium | **The 5000-row batch has no ORDER BY**, so a different subset can be taken each run; backlogs take several runs. | load SP ~249 |
| 10 | Medium | **Only crawler rows with `IsSeenInLastRun` 0 or 1 are loaded.** A row stuck at 2 or 3 never updates RAW, so its price can stay stale. The meaning of 2 and 3 is not documented in the repo (crawler is external). The daily map SP counts only 1 as seen; the OneTime SPs count 1 or more. | load SP ~390; map SP |
| 11 | Medium | **`IsPriceTaxIncluded` is never written by the load SP**, and is absent from the mirror trigger and mirror table. Nothing in the repo is found that fills it on RAW; it may be set outside the repo (to confirm). If it is never filled, the map's tax lock stays NULL, and retail rows also get NULL. | load SP; mirror trigger |
| 12 | Low | **The mirror trigger writes through a linked server** inside every RAW update; if the linked server is down, the RAW update fails. It saves old versions only, nothing on insert, and honours `SkipMirror`. Its `@oper` variable is unused. | `tbl_RAW_Catalog` trigger |
| 13 | Low | **Debug leftover:** `EWMaster.dbo.TempWatches` is dropped and recreated on every load run; unsafe if two runs overlap. | load SP ~872 |

## D. Last-seen dates and flags

| # | Priority | Issue | Where |
|---|---|---|---|
| 21 | Low | **Loose price comparison.** Prices are compared as money then whole numbers, so 100.4 and 100.0 are treated as equal; currency is compared by text name. | UpdateMap SP ~68, 150 |
| 22 | Medium | **Dates are period-start dates.** A mirror row holds an old price with the date it started; RAW `UpdatedDate` is also a "changed" date. Whether that equals "last seen" depends on intended meaning (to confirm with the author). | UpdateMap SP |
| 20b | Medium | **Mirror date rule differs from the written rule.** The SP counts earlier non-null `UpdatedDate` rows but does not use the count; it uses any non-null `UpdatedDate`, including the first stale row after the crawler fix. It partitions by (id, location) where the written spec uses id only, and filters deleted rows before taking the previous row. | UpdateMap SP ~99-126; Ravi\Retail Price\mirror-updated-date-issue.md |
| 23 | Low | **Sync updates the whole history of a pair** (all qualifying rows, not just the latest), and writes an empty `tblTransaction` row every run even when nothing changes. | sync SP ~118-136 |
| 24 | Low | **Stale headers.** The sync SP header still describes the date being synced; the update SP header says it calls Sync. | sync SP; update SP |
| 27 | Low | **Draft-table mirror trigger skips `IsVerified` and `IsPriceTaxIncluded`**, so history of those two columns is not kept. | `tbl_CAT_CatalogRetailPrice_d` trigger |

## E. Publish

| # | Priority | Issue | Where |
|---|---|---|---|
| 25 | Medium | **Publish depends on `TransactionId` increasing.** A draft change that does not raise `TransactionId` is never published. | publish step 7 |
| 26 | Medium | **A published row later set to StatusID 2 stays live with old values** (not updated, not deleted). | publish step 7 |
| 28 | Low | The whole publish runs in one transaction (thousands of lines), so locking and rollback cover all steps. | `sp_PublishAllDataNew` |

## F. Structure and documentation debt

- Many scratch or backup tables sit next to real ones.
- The job schedule and step order are not in any repository (to confirm).
- `sp_ProcessUpdatedRetailPrices`, `sp_Insert_CatalogRetailPrice_FromMapping` and `tbl_RetailPrice_SP_RunLog` need an owner decision (retire or keep).
