---
type: Knowledge Fact
title: EveryWatch DB — core structural conventions
description: Foundational, cross-cutting conventions about how the EveryWatch/EWMaster schema is organized — the four data layers, draft identity writeback, synonym-table resolution pattern, schema source-of-truth, watch/lot status lifecycles, and the auction/marketplace routing enums. Complements the catalog/enrichment-specific facts in the other Knowledge topic files.
tags: [knowledge, database, ew-db, schema, conventions]
timestamp: 2026-10-31
Status: Draft for review (summarized from ew-brain `data-reference/conventions/*` and `data-reference/lifecycles/*`)
Confidence: High (source), summarized here — reconfirm specific row counts/dates before quoting as current
---

# EveryWatch DB — core structural conventions

These are schema-shape facts, not catalog/enrichment-specific facts (those stay in the topic files listed in [index.md](index.md)). Summarized from ew-brain's `data-reference/conventions/` and `data-reference/lifecycles/`.

## 1. The four data layers

EveryWatch data moves through four tiers:

| Layer | Representative tables | Who writes |
|---|---|---|
| **Crawl** | `MAC_Auctions`, `MAC_Artworks`, `MAC_Watches`, `MAC_Sources` (linked server `[EC2AMAZ-K9AGUNN]`) | Crawlers, externally |
| **Draft** | `tblWatch_d`, `tblEvent_d`, `tblAuctionLot_d`, `tblMediaAsset_d`, `tblRawWatch` | Sync SPs (`usp_Crawler_*`) |
| **Publish** | `tblWatch`, `tblEvent`, `tblAuctionLot`, `tblMediaAsset` | Publish SPs (`usp_PublishWatches`, `usp_Publish_Event`) |
| **Audit/history** | `tblLog`, `tblStatusLog`, `StoreProcedureError`, `tblPriceHistory`, `tbl_ENT_Trsansaction` | Every sync run, append-only |

**Why the split:** crawl/draft is a *trust boundary* (external scrapers can't be schema-enforced; draft is where EveryWatch's own SPs validate and resolve FKs). Draft/publish is a *moderation boundary* (draft is where moderators work; publish is what the site serves — the site never reads draft, CMS never reads publish).

