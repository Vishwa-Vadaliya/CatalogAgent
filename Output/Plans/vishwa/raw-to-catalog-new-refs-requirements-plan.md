---
type: Plan
title: Plan — Requirements for adding new unique refs from raw catalog to catalog (ECH-693)
description: Plan for building the requirements document for ECH-693 — the main goal (add each new unique official-source reference to tbl_CAT_Catalog_d once), confirmed decisions, the exceptions to handle, what to carry over from the old scripts, open questions, and the order of work up to the scripts.
tags: [plans, vishwa, ech-693, raw-catalog, catalog, requirements]
timestamp: 2026-10-31
---

# Plan — Requirements for ECH-693

## 1. Main goal

Add to **`tbl_CAT_Catalog_d`** the reference numbers that exist in **`tbl_RAW_Catalog`** (official sources only) but **do not exist in `tbl_CAT_Catalog_d`** yet — **one catalog row per unique reference**.

The same reference number appears in `tbl_RAW_Catalog` many times: from different sources, and as separate listings, usually with the same model, dial colour and case material. Those repeats must **not** each become a catalog row. They collapse into **one** new unique reference, and that one is added.

The flow has to be repeatable every week or twice a week (ticket ECH-693), so it also has to avoid redoing refs it has already added, rejected or failed.

### 1.1 Second requirement: a raw-to-catalog mapping table

We also keep a table that maps the **official-source rows of `tbl_RAW_Catalog`** to their **`CatalogId`** in `tbl_CAT_Catalog_d`. Its first job is the coverage picture: of all official-source raw rows, **how many have a catalog ID against them** and how many don't. In Vishva's words: "there should be the catalog's ID and the catalog ID for all the official sources mapped."

My reading is *raw catalog `Id` → `CatalogId`, one row per official raw row*. **To confirm (Q14–Q16)** — see section 8.

## 2. The ticket

**ECH-693** (Task, assignee Vishva, team Data Intelligence & ENR, under epic ECH-539 "New Enrichment Creation, Reference Extraction & Variation Coverage"):

> Change the flow to add new refs from manufacturer in catalog — "Currently we are adding new manufacturer refs manually, now we want to create agentic flow that we can use weekly or twice a week."

Today, roughly monthly, `tbl_RAW_Catalog` is updated by the crawler sync and the new references with their details are added to `tbl_CAT_Catalog_d` by hand. Vishva doesn't have the queries for this. They have to be built.

## 3. Decisions confirmed so far

1. Only **official source** rows are in scope.
2. We build **our own stored procedures and staging table(s) in EWMaster**. Creating them is allowed. (Rule A1 in `Rules/EW_Rules.md` still says the user prefers not to create SPs in EWMaster; it needs updating only if the user asks.)
3. Janvi's scripts are **context only**. We don't have to reuse them, but **nothing important in them may be missed** (section 7).
4. This task has **nothing to do with `brand-ref-agent`**. It is a database flow, not that skill, and shouldn't borrow from it.
5. Claude never runs SQL. Scripts and procedures are written for Vishva to run.
6. **Don't assume anything.** While building the requirements, the plans, the queries or the stored procedures, if something isn't known — a definition, a table or column, a rule, what to do in an edge case — **stop and ask Vishva**. Don't fill the gap with a guess, a default, or "what the old scripts did". If an old script did something, say so and ask whether to keep it. (This matches rule A1, "Ask, don't assume, when a definition is unclear", and A7, flag extra logic instead of silently building it in.)
7. A **mapping table of official-source raw rows to catalog IDs**, with a coverage count (mapped / not mapped), is part of the work (section 1.1).

## 4. Where the work goes

| What | Where |
|---|---|
| This plan | `Plans/vishwa/` (this file) |
| Requirements | `Documents/RawToCatalog_NewRefs_Requirements.md` (not `requirements.md`, which is the brand-ref-agent spec) |
| Scripts, stored procedures, table DDL | `Queries/Vishva/RawToCatalog_NewRefs/` — `.sql` only, written after the requirements are confirmed |

Nothing in `D:\EW\ew-db` changes unless Vishva explicitly says so; if the new procedures should also live in `ew-db/MasterDB`, that's a separate decision (rule A6). Existing scripts elsewhere are read-only context.

## 5. What we already know (verify before relying on it)

**Why raw has repeats by design.** `tbl_RAW_Catalog` has a unique index on `(AuctionId, SourceId, ArtworkId)`, so every listing from every source is its own row. Many rows share one reference number.

