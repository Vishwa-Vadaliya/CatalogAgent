---
type: Playbook
title: Raw to catalog — new references
description: Adding new unique official-source references from tbl_RAW_Catalog into tbl_CAT_Catalog_d through sp_Create_Catalog, after manual review.
tags: [playbook, raw-to-catalog, new-refs, staging, ech-693]
timestamp: 2026-11-04
---

# Playbook — raw to catalog (new references)

## Read first

- [../Documents/RawToCatalog/RawToCatalog_NewRefs_Overview.md](../Documents/RawToCatalog/RawToCatalog_NewRefs_Overview.md) — the plain-language walkthrough of the whole flow, with the worked example and the safety nets. Start here.
- [../Documents/RawToCatalog/RawToCatalog_NewRefs_Requirements.md](../Documents/RawToCatalog/RawToCatalog_NewRefs_Requirements.md) — the requirements and the raw → catalog field mapping.
- [../Knowledge/references-and-models.md](../Knowledge/references-and-models.md) — `StatusID`, `EntityType`, the Rolex `m` exception.
- [../Knowledge/stored-procedures.md](../Knowledge/stored-procedures.md) — `sp_Populate_NewRefStaging` → `sp_Approve_StagingRecord` → `sp_Create_Catalog`.
- Existing work: `Output/Queries/Vishva/RawToCatalog_NewRefs/` and `Output/Plans/vishwa/raw-to-catalog-new-refs-requirements-plan.md`.

## Steps

1. **Official sources only.** The source filter is wider than it looks — `IsActive` NULL or 1, and
   `CatSourceName` containing OFFICIAL. Reuse the filter from `sp_map_rawCatalog_catalogCountry`
   rather than writing a new one.
2. **Clean the key the way the existing map procedure does** — strip the Rolex leading `m`, use the
   Mirror fallback for blank references. Read that procedure before writing the step.
3. **Stage, don't insert.** Every candidate lands in the staging table with every field
   `sp_Create_Catalog` takes. Where a field exists in raw under a different name (e.g. `MovementNo`
   for movement number), map it — don't leave the parameter unfilled.
4. **Manual review is the gate.** Produce a read-only review script on temp tables that the user runs
   and reads. Do not create views for this.
5. **Create** via a cursor over the approved staging rows, one `sp_Create_Catalog` per row, writing
   errors to a status column. Colour and case material are link tables, so they need their own
   INSERT keyed on the new CatalogId.
6. **Deliver** per [OUTPUT.md](OUTPUT.md). No publish call in the script (A9).

## Traps

- A new ref may need a `PartialReference` parent row before the `Watch` row makes sense.
- `StatusID` is checked numerically on the **draft** table (`tbl_CAT_Catalog_d.StatusID = 1`), not by
  status name on the published table.
- Don't hand-fill columns that don't exist on `tbl_CAT_Catalog_d` — confirm each one in `ew-db` first.
- Only list the columns the user asked for; a NULL-filled full-column template is not the ask (A7).
