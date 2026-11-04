---
type: Plan
title: PriceLastSeenDate continuous flow (public verified)
description: Plan to make the daily retail price flow keep PriceLastSeenDate correct on every run — latest price gets the mapping date, older prices get the next price's CreatedAt — by changing sp_Sync_PriceLastSeenDate_isSeenInLastRun and re-enabling its call in sp_update_CatalogRetailPrice_FromMapping.
tags: [plans, janvi, retail-price, price-last-seen-date, ewmaster]
timestamp: 2026-10-28
name: PriceLastSeenDate continuous flow
overview: Sync SP computes the target PriceLastSeenDate per public verified row (latest = map date, older = next CreatedAt) and updates only rows that differ; insert SP calls it again after UpdateMap. No change to the map SP, UpdateMap SP or publish.
todos:
  - id: decisions
    content: Owner answers the decisions in section 3
    status: completed
  - id: live-script
    content: Get the live definition of sp_Sync_PriceLastSeenDate_isSeenInLastRun (ew-db copy is stale) and of sp_update_CatalogRetailPrice_FromMapping
    status: completed
  - id: sync-sp
    content: Change sp_Sync_PriceLastSeenDate_isSeenInLastRun (section 4.1)
    status: completed
  - id: insert-sp
    content: Re-enable the sync call in sp_update_CatalogRetailPrice_FromMapping and update headers (section 4.2)
    status: completed
  - id: checks
    content: Write check queries in Queries/Janvi/RetailPrice; owner runs dry run, then real run (section 6)
    status: pending
  - id: docs
    content: Update Documents/RetailPrice (sp/03, sp/05, 10, CONTEXT, Knowledge §7) after the change is live
    status: pending
isProject: false
---

# PriceLastSeenDate continuous flow (public verified)

Background and current state: [Documents/RetailPrice/10-last-seen-seen-flag-production-status.md](../../Documents/RetailPrice/10-last-seen-seen-flag-production-status.md).

## 1. Requirement

For public verified retail prices (`tbl_CAT_CatalogRetailPrice_d`, `StatusID = 1`, `IsPrivate = 0`, `IsVerified = 1`), on every daily run:

| Row of a pair | `PriceLastSeenDate` |
|---|---|
| Latest price | The mapping date: `tbl_MAP_RawCatalog_CatalogCountry.PriceLastSeenDate` (NULL while still on the site) |
| Older price | `CreatedAt` of the next price |

Existing data was already fixed by the one-time fix (around 2026-09-24). This plan makes the daily flow keep it right from now on.

## 2. What happens today in one daily run, and what is missing

| Order | Step | Today | Missing for the requirement |
|---|---|---|---|
| 1 | `sp_map_rawCatalog_catalogCountry` | Map flags refreshed | nothing |
| 2 | Insert part of `sp_update_CatalogRetailPrice_FromMapping` | New price inserted with `PriceLastSeenDate = NULL` | The price that **was** latest is now older; its date must become the new price's `CreatedAt`. Nothing does that. |
| 3 | `sp_UpdateMap_PriceLastSeen` | Map date computed against the (new) latest price | nothing — this is already the "mapping date" |
| 4 | `sp_Sync_PriceLastSeenDate_isSeenInLastRun` | Call commented out; inside it the date part is commented out (old all-rows rule) | Copy the map date to the latest row only; set older rows to next `CreatedAt` |
| 5 | `sp_PublishAllDataNew` step 7 | Copies rows whose `TransactionId` went up | nothing, as long as step 4 sets a new `TransactionId` on changed rows |

So the gap is all in step 4 (and its call). One place fixes both cases: a new price arriving, and the map date changing for an unchanged latest price.

## 3. Decisions (owner, 2026-10-28)