**How raw data arrives.** `sp_SYNC_SyncWatchesCatalog` (`ew-db/MasterDB`) copies watches, auctions and photos from the crawler database (`MACrawler_`) into `tbl_RAW_Catalog`, `tbl_RAW_Auction` and `tbl_RAW_Media`, up to 5,000 watches per run. It never writes to `tbl_CAT_Catalog_d`. Columns that show what is new or changed: `Id` (identity), `TransactionId`, `CreatedDate`, `UpdatedDate`, `IsDeleted`, `IsSeenInLastRun`, `LastSeen`.

**Which raw rows are official.** `tbl_sourceManufacturer_mapping` maps `SourceId` to `CatManufacturerId`, `CatManufacturerName` and `CatSourceName`. A `CatSourceName` starting "Official Website" marks an official source (`Knowledge/EW_DB_Knowledge.md`).

**What matches raw rows to catalog rows today.** `sp_map_rawCatalog_catalogCountry` links official-source raw rows to existing catalog rows (`EntityType = 'Watch'`, `StatusID = 1`) by a normalized reference (`UDF_ExtractNumbersAndAlphabets`), with manual overrides in `tbl_CAT_RawCatalogMapping`. It only maps; it never creates catalog rows.

**An existing mapping table, and how it differs.** `tbl_MAP_RawCatalog_CatalogCountry` (`RawCatalogId`, `CatalogId`, `CountryId`, `IsSeenInLastRun`, `IsDeleted`, price-date and tax columns, `ResolutionNote`) is filled by `sp_map_rawCatalog_catalogCountry` for official sources, and refs it can't resolve go to `tbl_MAP_RawCatalog_CatalogCountry_Ambiguous` (with candidate catalog IDs). It belongs to the retail-price pipeline, and a unique index allows only **one active row per `(CatalogId, CountryId)`**, so it does **not** hold a row for every official raw row. It may or may not be what Vishva wants (Q14).

**How a catalog row is created.** `sp_Create_Catalog` (`ew-db/MasterDB`), one reference per call:
- It needs exact, active names for manufacturer, model, source (`tbl_CAT_Source_d`) and the optional edition, dial stamp, strap style, movement type, and so on.
- List fields resolve against `tbl_CAT_Color_d` (dial colours), `tbl_CAT_Material_d` (case, bezel, case back, strap, dial and indices materials), `tbl_CAT_Embelishment_d` and `tbl_CAT_IndicesStyle_d`.
- Rolex, Patek Philippe and Audemars Piguet refs must match a structure in `tbl_CAT_ReferenceStructure_d`, and the model must agree with existing refs that start the same way (unless `@AllowModelMismatch = 1`).
- Refs starting `126610LN` are blocked with an error.
- It inserts `tbl_CAT_Catalog_d`, the attribute links, `tbl_CAT_Media_d` images, and builds `PartialReference` parents via `sp_create_CatalogHierarchy_FromReference`. Each call is its own transaction.
- If `@UserID` is not passed, it looks the SQL login up in `tblUser` and fails if it isn't there.

## 6. Exceptions to handle

The requirements must say what to do in each of these cases. "Decision" marks where Vishva's answer is needed (section 8).

