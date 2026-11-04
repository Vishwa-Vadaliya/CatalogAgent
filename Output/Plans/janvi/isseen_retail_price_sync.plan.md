---
type: Plan
title: IsSeen retail price sync
description: Plan for the production daily flow that syncs IsSeenInLastRun from raw catalog crawls into tbl_CAT_CatalogRetailPrice_d and publishes it.
tags: [plans, janvi, retail-price, ewmaster, isseeninlastrun]
timestamp: 2026-10-24
name: IsSeen retail price sync
overview: Production daily flow for all brands—normalize raw reference (Rolex strip leading m; others UDF), resolve CatalogId via tbl_CAT_RawCatalogMapping then catalog fallback, aggregate MAX(IsSeenInLastRun) per (CatalogId, CountryId) into a staging table, update tbl_CAT_CatalogRetailPrice_d, publish.
todos:
  - id: ddl-staging
    content: "Create dbo.tbl_Staging_CatalogRetail_IsSeen in MasterDB with exactly: SourceRunAt, CatalogId, CountryId, IsSeenInLastRun"
    status: completed
  - id: ddl-retail-columns
    content: "Align MasterDB scripts: tbl_CAT_CatalogRetailPrice_d / _d mirror trigger / tbl_CAT_CatalogRetailPrice with IsSeenInLastRun; tbl_CAT_RawCatalogMapping constraints as in prod"
    status: completed
  - id: sp-sync
    content: Implement sp_Sync_PriceLastSeenDate_isSeenInLastRun (all brands, steps 3–9); NOLOCK on reads only
    status: completed
  - id: publish-merge
    content: Extend sp_PublishAllDataNew for IsSeenInLastRun on tbl_CAT_CatalogRetailPrice from _d
    status: completed
  - id: sql-agent
    content: "SQL Agent job: run sync SP after raw catalog refresh; then sp_PublishAllDataNew if same-day publish required"
    status: completed
isProject: true
---

# IsSeenInLastRun — production flow (next steps only)

## 1. Scope

- **All manufacturers** that participate in manufacturer-site / `tbl_RAW_Catalog` retail crawling (no fixed “top five” list in code unless you add a configurable exclude list later).
- **Sources of raw rows:** `tbl_RAW_Catalog` joined to `tbl_RAW_Source` and `tbl_source_manufacturer_mapping` so each row has a **`CountryId`** for MSRP geography (same grain as `tbl_CAT_CatalogRetailPrice_d.CountryId`).
- **Targets:** active draft retail rows `tbl_CAT_CatalogRetailPrice_d` with `StatusID = 1` and `IsPrivate = 0` (adjust only if product requires including private rows).

## 2. Intermediate table (persistent staging)

Create a real table in **EWMaster** (name example: `dbo.tbl_Staging_CatalogRetail_IsSeen`). Each daily run does **`TRUNCATE`** (or `DELETE`) then **`INSERT`** a full snapshot for that run.

**Columns (only these four):**

| Column | Purpose |
|--------|--------|
| `SourceRunAt` | `GETDATE()` when the job started (batch marker). |
| `CatalogId` | Resolved catalog row. |
| `CountryId` | From `tbl_source_manufacturer_mapping` on that raw row (must match `_d.CountryId`). |
| `IsSeenInLastRun` | **`MAX`** over all contributing raw rows for that pair; store **0** or **1** only. |

Do **not** put draft `TransactionId` here; the **final** table update owns transaction identity. Use **temp tables inside the SP** for any debug columns (e.g. resolution path, raw row counts).

## 3. How `CatalogId` is resolved (per raw row)

Apply **in order**; stop at first hit.

1. **`tbl_CAT_RawCatalogMapping` by row**  
   `WHERE map.RawCatalogId IS NOT NULL AND map.RawCatalogId = tbl_RAW_Catalog.Id` → `map.CatalogId`.

2. **`tbl_CAT_RawCatalogMapping` by cleaned reference**  
   Compute **`CleanKey`** (see §4).  
   `WHERE map.RawCatalogId IS NULL AND map.RawReferenceNumber = CleanKey` (after you fix trim/case/collation rules once) → `map.CatalogId`.

3. **Catalog fallback (no mapping row)**  
   Join `tbl_CAT_Catalog_d` on active catalog: same **`ManufacturerId`** as from source mapping, and match **normalized** catalog reference to **`CleanKey`** (same normalization as used for mapping lookup—Rolex rule or `EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets` on both sides, consistently).

If still unresolved, **drop** that raw row from the visibility pipeline (it cannot drive a retail row).

## 4. `CleanKey` by brand

| Brand | Rule |
|--------|------|
| **Rolex** | Leading **`m`** removal on the working reference string (same idea as prior cleanup: references or `ArtworkId` patterns that start with `m%`—implement the exact expression once in the SP and document it). Use the result as **`CleanKey`** for mapping and catalog fallback. |
| **All other brands** | **`CleanKey` = `EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(<chosen raw ref column>)`** (same column(s) you use elsewhere for catalog matching). |

