---
type: Document
title: Requirements — new unique refs from raw catalog to catalog (ECH-693)
description: Requirements for the flow that maps official-source rows of tbl_RAW_Catalog to tbl_CAT_Catalog_d and adds each new unique reference through sp_Create_Catalog after manual review. DRAFT for review — items marked "To confirm" are not decided.
tags: [documents, vishwa, ech-693, raw-catalog, catalog, requirements]
timestamp: 2026-11-02
---

# Requirements — new unique refs from raw catalog to catalog (ECH-693)

**Status: DRAFT for review.** Everything marked **To confirm** needs Vishva's answer before the scripts are written. Decisions come from the answers recorded in [Plans/vishwa/raw-to-catalog-new-refs-requirements-plan.md](../Plans/vishwa/raw-to-catalog-new-refs-requirements-plan.md) section 11.

## 1. Goal and ticket

**ECH-693** — "Change the flow to add new refs from manufacturer in catalog". New manufacturer refs are added by hand today. The new flow runs weekly or twice a week and adds each **new unique reference** found in the official-source rows of `tbl_RAW_Catalog` to `tbl_CAT_Catalog_d`, **one catalog row per reference**, after a person has reviewed it.

A second deliverable is a **mapping table** from official raw rows to `CatalogId`, with a coverage count (how many official raw rows have a catalog row, how many don't).

## 2. Scope

| Item | Decision |
|---|---|
| Sources | Official sources only: `tbl_sourceManufacturer_mapping` with `IsActive = 1` and `CatSourceName LIKE 'Official Website%'` |
| Manufacturers | All manufacturers that have an official source |
| Raw rows | `IsDeleted <> 1` (NULL counts as live — **confirmed**). `IsSeenInLastRun = 0` rows are **included** |
| Match key | **Normalized reference number only**, per manufacturer. Model, dial colour, case material are not compared. No country |
| "Exists in the catalog" | An active `Watch` row (`EntityType = 'Watch'`, `StatusID = 1`). `PartialReference`, `StatusID` 2 and 3 are **not** considered |
| Creation | Only through `sp_Create_Catalog`. Catalog columns that are not parameters of it are not filled |
| Review | A person reviews every new ref and its values before it is created |
| Never | Claude never runs SQL. No publish calls. `ew-db` is not changed |

## 3. Objects to create (all new, in EWMaster)

Scripts live in `Queries/Vishva/RawToCatalog_NewRefs/`, not in `ew-db` (rule A6). Names are proposals — **to confirm**. They sit beside Janvi's existing `tbl_CAT_NewRefStaging` objects and do not touch them.

| Object | Kind | Purpose |
|---|---|---|
| `tbl_CAT_RawRefMap` | Table | One row per official raw `Id`: `RawCatalogId`, `ManufacturerId`, `SourceId`, `ReferenceRaw`, `RefKey` (normalized), `CatalogId` (NULL = unmapped), `MapStatus`, dates |
| `tbl_CAT_RawRefStaging` | Table | One row per unique new ref: cleaned ref, raw and mapped values, conflicting values, images, `IsApproved`, `ExecutionStatus`, `CatalogId`, `ExecutionError` |
| (check script, temp tables) | Comma list | `CatalogId`, `ReferenceNumber`, comma-separated raw `Id`s |
| (check script, temp tables) | Coverage | Mapped / unmapped counts (overall, by manufacturer, by source) |
| `vw_CAT_RawRefStaging_ForReview` | View | What the reviewer sees: values, conflicts, images, flags |
| `vw_CAT_RawRefUnmatchedValues` | View | Raw values that have no master value, by field, with counts (to create in the master tables) |
| Stored procedures | Procs | One per step (section 4) and one wrapper that runs steps 1–4 |

`MapStatus` values: `Unmapped` (loaded, no catalog row yet), `Matched` (already in the catalog), `New` (staged for review), `Created` (we created the catalog row), `Rejected` (`sp_Create_Catalog` refused it; the reason is in the staging row).

## 4. The flow

Each step is its own stored procedure and can be run alone. A wrapper runs steps 1–4. Step 5 only creates refs a person has approved.

1. **Sync the map table.** Insert official raw rows (`IsDeleted <> 1`) that are not in `tbl_CAT_RawRefMap` yet, with `CatalogId = NULL`. First run loads everything; later runs only add new raw rows.
2. **Match to the catalog.** For rows with `CatalogId IS NULL` only: normalize the raw ref and look it up in a per-manufacturer catalog lookup built once (active `Watch` rows). On a hit, set `CatalogId`, `MapStatus = 'Matched'`.
   - Normalization: `fn_ExtractNumbersAndAlphabets` after the cleaning rules in section 6, applied on **both** sides.
3. **Stage new refs.** Rows still `CatalogId IS NULL` and not `Rejected` are grouped by manufacturer and normalized ref. Each group becomes one staging row, unless it is already in staging. `MapStatus = 'New'`.
4. **Consolidate and map values.** For each staging row, take values from all its raw rows (section 5), map them to master values, find images, parse numbers. Unmatched values are left NULL and shown in `vw_CAT_RawRefUnmatchedValues`.
5. **Review (manual).** The reviewer opens `vw_CAT_RawRefStaging_ForReview`, checks every row and sets `IsApproved = 1`.
6. **Create (cursor).** For each approved row not yet created: call `sp_Create_Catalog` once. On success write `CatalogId`, `ExecutionStatus = 'Success'`, set `MapStatus = 'Created'` and `CatalogId` on all its raw rows. On error write `ExecutionStatus = 'Error'` and the message, set `MapStatus = 'Rejected'`. The reference is reported and not retried until someone resets it.
7. **Reports.** Coverage, pending review, rejected refs, unmatched master values.

After step 6, new raw rows for a ref that now exists in the catalog are matched by step 2 on the next run.

## 5. Conflicting values and images

- When the raw rows of one ref disagree on a field, the **most frequent value** is used. The reviewer sees **all** the values with their counts. Tie-break: the **highest raw `Id`** (most recent row) — Vishva left it to Claude; chosen because the newest listing is the freshest data.
- **Case size:** `Width`, else the leading number of `Dimensions` (as Janvi's script does).
- **Images** (`tbl_RAW_Media`, `IsDeleted = 0`): primary = the image with the lowest `orderIndex`; **all the other images of that same raw row** are secondary. If the first raw row of the ref has no image, try the other raw rows of the same ref in turn, and take primary and secondary from the first row that has images (**confirmed**). Janvi's script only used the lowest raw `Id`; the fallback is new.
- **Source link:** the raw `URL` column; one URL per ref — the one from the highest raw `Id` that has a URL (same "most recent" rule as the tie-break).

## 6. Reference cleaning

Keep from Janvi's script:
- **Rolex:** leading "M" removed.
- **Audemars Piguet:** "-" replaced by ".".
- **Tudor:** one leading "M" ignored on both the raw and the catalog side before comparing.
- A second catalog check after cleaning.

The staging row keeps the raw ref, the cleaned ref and the cleaning method used.

## 7. Field mapping (raw to `sp_Create_Catalog`)

"Universal" = `sp_Map_RawValueToCatalog_Universal` (exists in `ew-db`). "Exact" = trimmed, case-insensitive match on the active master row, as Janvi's script does.

| `sp_Create_Catalog` parameter | Raw source | How |
|---|---|---|
| `@ManufacturerName`, `@SourceName` | `tbl_sourceManufacturer_mapping` (`CatManufacturerName`, `CatSourceName`) | Direct |
| `@ReferenceNumber` | `ReferenceNo` | Cleaned (section 6) |
| `@ModelName` | `Model` | Universal (`Model`); no match → rejected and reported |
| `@CaseSize` | `Width`, `Dimensions` | Parsed |
| `@EntityType` | — | `'Watch'` |
| `@SourceLink` | `URL` | Section 5 |
| `@PrimaryImageURL`, `@SecondaryImageURL` | `tbl_RAW_Media` | Section 5 |
| `@MovementTypeName` | `Movement` | Universal (`MovementType`) |
| `@CalibreNumberName` | `Caliber` | Universal (`Caliber`, exact) |
| `@CaseMaterials` | `CaseMaterial` | Universal (`CaseMaterial`), per comma part |
| `@DialColors` | `DialColor` | Universal (`DialColor`), per comma part |
| `@StrapMaterials` | `BraceletOrStrapMaterial` | Universal (`StrapMaterial`) |
| `@DialMaterials` | `DialMaterial` | Universal (`DialMaterial`) |
| `@DialEmbelishments` | `DialEmbellishment` | `tbl_CAT_Embelishment_d`, exact |
| `@BezelMaterials` | `BezelMaterial` | `tbl_CAT_Material_d`, exact |
| `@CasebackMaterials` | `CaseBackMaterial` | `tbl_CAT_Material_d`, exact |
| `@IndicesStyles` | `IndicesStyle` | `tbl_CAT_IndicesStyle_d`, exact |
| `@StrapStyleName` | `StrapStyle` | `tbl_CAT_StrapStyle_d`, exact |
| `@CrownEmbelishmentName` | `CrownEmbelishment` | `tbl_CAT_CrownEmbelishment_d`, exact |
| `@MovementJewelsName` | `Jewels` | `tbl_CAT_MovementJewels_d`, exact |
| `@EditionName` | `Edition` | `tbl_CAT_Edition_d`, exact, per manufacturer |
| `@DialStampName` | `DialStamp` | `tbl_CAT_DialStamp_d`, exact |
| `@PowerReserveHourName` | `PowerReserve` | One unambiguous number (days × 24), kept only if it exists in `tbl_CAT_PowerReserveHour_d` |
| `@WaterResistancesMeters` | `WaterResistance` | One unambiguous number; ATM/bar × 10, feet × 0.3048 |
**Not filled (confirmed):** `@Style`, `@CatalogNotes`, `@MovementNumberName`.

**No matching raw column — left NULL:** `@CaseEmbelishments`, `@StrapEmbelishments`, `@BezelEmbelishments`, `@BezelStyleName`, `@BezelTypeName`, `@NicknameName`, `@PusherShapeName`, `@Series`, `@IndicesMaterials` / `@IndicesMaterialName`.
**Fixed values:** `@UserID = 6` (confirmed). **Defaults:** `@RuleId`, `@StatusId`, `@TransactionID`.

**Values that are not in the master table.** The value is not created in the master table by this flow. It is left NULL in the staging row, and `vw_CAT_RawRefUnmatchedValues` lists it, by field, with the raw text and the number of refs, so the person who owns that master table can create it. After it is created, staging is re-mapped (step 4 can be re-run for a row).

## 8. Exceptions

| # | Case | What happens |
|---|---|---|
| 1 | Same ref in many raw rows and sources | One staging row; all raw `Id`s mapped to it |
| 2 | Different values across those rows | Most frequent value; reviewer sees all (section 5) |
| 3 | Same ref written differently | Section 6 cleaning, then normalized comparison |
| 4 | Ref exists only as `PartialReference`, `StatusID` 2 or 3 | Treated as **new** |
| 5 | Raw row `IsDeleted = 1` | Ignored. `IsSeenInLastRun = 0` rows are included |
| 6 | Blank or NULL ref | Not staged. No other junk filter: follow Janvi's script (it excludes only NULL and blank refs) — confirmed |
| 7 | Model not in `tbl_CAT_Model_d`, manufacturer mismatch, structure check fails (Rolex, Patek, AP), `126610LN` block, source not in `tbl_CAT_Source_d`, or any other `sp_Create_Catalog` error | Row marked `Rejected` with the error text; reported; not retried until reset |
| 8 | Raw value with no master value | Left NULL; listed in the unmatched-values view |
| 9 | No image / no case size | Ref is still created. Images are searched across all raw rows of the ref |
| 10 | Official raw row matches **more than one** active `Watch` row in the catalog | The **lowest `CatalogId`** goes in the map, and these refs are listed in a report (confirmed) |
| 11 | Rerun meets a ref already staged, created or rejected | Skipped: the map table and staging table carry its state |
| 12 | `sp_Create_Catalog` needs `@UserID` | Always passed as `6` (confirmed) |

## 9. Running it

- No SQL Server Agent for now. A wrapper procedure runs steps 1–4; step 6 is a separate procedure run after approval. Either can be attached to any scheduler later (for example Windows Task Scheduler with `sqlcmd`).
- Each call of `sp_Create_Catalog` is its own transaction, so one failure does not undo the others.
- `sp_Create_Catalog` has `@IsDryRun`. The creation procedure gets a dry-run mode that passes it (confirmed).

## 10. Constraints from the rules

- Temp tables, not CTEs (B1); `NOLOCK` on reads (B3); headers on every step (B4).
- B2 forbids `DECLARE` in scripts the user runs step by step. Stored procedures need parameters and variables, so the procedures use them; the step scripts for the user to run (setup, checks, previews) use temp-table parameters. **To confirm.**
- Updates in a hand-run script: preview, then uncommitted transaction (B7). Not applicable inside the stored procedures, which are the deliverable.
- No publish calls (A9). `ew-db` untouched (A6).

## 11. Order of the scripts

1. Table and view DDL (`tbl_CAT_RawRefMap`, the comma view, the coverage view).
2. Steps 1–2 procedures (sync, match) and a first-run check.
3. Staging table and steps 3–4 procedures (stage, map values, images).
4. Review view and unmatched-values view.
5. Step 6 procedure (cursor, `sp_Create_Catalog`) and the wrapper.
6. Test on stage: dry run first.

## 12. Open items (all marked "To confirm" above)

Answered 2026-11-02: `IsDeleted` NULL is live; lowest `CatalogId` on several matches; images; `@Style`, `@CatalogNotes`, `@MovementNumberName` not filled; junk refs follow Janvi; `@UserID = 6`; dry-run mode; `DECLARE` inside procedures is fine.

Also answered: tie-break = highest raw `Id`; source link = raw `URL`.

Still open: none that blocks the scripts. Object names are proposals and have not been objected to.
