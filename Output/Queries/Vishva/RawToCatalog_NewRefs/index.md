---
type: Data Index
title: Queries/Vishva/RawToCatalog_NewRefs index
description: Folder for the ECH-693 work — scripts that take new manufacturer references from tbl_RAW_Catalog into tbl_CAT_Catalog_d. Scripts are written only after the requirements are agreed.
tags: [index, queries, vishva, raw-catalog, catalog, ech-693]
timestamp: 2026-10-31
---

# Queries/Vishva/RawToCatalog_NewRefs — index

Ticket: ECH-693, "Change the flow to add new refs from manufacturer in catalog".

Status: **requirements drafted; scripts 01–03 run (1,593 new refs staged, 4,991 raw rows marked `New`); script 04 written, not run yet.**

- Plan for building the requirements: [Plans/vishwa/raw-to-catalog-new-refs-requirements-plan.md](../../../Plans/vishwa/raw-to-catalog-new-refs-requirements-plan.md)
- Requirements (draft): [Documents/RawToCatalog_NewRefs_Requirements.md](../../../Documents/RawToCatalog_NewRefs_Requirements.md)

## Scripts (run in order, in SSMS — Claude never runs them)

1. [01_Create_RawRefMap_Table.sql](01_Create_RawRefMap_Table.sql) — `tbl_CAT_RawRefMap` (one row per official raw row, `CatalogId` NULL = unmapped) and its indexes. No views: coverage and the comma list are in `Check_Coverage_And_ByCatalog.sql` (temp tables).
2. [02_Create_SyncAndMatch_Procedure.sql](02_Create_SyncAndMatch_Procedure.sql) — `sp_CAT_RawRef_SyncAndMatch @SkipSync = 0, @Rekey = 0`: part 1 loads official raw rows into the map (blank references from the Mirror, Rolex ArtworkId repair, sources with IsActive NULL/1 and a name containing OFFICIAL), part 2 sets `CatalogId` by normalized ref. `@SkipSync = 1` runs part 2 only; `@Rekey = 1` (one time) keys the not-yet-mapped rows again with the new rules. Needs script 01.
3. [03_Create_Staging_Table_And_StageNew_Procedure.sql](03_Create_Staging_Table_And_StageNew_Procedure.sql) — `tbl_CAT_RawRefStaging` (one row per unique new ref, all later columns included) and `sp_CAT_RawRef_StageNew`. Needs scripts 01 and 02.
3b. [03b_Add_Review_Fields_To_Staging.sql](03b_Add_Review_Fields_To_Staging.sql) — adds 13 staging columns for the other `sp_Create_Catalog` fields (movement number and style come from raw in step 4; case / strap / bezel embellishments, indices materials, series, bezel style / type, nickname and pusher shape are filled in the review). `CatalogNotes` is not added. Run once after 03, before re-creating 04 and 06.
4. [04a_Create_MapValue_Procedure.sql](04a_Create_MapValue_Procedure.sql) — `sp_CAT_RawRef_MapValue`, our own value-mapping procedure: a copy of `sp_Map_RawValueToCatalog_Universal` (which stays untouched in `ew-db`) plus bezel / case-back material, indices style, strap style, crown embellishment, jewels, edition and dial stamp. Run before 04.
5. [04_Create_FillValues_Procedure.sql](04_Create_FillValues_Procedure.sql) — `tbl_CAT_RawRefUnmatchedValue` (raw values with no master value) and `sp_CAT_RawRef_FillValues` (most frequent raw value per field, mapped to master values, parsed case size / power reserve / water resistance, images, source link, conflict notes). `@Reprocess = 1` re-fills not-yet-approved rows. Needs scripts 01–03 and 04a.

6. [05c_Export_Master_Values_For_Review.sql](05c_Export_Master_Values_For_Review.sql) — read-only: every active master value for the review-filled fields (needed because `sp_Create_Catalog` rejects names that are not in the master tables). Not needed with read-only MCP.
6. [05b_Export_Review_Batch.sql](05b_Export_Review_Batch.sql) — read-only export of one manufacturer batch (all `IsApproved = 0` refs, conflict notes first, with raw Title / Description) for the Claude review. Written, not run.

Change after the first run: **step 2 now reads `tbl_CAT_RawCatalogMapping` first** (a key there wins, any brand, only when it points to exactly one active Watch catalog row; several catalogs = flagged in `MapNote`). Script 02 was edited; re-run it, then `EXEC dbo.sp_CAT_RawRef_SyncAndMatch @Rekey = 1` (one time; later runs use no parameter), then:

- [02b_Clean_Staging_After_MappingTable_Check.sql](02b_Clean_Staging_After_MappingTable_Check.sql) — lists, then deletes, staged refs (not approved, not executed) whose raw rows the mapping-table check matched. Workflow tables only.

7. [06_Create_CreateCatalog_Procedure.sql](06_Create_CreateCatalog_Procedure.sql) — `sp_CAT_RawRef_CreateCatalog`: cursor over `IsApproved = 1` refs, calls `sp_Create_Catalog` once per ref. **Dry run is the default** (`@IsDryRun = 1`); batch with `@ManufacturerName` / `@MaxRows`. Re-checks the catalog and `tbl_CAT_RawCatalogMapping` right before creating (refs found there are marked `Skipped`). Written, not run.

## Checks (read-only)

- [Check_Coverage_And_ByCatalog.sql](Check_Coverage_And_ByCatalog.sql) — read-only, temp tables: coverage per manufacturer and source, overall total, and the comma list of raw ids per catalog row.
- [Check_Step6_Results.sql](Check_Step6_Results.sql) — after step 6: statuses, errors grouped by message, skipped refs, created catalog rows, coverage.

- [Check_Step4_Results.sql](Check_Step4_Results.sql) — after step 4: fill counts overall and per manufacturer, values with no master value, the full table (raw text next to the mapped value) for one manufacturer, and the refs with notes.
- [Check_View_Unmapped_Refs.sql](Check_View_Unmapped_Refs.sql) — list the unique new refs staged by step 3 (summary per manufacturer, the full list, and the raw rows with no usable ref).
- [Check_Unmapped_Breakdown.sql](Check_Unmapped_Breakdown.sql) — per manufacturer: unmapped raw rows, rows without a usable ref, and the number of unique new refs behind them.
- [Check_Sample_Refs_For_Manufacturer.sql](Check_Sample_Refs_For_Manufacturer.sql) — 20 unmapped raw refs next to 20 catalog refs of one manufacturer, to see whether low coverage is new refs or a format difference.
