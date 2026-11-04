---
type: Knowledge Fact
title: Databases, the mirror DB, and manufacturer ids
description: The two EveryWatch databases and how they relate — app DB vs catalog DB, the mirror history DB, cross-DB prefixes, ids differing between the two, and the manufacturer id table.
tags: [knowledge, databases, mirror, manufacturer-ids, cross-db]
db: both
keywords: [EveryWatch, EWMaster, MasterDB, catalog DB, app DB, mirror, Mirror.EWMaster, manufacturer id, ManufacturerId, CatalogId, which database, prefix]
timestamp: 2026-11-04
---

# Databases, the mirror DB, and manufacturer ids

Start here when a task crosses the two databases, or when you need a brand's id.
Always confirm columns against `D:\EW\ew-db` before using them. Items marked (?) are unconfirmed —
ask before relying on them. When two sessions disagree, the **newest** rule wins.

## 1. Databases

- **EveryWatch** (`EveryWatchDDL` in repo) = app DB: watches, refs, models, enrichment (`tblWatch*`, `tblReferenceNumber*`, `tbl_RE_*`).
- **EWMaster / MasterDB** = Catalog DB: `tbl_CAT_*`, `tbl_RAW_*`, `tbl_MAP_*`. Scripts often run from EWMaster → prefix app tables with `EveryWatch.dbo.`.
- Mirror DB: `Mirror.EWMaster.*_m`, `MIRROR.EW.*_m` — filled by `tr_UD_*` triggers on UPDATE/DELETE (history versions, `IdMirror`, `MirrorDate`). A big update writes as many mirror rows.
  - **Always fetch mirror data by ID** — the `CatalogId`, or the `Id` column of the raw catalog table (`tbl_RAW_Catalog`) — and keep a filter on the updated date (or similar). Don't scan the mirror table without an ID.
- **Ids differ between the two DBs** (manufacturer, dial color, case material…).
  - Manufacturer bridge: `EveryWatch.dbo.tblManufacturer.CatalogId` = `tbl_CAT_Manufacturer_d.ManufacturerId`.
  - Dial color / case material: resolve ids to **names** and match on names. A watch or catalog can have several → comma-separated.

## 2. Manufacturer ids

| Brand                                                                    | EveryWatch (app) | EWMaster (catalog)                                                |
| ------------------------------------------------------------------------ | ---------------- | ----------------------------------------------------------------- |
| Rolex                                                                    | 257              | 129                                                               |
| Patek Philippe                                                           | 193              | 114                                                               |
| Audemars Piguet                                                          | 142              | 12 (scripts often use `ManufacturerName LIKE 'Audemars Piguet%'`) |
| Cartier                                                                  | 23               | 26 (?)                                                            |
| IWC                                                                      | 5                |                                                                   |
| Hermès                                                                   | 11               |                                                                   |
| Omega                                                                    | 123              | 108                                                               |
| Mathey-Tissot                                                            | 221              |                                                                   |
| Breguet / Breitling / Longines / TAG Heuer / Tudor / Vacheron Constantin |                  | 19 / 20 / 89 / 141 / 143 / 148                                    |

- "5 brands" list (app): 142, 23, 193, 257, 269 (269 = ?).
- `Manufacturer114_Watch_EnrichmentResults_Scores.sql` uses 114 on app-DB `tblWatch_d` — brand in the app DB unknown (?).

## See also

- [conventions.md](conventions.md) — the four data layers (crawl/draft/publish/audit) and `MA_Id` identity writeback.
- [watches.md](watches.md) — the draft/publish pattern inside the app DB.
