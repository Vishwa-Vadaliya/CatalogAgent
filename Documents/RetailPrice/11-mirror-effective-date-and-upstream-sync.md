---
type: Document
title: Mirror EffectiveDate model and upstream crawler sync
description: Where retail-price raw data actually comes from before it reaches tbl_RAW_Catalog, the structural S1/S2/S3 model for deriving a trustworthy price-change date from mirror rows, and the IsDeleted=1 exclusion fix.
tags: [documents, retail-price, catalog, mirror, effective-date]
timestamp: 2026-10-31
Status: Draft for review (summarized from ew-brain `03-architecture/retail-price-lifecycle.md` and `04-modules/enricher/retail-price/05-implementation.md` + `06-decisions.md`)
Confidence: Medium-High (source marks some operational details as "to confirm in Agent")
---

# Mirror EffectiveDate model and upstream crawler sync

This fills two gaps upstream and inside the flow already documented in [01-overview-and-glossary.md](01-overview-and-glossary.md) / [02-end-to-end-flow.md](02-end-to-end-flow.md): (1) where `tbl_RAW_Catalog` itself comes from, which this document set has never traced past "the crawler"; and (2) a clean conceptual model for deriving a trustworthy price-change date from mirror rows.

## 1. Upstream: how `tbl_RAW_Catalog` gets filled in the first place

Everything in this document set starts at `tbl_RAW_Catalog`. One step earlier:

**`dbo.sp_SYNC_SyncWatchesCatalog`** (`ew-db`, `MasterDB/dbo/stored procedures/`) reads watch-listing data from the **MACrawler** database (Artworks, Watches, Sources, Auctions as coded there), filtered by `SourceDataType = 5`, `Project = 'w'`, `isRunning = 0`, `IsSeenInLastRun != 3`, and "changed since last sync" (crawler `UpdatedDate` vs `SyncDate`). It builds a working set and inserts/updates `dbo.tbl_RAW_Catalog` (plus `tbl_RAW_Source`, raw auctions, `tbl_RAW_Media`), logs `tblTransaction` rows for create vs update, and writes back to crawler `SYNC_*` tables / calls crawler `sp_SYNC_Sync*ByRunId` procs so the crawler can advance its own sync state.

**Operational:** runs as its own SQL Agent job, separate from the map/retail-sync/insert chain, on an approximately hourly cadence (confirm exact schedule in Agent).

**Why it matters for retail price:** this procedure is **upstream of everything** — `tbl_MAP_RawCatalog_CatalogCountry`, `sp_Sync_PriceLastSeenDate_isSeenInLastRun`, and `sp_Insert_CatalogRetailPrice_FromMapping` all depend on a current `tbl_RAW_Catalog`. It is not part of the same run as map/sync/insert; correct production order is **raw sync first (its own schedule), then map → sync retail flags → insert history** when a coherent end-to-end run is needed.

**Timestamp meanings across the three layers:**
| Layer | What the timestamp means |
|---|---|
| Crawler `UpdatedDate` | When the source system/crawl last changed that listing — business time in the crawler DB, not when EWMaster synced it. |
| `tbl_RAW_Catalog` (after sync) | What the crawl *thinks*, as of the last sync run; `SyncDate` records when EWMaster pulled it. |
| `Mirror.EWMaster.tbl_RAW_Catalog_m` | When EWMaster actually *applied* that change — the mirror trigger (`tr_UD_tbl_RAW_Catalog`) fires after `UPDATE`/`DELETE` on the primary row, so mirror timing is "after sync applied," not "when the listing changed upstream." |

## 2. Mirror EffectiveDate — the S1/S2/S3 model

**EffectiveDate** = the business date assigned to a price point for ordering history and same-day dedup. It is deliberately **not** always `UpdatedDate`, `MirrorDate`, or `CreatedDate` taken at face value:

| Field | What it actually is |
|---|---|
| `UpdatedDate` (mirror) | When crawl *last wrote* that row's stamp — reliable on live raw after a past crawler fix, but historically unreliable on mirror rows (see below). |
| `MirrorDate` | When EWMaster applied the change and the mirror trigger pushed the *previous* live snapshot into history — "when the old price was replaced." |
| `CreatedDate` | When the raw listing row was first created — used only as a fallback for a listing's very first mirror snapshot. |

