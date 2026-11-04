---
type: Plan
title: Rolex retail prices blocked by the reference guard
description: Plan to fix sp_update_CatalogRetailPrice_FromMapping so Rolex official-site prices pass the reference guard (leading m / ArtworkId rule, same as the map SP), plus a one-time catch-up for Rolex listings already behind the watermark.
tags: [plans, janvi, retail-price, rolex, reference-guard, ewmaster]
timestamp: 2026-10-28
name: Rolex reference guard fix
overview: The insert SP's reference guard compares the raw ReferenceNo as-is with the catalog reference, so Rolex rows (leading m, blank ReferenceNo, truncated ReferenceNo) are dropped although the map SP mapped them. Fix = Rolex-aware guard key in the three guard places; then a catch-up decided from the diagnostic counts.
todos:
  - id: diagnostic
    content: Owner runs RetailPrice_Rolex_Guard_Diagnostic.sql and shares the summary
    status: pending
  - id: decisions
    content: Owner answers section 6
    status: completed
  - id: guard-fix
    content: Rolex-aware guard key in sp_update_CatalogRetailPrice_FromMapping (3 places)
    status: completed
  - id: catch-up
    content: Temporary @RolexCatchUpFromTransactionId (version 1), run once from the dummy id, then remove (version 2)
    status: pending
  - id: test
    content: Dry run, real run, checks (section 7)
    status: pending
isProject: false
---

# Rolex retail prices blocked by the reference guard

Related: [sp/03](../../Documents/RetailPrice/sp/03-sp-update-catalog-retail-price-from-mapping.md). Builds on the ew-db branch `retail-price-last-seen-date` (the PriceLastSeenDate change).

## 1. Problem

Rolex prices from the official site are mapped (`tbl_MAP_RawCatalog_CatalogCountry` has the rows) but no new Rolex prices are inserted into `tbl_CAT_CatalogRetailPrice_d`. Example from the earlier review: RAW 384661, CatalogId 210390, CountryId 233, USD 40,900. Estimated about 21,400 mapped Rolex raws affected (13 Rolex sources × 1,644, plus 64 from "source 17168") — unverified estimate; source 17168 is not found in code, data files or Knowledge (Knowledge §7 Rolex SourceIds: 13987, 15032–15043). The diagnostic gives the real numbers.

## 2. Root cause (from the code)

**The map SP and the insert SP read the Rolex reference differently.**

`sp_map_rawCatalog_catalogCountry` builds the match key for Rolex (`CatManufacturerName = 'ROLEX'` on `tbl_sourceManufacturer_mapping`, `ArtworkId` not blank). First match wins:

| # | Raw data | Key used |
|---|---|---|
| 1 | Reference blank, `ArtworkId` starts with `m` | `ArtworkId` without the `m` |
| 2 | Reference starts with `m` | Reference without the `m` |
| 3 | Reference shorter than `ArtworkId`, contained in it, `ArtworkId` starts with `m` | `ArtworkId` without the `m` (repairs a truncated reference) |
| 4 | Otherwise | Reference as is |

("Reference" = RAW `ReferenceNo`, or, when that is blank, the latest non-blank Mirror `ReferenceNo`.) The key is then cleaned with `EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets` and matched to the catalog. Example: `ArtworkId = m126610ln-0001` → `126610ln0001` = catalog `126610LN-0001`.

`sp_update_CatalogRetailPrice_FromMapping` then applies a **reference guard** to every RAW and Mirror row before using its price ("the same RawCatalogId can point at wrong data"):

```
RefExt = dbo.fn_ExtractNumbersAndAlphabets(ReferenceNo)      -- raw ReferenceNo, as is
keep the row only if RefExt <> ''
             and (RefExt = fn_Extract(catalog ReferenceNumber)
                  or RefExt is in tbl_CAT_RawCatalogMapping for that CatalogId)
```

No Rolex rule here. So a Rolex row fails the guard when:

