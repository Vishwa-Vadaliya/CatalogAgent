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
| (name TBD) | (purpose TBD) | | [Open](https://docs.google.com/spreadsheets/d/1PV7a6GqQemUivpCZnCxEB-CBEdKdt2R_xuWgiK-Ac5M/edit?gid=31837576#gid=31837576) | Spreadsheet ID: `1PV7a6GqQemUivpCZnCxEB-CBEdKdt2R_xuWgiK-Ac5M` |

## Catalog Traceback — `Sheet2` structure

One row per change made to the catalog. Built and rebuildable with
`PythonScripts/catalog_traceback_setup.py` (dry run by default; `--write` to apply).

| Col | Header | Notes |
|---|---|---|
| A | `Date` | When the change was made. Format `yyyy-mm-dd`. |
| B | `ChangedBy` | Who made it. |
| C | `Brand` | Manufacturer, so the log filters by brand. |
| D | `EntityType` | Dropdown: `Catalog` / `Model` / `Enrichment`. Says which Id column identifies the row. |
| E | `CatalogId` | `tbl_CAT_Catalog_d.CatalogId`. |
| F | `ModelId` | `tbl_CAT_Model_d.ModelId`. |
| G | `EnrichmentId` | `tbl_RE_ReferenceEnrichment.ReferenceEnrichmentId`. |
| H | `Action` | Dropdown: `Renamed` / `Deleted` / `Merged`. |
| I | `Field` | Dropdown: `ReferenceNumber` / `ModelName`. Blank for a plain delete. |
| J | `OldValue` | Value **before** the change. **Plain text** — a ref like `B1/M` or `5711/1A-010` must not be reinterpreted as a date or fraction. |
| K | `NewValue` | Value **after** the change. Plain text. |
| L | `MergedIntoId` | For `Merged` / duplicate deletes: the id that **survived**. Answers "where did it go". |
| M | `Reason` | Why, in words. |
| N | `Ticket` | Jira key or source sheet. |
| O | `Status` | Dropdown: `Pending` / `Accepted` / `Rejected`. |

Every row carries its change in the **same two columns** (`OldValue` / `NewValue`), whatever the
entity type, so one filter answers "show all renames" across catalog and model alike. Adding
another tracked field later costs no columns — just a new `Field` value.

**Already in the database, so not duplicated here:**

- `tbl_CAT_Catalog_d.StatusID` — `1` Active, `2` Draft, `3` Deleted. Catalog deletes are soft and
  already recorded; the sheet adds the *reason*, not the fact.
- `tblAttributeMergeQueue` — `OldAttributeId`, `NewAttributeId`, `MergedDate`;
  `AttributeTypeId` `2` = Model, `3` = ReferenceNumber. Merges already have an old→new trail.

## Google Drive folders

| Name | Purpose | Link |
|------|---------|------|
| (link to be shared) | | |
