---
type: Plan
title: Raw catalog mapping (one-time + daily)
description: Plan for the tbl_MAP_RawCatalog_CatalogCountry mapping table — one-time backfill and daily refresh of raw-catalog-to-CatalogId/CountryId mapping.
tags: [plans, janvi, raw-catalog, mapping, ewmaster]
timestamp: 2026-10-24
name: Raw catalog mapping (one-time + daily)
overview: tbl_MAP_RawCatalog_CatalogCountry — PK RawCatalogId (one CatalogId per raw row); ambiguous multi-CatalogId resolutions go to review, not silent tie-break. Aggregate to tbl_CAT_CatalogRetailPrice_d.IsSeenInLastRun; one-time + daily SPs; MSRP price rules out of scope.
todos: []
isProject: false
---

# RawCatalog mapping table — one-time load and daily maintenance

## Scope of this document

This plan covers **only**:

- DDL for the **mapping table** (`CatalogId`, `RawCatalogId`, `CountryId`, `IsSeenInLastRun`, audit columns).
- **Official-source** filtering using **`CatSourceName`** on **`tbl_source_manufacturer_mapping`** and how that relates to **`tbl_CAT_Source_d`**.
- **One-time** population (backfill all qualifying historical raw rows).
- **Daily** script: refresh **`IsSeenInLastRun`** from **`tbl_RAW_Catalog`** for rows already mapped; **INSERT** new mappings for new raw rows that pass filters and resolve to a **`CatalogId`**.

**Out of scope here (you will document separately):** how catalog retail **prices** (money amounts) are **applied** in **`tbl_CAT_CatalogRetailPrice_d`** (including **CreatedAt**, which date drives inserts vs updates, mirror/history). That flow never implies editing **`tbl_RAW_Catalog`**.

**Intermediate table for `IsSeenInLastRun` → `tbl_CAT_CatalogRetailPrice_d`:** the canonical intermediate layer is **`dbo.tbl_MAP_RawCatalog_CatalogCountry`** (DDL path: `MasterDB/dbo/table/tbl_MAP_RawCatalog_CatalogCountry.sql`, final name may differ). After daily mapping refresh, **aggregate** over this table by **`CatalogId`** + **`CountryId`** (e.g. **`IsSeenInLastRun = MAX`** over all mapped raw rows for that pair, capped 0/1), then **`UPDATE tbl_CAT_CatalogRetailPrice_d`** by joining on **`CatalogID`** and **`CountryId`**. **`tbl_Staging_CatalogRetail_IsSeen`** is **not** this intermediate table for the target design—it was the earlier staging snapshot (`SourceRunAt`, truncate/rebuild). Refactor **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`** (or replace it) so it reads from **`tbl_MAP_RawCatalog_CatalogCountry`** instead of rebuilding **`#RawResolved`** into staging each run.

---

## Overview

**Goal:** Keep a **stable row per `tbl_RAW_Catalog.Id`** that ties raw crawler lines to **`CatalogId`** + **`CountryId`** for manufacturer-official sources, so downstream processes do not repeatedly resolve reference strings when processing the same raw identity.

**Principles:**

- One **catalog** per reference (conceptually); raw can repeat across sources/countries.
- **`CountryId`** comes from **`tbl_source_manufacturer_mapping`** on **`SourceId`** + **`Manufacturer`** (same grain as **`tbl_CAT_CatalogRetailPrice_d.CountryId`**).
- Only sources classified as **official manufacturer** (see §3) participate in this mapping.

---

## 1. Persistent mapping table (DDL shape)

**Suggested name:** `dbo.tbl_MAP_RawCatalog_CatalogCountry` (adjust to naming standards).

**Purpose:** one row per **`tbl_RAW_Catalog.Id`** that participates in official-manufacturer mapping.

| Column | Type (suggested) | Purpose |
|--------|------------------|---------|
| `RawCatalogId` | `BIGINT` NOT NULL | PK — `tbl_RAW_Catalog.Id` |
| `CatalogId` | `INT` NOT NULL | FK → `tbl_CAT_Catalog_d.CatalogId` |
| `CountryId` | `BIGINT` NOT NULL | FK → country / matches `_d.CountryId` |
| `IsSeenInLastRun` | `TINYINT` NOT NULL | Mirror of **`tbl_RAW_Catalog.IsSeenInLastRun`** for this row; updated daily |
| `MappingCreatedAt` | `DATETIME2` NOT NULL | First insert for this `RawCatalogId` |
| `MappingUpdatedAt` | `DATETIME2` NULL | Optional: last mapping touch |
| `ResolutionNote` | `NVARCHAR(100)` NULL | Optional: `MappingTable`, `CatalogFallback`, etc. |

**Constraints / indexes:**