| # | Question | Decision |
|---|---|---|
| D1 | What is a "pair" for latest / next price? | **`CatalogID + CountryId`** (no currency). Same as `sp_UpdateMap_PriceLastSeen`, which ranks per map row (one active map row per pair) by `CreatedAt DESC, CatalogRetailPriceID DESC`. |
| D2 | Public verified pairs with **no active map row** (prices added by hand) | **Older rows: apply the rule** (date = next price's `CreatedAt`). **Latest row: do not touch** — handled manually. `IsSeenInLastRun`: not touched (as today). |
| D3 | Latest row's date | **Map row exists → strict copy of the map date, including NULL.** No map row → keep whatever date the latest row has (it may be entered by hand). |
| D4 | Two prices of a pair with the same `CreatedAt` | Order by `CreatedAt`, then `CatalogRetailPriceID`. The older one gets a date equal to its own `CreatedAt` — accepted. |

Summary of the target per row:

| Pair has an active map row? | Row | `PriceLastSeenDate` | `IsSeenInLastRun` |
|---|---|---|---|
| Yes | Older | next price's `CreatedAt` | map flag |
| Yes | Latest | map date (NULL copied as NULL) | map flag |
| No | Older | next price's `CreatedAt` | unchanged |
| No | Latest | unchanged | unchanged |

`StatusID` 2 (pending outlier) and 3 (deleted) rows are left out of the chain. If a pending row is approved to 1 later, the next run recalculates the dates around it.

## 4. Changes by SP

### 4.1 `sp_Sync_PriceLastSeenDate_isSeenInLastRun` — main change

Start from the **live** definition (the ew-db copy still has the old date logic active).

0. Scope of rows: all public verified active rows (catalog `StatusID = 1`), **not only pairs with a map row** (change from today's INNER JOIN, needed for D2).
1. **Keep** `#Agg` per pair from active map rows: `IsSeenInLastRun` (MAX) and map `PriceLastSeenDate`.
2. **New `#Target`**: every public verified active row (catalog `StatusID = 1`), with
   - `NextCreatedAt = LEAD(CreatedAt) OVER (PARTITION BY CatalogID, CountryId ORDER BY CreatedAt, CatalogRetailPriceID)`
   - `HasMap` = the pair has a row in `#Agg` (LEFT JOIN)
   - `NewPLS` = `NextCreatedAt` when not NULL (older row, with or without map); else, when `HasMap`, the map date (NULL copied); else the row's current date (latest row without map: unchanged)
   - `NewSeen` = `#Agg.IsSeenInLastRun` when `HasMap` (all rows of the pair); else the row's current value
3. **Dry run** (`@DryRun = 1`): return rows that would change, with current and new `IsSeenInLastRun` / `PriceLastSeenDate`, and a column `RowRole` = Latest / Older.
4. **Real run**: one `tblTransaction` (type 2), update only rows where seen flag or date differs (compare as `datetime2(3)`), set `TransactionId`. Optional: skip creating the `tblTransaction` row when nothing differs (known issue 23).
   - The SP name stays the same (callers and job unchanged).
5. Rewrite the header comment to the new rule.

Uses temp tables, `WITH (NOLOCK)` on reads only (not inside `UPDATE … FROM` on the target), no new indexes needed.

### 4.2 `sp_update_CatalogRetailPrice_FromMapping` — small change

1. Remove the comment on `EXEC dbo.sp_Sync_PriceLastSeenDate_isSeenInLastRun @UserId = 1;` (after `sp_UpdateMap_PriceLastSeen`).
2. Optional (known issue 18): wrap the two post-steps in their own `TRY…CATCH`, so a failure there does not write a `Failed` sync-log row after the inserts were already committed with `Success`.
3. Update the header ("then UpdateMap + Sync", new date rule).

No change to how rows are inserted: they still go in with `PriceLastSeenDate = NULL`, and the sync fixes them in the same run.

### 4.3 No change

- `sp_UpdateMap_PriceLastSeen` — already produces the mapping date for the latest price. Its "latest" ordering (`CreatedAt DESC, CatalogRetailPriceID DESC`, per `CatalogId + CountryId`) must match the sync's ordering; it does (D1).
- `sp_map_rawCatalog_catalogCountry`, `sp_PublishAllDataNew`, `ResyncCatalogRetailPriceToEW` (out of scope).
- Before editing: check `EveryWatchDDL/dbo/routine` for matching routines (none found for these three names).

## 5. Example of one run

Pair with an active map row. Before: pair has 5,000 (2025-01-10, date 2025-06-01) and 5,300 (2025-06-01, latest, date NULL, still on site).
Crawl shows 5,600 on 2026-02-15.

| Step | 5,000 | 5,300 | 5,600 |
|---|---|---|---|
| Insert | 2025-06-01 | NULL | inserted, NULL |
| UpdateMap | — | — | map date NULL (on site) |
| Sync | unchanged | **2026-02-15** (next `CreatedAt`), new `TransactionId` | NULL (map) |
| Publish | — | updated | inserted |

Later the 5,600 listing disappears: UpdateMap sets the map date from RAW / Mirror; the sync copies it onto the 5,600 row only.

Pair **without** a map row (manual prices 8,000 on 2025-03-01 and 8,400 on 2026-01-10): the sync sets the 8,000 row's date to 2026-01-10; the 8,400 row and both `IsSeenInLastRun` values are left as they are.

## 6. Testing (owner runs all SQL)

1. Save the current state: `SELECT … INTO` a backup of public verified rows (`CatalogRetailPriceID`, `IsSeenInLastRun`, `PriceLastSeenDate`, `TransactionId`).
2. Run the new sync with `@DryRun = 1`. Expect: few or no Older rows (the one-time fix already applied the rule); Latest rows where the map date differs. A large number of Older changes means the one-time fix used a different rule (see D1).
3. Real run on the draft table; then the check queries:
   - Older rows (with or without map) where `PriceLastSeenDate` ≠ next `CreatedAt` → expect 0.
   - Latest rows of pairs with a map row where `PriceLastSeenDate` ≠ map date (NULL-safe) → expect 0.
   - Latest rows of pairs without a map row: same values as the backup → expect no change.
   - Latest rows with `IsSeenInLastRun = 0` and no date → list (rule "Seen = 0 always has a date").
4. Re-enable the call in the insert SP; watch the next daily run; check again.
5. Publish and compare draft vs published for changed rows.

Check queries go in `Queries/Janvi/RetailPrice/`.

## 7. Case check — does the design meet the requirement?

Daily order: map SP → insert (0 or more rows) → `sp_UpdateMap_PriceLastSeen` → sync → (publish). UpdateMap and sync run on every real run, even with 0 inserts, so map changes reach retail daily.

| # | Case | What happens | Meets requirement? |
|---|---|---|---|
| 1 | New price for a mapped pair | Insert adds it (date NULL). UpdateMap computes the map date against the **new** latest. Sync: previous latest → new price's `CreatedAt`; new latest → map date. | Yes |
| 2 | Latest price leaves the site | UpdateMap sets the map date (RAW / Mirror). Sync copies it to the latest row only. | Yes |
| 3 | Listing comes back, same price | UpdateMap rule 1 → map NULL. Sync copies NULL (D3 strict copy). | Yes |
| 4 | No change in a run | Nothing differs → no rows updated, no `TransactionId` change, nothing republished. | Yes |
| 5 | Outlier inserted (`StatusID` 2) | Not in the chain; previous price stays latest (UpdateMap uses `StatusID = 1` too, so both agree). | Yes |
| 6 | Outlier approved later (2 → 1) | Next run: chain recalculated around it; UpdateMap recalculates the map date if it became latest. | Yes, from the next run |
| 7 | Price deleted (`StatusID` 3) | Left out; the row before it becomes latest (gets map date) or gets the next remaining `CreatedAt`. | Yes |
| 8 | Price inserted in the middle of history (back-dated) | `LEAD` works on the full ordered chain, so both neighbours are corrected. | Yes |
| 9 | Manual pair, no map row | Older rows → next `CreatedAt`; latest and `IsSeenInLastRun` untouched (D2, D3). | Yes |
| 10 | Two prices same `CreatedAt` | Ordered by id; older gets its own `CreatedAt` (D4). | Yes |
| 11 | Pair with prices in two currencies | One chain per pair across currencies (D1). | Yes, as decided |
| 12 | Non-verified or private row between verified rows | Not in the chain; the verified row's date is the next **verified** price's `CreatedAt`. | Yes (scope) |
| 13 | Catalog not active (`tbl_CAT_Catalog_d.StatusID <> 1`) | Rows untouched (same filter as today). | Yes |
| 14 | Map row becomes deleted (RAW listing `IsDeleted = 1`), no other active map row | Owner decision: `IsSeenInLastRun = 0` on all rows of the pair; latest date kept as is; older rows still next `CreatedAt`. | Yes |
| 15 | Public verified row with `CountryId` NULL | Owner decision: skipped (never touched). | Yes |
| 16 | Latest date from UpdateMap rule 3 (listing not seen, RAW still shows the price) | Map date = RAW `UpdatedDate` = when the price last **changed**, roughly the price's own `CreatedAt`, not the day it left the site. Copied as is (D3). | Copies the map correctly; whether the map date itself is right is an UpdateMap question (known issue 22), outside this change. |

## 8. Implementation (2026-10-28, ew-db branch `retail-price-last-seen-date`, not deployed, not committed)

| File | Change |
|---|---|
| `MasterDB/dbo/stored procedures/sp_Sync_PriceLastSeenDate_isSeenInLastRun.sql` | Rewritten from the live script (28/10): `#Agg` (active map), `#DeletedOnly`, `#Chain` (`LEAD(CreatedAt)` per pair), `#Target` (changed rows only); dry run returns changed rows + counts per RowRole / MapState; real run skips `tblTransaction` when nothing changes; update joins on `CatalogRetailPriceID`. |
| `MasterDB/dbo/stored procedures/sp_update_CatalogRetailPrice_FromMapping.sql` | Sync call after `sp_UpdateMap_PriceLastSeen` re-enabled (uncommented). Nothing else changed. |
| `CatalogBrain/Queries/Janvi/RetailPrice/RetailPrice_PLS_Sync_Checks.sql` | Backup step, checks C1–C6, unchanged-manual-latest check. |

Deploy order: backup (check script step 0) → create the sync SP → `EXEC dbo.sp_Sync_PriceLastSeenDate_isSeenInLastRun @DryRun = 1` and review → real run → checks → deploy the insert SP (re-enabled call) → next daily run → checks → publish.

## 9. Test log

| Date | Step | Result |
|---|---|---|
| 2026-10-28 | Pre-check (`RetailPrice_PLS_Sync_Checks.sql`, before the new SP) | C1–C4 and C6: 0 rows. C5: 13 rows (latest, Seen = 0, no date) — all manually added public verified prices with no map row (MapState None); not touched by the new SP, no issue. Existing data already follows the new rule. |
| 2026-10-28 | Dry run of the new sync (`@DryRun = 1`), SP created in EWMaster | 0 rows — matches the pre-check; nothing to change in current data. |
| | First daily run with the sync call re-enabled | Expected: C1–C4 = 0; pairs with a new price that day show the previous price's date = new `CreatedAt`. |

## 10. Open item: map date before the latest price's CreatedAt (decided: option A, build later)

**Found 2026-10-28.** The sync dry run showed 5 pairs where the latest price would get a map date earlier than its CreatedAt. For example, CatalogID 121431 / UK (RawCatalogId 258321) gets 2024-08-05 07:29, but the price was created 2024-11-08.

**Cause:** `sp_UpdateMap_PriceLastSeen` rule 4 (the price is now only in the Mirror) uses `UpdatedDate` when it is not NULL. The matching Mirror row is the first one saved after `UpdatedDate` started being filled, and it carries a stale, too-old value. The older Mirror rows have NULL.

**Decision (owner, option A):** in rule 4, when the date found is before the retail CreatedAt, use the date RAW first showed a different price. If there is none, use the matching Mirror row's MirrorDate. The sync stays a strict copy.

**Status:** not built yet; production status comes first. Diagnostic: `Queries/Janvi/RetailPrice/RetailPrice_PLS_MapDateBeforeCreatedAt_Diagnostic.sql`.