| Raw `ReferenceNo` | Guard key | Catalog key | Result |
|---|---|---|---|
| `m126610ln-0001` | `m126610ln0001` | `126610ln0001` | dropped (leading m) |
| blank | `''` | `126610ln0001` | dropped (empty) |
| `126610` (truncated; full ref in `ArtworkId`) | `126610` | `126610ln0001` | dropped |

It is dropped silently: no log, no error. The guard is in three places, all with the same rule:

| Place | Path | Approx. line |
|---|---|---|
| `#MirrorBaseInc` | Mirror rows, incremental (pair already has retail) | ~240 / ~281 |
| `#MirrorBaseFull` | Mirror rows, full history (pair has no retail yet) | ~299 / ~340 |
| `#TempRawMapped` | Current RAW row | ~425 / ~468 |

**Second effect: the watermark.** Each run moves the watermark to the highest RAW `TransactionId` even with 0 inserts (known issue 1). Rolex rows dropped in earlier runs are not looked at again unless:
- the pair has **no** public retail yet → `NeedFullMirrorHistory = 1` → the full RAW + Mirror history is read again on every run (these recover by themselves once the guard is fixed), or
- the RAW row changes again (new `TransactionId`).

Pairs that **already have** some public retail (older prices, from an earlier backfill or manual load) only read rows above the watermark. Their missed price changes stay missed after the guard fix. They need a one-time catch-up (section 5).

## 3. Fix A — Rolex-aware guard key (code change)

In `sp_update_CatalogRetailPrice_FromMapping` only:

1. **`#ActiveMapPairs`**: add `IsRolex` (bit) = the RAW row's source has `CatManufacturerName = 'ROLEX'` in `tbl_sourceManufacturer_mapping` (join `rawCur.SourceId`; same test as the map SP).
2. **In each of the three guard places**: compute the guard key from `ReferenceNo` **and** `ArtworkId` of that row (RAW or Mirror):
   - Not Rolex → unchanged: `fn_Extract(ReferenceNo)`.
   - Rolex and `ArtworkId` not blank → the same 4 rules as the map SP (table in section 2), on that row's own `ReferenceNo` / `ArtworkId`, then `fn_Extract`.
   - Rolex and `ArtworkId` blank → `fn_Extract(ReferenceNo)` with a leading `m` removed.
3. The comparison stays the same: key not empty and (key = catalog key or key in `tbl_CAT_RawCatalogMapping` for that catalog). So the guard still blocks a Rolex listing whose content now points at a different reference.

Not changed: the map SP, `sp_UpdateMap_PriceLastSeen`, the sync SP, the currency gate, outlier rule, dedup, watermark logic.

**Why not just skip the guard for Rolex?** The map never re-matches a mapped row (known issue 8). If a Rolex listing id is reused for another watch, the guard is the only check that stops the wrong price. Keeping it, with the Rolex rule, is safer.

**Difference that stays:** the map SP cleans with `EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets`, the insert SP with `dbo.fn_ExtractNumbersAndAlphabets` (both: letters and digits, lowercase). Kept as is; the diagnostic shows whether they ever disagree.

## 4. What the fix does on the first run after deploy

| Rolex pair | First run after the fix | Later runs |
|---|---|---|
| No public retail yet | Full RAW + Mirror history read (`NeedFullMirrorHistory = 1`) → price history inserted (outlier rule applies; baseline = the newest candidate) | Incremental |
| Has public retail, RAW row changed after the deploy | New price inserted | Incremental |
| Has public retail, RAW row **not** changed since it was blocked | Nothing (row is below the watermark) | Nothing until the price changes on the site → **needs catch-up** |

Then `sp_UpdateMap_PriceLastSeen` and the new sync set `PriceLastSeenDate` / `IsSeenInLastRun` on the new rows as usual.

## 5. Fix B — one-time Rolex catch-up from the dummy watermark (decided)

**Owner (2026-10-28):** most Rolex raws carry the leading `m`, so most are skipped. Rolex pairs already have retail (base data). `tbl_cat_RetailPrice_SyncLog` holds a **Dummy** row whose `MaxRawCatalogTransactionId` marks the base data; since then (6–8 months) no Rolex updates came in. Catch up **every Rolex update after the dummy TransactionId**. Other brands: no change. The Rolex-specific catch-up is **one-time** and is removed afterwards; the permanent change is only the reference guard.