- **PK:** `RawCatalogId` — **one mapping row per raw catalog identity**; this enforces that there is **only one `CatalogId`** stored for that **`RawCatalogId`**.
- **`CountryId`** on that row comes from **`tbl_source_manufacturer_mapping`** for that raw line, so in practice **for a given `RawCatalogId` you have a single `(CountryId, CatalogId)`** — no duplicate countries for the same raw row.
- **FKs:** optional to `tbl_RAW_Catalog`, `tbl_CAT_Catalog_d`, country table.
- **NC index:** `(CatalogId, CountryId)` for aggregating many raw rows to one retail pair (many different **`RawCatalogId`** values may share the same **`CatalogId` + `CountryId`** — that is expected).

**Uniqueness rule (business):** **One `CatalogId` per `RawCatalogId`** (and therefore **one catalog per raw row + its country**). The PK guarantees at most one stored mapping per raw id.

**Ambiguous resolution (two or more `CatalogId` candidates for one raw):** Do **not** treat arbitrary **`MIN(CatalogId)`** as acceptable without a team rule. **Preferred:** skip insert into **`tbl_MAP_RawCatalog_CatalogCountry`**, record the case for **review** (separate queue table, report, or **`ResolutionNote` / status column** such as pending ambiguous), and correct **`tbl_CAT_RawCatalogMapping`** or catalog rows so resolution becomes **single-valued**. Only insert when exactly **one** **`CatalogId`** is resolved (or when an explicit, documented tie-break is approved).

**Relationship to `tbl_CAT_RawCatalogMapping`:** that table remains the **reference-string → `CatalogId`** directory. The mapping table is the **per–raw-row** link after resolution.

**Relationship to `tbl_Staging_CatalogRetail_IsSeen`:** for **`IsSeenInLastRun`** on **`tbl_CAT_CatalogRetailPrice_d`**, the **intermediate** data is **`tbl_MAP_RawCatalog_CatalogCountry`** (many rows per `(CatalogId, CountryId)` — one per raw line). The staging table was a **transient per-run** aggregate (`SourceRunAt` + truncate); the new design keeps **durable** raw-level rows and derives the aggregate at sync time from the map.

---

## 2. Reference → `CatalogId` (same rules as `sp_Sync_PriceLastSeenDate_isSeenInLastRun`)

1. **`tbl_CAT_RawCatalogMapping`:** `CatalogId` and `RawReferenceNumber` NOT NULL; `RTRIM(LTRIM(RawReferenceNumber)) = RTRIM(LTRIM(ISNULL(ReferenceNo,'')))` on the raw row. Do **not** use `RawCatalogId` for resolution in that procedure.
2. **Fallback:** **`tbl_CAT_Catalog_d`**, `StatusID = 1`, same **`ManufacturerId`** as from **`tbl_source_manufacturer_mapping`**, and **`EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(ReferenceNumber) = EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(CleanKey)`** with **`CleanKey`** from the Rolex / non-Rolex rules already in the sync SP.

One-time and daily procedures should **share** this resolution (TVF or shared batch logic) so behavior does not drift.

**Detection of ambiguity:** After applying mapping branch + catalog fallback, if more than one distinct **`CatalogId`** remains for the same **`RawCatalogId`**, flag for **review** and **omit** from the main mapping table until resolved (unless product approves a single tie-break rule and documents it here).

---

## 3. Official manufacturer sources (`CatSourceName` + `tbl_CAT_Source_d`)

**Column:** **`CatSourceName`** on **`tbl_source_manufacturer_mapping`** (see prod; some repos also have **`tbl_sourceManufacturer_mapping`** with **`CatSourceName`** — align with the table your ETL actually joins for crawl sources).

**Catalog context:** **`tbl_CAT_Source_d`** holds canonical catalog source labels in **`SourceName`**, e.g.:

- `official website - Audemars Piguet`
- `official website - Rolex`
- `watchBase`
- …

Those entries describe **what kind of source** the catalog uses (OEM site vs third party). **`tbl_source_manufacturer_mapping`** ties each crawl **`SourceId`** to metadata; **`CatSourceName`** carries the **human-readable / classification** aligned with that catalog source taxonomy.

**Practical filter for “official manufacturer crawl”:** restrict mapping candidates where **`CatSourceName`** indicates an official site, e.g.

```sql
UPPER(LTRIM(RTRIM(ISNULL(tsmm.CatSourceName, N'')))) LIKE N'%OFFICIAL%'
```

Using **`%OFFICIAL%`** (not only prefix `OFFICIAL%`) matches names like “official website - …”. Collations and real prod values should be validated once; adjust if any official row omits the word “official”.

