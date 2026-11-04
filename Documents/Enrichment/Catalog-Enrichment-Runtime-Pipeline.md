---
type: Document
title: Catalog enrichment — runtime pipeline (cross-service)
description: How an enrichment rule actually gets generated, matched against a watch, assigned, and published across ew-scheduler/ew-ql/ew-db/ew-embed-api — the execution side, as opposed to the rule-authoring side covered in Catalog-Enrichment-Complete-Guide.md.
tags: [documents, catalog-enrichment, enrichment-lifecycle, ewmaster, ew-ql, ew-scheduler]
timestamp: 2026-10-31
Status: Draft for review (summarized from ew-brain `03-architecture/enrichment-lifecycle.md`, owner: Mayur, last verified 2026-04-30)
Confidence: High (source doc), summarized here — confirm line numbers against the actual repos before quoting
---

# Catalog enrichment — runtime pipeline (cross-service)

[Catalog-Enrichment-Complete-Guide.md](Catalog-Enrichment-Complete-Guide.md) covers **how a rule is authored** (`tbl_CAT_EnrichmentRule_d`, reference-structure hierarchy, F.P. Journe model-based rules). This document covers **what happens after that rule exists** — the cross-service pipeline that turns a catalog row into an assigned, published enrichment on a watch. It spans four services: `ew-scheduler`, `ew-ql`, `ew-db`, `ew-embed-api`, plus OpenSearch.

## 1. End-to-end flow

```
EWMaster tbl_CAT_Catalog
  -> CatalogToEnrichmentSyncJob (ew-scheduler)
    -> EnrichmentCatalogData (staging table)
      -> SeedEnrichments / UpdateEWQL (ew-ql API)
        -> tbl_RE_ReferenceEnrichment + tbl_RE_EnrichmentRule
          -> RuleService loads rules into an in-memory cache
            -> CoreFieldsEnrichmentMatchingService (Type 3)
            -> ImageSimilarityEnrichmentMatching (Types 1, 4, 5), via vectors in OpenSearch
              -> usp_AssignEnrichmentToWatches (ew-db)
                -> tblWatch_d.ReferenceEnrichmentId
                  -> usp_assignDataBasedonEnrichment (ew-db)
                    -> tblWatch (published)

EWMaster tbl_CAT_EnrichmentRule + tbl_CAT_ReferenceStructure
  -> GlobalRuleSyncService (ew-scheduler)
    -> tbl_RE_EnrichmentRule (global rules, ReferenceEnrichmentId IS NULL)
      -> POST rule/refresh-cache -> ew-ql in-memory rule cache
```

A separate path, `CMS User -> ReferenceEnrichmentController (ew-cms-backend) -> tbl_RE_ReferenceEnrichment`, lets a CMS user create/update/view enrichments directly.

## 2. Key tables and what their columns mean

- **`tbl_RE_ReferenceEnrichment`** — the enrichment record itself (manufacturer, model, ref number, movement, case size, etc.). `GlobalRuleId` (nullable int) on this table links the enrichment back to the global-rule template it was generated from (see §6).
- **`tbl_RE_EnrichmentRule`** — the EWQL rule tied to an enrichment. `ReferenceEnrichmentId = NULL` marks a **global/template rule** (generates new enrichments dynamically at match time) rather than a rule for one specific enrichment. `CatalogEnrichmentRuleId` is the FK back to `tbl_CAT_EnrichmentRule.Id` it was generated from; `CatalogEnrichmentRuleTransactionId` is the change-detection stamp — the rule is only regenerated when this differs from the catalog row's current `TransactionId`. `GlobalRuleId` here groups rules that share the same variation pattern (see §6).
- **`EnrichmentCatalogData`** — staging table synced from the EWMaster catalog; carries reference-number hierarchy columns (`ParentReferenceNumberId`, `GrandParentReferenceNumberId`, `GreatGrandParentReferenceNumberId`), `CatalogTransactionId` (drives whether a row needs create vs update in ew-ql), `GlobalRuleId` (aliased from `tbl_CAT_Catalog.RuleId` by `usp_CatToEnrichmentResync`), and `IsProcessed`.
- **`tbl_RE_DataToFix`** — watches with multiple ambiguous enrichment matches; `IsFixed` flips when resolved.
- **`TblWatchEnrichmentResults`** — per-watch assignment metadata: `EnrichmentTypeId`, `ImageMatchScore`, `MatchConfidence`.
- **`tbl_CAT_EnrichmentRule`** (EWMaster) — source of truth for global-rule templates; 17 boolean bit-flag columns (one per field: CaseMaterial, DialColor, DialMaterial, CaseSize, StrapMaterials, Editions, DialStamp, Calibre, DialFinish, BezelColor, BraceletMaterial, BraceletStyle, IndicesEmbellishment, IndicesStyle, CaseEmblishment, DialEmblishment, Nickname) indicating which fields require an `EXISTS()` clause in the generated EWQL.
- **`tbl_CAT_ReferenceStructure`** (EWMaster) — reference-structure hierarchy with `ParentId`; used to walk ancestor chains (self → parent → grandparent → great-grandparent, max 4 levels) for structure-based global rules.
- **`tblManufacturerConfig`** — per-manufacturer image-match thresholds (`EnrichmentSimilarity`, `Enrichmentconfidence`, `BrandSimilarity`) consumed in `usp_AssignEnrichmentToWatches`.