**Why mirror `UpdatedDate` can't be trusted at face value (history of two bugs, now fixed):** (1) the crawler used to update `Price` on a price change without refreshing `UpdatedDate`; (2) the mirror trigger's column list didn't even copy `UpdatedDate`, so mirror rows got `NULL` regardless of what live held. Both are now fixed going forward, but there is a **one-time transition** per `RawCatalogId`: the first mirror row with a non-null `UpdatedDate` after the fix often still carries a stale pre-fix value.

**The three scenarios**, determined structurally (no date-gap thresholds) by walking each `RawCatalogId`'s mirror rows in `MirrorDate` order and tracking whether any *earlier* row already had `UpdatedDate IS NOT NULL`:

| Scenario | How to recognize | Trust mirror `UpdatedDate`? | EffectiveDate used |
|---|---|---|---|
| **S1 — Pre-fix** | `UpdatedDate IS NULL` on this row | No | Derived (see below) |
| **S2 — Transition** | `UpdatedDate IS NOT NULL`, but no prior row for this id had a non-null `UpdatedDate` | No — exactly one row per id, the first flip from all-NULL to non-null, still stale | Derived (same as S1) |
| **S3 — Reliable** | `UpdatedDate IS NOT NULL` and at least one prior row also had one | Yes | `= mirror UpdatedDate` |

**Derivation for S1/S2:** first mirror row for an id → `EffectiveDate = CreatedDate`. Any later S1/S2 row → `EffectiveDate = MirrorDate of the previous mirror row` (i.e. when the previous price was pushed into history). For the current live `tbl_RAW_Catalog` row (not a mirror scenario) → `EffectiveDate = live UpdatedDate`.

**Worked example** (prices stepping 10→15→20→25 in mirror, live ends at 30):

| Snapshot | Price | Mirror UpdatedDate | MirrorDate | Scenario | EffectiveDate used |
|---|---|---|---|---|---|
| Mirror 1 | 10 | NULL | 4/15 | S1 | 4/13 (CreatedDate) |
| Mirror 2 | 15 | NULL | 4/17 | S1 | 4/15 (prior MirrorDate) |
| Mirror 3 | 20 | 4/13 (stale) | 4/19 | S2 | 4/17 (prior MirrorDate — still derived, not the stale stamp) |
| Mirror 4 | 25 | 4/19 | 4/21 | S3 | 4/19 (now trusted) |
| Live | 30 | 4/23 | — | — | 4/23 (live UpdatedDate) |

**Where this applies:** `sp_Insert_CatalogRetailPrice_FromMapping` uses the full S1/S2/S3 CASE when building mirror history, unioning with live RAW and deduping by calendar day of EffectiveDate. Note this is **not universal** — `sp_map_rawCatalog_catalogCountry`'s reference fallback uses a simpler `COALESCE(UpdatedDate, MirrorDate)`, not the full scenario model, and live-path `PriceLastSeenDate` uses its own rules (see `Knowledge/retail-price.md`) — don't assume every mirror-touching procedure applies this model.

## 3. `IsDeleted = 1` exclusion (soft-deleted listings)

**Past gap:** retail-history insert could still read mirror rows for a listing even after that listing was removed (soft-deleted) from the manufacturer's site on raw, because mirror snapshots weren't consistently filtered by `IsDeleted`.

**Current rule:** `sp_Insert_CatalogRetailPrice_FromMapping` requires `dbo.tbl_RAW_Catalog.IsDeleted = 0` on the current row for a `RawCatalogId`, and excludes `Mirror.EWMaster.tbl_RAW_Catalog_m` rows with `IsDeleted = 1`. The mapping mirror helpers (`#MirrorBestRef` / `#MirrorBestPrice`, both Daily and OneTime variants) apply the same mirror `IsDeleted` filter. The map's own `map.IsDeleted = 0` requirement on the active row is unchanged and still required.

## Source

Summarized from ew-brain `03-architecture/retail-price-lifecycle.md` (upstream sync) and `04-modules/enricher/retail-price/05-implementation.md` + `06-decisions.md` (EffectiveDate model, IsDeleted fix). Confirm exact SQL Agent job names/schedules against production — the source docs flag those as unconfirmed too.
