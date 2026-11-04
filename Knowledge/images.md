---
type: Knowledge Fact
title: Image tables
description: Where images live in each database — catalog media, watch media assets, enrichment media and raw media — and which filters apply to each.
tags: [knowledge, images, media, primary-image]
db: both
keywords: [image, images, media, IsPrimary, primary image, tbl_CAT_Media, tblMediaAsset, tbl_RE_ReferenceEnrichmentMediaAsset, tbl_RAW_Media, Preview960, S3Url, orderIndex]
timestamp: 2026-11-04
---

# Image tables

The rule for *which* image to take — the primary one only — is B5 in
[../Rules/10-sql-style.md](../Rules/10-sql-style.md). This file is where the tables are.

- **Catalog DB (MasterDB):** `tbl_CAT_Media` / `tbl_CAT_Media_d` (`CatalogId`, `URL`, `S3Url`, `IsPrimary`).
- **EveryWatch DB:**
  - Watch: `tblMediaAsset` / `tblMediaAsset_d` (`WatchId`, `Url`, `Preview960`, `IsPrimary`).
  - Enrichment: `tbl_RE_ReferenceEnrichmentMediaAsset` (`ReferenceEnrichmentId`, `IsPrimary = 1`, `Preview960` / `Original`).
- **No `IsDeleted` filter on the EveryWatch image tables** (`tblMediaAsset(_d)`, `tbl_RE_ReferenceEnrichmentMediaAsset`) — the flag isn't maintained there. Filter only `IsPrimary = 1`.
- **Raw images:** `tbl_RAW_Media` (`RawCatalogId = trc.Id`, no `IsDeleted` filter); no `IsPrimary` column — the primary is the row with the lowest `orderIndex`.

## See also

- [../PythonScripts/](../PythonScripts/index.md) — `check_tilt.py` flags tilted catalog images, `pick_best_image.py` picks the most vertical image per reference.
- [workflows/image-match-review.md](workflows/image-match-review.md) — the per-brand image match review.