**Chosen approach: temporary parameter, incremental path, Rolex only.**

- Add `@RolexCatchUpFromTransactionId bigint = NULL` to `sp_update_CatalogRetailPrice_FromMapping`.
- When set: for Rolex map rows (`IsRolex = 1`) the incremental RAW and Mirror filters use this value instead of the SyncLog watermark (`RawCurrentTransactionId > …`, mirror `TransactionId > …`, RAW `TransactionId > …`). All other rows use the normal watermark. Everything else (guard, currency gate, outlier rule, same-day collapse, idempotent dedup, insert, SyncLog row, UpdateMap, sync) is the normal daily logic.
- When NULL (the daily job): no difference at all.
- Watermark after the run: normal (highest RAW `TransactionId`).

Why this one:

| Option | Verdict |
|---|---|
| Temporary parameter, incremental from the dummy id, Rolex only (**chosen**) | Reads exactly "Rolex updates after the dummy" with the same rules as the daily run; other brands untouched; dry run available |
| Full history for Rolex (earlier B1) | Reads history from before the dummy too — more than needed |
| Touch Rolex RAW `TransactionId` (B2) | Picks up only the current RAW price, loses the Mirror history since the dummy; changes crawler data |
| Lower the global watermark (B3) | Re-reads every brand — owner said other brands are not needed |

**Order (important):** deploy the guard fix and the parameter together, and run the catch-up **before the next scheduled daily run** (or pause the job for that day). If a daily run with the new guard runs first, it inserts the newest Rolex prices; the catch-up would then add the older missed changes behind them as back-dated rows. The PriceLastSeenDate sync would still fix the dates, but the order is cleaner.

Steps:
1. Deploy version 1: guard fix + `@RolexCatchUpFromTransactionId`.
2. `EXEC dbo.sp_update_CatalogRetailPrice_FromMapping @DryRun = 1, @RolexCatchUpFromTransactionId = <dummy id>;` → review the preview (Rolex rows, per country, `StatusID` 2 outliers against the base prices).
3. Same with `@DryRun = 0` (one run; also runs UpdateMap + sync for PriceLastSeenDate).
4. Deploy version 2: guard fix only (parameter removed). The daily job continues as normal.

Known limit inside the catch-up: the incremental Mirror path drops Mirror rows with NULL `UpdatedDate` (known issue 16). Rolex rows after the dummy should have `UpdatedDate` (crawler fix); the diagnostic can confirm.

## 6. Decisions (owner, 2026-10-28)

| # | Question | Answer |
|---|---|---|
| 1 | Which Rolex rows are skipped? | Most Rolex rows: the reference starts with `m`. |
| 2 | Do Rolex pairs have retail already? | Yes, base data; no updates since the SP went live 6–8 months ago. |
| 3 | What to catch up | Every Rolex update after the **Dummy** SyncLog TransactionId. |
| 4 | Catch-up method | One-time, Rolex only, removed afterwards (section 5). |
| 5 | Other brands | Not needed. |

## 7. Test plan (owner runs all SQL)

1. **Diagnostic** — `Queries/Janvi/RetailPrice/RetailPrice_Rolex_Guard_Diagnostic.sql`: every active Rolex map row with the current guard result vs the new guard result, whether the pair has retail, and whether the RAW row is behind the watermark. Expect: most rows fail now and pass with the new key.
2. After Fix A (normal daily call, no catch-up): `EXEC dbo.sp_update_CatalogRetailPrice_FromMapping @DryRun = 1;` → Rolex rows appear in the preview; check counts per country, outliers (`StatusID` 2), dates. Note: the dry run still runs the map SP first (known issue 5).
3. Real daily run → check new Rolex rows; run `RetailPrice_PLS_Sync_Checks.sql` (C1–C4 = 0).
4. Catch-up run (section 5, steps 2–3), then deploy version 2 without the parameter.
5. Publish.

## 8. Files (2026-10-28) — not yet applied to ew-db

