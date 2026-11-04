---
type: Data Index
title: Documents index
description: Index of the Documents folder — deep background by domain: enrichment, retail price, brands, raw-to-catalog.
tags: [index, documents]
timestamp: 2026-11-04
---

# Documents — index

Deep background. Quick facts live in [../Knowledge/index.md](../Knowledge/index.md); a playbook names
the document to read for the job in hand.

## Enrichment

- [Enrichment/Catalog-Enrichment-Complete-Guide.md](Enrichment/Catalog-Enrichment-Complete-Guide.md) — the entry point for everything about enrichment rules.
- [Enrichment/Catalog-Enrichment-Rules-Documentation.md](Enrichment/Catalog-Enrichment-Rules-Documentation.md) — full SP/table reference for enrichment rules.
- [Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md](Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md) — the multiple-enrichment-match collision problem.
- [Enrichment/Catalog-Enrichment-Runtime-Pipeline.md](Enrichment/Catalog-Enrichment-Runtime-Pipeline.md) — how a rule is generated, matched, assigned and published across ew-scheduler / ew-ql / ew-db / ew-embed-api, plus the `EnrichChangeDate` queue and `GlobalRuleId`.
- [Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md](Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md) — the named dial-variant precedent.

## Retail price

- [RetailPrice/index.md](RetailPrice/index.md) — the whole set: flow, tables, known issues, flag-group snapshot, case documents for management and engineers, and one document per stored procedure. **Start with [RetailPrice/CONTEXT.md](RetailPrice/CONTEXT.md).**

## Brands & reference numbers

- [Brands/Brand_Reference_Validation_Workflow.md](Brands/Brand_Reference_Validation_Workflow.md) — the general brand reference validation & enrichment workflow.
- [Brands/Reference_Numbers.md](Brands/Reference_Numbers.md) — general reference-number & model cleanup knowledge, plus Cartier patterns.
- [Brands/BrandRefAgent_Requirements.md](Brands/BrandRefAgent_Requirements.md) — the Brand Reference Agent requirements spec.
- Per-brand notes: [Bovet](Brands/Bovet_Reference_Validation.md), [Cartier](Brands/Cartier_Reference_Validation.md), [Credor](Brands/Credor_Reference_Validation.md), [Daniel Roth](Brands/Daniel_Roth2_Reference_Validation.md), [Jacob & Co.](Brands/Jacob_and_Co_Reference_Validation.md), [Jaeger-LeCoultre](Brands/Jaeger_LeCoultre_Reference_Validation.md), [Louis Vuitton](Brands/Louis_Vuitton_Reference_Validation.md), [Piaget](Brands/Piaget_Reference_Validation.md).
- Jaeger-LeCoultre extras: [model-name confidence](Brands/Jaeger_LeCoultre_ModelName_Confidence.md), [valid refs by length](Brands/Jaeger_LeCoultre_Valid_Refs_By_Length.md), [weak dotted links](Brands/Jaeger_LeCoultre_Weak_Dotted_Links.md).

## Raw to catalog (ECH-693)

- [RawToCatalog/RawToCatalog_NewRefs_Overview.md](RawToCatalog/RawToCatalog_NewRefs_Overview.md) — plain-language overview of the whole flow with a worked example, the review page sketch, what runs once versus every run, and the safety nets. Written to show to someone new.
- [RawToCatalog/RawToCatalog_NewRefs_Requirements.md](RawToCatalog/RawToCatalog_NewRefs_Requirements.md) — DRAFT requirements for adding new unique official-source refs from `tbl_RAW_Catalog` to `tbl_CAT_Catalog_d` through `sp_Create_Catalog`, with the raw-to-catalog mapping table.

Session summaries and superseded notes are in [../Archive/index.md](../Archive/index.md).