**Also require** (same as sync SP): **`CountryId`** and **`ManufacturerId`** NOT NULL on the mapping join; **`tbl_RAW_Catalog.IsDeleted = 0`**.

---

## 4. One-time mapping population (“backfill”)

**Goal:** Insert into the mapping table for **all historical** `tbl_RAW_Catalog` rows that:

- Pass the **official** filter (§3) and base joins, and  
- Resolve to a **`CatalogId`** via §2.

**Suggested procedure:** e.g. `dbo.sp_MAP_RawCatalog_CatalogCountry_OneTime` with `@DryRun`, `@BatchSize`, optional `@SinceRawCatalogId`.

**Logic:**

1. Build **`#RawBase`** (same columns as sync SP: id, `ReferenceNo`, `CleanKey`, `ManufacturerId`, `CountryId`, `IsSeenInLastRun`, plus official filter).
2. Resolve **`CatalogId`** per row using the same **set-based** pattern as **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`** (`#MapTrim` / `#CdKeys`).
3. **`INSERT`** mapping rows only where **`RawCatalogId`** is **not** already in the mapping table.
4. Set **`MappingCreatedAt`**.

**Idempotency:** Re-run safe; skip existing keys.

**Deliverable:** `MasterDB/dbo/table/…` DDL + `MasterDB/dbo/stored procedures/…` one-time SP.

---

## 5. Daily (or alternate-day) maintenance

**Single focused job:** keep the mapping table **aligned with raw** and **grow** it for new crawled rows.

### 5.1 Refresh `IsSeenInLastRun`

- **Join:** mapping table → **`tbl_RAW_Catalog`** on **`RawCatalogId` = **`Id`**.
- **`UPDATE`** mapping.**`IsSeenInLastRun`** from raw when it changed (optional: only touch **`MappingUpdatedAt`** when value changes).

### 5.2 New raw rows not yet mapped

- Select **`tbl_RAW_Catalog`** rows that satisfy the **same** official + join + not-deleted rules and **do not exist** in the mapping table.
- Run the **same** resolution as §2; **`INSERT`** successful resolves into the mapping table with **`MappingCreatedAt`**.

### 5.3 Optional orchestration

- One procedure (e.g. `sp_map_rawCatalog_catalogCountry`) that runs §5.1 then §5.2 in one transaction or batch, with logging.
- **SQL Agent** after raw catalog crawl / on your chosen schedule.

**Sync to draft retail (same job or next step):** from **`tbl_MAP_RawCatalog_CatalogCountry`**, compute staging aggregate **`(CatalogId, CountryId, IsSeenInLastRun)`** (e.g. `MAX` over mapped rows), then **`UPDATE tbl_CAT_CatalogRetailPrice_d`** with **`StatusID = 1`**, **`IsPrivate = 0`**, join on **`CatalogID`** + **`CountryId`**; **zero out** pairs with no mapped signal if that remains your rule. **Price** columns are **not** in scope here.

---

## 6. Files / modules (ew-db MasterDB)

| Item | Location |
|------|----------|
| Mapping table DDL | `MasterDB/dbo/table/tbl_MAP_RawCatalog_CatalogCountry.sql` (name TBD) |
| One-time backfill SP | `MasterDB/dbo/stored procedures/sp_MAP_RawCatalog_CatalogCountry_OneTime.sql` |
| Daily maintenance SP | `MasterDB/dbo/stored procedures/sp_map_rawCatalog_catalogCountry.sql` (name TBD) |
| Refactor | **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`**: drive **`IsSeenInLastRun`** from **`tbl_MAP_RawCatalog_CatalogCountry`** + aggregate; drop or stop using **`tbl_Staging_CatalogRetail_IsSeen`** for this path |
| Optional | Share resolution logic via TVF |

**EveryWatchDDL:** confirm whether a matching routine exists before adding procedures (project rule).

---

## 7. Validation (mapping + IsSeen path)

- One-time count matches expectation for official + resolvable raw rows.
- Daily run picks up **new** **`tbl_RAW_Catalog.Id`** values within one cycle.
- **`IsSeenInLastRun`** on the mapping table tracks raw after refresh.
- Aggregate over **`(CatalogId, CountryId)`** from the map matches what **`tbl_CAT_CatalogRetailPrice_d`** receives for **`IsSeenInLastRun`** after the sync join.
- Unresolved rows remain unmappable until **`tbl_CAT_RawCatalogMapping`** / catalog is fixed.
- **Ambiguous** raw rows (two+ **`CatalogId`** candidates) do not appear in the mapping table until data or rules are fixed; review queue / report is empty or shrinking after cleanup.

---

## 8. Future: catalog retail price updates

When you define the full flow (including **CreatedAt**, dates, and whether inserts are new **`tbl_CAT_CatalogRetailPrice_d`** rows vs updates), add a separate plan section or doc. **Reminder:** applying catalog retail price does **not** mean updating **`tbl_RAW_Catalog`**; raw remains the **source of truth** for crawl output.

---

## 9. Relation to existing plan

**`isseen_retail_price_sync.plan.md`** described **`tbl_Staging_CatalogRetail_IsSeen`** + **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`** as the path to **`tbl_CAT_CatalogRetailPrice_d.IsSeenInLastRun`**. **Current target design:** **`tbl_MAP_RawCatalog_CatalogCountry`** is the **intermediate** table; **`IsSeenInLastRun`** on **`_d`** is updated by joining **`CatalogId`** + **`CountryId`** to an aggregate built **from the map**, not from **`tbl_Staging_CatalogRetail_IsSeen`**. Keep or retire the staging table depending on whether anything else still depends on it.