`Queries/Janvi/RetailPrice/SP_Versions/`:

| File | Content |
|---|---|
| `sp_update_CatalogRetailPrice_FromMapping_00_original.sql` | ew-db `origin/master` copy, before any change (rollback). |
| `sp_update_CatalogRetailPrice_FromMapping_v2_final.sql` | Permanent: Rolex-aware guard key (`IsRolex` on `#ActiveMapPairs` from `tbl_sourceManufacturer_mapping`; `CROSS APPLY` guard key in the 3 guard places) + sync call re-enabled (PriceLastSeenDate plan). |
| `sp_update_CatalogRetailPrice_FromMapping_v1_rolex_catchup.sql` | v2 + one-time: `@RolexCatchUpFromTransactionId`; `FromTransactionId` per map row (Rolex = catch-up id, others = watermark) in the 3 incremental filters; Rolex date gate (drop candidates on or before the key's latest public verified retail date) when the catch-up is active; dry run also returns `RolexFromTransactionIdUsed`. |

Edge cases handled in the code:

| Case | Handling |
|---|---|
| `ReferenceNo` starts with `m` / `M` | Stripped (case-insensitive, not depending on collation) |
| `ReferenceNo` blank, `ArtworkId` starts with `m` | `ArtworkId` without `m` |
| `ReferenceNo` truncated, contained in an `m` `ArtworkId` | `ArtworkId` without `m` (uses `CHARINDEX`, so `_`/`%` in a reference are not wildcards) |
| Mirror rows | Guard key from the mirror row's own `ReferenceNo` / `ArtworkId` |
| Listing now shows another watch | Still dropped: key compared to catalog ref / `tbl_CAT_RawCatalogMapping` |
| Non-Rolex brands | Key = `ReferenceNo` as before; `FromTransactionId` = watermark (v1) |
| Catch-up id NULL or ≥ watermark | No catch-up; behaves like v2 |
| Rolex row changed after the dummy only for a flag (old `UpdatedDate`) | Date gate drops it (no back-dated row) |
| Same price as an existing row on the same day | Dropped by the existing dedup (`#ExistingRetail`) |
| Rolex pair with no public retail at all | Full history path (existing behaviour for new pairs, also in v2) |
| Rolex pair with only non-verified public retail | Incremental from the dummy; no gate (no verified latest); outlier baseline = newest candidate |
| Price jump > 50 % vs base price | `StatusID` 2 (existing rule) |

Not handled (accepted): RAW row with blank `ReferenceNo` and an `ArtworkId` without `m` (map may use a Mirror reference; guard key is empty → dropped); Mirror rows with NULL `UpdatedDate` on the incremental path (known issue 16); a Rolex source whose `CatManufacturerName` is not `ROLEX` (the diagnostic lists the sources it finds; Knowledge §7 Rolex SourceIds: 13987, 15032–15043).

## 9. Test log

**2026-10-28 — v1 dry run** (`@DryRun = 1`, `@RolexCatchUpFromTransactionId` = Dummy id). Output: 16,619 candidate rows.

| Group | Rows | Result |
|---|---|---|
| Rolex | 13,390 | 1,030 catalogs × 13 countries. One row per (CatalogID, CountryId, CurrencyId). CreatedAt 2026-06-01/03/04, which is the single Rolex manufacturer change. All StatusID 1. % diff from 0 to +10, with an average of about +3.5 % in every country and none negative. |
| Rolex, 0 % | 26 | 2 catalogs (`228235jg-0002`, `228235jg-0003`) × 13. These keys have no public verified retail, so the baseline is the row itself. They become the first price (new-pair path). |
| Non-Rolex | 3,229 | Normal incremental from the watermark. CreatedAt is mostly 2026-09-30 to 2026-10-26. 30 JLC rows (Jun–Aug, 0 %) are new keys on the full-history path. |
| StatusID 2 | 30 | Frederique Constant 221988 (broken RAW prices, for example 213,997,376) and Breitling. These are existing outlier rules; not published. |

The owner accepted the result: Rolex has had no manufacturer change since June 2026.
