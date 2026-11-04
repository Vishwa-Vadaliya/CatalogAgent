---
type: Data Index
title: Documents/RetailPrice/sp index
description: One document per retail price stored procedure (how it works, step by step) with its status.
tags: [index, documents, retail-price, stored-procedures]
timestamp: 2026-10-28
---

# Documents/RetailPrice/sp — index

| SP | Document | Status |
|---|---|---|
| `sp_SYNC_SyncWatchesCatalog` | [01-sp-sync-watches-catalog.md](01-sp-sync-watches-catalog.md) | In use (job schedule to confirm) |
| `sp_map_rawCatalog_catalogCountry` | [02-sp-map-raw-catalog-catalog-country.md](02-sp-map-raw-catalog-catalog-country.md) | In use (called by the update SP) |
| `sp_update_CatalogRetailPrice_FromMapping` | [03-sp-update-catalog-retail-price-from-mapping.md](03-sp-update-catalog-retail-price-from-mapping.md) | **In use (confirmed)** |
| `sp_UpdateMap_PriceLastSeen` | [04-sp-update-map-price-last-seen.md](04-sp-update-map-price-last-seen.md) | In use (called by the update SP) |
| `sp_Sync_PriceLastSeenDate_isSeenInLastRun` | [05-sp-sync-price-last-seen-date-is-seen-in-last-run.md](05-sp-sync-price-last-seen-date-is-seen-in-last-run.md) | **Usage to confirm** (not called by the update SP) |
| `sp_PublishAllDataNew` (retail step) | [06-sp-publish-retail-step.md](06-sp-publish-retail-step.md) | In use |
| Other / not in use | [07-other-and-not-in-use.md](07-other-and-not-in-use.md) | `sp_Insert_CatalogRetailPrice_FromMapping` **not in use (confirmed)**; others to confirm |