## 3. Enrichment types — the full matching pipeline, not just the id meanings

`Knowledge/enrichment.md` already lists what each `EnrichmentTypeId` 1–6 means. What's missing is **how** types 1/4/5 are actually computed and **why** one wins over another:

**Matching order (ew-ql `EnrichmentService.MatchEnrichment`):**
1. **Core fields (Type 3)** — `CoreFieldsEnrichmentMatchingService` evaluates each watch against parsed EWQL rules.
2. **Clean results** — per watch, prefer the rule with the highest `WhereClauseCount` (most specific wins); true ties go to `tbl_RE_DataToFix` and feed into image disambiguation.
3. **Image disambiguation (Type 1)** — for watches still carrying multiple candidates after step 2, score watch-vs-candidate image vectors.
4. **Longest reference + image (Type 4, Rolex only)** — for watches with no result yet and a `ReferenceNumberId`: resolve the longest reference with enrichments, then image-match if still ambiguous.
5. **Manufacturer-wide image (Type 5)** — runs for *every* watch with a `ManufacturerId`, regardless of whether it already has a match from steps 1–4; it is not gated on "no prior match" — `usp_AssignEnrichmentToWatches` is what demotes it afterward (see below).

**Image scoring (`EnrichmentPredictor`, ew-ql):** L2-normalize the watch embedding → dot product against each candidate enrichment embedding (cosine similarity, since enrichment vectors are already unit-length) → softmax "confidence" over candidates with a fixed temperature of **17.387385**: `P[i] ∝ exp(17.387385 * (sim[i] - max(sim)))`. Same temperature constant is used in ew-embed-api's `/get-matching` endpoint for parity.

**Threshold + winner logic (`usp_AssignEnrichmentToWatches`, ew-db), joined on `tblManufacturerConfig` by `tblWatch_d.ManufacturerId`:**
- Type 5 (`ManufacturerWideImageMatch`): fails if `ImageMatchScore < COALESCE(BrandSimilarity, 0.97)`.
- Type 4 (`LongestRefRuleImage`): fails if `ImageMatchScore < COALESCE(EnrichmentSimilarity, 2)`.
- Type 1 (`ImageSimilarity`): fails if `ImageMatchScore < COALESCE(EnrichmentSimilarity, 2)` **or** `MatchConfidence < COALESCE(Enrichmentconfidence, 2)`.
- Type 3: no image threshold check.
- **Type 5 is demoted even after passing its own threshold** if another type (1/3/4) still exists for the same watch — a row that logs to `tbl_RE_core_EnrichmentTest_delete_me` and is dropped. Type 5 only survives when no higher-priority type remains for that watch.
- Failed rows are also written to `tbl_RE_core_EnrichmentTest_delete_me` for analysis before being removed from the mapping set.
- **Type 6 (user-assigned) is never computed by this pipeline** — it only exists because `usp_AssignEnrichmentToWatches` and the `MERGE` into `TblWatchEnrichmentResults` explicitly preserve an existing `EnrichmentTypeId = 6` row so CMS manual assignments are never overwritten by automated matching.

## 4. Image vector infrastructure (why types 1/4/5 work at all)

Image-based matching needs 512-dimensional embeddings sitting in OpenSearch before any scoring can happen:

