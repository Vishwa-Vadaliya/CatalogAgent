---
type: Knowledge Fact
title: Reference numbers, models, and the clean-name functions
description: How reference numbers and models work on the catalog side versus the watch side, the Rolex leading-m exception when comparing raw to catalog, and the clean-name and ref-structure functions.
tags: [knowledge, references, models, synonym, parent-child, rolex, clean-name, ref-structure]
db: both
keywords: [tblReferenceNumber, tblModel, ReferenceNumberId, ModelId, synonym, merge, parent, child, PartialReference, StatusID, Rolex m, fn_ConvertToRefStructure, CleanName, MSRP, tbl_CAT_Catalog_d]
timestamp: 2026-11-04
---

# Reference numbers & models

Covers both sides: the catalog side (EWMaster) and the watch side (EveryWatch). Read the whole file
before working on refs — the two sides behave differently and the difference is the usual source of
mistakes.

## 4. Reference numbers & models

- **Catalog side:** the reference number is already in the catalog table itself (`tbl_CAT_Catalog` / `tbl_CAT_Catalog_d`.`ReferenceNumber`, plain text) — use it directly.
- **Watch side:** always go through `tblReferenceNumber` to get a watch's reference number.

- `tblReferenceNumber`: ReferenceNumberId, ReferenceNumber, ModelId, ManufacturerId, ParentId (self), IsActive/IsPending/IsDeleted, IsAutoCreated, IsModelVerified, CleanName (trigger `onReferenceNumberClean`), CatalogId.
  - Flags are not mutually exclusive (1/1/0 = active+pending, 1/0/1 occur).
  - Ref cleanup: include active and pending, no `IsDeleted` filter (only `tblWatch`/`tblWatch_d` use it); whole table, no min watch-count filter unless asked.
- `tblModel`: ModelId, ModelName, ManufacturerId, ParentId, flags, CleanName, CatalogId.
- `tblAttributeMergeQueue`: OldAttributeId, NewAttributeId, MoveToSynonym, MergedDate. AttributeTypeId 2 = Model, 3 = ReferenceNumber. Enqueued by `usp_mergeMaster`.
- **Catalog side active/draft/deleted:** `tbl_CAT_Catalog_d.StatusID` — 1 = Active, 2 = Draft, 3 = Deleted. "Active" on the catalog side = `tbl_CAT_Catalog_d.StatusID = 1` on the **draft** table, checked by numeric id directly — not `tbl_CAT_Status.StatusName <> 'Deleted'` on the published `tbl_CAT_Catalog` table.
- `tbl_CAT_Catalog_d.EntityType`: `'Watch'` or `'PartialReference'` (check constraint). A PartialReference row is the parent/stub for a starting ref (e.g. Rolex `116710` for child `116710BLNR`); Watch rows are the full references underneath it.
- `tblReferenceNumberMSRP(_d)` = app copy of retail prices (synced by `ResyncCatalogRetailPriceToEW`). EWMaster is the source of truth.
- **Synonym**: "if ref/model A is synonym of B then when A comes we will show B on website". Kept for matching/search, not displayed.
- **Parent/child**: the child is still shown (kind of correct); its ideal value is the parent. Rolex 126710BLRO-0001 → 126710BLRO → 126710; Patek 5711/1A-010 → 5711/1A → 5711/1 → 5711.
- **Merge** = make the wrong/duplicate value a synonym of the correct one. Sheet label is "Merge" (not "Synonym").
- **Correct vs Synonym**: corrected ref already in the table → Synonym; otherwise → Correct.

## 5. Rolex reference exception (raw catalog vs catalog)

- When comparing the reference number of `tbl_RAW_Catalog` against `tbl_CAT_Catalog_d`, Rolex refs in `tbl_RAW_Catalog` can carry an extra leading `m`/`M` (`m52508-0007` → `52508-0007`).
- **Always strip that leading `m`/`M` first**, and use the stripped ref for every Rolex pull from `tbl_RAW_Catalog`.
- Tudor catalog refs may have an optional leading M.

## 6. Clean name & structure functions

- `fn_extractnumberandalphabet` / `fn_ExtractNumbersAndAlphabets` = letters + digits, lowercased ("Complete Clean Name"). Same clean name = duplicate.
  - Scalar UDF with a WHILE loop → slow in join predicates. Precompute cleaned keys into indexed temp tables first.
- `fn_ConvertToRefStructure` / `fn_ConvertToStructure` (EWMaster): digit → X, letter → A, punctuation kept (`116500LN` → `XXXXXXAA`). Don't write an inline TRANSLATE. Don't index RefStruct.
- `fn_CleanReferenceNumber`: AP official refs '-' → '.'.

## See also

- [../Documents/Brands/Reference_Numbers.md](../Documents/Brands/Reference_Numbers.md) — ref & model cleanup notes with Cartier patterns.
- [../Documents/Brands/Brand_Reference_Validation_Workflow.md](../Documents/Brands/Brand_Reference_Validation_Workflow.md) — the full validation workflow.
- [retail-price.md](retail-price.md) — the Rolex 'm' issue also blocks the retail price reference guard.
