---
type: Data Index
title: Google Sheets index
description: Index of the Google Sheets and Drive folders the team works with; the sheets themselves stay in Google Drive.
tags: [data, google-sheets, index]
timestamp: 2026-10-24
---

# Google Sheets index

Links to the Google Sheets we work with. The sheets themselves stay in Google Drive; this file is only the index.

## Sheets

| Name | Purpose | Owner | Link | Tabs / notes |
|------|---------|-------|------|--------------|
| Catalog Traceback | Change log for the catalog — every manual rename of a ReferenceNumber or ModelName, every delete, every merge, with the reason and a review decision. | Vishva | [Open](https://docs.google.com/spreadsheets/d/1l23GqhRziHUNjeijLtxVTAZurtdhjPTKNkbV5xTvqEE/edit?gid=694723679#gid=694723679) | Spreadsheet ID: `1l23GqhRziHUNjeijLtxVTAZurtdhjPTKNkbV5xTvqEE`. `Sheet2` (gid 694723679) — **current structure**, see below. `Sheet1` (gid 0) — the old free-text log (45 rows), not yet migrated. |
| Rolex Nicknames | Every Rolex catalog row in the DB (catalogid, model, reference), with the nickname it currently has and the nickname it should have. Source sheet for the Rolex nickname assignment. | Vishva | [Open](https://docs.google.com/spreadsheets/d/1OhYcxSITOt75BVJZVmyx7ijdhGsWpho--TCvYWx5VRg/edit?gid=0#gid=0) | Spreadsheet ID: `1OhYcxSITOt75BVJZVmyx7ijdhGsWpho--TCvYWx5VRg`. `Sheet1` (gid 0), 9,673 rows. A-E came from the DB; F-L (`SuggestedNickname`, `ConditionalNickname`, `Condition`, `AltNames`, `Scope`, `Confidence`, `Status`) were added by the agent — A-E are never overwritten. |
| (name TBD) | (purpose TBD) | | [Open](https://docs.google.com/spreadsheets/d/1PV7a6GqQemUivpCZnCxEB-CBEdKdt2R_xuWgiK-Ac5M/edit?gid=31837576#gid=31837576) | Spreadsheet ID: `1PV7a6GqQemUivpCZnCxEB-CBEdKdt2R_xuWgiK-Ac5M` |

## Catalog Traceback — `Sheet2` structure

One row per change made to the catalog. Built and rebuildable with
`PythonScripts/catalog_traceback_setup.py` (dry run by default; `--write` to apply).

**Two header rows.** Row 1 groups the columns into blocks, row 2 holds the column names; both are
frozen. Only the columns relevant to a change are filled — the rest stay empty.

| Group | Col | Header | Notes |
|---|---|---|---|
| **LOG ENTRY** | A | `Date` | When the change was made. `yyyy-mm-dd`. |
| | B | `ChangedBy` | Who made it. |
| | C | `Brand` | Manufacturer, so the log filters by brand. |
| **CATALOG** | D | `CatalogId` | `tbl_CAT_Catalog_d.CatalogId`. |
| | E | `ReferenceNumber` | The ref on that row, **as it was before the change**. Plain text. |
| | F | `EnrichmentId` | `tbl_RE_ReferenceEnrichment.ReferenceEnrichmentId`. |
| **MODEL** | G | `ModelId` | `tbl_CAT_Model_d.ModelId`. |
| | H | `ModelName` | The model name, **as it was before the change**. Plain text. |
| **CHANGE** | I | `Action` | Dropdown: `Renamed` / `Deleted` / `Merged`. |
| | J | `Field` | Dropdown: `ReferenceNumber` / `ModelName` / `CatalogId`. |
| | K | `OldValue` | Value **before**. Fill for `Renamed`/`Merged`. Plain text. |
| | L | `NewValue` | Value **after**. Fill for `Renamed`. Plain text. |
| | M | `MergedIntoId` | The id that **survived** a merge or duplicate delete. |
| | N | `Reason` | Why, in words. |
| **REVIEW** | O | `Accept/Reject` | Dropdown: `Pending` / `Accepted` / `Rejected`. The reviewer's decision. |

**Which columns get filled**

| Change | Filled |
|---|---|
| Catalog row deleted | `CatalogId` — `Field` = `CatalogId` |
| Reference renamed | `CatalogId`, `ReferenceNumber` — `Field` = `ReferenceNumber`, with `OldValue`/`NewValue` |
| Model renamed or deleted | `ModelId`, `ModelName`, `CatalogId` — `Field` = `ModelName`; no `ReferenceNumber` |
| Duplicate merged | as for the entity, plus `MergedIntoId` = the id that survived |

**`EnrichmentId` (F) is left blank**, never placeholdered. It lives in
`EveryWatch.dbo.tbl_RE_ReferenceEnrichment` (join `re.CatalogId = cat.CatalogId`, as
`sp_Get_CatalogDetails` does), outside the MCP grant — which covers `EWMaster` on stage only. Fill it
by hand if you have it. An empty cell is what a later backfill expects.

`Field` alone says which entity a row is about, so there is no separate entity-type column. The
change itself always sits in the same pair (`OldValue` / `NewValue`), so one filter answers "show
all renames" across catalog and model alike.

**Formatting is part of the sheet, not an extra.** Ids, dates and statuses are centred; names,
references and `Reason` are left-aligned; everything wraps; data rows alternate shading; the column
groups are separated by a vertical rule; row 1-2 stay frozen. `catalog_traceback_repair_format.py`
is the one definition of that — run it after any bulk write or a `catalog_traceback_setup.py`
rebuild. `catalog_traceback_log.py` re-applies the per-row part after every append, so a logged row
cannot land unformatted.

**Plain text matters:** `ReferenceNumber`, `ModelName`, `OldValue` and `NewValue` are all forced to
text. A ref like `B1/M` or `5711/1A-010` would otherwise be silently read as a date or a fraction.

**Already in the database, so not duplicated here:**

- `tbl_CAT_Catalog_d.StatusID` — `1` Active, `2` Draft, `3` Deleted. Catalog deletes are soft and
  already recorded; the sheet adds the *reason*, not the fact.
- `tblAttributeMergeQueue` — `OldAttributeId`, `NewAttributeId`, `MergedDate`;
  `AttributeTypeId` `2` = Model, `3` = ReferenceNumber. Merges already have an old→new trail.

## Google Drive folders

| Name | Purpose | Link |
|------|---------|------|
| (link to be shared) | | |