| # | Exception | Why it matters | Decision |
|---|---|---|---|
| 1 | The same ref appears in many raw rows and sources | Must produce one candidate, not many | Done by design: group by manufacturer and normalized ref |
| 2 | Same ref, **different** model, dial colour, case material or size across rows | One value must be chosen | Q1 |
| 3 | Same ref written differently (spaces, dashes, case, Rolex leading "M", AP dash vs dot, Tudor optional "M") | Would create duplicates or miss an existing ref | Carry over the old cleaning rules (section 7) |
| 4 | Ref exists in the catalog only as a **PartialReference**, or with `StatusID` 2 (draft) or 3 (deleted) | Counts as existing or as new? The old script treated any active row as existing; the old mapping proc only `Watch` rows | Q2 |
| 5 | Raw rows with `IsDeleted = 1`, or no longer seen on the official site (`IsSeenInLastRun`) | Discontinued or removed listings may still be "new" refs | Q3 (rule B10 says don't filter `IsDeleted` outside the watch tables unless asked) |
| 6 | Ref blank, junk, a serial or case number, or has noise appended | Should not become a catalog ref | Q4 |
| 7 | Model not in `tbl_CAT_Model_d` for that manufacturer, or a manufacturer name not matching `tbl_CAT_Manufacturer_d` | `sp_Create_Catalog` rejects the row | Q5 |
| 8 | Raw value doesn't match a master value (dial colour, case material, strap, movement, dial material, caliber) | Needs mapping rules, or a blank | Carry over exact, alternative and fuzzy mapping (section 7) |
| 9 | Rolex / Patek / AP structure not in `tbl_CAT_ReferenceStructure_d`; model peer-check mismatch; `126610LN` block | `sp_Create_Catalog` rejects the row | Q5 |
| 10 | Source name not in `tbl_CAT_Source_d` | `sp_Create_Catalog` rejects the source | Q6 |
| 11 | No image, or no case size, for the ref | Catalog row incomplete | Q7 |
| 12 | The weekly run meets a ref already added, already waiting, rejected, or failed earlier | Duplicates, endless retries | Q8 |
| 13 | Several official sources for one manufacturer (different countries) with different values | Same as #2 across sources | Q1 |
| 14 | One official raw row matches **more than one** catalog row (for example the same ref as a `Watch` and a `PartialReference`, or two active catalog rows) | The mapping needs one `CatalogId` per raw row | Q15 |
| 15 | An official raw row matches **no** catalog row | Stays unmapped; is it the signal for a new ref? | Q14, Q16 |

## 7. Carry over from Janvi's scripts (nothing important missed)

Source: `D:\EW\Scripts\Queries\Janvi\Raw To Catalog\` (read for this plan: `00_Database_Setup_Steps.sql`, `Run_NewRef_Detection_And_CatalogCreation.sql`, `01_Test_EndToEnd_Workflow.sql`, `02_Monitoring_Queries.sql`). Still to read in step 1 of section 10: `Copy_ArtworkTaxIncluded_BatchWise.sql`, `Queries/Vishva/Query4.sql`, `Query3.sql`, and the Patek staging script `D:\EW\Scripts\Queries\Janvi\PatekCatalogStaging\`.

**Keep (each must appear in the requirements or be explicitly dropped with a reason):**
- Official-source filter: `tbl_sourceManufacturer_mapping` with `IsActive = 1` and `CatSourceName LIKE 'Official Website%'`, and a manufacturer filter option.
- Normalised comparison with the catalog via `fn_ExtractNumbersAndAlphabets`, per manufacturer, built once as a lookup, not the function per row (performance).
- Ref cleaning: Rolex leading "M" removed; AP "-" to "."; Tudor leading "M" ignored on **both** sides of the comparison; a second check after cleaning.
- Skip refs already waiting in staging.
- Consolidation of the raw rows per ref: model, dial colour, case material, bracelet material, dial material, power reserve, dial embellishment, caliber, width or dimensions, movement, bezel colour, source link (URL), source names.
- Case size parsing: from `Width`, else the leading number of `Dimensions`.
- Images from `tbl_RAW_Media`: primary = lowest `orderIndex` (not deleted), the rest as secondary images.
- Mapping raw text to master values: manual override first (`tbl_CAT_FieldMapping`), then exact, then alternative names, then fuzzy for dial colour, case material, model and strap; compound text handling ("with", "&", "/", last comma token); steel / stainless defaults and PVD and gold guards.
- Review before creating: an `IsApproved` flag; a rule for bulk approval only when model, dial colour, case material, image and case size are all present.
- Creation: one `sp_Create_Catalog` call per approved ref, `EntityType = 'Watch'`, the official `CatSourceName` as `@SourceName`, with the result and any error written back to the staging row.
- Review and monitoring views: pending rows, summary per manufacturer, unmapped values, execution errors, missing required fields.

**Known problems in the old scripts — don't repeat:**
- Its mapping proc reads `tbl_CAT_DialColor_d` and `tbl_CAT_CaseMaterial_d`, which are not in `ew-db`; the create path uses `tbl_CAT_Color_d` and `tbl_CAT_Material_d`.
- It scans all raw rows every run (no watermark), and its staging check skips only rows with `ExecutionStatus IS NULL`, so error rows are staged again.
- It picks one value per field with `MAX()`, so conflicting values are decided alphabetically, not on purpose.
- Power reserve and dial embellishment are never mapped or passed on.
- Strap material and dial material are mapped against `tbl_CAT_StrapMaterial_d` / `tbl_CAT_DialMaterial_d`, while `sp_Create_Catalog` checks `tbl_CAT_Material_d`.
- The test and monitoring scripts name objects that the setup file doesn't create.
- Its detection step has no `IsDeleted` or `IsSeenInLastRun` decision (exception #5).

**Uncommitted, unrun edits from the abandoned approach** are still in `D:\EW\Scripts` (the main script and `00_Database_Setup_Steps.sql` modified; `03_Add_Extended_Field_Columns.sql` new). Keep or revert is Vishva's call.

## 8. Open questions (to answer before drafting)

1. **Conflicting values (exceptions 2 and 13).** When one ref has different models, colours, materials or sizes across rows, which wins? The most frequent value (as `Queries/Vishva/Query3.sql` does for reference numbers), or one preferred source, or send to review?
2. **"Exists in the catalog" (exception 4).** Does a ref that only exists as a `PartialReference`, a draft (`StatusID` 2) or a deleted row (`StatusID` 3) count as existing, so it's skipped, or as new?
3. **Raw rows to ignore (exception 5).** Include raw rows with `IsDeleted = 1`, or not seen in the last run?
4. **Junk refs (exception 6).** Any shapes to exclude (blank, serial numbers, very short, odd characters)? Or rely on the review step?
5. **Rejections by `sp_Create_Catalog` (exceptions 7 and 9).** When the model is missing, the manufacturer name doesn't match, or the structure check fails: skip and report, or do something else? Should creating a missing model be part of the flow?
6. **`@SourceName`.** Which `tbl_CAT_Source_d` name goes in for official sources, and does it exist for each manufacturer?
7. **Minimum to create a ref (exception 11).** Is a ref without an image or case size created, or held back?
8. **Weekly reruns (exception 12).** Where is "last run" remembered (a small log table with the highest raw `Id` or date), and how are rejected and failed refs treated on the next run?
9. **Review.** Does a person approve every ref, or do clean ones go straight in?
10. **How it runs.** The ticket says "agentic flow" used weekly or twice weekly. Confirm: stored procedure(s) that Vishva runs on that schedule, or a scheduled job?
11. **Fields beyond the basics.** Besides manufacturer, ref and model: dial colour, case material, size, image — also strap and dial material, power reserve, embellishments, edition, dial stamp, jewels, water resistance?
12. **After creation.** Is price mapping, enrichment or publishing in scope? (Publish calls never go into a handed-off script — rule A9.)
13. **Manufacturers.** All manufacturers that have an official source, or a chosen list?
14. **The mapping table (section 1.1).** Is it *raw catalog `Id` → `CatalogId`, one row for every official raw row*? Is it a new table, or should it reuse `tbl_MAP_RawCatalog_CatalogCountry`, which has a different shape (country, price columns, one active row per catalog and country)? Should "a new ref" simply mean an official raw row left **unmapped** by this table?
15. **How a raw row is matched to a catalog row.** The same normalised-ref comparison the existing mapping uses (with the Rolex, AP and Tudor rules)? Which catalog rows count: `Watch` only, or `PartialReference`, drafts and deleted rows too? What happens when a raw row matches several catalog rows: leave unmapped and record it (like the existing "ambiguous" table), or pick one by a rule?
16. **What the coverage report shows, and when it refreshes.** Counts of mapped and unmapped official raw rows overall, or per manufacturer and per source? Is the table refreshed on every run, and again after new refs are created, so it reflects the new catalog rows?

## 9. Outline of the requirements document

1. Main goal (section 1) and the ticket
2. Current manual process and what is automated
3. Scope: official sources, manufacturers, what counts as a "new unique ref"
4. Tables and procedures used (section 5, confirmed), and the raw-to-catalog mapping table with its coverage report (section 1.1)
5. The flow, step by step, each with input, output and checkpoint
6. How duplicates collapse to one ref, and the rule for conflicting values
7. Exceptions and what happens for each (section 6, decided)
8. Field mapping: raw column, catalog field, master table, what to do when unmatched
9. Review and approval rules
10. Failure handling and weekly reruns (the run log)
11. Objects to create: staging table(s), log table, stored procedures
12. Constraints from the rules: never run SQL; temp tables not CTEs (B1); `NOLOCK` on reads (B3); headers on every step (B4); updates with a preview and an uncommitted transaction (B7); no publish calls (A9); `ew-db` untouched (A6). `DECLARE` variables are discouraged (B2) — check how that fits stored procedures when designing them
13. Deliverables and where they go
14. Open items

## 10. Order of work

Throughout every step below, decision 6 in section 3 applies: **no assumptions — ask Vishva whenever something is unclear.** Anything that comes up that isn't covered by section 8 gets added to that list as a new question, and is answered before it is built.

1. Read the remaining old scripts listed in section 7, and add anything important to the carry-over list.
2. Get answers to section 8 — at least questions 1, 2, 3, 5, 8, 10 and 14 before drafting.
3. Draft `Documents/RawToCatalog_NewRefs_Requirements.md` following section 9.
4. Review it together and mark the confirmed decisions.
5. Write a second plan for the scripts: the tables and procedures to create, the steps, and the order to run and test them.
6. Write the scripts in `Queries/Vishva/RawToCatalog_NewRefs/`, each step independent and re-runnable, for Vishva to run on stage first.
7. Update `Queries/Vishva/RawToCatalog_NewRefs/index.md`, `Plans/vishwa/index.md` and `Documents/index.md` as each file is added.

## 11. Answers confirmed by Vishva (2026-11-02)

| Q | Answer |
|---|---|
| 1 | Match on **reference number only** (normalized). No comparison of model, dial colour or case material. No country involved. |
| 2 | Only an active `Watch` row (`StatusID = 1`) counts as existing. `PartialReference`, `StatusID` 2 and 3 are **not** considered. |
| 3 | Skip `IsDeleted = 1`. Rows with `IsSeenInLastRun = 0` are included. |
| 5 | If `sp_Create_Catalog` rejects a ref: skip it and **report** it. |
| 6 | Source names come from `tbl_sourceManufacturer_mapping` (`SourceId` → `CatSourceName`, which matches `tbl_CAT_Source_d`). |
| 7 | A ref is created even without an image or case size. For the image, try **every raw row of that ref** until one has one (as in Janvi's scripts). |
| 8 | Work set = official raw rows, `IsDeleted <> 1`, whose `Id` is **not mapped** in the mapping table. Table shape: see below. |
| 9 | A person reviews **every** new ref and its values once, before it goes into the catalog. |
| 10 | Automate, but **creation only after manual approval**. No SQL Server Agent available for now. |
| 11 | Take **all raw fields that exist in `tbl_CAT_Catalog_d`** (not `TransactionId` etc.), not just the basics. |
| 13 | All manufacturers with an official source. |

Mapping table: one row per official raw `Id` with `CatalogId` (NULL where unmapped); comma lists are produced by a view. Detail in the requirements doc.

**Also confirmed (same day, second round):**
- Mapping table = one row per raw `Id`, `CatalogId` NULL when unmapped. The comma view shows `CatalogId`, `ReferenceNumber` and the comma-separated raw `Id`s.
- Automation = stored procedures, no SQL Server Agent; one wrapper procedure runs the pipeline and can be attached to any scheduler later.
- Fields: create **only through `sp_Create_Catalog`**. Catalog columns that are not parameters of `sp_Create_Catalog` are **not** filled.
- Conflicting values: most frequent value wins; the reviewer sees all the disagreeing values.

**Third round (same day):**
- Each run works only on **official raw rows with `CatalogId IS NULL`** in the mapping table (plus raw rows not yet in the mapping table, which are inserted first). No full scan of `tbl_RAW_Catalog` per run.
- Keep the ref cleaning: Rolex leading "M" removed, AP "-" to ".", Tudor leading "M" ignored on both sides.
- Creation uses a **cursor** over approved staging rows, one `sp_Create_Catalog` call each. The staging table is where the reviewer sees the values before they go in.
- `sp_Map_RawValueToCatalog_Universal` **exists** in `ew-db/MasterDB` (read 2026-11-02). It maps DialColor, CaseMaterial, Model, MovementType, StrapMaterial, DialMaterial, DialEmbellishment (exact only) and Caliber (exact only). It reads `tbl_CAT_Color_d` and `tbl_CAT_Material_d` plus the `*Alternative_d` tables, all present in `ew-db`.
- `tbl_CAT_NewRefStaging`, its views and `sp_Approve_StagingRecord` / `sp_Update_StagingMapping` already exist in `ew-db` (Janvi's earlier objects, without the extended columns).

**Still open:** which scheduler, later. Status placement proposed (mapping table holds the match state per raw row; a separate staging table holds review, approval and creation result per unique ref) — waiting for Vishva's OK.