- **ew-embed-api** (Python/FastAPI) computes vectors but never persists them. `/generate-enrichment-embedding` returns one L2-normalized 512-d vector per image (ConvNeXt V2 Tiny, fine-tuned). `/generate-enrichment-batch-embedding` chunks >32 files into batches of 32: per-image L2-normalize → mean-pool each chunk → mean-pool across chunks if multiple → final L2 re-normalize.
- **`EnrichmentVectorGenerateJob`** (ew-scheduler) pages enrichment media (50 `ReferenceEnrichmentId`s at a time), skips anything already indexed in OpenSearch (`enrichment_vector`, doc id `e_{ReferenceEnrichmentId}`), downloads images in parallel, posts the batch-embedding call, and bulk-indexes the results.
- **`EnrichmentImageDownloaderJob`** handles S3 upload of enrichment media and deletes stale `enrichment_vector` docs so they get regenerated.
- **`ImageVectorService`** / related jobs do the same for watch-side listing vectors in the `watch_image_vector` index.
- At match time, ew-ql reads vectors from OpenSearch by id and computes similarity **in-process** (`EnrichmentPredictor`) — not via OpenSearch kNN.

## 5. The `EnrichChangeDate` reprocessing queue (why a watch gets re-enriched)

`tblWatch_d.EnrichChangeDate = NULL` is the signal "this watch needs enrichment recalculated." `usp_GetWatchesForEnrichmentCalculation` dequeues up to 5000 `NULL` rows, **immediately stamps them with `GETDATE()`** before returning them, so a non-NULL value means either "already enriched" or "currently being processed" — the column does double duty as both the queue flag and the in-flight marker (no separate "in process" column was added, to avoid a second flag every consumer would need to learn).

**Why this matters:** `usp_AssignEnrichmentToWatches` only sets `EnrichChangeDate = @CurrentDate` at the end **if the column is still non-NULL at commit time**. If any other writer (synonym linking, raw sync, CMS edit, catalog resync) reset it to `NULL` while EW.QL was mid-match, that `NULL` is preserved — the watch stays queued and gets picked up again with fresher data, instead of being closed out with an enrichment computed from stale draft fields.