**`tblWatch_d` has 36 incoming FKs (#1 in the whole DB) vs `tblWatch`'s 18.** Most cross-table relationships — enrichment, every junction table, all moderation state — point at the **draft** table, not publish. A join tracing lot → watch → manufacturer almost always wants `tblWatch_d`. If a query reads from publish and tries to join publish-only equivalents of everything else, it's probably losing data.

**The audit layer is not noise, and is not purely append-only in effect:**
- `tblLog` (~289M rows) — the only place sync errors get a human-readable message tied to a specific watch id.
- `StoreProcedureError` (~21M rows) — first place to check for a sync failure (line number, severity, SP name).
- `tblStatusLog` (~533M rows) — the only history of *why* a watch is in its current status.
- **`tblPriceHistory` (~158M rows) is dual-purpose**: it is *both* an audit table (price changes append here during marketplace sync) *and* a live read source for the website's price-history feature. Don't treat it as disposable log noise — it's load-bearing for a live feature too.

**Naming rule:** draft tables end in `_d`; publish tables drop the suffix. Audit tables follow no consistent naming pattern — their layer is defined by which SPs write to them, not by name.

## 2. `MA_Id` — draft identity and the linked-server writeback

`MA_Id` is the draft id assigned by the CMS to a crawled entity (watch or event) — **the crawler doesn't own it, the CMS does.** After a sync run processes a crawl row, the SP writes `MA_Id` back across the linked server (`[EC2AMAZ-K9AGUNN]`) to the crawl row, so the next sync can find the matching draft record. Without this writeback, every sync run would create duplicates.

Three columns get written back across the linked-server boundary:
- **`MA_Id`** — once written, this row's sync target is locked in.
- **`SyncDate`** — timestamp the row was processed. The next run skips any crawl row whose `UpdatedDate <= SyncDate`. This doubles as the retry mechanism: if an SP errors *before* writing `SyncDate`, the row's `UpdatedDate` stays newer than `SyncDate` and it gets retried automatically on the next run — no separate retry queue or DLQ exists.
- **`SyncError`** — populated only on failure. This is the cross-team debugging contract: the crawler team reads this column in the crawl DB to see "your row failed because of Y" without needing access to EveryWatch's own logs. Treat its format as a real interface, not a log — changing it changes the contract.

## 3. Synonym tables — the raw-text-to-ID resolution + moderation pattern

[[feedback_always_join_on_id_columns]] says to always resolve text input to an ID via a lookup table before joining — synonym tables are the mechanism underneath that rule for raw crawled text.

Every `tbl<Entity>Synonym` table plays **two roles** at once:
1. **Forward lookup** — `sp_UT_SyncRawData` / `usp_AutoFill<Entity>Data` SPs query it to resolve raw text (e.g. `"Stainless Stl."`) to a catalog id (e.g. `CaseMaterialId`), written into `tblWatch_d` on a match.
2. **Unmatched-values queue** — on a miss, the raw text is inserted into the synonym table itself with no id mapping, for a moderator to review and either link to a real catalog row or reject.

16 of these exist, each paired with a catalog table: `tblManufacturerSynonym`, `tblModelSynonym`, `tblReferenceNumberSynonym`, `tblColorSynonym`, `TblMaterialSynonym`, `tblCaseMaterialSynonym`, `tblBraceletMaterialSynonym`, `tblClaspMaterialSynonym`, `tblCaseSizeSynonym`, `tblMovementSynonym`, `tblCurrencySynonym`, `tblFeatureSynonyms` (plural name, singular catalog target `tblFeatures`), `tblComplicationSynonym`, `tblConditionSynonym`, `tblNewnessSynonym`, `tblUnitSynonym`. Plus `TblSynonymMasterLinkingQueue` — not a synonym table itself, but the cross-attribute moderator queue for entries awaiting linking.

**Practical rules:** never write to a synonym table directly (bypasses the lookup/resolution contract); never treat it as "all values of X" (it includes pending/rejected raw text, not canonical values — use the real catalog table for that); do use it to check "has this raw text been seen before." Growing unmapped-entry counts are a leading indicator of either a new source with unfamiliar text patterns, or a stalled moderation queue.

## 4. Schema source of truth — prod drifts from the DDL repo

The DDL repo (`ew-db`) accretes stale scripts, `Copy of *` files, and one-off migration snapshots — it does not retract them. At one point of comparison, the DDL repo showed **631** table files vs **482** base tables actually live in prod — a ~150-file gap of files that describe tables that were never created or have since been dropped.

**Practical rule for this project:** [Rules/00-core.md](../Rules/00-core.md) already tells you to check `D:\EW\ew-db` schema files as ground truth for column names — that's fine for syntax and structure, but **if a table or column's existence is load-bearing for a conclusion, confirm it's still live** (via an actual query against the DB, not just the presence of a `.sql` file in the repo) rather than trusting the DDL file alone. The DDL repo **is** the right source for *history* — "when was this column added" — just not for "does this table currently exist."

## 5. `tblWatch_d.Status` — the watch moderation lifecycle (not currently documented at all)

22 status codes are defined; roughly 18 are actually populated in prod at any given time (3 — Temporary Discarded, Temp Discarded By Moderator, Basic Data Check Failed — are documented but have shown zero rows; possibly dead values or states too transient to ever be caught by a snapshot query).

Key codes: `1` Lot From Sync (initial) → `2`/`3` Basic Data Passed/Failed → `6` Ready For Auto Clean → `9` Ready For Moderation (auction) or `16` Ready For Publish (marketplace) → `17` Published (dominant terminal state, typically the large majority of live rows) → `18`/`19`/`21` various post-auction waiting states. `11` = Permanent Discarded, `12` = Save For Later (price-validation discard target).

**The Basic Data rule (why a watch is stuck at Status 3):** a watch gets `Status = 2` iff at least one of `RawManufacturer`, `RawModel`, `RawReferenceNumber` is non-empty at sync time; if all three are empty, `Status = 3`. No other criterion. Fixing crawler-side population of any one of those three fields is the only way to move a Status-3 watch forward.

Dominant flow: `1 → 2 → 6 → 16 → 17` for marketplace, with `9` inserted before `16` for auction (human moderation gate).

## 6. `tblAuctionLot_d.LotStatusId` — full enum (CatalogBrain previously only had a partial 3-value version)

[watches.md](watches.md) currently says only "2/4 = Sold, 1 = Active, 3 = Unsold." Fuller picture:

| LotStatusId | Meaning | Notes |
|---|---|---|
| `NULL` | no value | |
| `1` | Upcoming/Available | Auction not started, or marketplace lot still buyable |
| `2` | Sold | Auction lot sold |
| `3` | Unsold | Auction lot missed reserve |
| `4` | Withdrawn (auction) / Sold-or-removed (marketplace) | Usually the largest bucket overall |
| `5` | **Manually set — do not overwrite** | Human-edit guard: sync SPs check for `5` before writing `LotStatusId` and skip the update if found. Equivalent in spirit to an `EventModerationStatus` floor for events. **Must be respected in any code that touches `LotStatusId`** — removing the check silently destroys moderator work. |
| `6` | Undocumented | A non-trivial number of rows carry this value with no corresponding branch in the known sync-SP calculation logic; parked as a low-priority open question upstream, not something to build logic around without re-deriving it. |

For analytics, treat `5` as its own bucket distinct from `4` — both look terminal but mean very different things ("withdrawn" vs "a human said don't touch this").

## 7. `SourceDataType` vs `EventTypeId` — two parallel auction/marketplace routing enums

Both encode the same auction-vs-marketplace distinction but live at different scopes, and should agree for a given source:

| Enum | Lives on | Values |
|---|---|---|
| `SourceDataType` | `MAC_Sources` (crawl-side) | `1, 2, 3` = auction (split historically by source family, otherwise equivalent); `4` = marketplace. Note: the retail-price ingestion procedure (`sp_SYNC_SyncWatchesCatalog`) filters on `SourceDataType = 5` — a value outside this auction/marketplace pair, for retail-listing ingestion specifically. |
| `EventTypeId` | `tblInfoSource` (registry-side) | `1` = Auction, `2` = Marketplace |

If `SourceDataType` and `EventTypeId` disagree for a given source, treat that as a data-quality bug, not an intentional distinction — they're meant to encode the same fact at two different join points.

## 8. Naming convention — which tables are real vs operational scratch

Two patterns are the live, canonical shapes: `Tbl<Entity>`/`tbl<Entity>` (casing is inconsistent and means nothing — don't read meaning into `tbl` vs `Tbl`), and `<table>_d` (the draft layer, see §1).

Everything else is operational scratch and should not shape query logic or be treated as a real source: `*_Backup_<date>` / `*_Bkp_<date>` / `*_<YYYYMMDD>` (manual pre-migration snapshots), `*_DeleteMe` / `*_deleteme` (personal scratch flagged for cleanup), `Tmp_*` / `TMP_*` / `tmp_*` (temp/staging), `Copy of *` (accidental SSMS copies). If you find yourself wanting to query one of these, that's usually a sign the real canonical table hasn't been identified yet — look for it rather than using the scratch copy. One exception worth being cautious about: a table with a person's-name suffix that is *not* `_DeleteMe`-shaped (e.g. a large table that mirrors a real one almost row-for-row) may be too large/active to dismiss as junk by the naming heuristic alone — verify before ignoring it.
