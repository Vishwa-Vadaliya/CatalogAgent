---
type: Document
title: PriceLastSeenDate and IsSeenInLastRun (public verified) — current state and target rule
description: Where PriceLastSeenDate and IsSeenInLastRun are written today for public verified retail prices, the confirmed target rule, the gap between them, and what is out of scope (private, non-verified, production status).
tags: [documents, retail-price, catalog, price-last-seen-date, is-seen-in-last-run]
timestamp: 2026-10-28
Status: Reviewed with the owner on 2026-10-28 (scope, target rule, open points answered)
Last verified: 2026-10-28 against ew-db commit 2503da57 (MasterDB DDL = live export of 2026-09-28) plus owner clarification
---

# PriceLastSeenDate and IsSeenInLastRun (public verified) — current state and target rule

## 1. Scope (confirmed by the owner)

- **In scope: public verified prices only** — `tbl_CAT_CatalogRetailPrice_d` rows with `IsPrivate = 0 AND IsVerified = 1` (and `StatusID = 1`). These are the only rows the retail SPs create or update.
- **Out of scope:** private prices and non-verified prices. Their `PriceLastSeenDate` (for example from a discontinued date) is not handled by these SPs and is not part of this work. The case documents 06–09 describe them for context only.
- **Later phase: reference production status** (`tbl_CAT_Catalog_d.RefProductionStatusID`) and `DiscontinuedDate`. They are a separate part of the catalog, not retail price. Once the retail price SP changes are finished, the next step is how production status is kept up to date in the catalog table.

## 2. The two fields

| Field | Lives on | Meaning |
|---|---|---|
| `IsSeenInLastRun` | `tbl_RAW_Catalog`, `tbl_MAP_RawCatalog_CatalogCountry`, draft and published retail | The listing was on the manufacturer's site at the last crawl. Per country. |
| `PriceLastSeenDate` | MAP, draft and published retail | The last day a price was valid on the manufacturer's site. |

## 3. Target rule for `PriceLastSeenDate` (confirmed)

Per (CatalogID, CountryId), public verified prices ordered by `CreatedAt`:

| Row | `PriceLastSeenDate` |
|---|---|
| Older price (a newer price exists) | `CreatedAt` of the **next** price |
| Latest price | The date from crawling: the MAP `PriceLastSeenDate` (from `sp_UpdateMap_PriceLastSeen`, section 4.3). NULL while the price is still live on the site. |

**Previous rule (dropped):** every row of the pair, history and latest, got the same date (the MAP date). That is why the date part of `sp_Sync_PriceLastSeenDate_isSeenInLastRun` is commented out in the live database.

Example, pair with three prices:

| CreatedAt | Price | `PriceLastSeenDate` |
|---|---|---|
| 2025-01-10 | 5,000 | 2025-06-01 (next price's CreatedAt) |
| 2025-06-01 | 5,300 | 2026-02-15 (next price's CreatedAt) |
| 2026-02-15 | 5,600 | MAP date (NULL if still on the site) |

## 4. Who writes what today

| Step | Procedure | `IsSeenInLastRun` | `PriceLastSeenDate` |
|---|---|---|---|
| Load | `sp_SYNC_SyncWatchesCatalog` | RAW: copied from the crawler (only 0/1 rows are loaded) | — |
| Map | `sp_map_rawCatalog_catalogCountry` | MAP: 1 only when RAW = 1, else 0 | MAP: NULL on insert; not updated |
| Insert | `sp_update_CatalogRetailPrice_FromMapping` | New retail rows: 0 | New retail rows: NULL |
| Last seen on MAP | `sp_UpdateMap_PriceLastSeen` (called at the end of the insert SP) | — | MAP (rule in 4.3) |
| MAP → retail | `sp_Sync_PriceLastSeenDate_isSeenInLastRun` (normally called by the insert SP after UpdateMap; see 4.2) | Retail = MAX over the pair's active MAP rows, on **every** public verified active row of the pair (intended) | **Commented out in live** (old all-rows rule) |
| Publish | `sp_PublishAllDataNew` step 7 | copied when `TransactionID` went up | copied |
| App DB | `ResyncCatalogRetailPriceToEW` (EveryWatchDDL) | copied to `tblReferenceNumberMSRP_d` | copied |

### 4.1 Note on the ew-db copy

The ew-db file `MasterDB/dbo/stored procedures/sp_Sync_PriceLastSeenDate_isSeenInLastRun.sql` (live export of 2026-09-28) still has the date part **active**. The owner confirms the live SP has it commented out. **The repo copy is stale for this SP.** Read the live definition before changing it.

### 4.2 How the sync SP runs

It is part of the daily insert SP: `sp_update_CatalogRetailPrice_FromMapping` calls `sp_UpdateMap_PriceLastSeen` and then the sync SP. The call to the sync SP is **commented out temporarily** while the owner tests it by hand with a dry run (owner, 2026-10-28). It is not a separate job step.

### 4.3 `sp_UpdateMap_PriceLastSeen` (MAP date — the "crawl date" for the latest price)

For each active MAP row, take the pair's latest public verified price (`StatusID=1`, newest `CreatedAt`, then id). First match wins:

1. MAP `IsSeenInLastRun = 1` and RAW price ≠ 0 → **NULL** (still on the site).
2. No public verified price for the pair → **NULL**.
3. RAW still shows that price (whole-number compare, same currency name) → RAW `UpdatedDate`.
4. Else → latest Mirror `EffectiveDate` where the Mirror price equals the retail price; NULL if none.

Written only when the date part changes.

## 5. Gap between today and the target rule

| Part of the target rule | Implemented today? |
|---|---|
| Latest price's date comes from the crawl | MAP has the date (4.3), but nothing copies it to the retail row (sync date part is commented out). |
| Older price's date = next price's `CreatedAt` | Existing data: **applied by a one-time fix** (owner confirmed; backup table `tbl_CAT_CatalogRetailPrice_d_PLSD_BK_24092026`, around 2026-09-24). New data: not in any SP. |
| Insert of a new price | The insert SP writes the new row with NULL date. It does not set the previous latest row's date to the new row's `CreatedAt`. |

## 6. Decisions (owner, 2026-10-28)

| # | Point | Decision |
|---|---|---|
| 1 | "Older = next `CreatedAt`" on existing data | Already applied by a one-time fix. |
| 2 | `IsSeenInLastRun` on retail | Keep the crawl flag on **all** public verified rows of the pair (history and latest), as the sync SP does today. |
| 3 | How the sync SP runs | Called inside the insert SP; call commented out only for manual dry-run testing. |
| 4 | Scope of changes | MasterDB only. `ResyncCatalogRetailPriceToEW` (app copy) is out of scope; it keeps copying what is published. |