Manufacturer name vs id: detect Rolex by **`tbl_CAT_Manufacturer_d`** / catalog manufacturer id or by **`tbl_source_manufacturer_mapping.CatManufacturer`**, whichever you standardize in code.

## 5. Aggregation rule

- For each **`(CatalogId, CountryId)`** coming from resolved raw rows (with `CountryId` from manufacturer mapping on that raw line):  
  **`IsSeenInLastRun = MAX(ISNULL(trc.IsSeenInLastRun, 0))`** capped to **0/1** if crawler ever sends wider tinyint range (e.g. treat `>= 1` as 1 if that is your rule).

## 6. Step-by-step job flow (stored procedure + optional job wrapper)

**Step 1 — Transaction**  
`INSERT dbo.tblTransaction …`; capture `@TransactionId` (or call your standard `sp_Create_Transaction` if that is how other catalog retail updates are done).

**Step 2 — Base raw set**  
`INSERT` into `#RawBase` from `tbl_RAW_Catalog` `WITH (NOLOCK)` joined to `tbl_RAW_Source` and `tbl_source_manufacturer_mapping` on `SourceId` and **`Manufacturer = trc.Manufacturer`**, carrying `trc.Id`, `ReferenceNo`, `ReferenceRaw`, `ArtworkId`, `IsSeenInLastRun`, `ManufacturerId` / manufacturer name for Rolex detection, and **`tsmm.CountryId`**.

**Step 3 — `CleanKey`**  
Update or compute column on `#RawBase`: Rolex branch vs non-Rolex UDF branch (§4).

**Step 4 — Resolve `CatalogId`**  
For each row in `#RawBase`, apply §3 (mapping by `RawCatalogId`, then by `RawReferenceNumber = CleanKey`, then catalog_d fallback). Output **`#RawResolved`** with at least `CatalogId`, `CountryId`, `IsSeenInLastRun` (plus any temp columns needed only inside the SP).

**Step 5 — Drop unresolved**  
Remove rows where `CatalogId IS NULL`.

**Step 6 — Aggregate into staging**  
`INSERT` into **`tbl_Staging_CatalogRetail_IsSeen`** with **only** the four columns:  
`SELECT @SourceRunAt, CatalogId, CountryId, MAX(...)` `GROUP BY CatalogId, CountryId`  
(same `@SourceRunAt` for every row in that run).

**Step 7 — Update draft retail (`tbl_CAT_CatalogRetailPrice_d`)**  
- `UPDATE crp` `SET IsSeenInLastRun = s.IsSeenInLastRun, TransactionId = @TransactionId`  
  `FROM tbl_CAT_CatalogRetailPrice_d crp`  
  `INNER JOIN tbl_Staging_CatalogRetail_IsSeen s ON s.CatalogId = crp.CatalogID AND s.CountryId = crp.CountryId`  
  `INNER JOIN tbl_CAT_Catalog_d cd ON cd.CatalogId = crp.CatalogID AND cd.StatusID = 1`  
  `WHERE crp.StatusID = 1 AND crp.IsPrivate = 0`  
  (and optionally only when value changed, to cut noise).  
- **No `NOLOCK`** on tables being updated.

**Step 8 — Rows with no crawl signal**  
For the same scoped retail rows (`StatusID = 1`, `IsPrivate = 0`, all manufacturers in scope):  
`UPDATE` **`IsSeenInLastRun = 0`** (and `TransactionId = @TransactionId`) where **no** row exists in **`tbl_Staging_CatalogRetail_IsSeen`** for that **`(CatalogID, CountryId)`** so delisted references clear to not seen.

**Step 9 — Publish**  
Run **`sp_PublishAllDataNew`** (same job step or a dependent job) so **`tbl_CAT_CatalogRetailPrice`** receives `IsSeenInLastRun` from `_d` once publish logic is extended.

**Step 10 — Logging**  
On success/failure, write a row to your chosen log table (reuse retail run log pattern if appropriate).

## 7. Codebase changes (MasterDB / `ew-db`)

- New table script under `MasterDB/dbo/table/` for **`tbl_Staging_CatalogRetail_IsSeen`**.
- New procedure **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`** under `MasterDB/dbo/stored procedures/` (confirm naming with team; **`EveryWatchDDL`** has no matching routine for this pattern per earlier check).
- Extend **`sp_PublishAllDataNew`** merge for `tbl_CAT_CatalogRetailPrice` to include **`IsSeenInLastRun`**.
- Update **`tr_UD_tbl_CAT_CatalogRetailPrice_d`** (and mirror `_m` table) if `IsSeenInLastRun` must appear in mirror payloads.

## 8. Validation (after build)

- Sample Rolex rows: `CleanKey` without leading `m`; mapping hit vs catalog fallback.
- Sample non-Rolex: UDF key matches **`tbl_CAT_RawCatalogMapping.RawReferenceNumber`**.
- `(CatalogId, CountryId)` with multiple raw lines: **`MAX`** matches expectation.
- Retail row with no staging line: becomes **0**.
- After publish, live **`tbl_CAT_CatalogRetailPrice`** matches **`_d`** for the flag.
