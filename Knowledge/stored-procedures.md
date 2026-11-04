---
type: Knowledge Fact
title: Stored procedures & functions — directory
description: One-line directory of the stored procedures and functions used across catalog work, with pointers to the topic file that explains each in context.
tags: [knowledge, stored-procedures, functions, sp, directory]
db: both
keywords: [stored procedure, sp_, usp_, sp_Get_CatalogDetails, sp_Create_Catalog, sp_Update_Catalog, sp_PublishAllDataNew, sp_Create_Enrule, sp_add_model, sp_Populate_NewRefStaging, sp_Create_Transaction, publish, what does sp do]
timestamp: 2026-11-04
---

# Stored procedures & functions

A directory: what each routine is for, and where the full context lives. Always confirm a routine
exists in the right folder of `D:\EW\ew-db` before referencing it — see
[ew-db-repo.md](ew-db-repo.md) and rule A6.

## Catalog

- `sp_Get_CatalogDetails @ManufacturerName / @ReferenceNumbers, @TempTableName = '##x'` → all catalog fields into a **global** temp table (a local `#` vanishes — dynamic SQL).
- `sp_Create_Catalog`, `sp_Update_Catalog` / `sp_update_catalog` (model name, primary image…; bulk fixes = one `exec` line per catalog), `sp_Delete_Catalog`, `sp_add_model 'Name', ManufacturerId`.
  - Cursor bulk pattern is fine (loop a temp table, write errors to a status column).
  - Create models: `catalogid IS NOT NULL AND catmodel IS NULL AND modelid IS NULL`; assign existing: same but `modelid IS NOT NULL`.
- `sp_PublishAllDataNew` (EWMaster) publishes draft → live; deleting a model still referenced by `tbl_CAT_Catalog.ModelId` fails (FK). Calls `sp_create_EnrichmentRefName_Bulk`. `sp_UT_PublishAllDataNew` = app-side publish.
  - Never put this call in a script handed to the user — rule A9 in [../Rules/00-core.md](../Rules/00-core.md).

## Enrichment

- `sp_create_EnrichmentRefName(_Bulk)`, `sp_Create_Enrule`, `sp_create_enrichment_rule`, `sp_update_enrichment_rule` — enrichment rules per tier (leaf/P/GP/GGP). Context: [enrichment.md](enrichment.md).
- `sp_get_coreRulesSummary` → RuleId, NumberOfField, comma list of set fields.

## Raw to catalog

- `sp_Populate_NewRefStaging` → `sp_Approve_StagingRecord` → cursor `sp_Create_Catalog` (official sources only). Context: [../Documents/RawToCatalog/RawToCatalog_NewRefs_Overview.md](../Documents/RawToCatalog/RawToCatalog_NewRefs_Overview.md).
- `sp_SYNC_SyncWatchesCatalog` (~hourly) loads crawler data into `tbl_RAW_Catalog` — upstream of the whole retail-price chain. Context: [retail-price.md](retail-price.md).

## Retail price

The daily job chain and what each of its procedures does is in [retail-price.md](retail-price.md):
`sp_map_rawCatalog_catalogCountry`, `sp_update_CatalogRetailPrice_FromMapping`,
`sp_Insert_CatalogRetailPrice_FromMapping`, `sp_UpdateMap_PriceLastSeen`,
`sp_Sync_PriceLastSeenDate_isSeenInLastRun`, `ResyncCatalogRetailPriceToEW`,
`usp_ConvertReferenceNumberMSRPCurrency`. Per-procedure documents:
[../Documents/RetailPrice/](../Documents/RetailPrice/index.md).

## Transactions

- `sp_Create_Transaction` / `usp_CreateTransaction` — see B6 in [../Rules/10-sql-style.md](../Rules/10-sql-style.md) for the required capture pattern.

## Functions

- `fn_extractnumberandalphabet` / `fn_ExtractNumbersAndAlphabets`, `fn_ConvertToRefStructure` / `fn_ConvertToStructure`, `fn_CleanReferenceNumber` — see [references-and-models.md](references-and-models.md).
- `usp_mergeMaster` enqueues into `tblAttributeMergeQueue` — see [references-and-models.md](references-and-models.md).
