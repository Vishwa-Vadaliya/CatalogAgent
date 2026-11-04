---
type: Data Index
title: Queries/Vishva index
description: Index of Vishva's saved SQL query files.
tags: [index, queries, vishva, sql]
timestamp: 2026-10-24
---

# Queries/Vishva — index

- `Query1.sql` — DDL for `dbo.tbl_RAW_ArtworkTax` (EWMaster).
- `query2.sql` — `sp_Assign_Complications_To_Catalog` stored procedure (EWMaster).
- `Query3.sql` — per-ReferenceNumberId rollup (most-occurring DialColor/CaseMaterial/ModelName, top-10 images, FirstWatchId) driven by a list of ReferenceNumberIds.
- `Query4.sql` — cursor-based runner for `sp_Create_Catalog`.
- `Query5.sql` — adds the `EnrichmentSimilarityScore` column to `tbl_CAT_Catalog_d`.
- `Query6.sql` — diagnosing a `sp_PublishAllDataNew` FK-constraint error on `tbl_CAT_WatchToComplication`.
- `Query7.sql` — full summary (watches, reference numbers, enrichments, raw refs, published counts) for `ManufacturerId = 8`.
