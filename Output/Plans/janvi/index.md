---
type: Data Index
title: Plans/janvi index
description: Index of Janvi's plan documents.
tags: [index, plans, janvi]
timestamp: 2026-10-24
---

# Plans/janvi — index

- [catalog_media_download_sp.plan.md](catalog_media_download_sp.plan.md) — ImageDownloadStatus/ArtworkPhotosId columns and `sp_SetCatalogMediaImageDownloadStatus` on EWMaster.
- [catalog_media_image_status_batch.plan.md](catalog_media_image_status_batch.plan.md) — single batch SP for catalog media image-download status (all errored rows).
- [isseen_retail_price_sync.plan.md](isseen_retail_price_sync.plan.md) — production daily IsSeenInLastRun retail-price sync flow.
- [mapping_pricelastseen_isseen.plan.md](mapping_pricelastseen_isseen.plan.md) — as-built review of the mapping + retail pipeline (PriceLastSeenDate, IsSeenInLastRun).
- [retail_price_last_seen_date_continuous.plan.md](retail_price_last_seen_date_continuous.plan.md) — daily flow keeps `PriceLastSeenDate` right for public verified prices (latest = map date, older = next `CreatedAt`).
- [retail_price_rolex_reference_guard.plan.md](retail_price_rolex_reference_guard.plan.md) — fix the insert SP's reference guard so Rolex prices are not dropped (leading `m` / `ArtworkId` rule), plus a one-time catch-up.
- [ref_production_status_continuous.plan.md](ref_production_status_continuous.plan.md) — keep `tbl_CAT_Catalog_d.RefProductionStatusID` up to date daily from map `IsSeenInLastRun` (any seen = In Production, else Out).
- [raw_catalog_retail_mapping_and_price_sync.plan.md](raw_catalog_retail_mapping_and_price_sync.plan.md) — `tbl_MAP_RawCatalog_CatalogCountry` one-time load and daily maintenance.