**The ten triggers that null `EnrichChangeDate`:**
1. **CMS core-field change** — only when a multi-value param actually changed, **and** the watch is not currently on a Type-1 (image) match (type-1 matches are protected from being nulled by ordinary field edits).
2. **Enrichment rule update** (`RuleService.UpdateRule`).
3. **Catalog resync** (`CatalogToEnrichmentSyncJob` reprocessing reference-number families).
4. **Model change** (F.P. Journe only — resets all watches for the affected model).
5. **Image change** (watches assigned via Type 5 get reset when the image changes).
6. **Manual reprocess** from CMS.
7. **Image download** — when a watch with *no* primary image yet gets one.
8. **Raw data sync** (`sp_UT_SyncRawData`) — nulled **unless** the watch already has a Type-1 match (so a high-confidence image match isn't invalidated by an unrelated raw-field change).
9. **Bulk overview update** (`usp_UpdateBulkOverviewWatches`) — same Type-1 protection rule as #8.
10. **Synonym master linking** (`usp_SynonymMasterLinking`) — deferred: nulled only at the very end, across all nine synonym passes combined, and only for watches with `SyncStatus IN ('Processed','Republish')`, so the identifier job never runs against a half-linked draft mid-procedure.

## 6. `GlobalRuleId` — what it is and why Rolex/Patek/AP mostly have it NULL

`GlobalRuleId` is a nullable int on both `tbl_RE_EnrichmentRule` and `tbl_RE_ReferenceEnrichment`. It originates from `tbl_CAT_Catalog.RuleId` in EWMaster and flows: `tbl_CAT_Catalog.RuleId` → `usp_CatToEnrichmentResync` (aliased as `GlobalRuleId`) → `EnrichmentCatalogData.GlobalRuleId` → `SeedEnrichments` → both `tbl_RE_ReferenceEnrichment.GlobalRuleId` and `tbl_RE_EnrichmentRule.GlobalRuleId`.

**What it represents:** multiple global rules can share the same reference structure (Rolex/Patek/AP) or the same model name (F.P. Journe) while requiring **different field combinations**. `GlobalRuleId` distinguishes which field-combination variant a given catalog entry should use. Example — two Rolex rules covering the same structure:
```
GlobalRuleId = NULL (original): referenceStructure = 'XXXXX' AND EXISTS(dialColorIds)
GlobalRuleId = 19   (newer):     referenceStructure = 'XXXXX' AND EXISTS(dialColorIds) AND EXISTS(dialMaterialIds)
```
**Why Rolex/Patek/AP mostly have `GlobalRuleId = NULL`:** the original global rules were inserted when there was only one field-combination variant per structure, so no id was needed. When a second variant appeared later (e.g. requiring `dialMaterialIds` too), a new `GlobalRuleId` (like 19) was introduced for just that variant — the old rows were never backfilled. **F.P. Journe is different**: since it has no reference-structure hierarchy at all, every rule needed a `GlobalRuleId` from the start to distinguish which model/field-combination group it belongs to — so F.P. Journe rules always have one set.

Used in matching: `CoreFieldsEnrichmentMatchingService.GetEnrichmentSingle` filters candidate global rules to `GlobalRuleId == watch's catalog-assigned GlobalRuleId`, narrowing the search before disambiguation.

## 7. F.P. Journe — concrete code-level differences (not just data shape)

[Catalog-Enrichment-Complete-Guide.md §3a](Catalog-Enrichment-Complete-Guide.md) already covers that F.P. Journe rules are model-keyed, not structure-keyed. What it doesn't cover is *how that plays out in code*:

1. Global rules use `modelName = '...'` instead of `referenceStructure = '...'` in the generated EWQL.
2. Generated (specific) rules key on `modelId` instead of `referenceNumberId`.
3. In `QueryJsonConverter.cs`, when EW.QL converts a parsed query back to EWQL for F.P. Journe, the `modelName` clause is stripped and `EXISTS(modelId)` is converted to `modelId = <actual id>`.
4. `ReferenceStructureUtil.ExtractReferenceNumberFromQuery` returns `0` for manufacturerId 267 (F.P. Journe) instead of extracting a real reference number — this deliberately skips reference-number-based disambiguation for this brand.
5. Catalog resync has an F.P.-Journe-only step: after resyncing enrichments, it reprocesses **all watches sharing the affected `ModelId`** (`ReprocessWatchesByModel`), whereas every other manufacturer only reprocesses by `ReferenceNumberId`.
6. F.P. Journe (267) sits alongside Rolex (257), Patek (193), and AP (142) in a "do not auto-generate simple rules" list — every F.P. Journe enrichment must come from a global rule match, never an auto-generated single-reference fallback rule.

**Root cause:** F.P. Journe watches don't follow a structured reference-number hierarchy — models are the primary grouping dimension, so the entire rule-generation and reprocessing logic keys on model instead of structure.

## 8. Three distinct publish paths (which one actually honors enrichment overrides)

Published watch tables are not updated by a single code path. This matters when deciding why a published watch does or doesn't reflect an enrichment override:

| Path | Procedure | Enrichment override applied? |
|---|---|---|
| 1 | `usp_assignDataBasedonEnrichment` | **Yes** — manufacturer/model, dial colors, case materials take enrichment values first (draft fills gaps); `ReferenceEnrichmentId` copied to `tblWatch` |
| 2 | `sp_UT_SyncRawData` (`@applyClean = 1`) | **No** — updates `tblWatch` straight from cleaned raw data; does not copy `ReferenceEnrichmentId` |
| 3 | Crawler sync SPs (`usp_Crawler_Artworks_Watches_Sync`, `usp_Crawler_Marketplace_Artworks_Watches_Sync`) | **No** — these call `sp_UT_SyncRawData` internally, so same as Path 2 |

Only Path 1 lets enrichment override manufacturer/model and dial-color/case-material data on the published side; Paths 2 and 3 publish the watch's own cleaned data unchanged.

## 9. `usp_SynonymMasterLinking` — nine conditional passes

Each pass runs only if that synonym type is currently queued in `TblSynonymMasterLinkingQueue`: (1) manufacturer, (2) model (manufacturer-scoped), (3) reference number (manufacturer + optional model), (4) case size, (5) movement, (6) dial colour + bezel colour (shared queue type `dialColor`, updates `tblWatchToDialColor_d` / `TblWatchToBezelColor_d`), (7) material synonym type `caseMaterial` (covers case/bracelet/dial/clasp/bezel material), (8) box (`IsBox` via `tbl_SYNC_BoxDictionary`), (9) paper (`IsPaper` via `tbl_SYNC_PaperDictionary`, skipped when `CertificationId = 1`). Affected `WatchId`s accumulate across all nine passes and only get their `EnrichChangeDate` nulled once, at the end (see trigger #10 in §5) — this was a deliberate fix so an early pass can't queue the identifier job on a draft that later passes haven't finished linking yet.

## Source

Summarized from ew-brain `03-architecture/enrichment-lifecycle.md` (owner: Mayur). Full mermaid diagrams, exact file/line references (`ew-scheduler`, `ew-ql`, `ew-db`, `ew-embed-api` source paths), and the CMS controller API surface live there — read it directly before changing any of this behavior.