---

## 10. Implementation steps (query-level order)

Do these in **`MasterDB/`** only (per repo rules). Before adding **new** stored procedures, do a **read-only** check under **`ew-db/EveryWatchDDL/dbo/routine`** for a matching name.

| Step | What to implement |
|------|-------------------|
| **1** | **Create the mapping table** — script `MasterDB/dbo/table/tbl_MAP_RawCatalog_CatalogCountry.sql`: columns **`RawCatalogId`** (PK), **`CatalogId`**, **`CountryId`**, **`IsSeenInLastRun`**, **`MappingCreatedAt`** (and optional **`MappingUpdatedAt`**, **`ResolutionNote`**); FKs/indexes as agreed. |
| **2** | **Confirm join columns in prod** — **`tbl_source_manufacturer_mapping`** includes **`CatSourceName`** (official filter: **`LIKE '%OFFICIAL%'`**); join **`SourceId`** + **`Manufacturer`** to **`tbl_RAW_Catalog`** same as today; **`CountryId`** / **`ManufacturerId`** NOT NULL. Adjust DDL/scripts if prod differs from repo snapshots. |
| **3** | **Shared resolution logic (optional but recommended)** — inline module or **`CREATE FUNCTION`** / proc fragment used by all steps below: build **`#RawBase`** (**`CleanKey`**, Rolex vs UDF), **`#MapTrim`** from **`tbl_CAT_RawCatalogMapping`**, **`#CdKeys`** from **`tbl_CAT_Catalog_d`**, same precedence as **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`** (mapping by trimmed **`ReferenceNo`**, then catalog fallback). |
| **4** | **One-time backfill SP** — e.g. `MasterDB/dbo/stored procedures/sp_MAP_RawCatalog_CatalogCountry_OneTime.sql`: official filter + resolve **`CatalogId`**; **`INSERT`** only when resolution yields **exactly one** **`CatalogId`** per **`RawCatalogId`**; if **multiple** candidates, **skip** and send to **review** (see §1 ambiguity); **`@DryRun`** / batch params optional. |
| **5** | **Daily mapping SP** — e.g. `MasterDB/dbo/stored procedures/sp_map_rawCatalog_catalogCountry.sql`: **`UPDATE`** **`IsSeenInLastRun`** from **`tbl_RAW_Catalog`** for rows already in the map; **`INSERT`** new rows only when resolution is **single-valued** (same ambiguity rule as step 4). |
| **6** | **Refactor IsSeen sync SP** — **`sp_Sync_PriceLastSeenDate_isSeenInLastRun.sql`**: stop depending on **`tbl_Staging_CatalogRetail_IsSeen`** / **`#RawResolved`** for the main path; **`SELECT CatalogId, CountryId, MAX(IsSeenInLastRun)`** (or equivalent) **from `tbl_MAP_RawCatalog_CatalogCountry`**; **`UPDATE tbl_CAT_CatalogRetailPrice_d`** join on **`CatalogID`** + **`CountryId`**; keep **`tblTransaction`** + zero-out rule for pairs with no mapped rows if still required. Remove **`TRUNCATE tbl_Staging_CatalogRetail_IsSeen`** from this SP unless another consumer needs it. |
| **7** | **SQL Agent / job script** — update `MasterDB/dbo/stored procedures/sqlagent_job_step_*.sql` (or equivalent): order **(a)** daily mapping SP, **(b)** refactored **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`**, **(c)** optional **`sp_PublishAllDataNew`** if same-day publish. |
| **8** | **Validate** — row counts after backfill; spot-check **`(CatalogId, CountryId)`** aggregates vs **`_d`** after a daily run; confirm **`tbl_Staging_CatalogRetail_IsSeen`** unused or dropped only after nothing else references it. |

Retail **price** amounts (**`Price`**, **`CreatedAt`** policy) stay **out** of this sequence until you define that flow.
