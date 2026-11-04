---
type: Knowledge Fact
title: Enrichment (ENR)
description: Reference enrichment in the EveryWatch app DB — the ENR tables, enrichment type ids, what "multiple ENR" means, where match data lives for enriched versus discarded watches, and the ENR workflow.
tags: [knowledge, enrichment, enr, multiple-match, image-similarity]
db: EveryWatch
keywords: [enrichment, ENR, ReferenceEnrichmentId, multiple ENR, multiple match, tbl_RE_DataToFix, tbl_RE_DiscardedWatch, TblWatchEnrichmentResults, EnrichmentTypeId, image similarity, manufacturer-wide, core fields, dial colour, variations]
timestamp: 2026-11-04
---

# Enrichment (ENR, EveryWatch)

- `tblWatch.ReferenceEnrichmentId` = assigned ENR. `tbl_RE_ReferenceEnrichment` (ReferenceEnrichmentId, ReferenceNumberId, ManufacturerId, EntityStatusId — 2 = published).
- `TblWatchEnrichmentResults` (WatchId = draft id) = watches that **got** an ENR and how: EnrichmentTypeId, ImageMatchScore, MatchConfidence, MatchingWatchDraftId. No ReferenceEnrichmentId column.
- `tbl_RE_DiscardedWatch` (~9.27M rows) = candidates for watches that did **not** get an ENR. Unique index (WatchId, ReferenceEnrichmentType) → start from filtered `tblWatch_d` and seek by WatchId; never scan by type first.
- EnrichmentTypeId (`tbl_RE_ReferenceEnrichmentType`): 1 = Image Similarity, 2 = Longest Reference, 3 = Core Fields, 4 = Longest-Ref Rule + Image, 5 = Manufacturer-Wide Image Match, 6 = User/Manually Assigned, 7 = cross-manufacturer image (?).
  - By default the manufacturer-wide image match score — i.e. the image match score for that type — will be 0.89.

- **Multiple ENR** = watch with `ReferenceEnrichmentId IS NULL` + candidate rows in `tbl_RE_DataToFix` (WatchId = draft id, RefEnrichmentId, one row per candidate). **No `IsFixed` filter** (newest rule, 2026-10-13; an older session used `IsFixed = 0`). Variations = distinct candidate ENRs per watch reference.
- Match data for a watch → has ENR: `TblWatchEnrichmentResults` (type flag; type 1 for image similarity). No ENR: `tbl_RE_DiscardedWatch` (type 5 = manufacturer-wide image candidates).
- Draft ref/ENR coverage → `tblWatch_d` with `IsDeleted = 0`; show % of total and % of parent (With Ref / Without Ref).
- "Unique from ref alone" = watch ref = ENR ref AND EnrichmentTypeId = 3; every other enriched watch = "made unique by us".
- ENR = one catalog id; watches in an ENR group must be uniquely identifiable by a minimal field set (dial color + case material, plus differentiators like bracelet).
- ENR workflow: unique watches per brand → finalize ref + model → create ENR → direct match → lower manufacturer-wide image score → image similarity for same ref → assign refs → create rules.

## See also

- [../Documents/Enrichment/Catalog-Enrichment-Complete-Guide.md](../Documents/Enrichment/Catalog-Enrichment-Complete-Guide.md) — the entry point for enrichment rules.
- [../Documents/Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md](../Documents/Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md) — the multiple-match collision problem.
- [../Documents/Enrichment/Catalog-Enrichment-Runtime-Pipeline.md](../Documents/Enrichment/Catalog-Enrichment-Runtime-Pipeline.md) — how a rule is generated, matched, assigned and published.
- [workflows/image-match-review.md](workflows/image-match-review.md) — the per-brand image match review.
- [stored-procedures.md](stored-procedures.md) — the enrichment rule SPs.
