---
type: Data Index
title: Documents/RetailPrice index
description: Index of the catalog-side retail price documentation set (crawler to published retail price): flow, data, issues, case documents and one document per stored procedure.
tags: [index, documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review (not all documents reviewed by the owner)
---

# Documents/RetailPrice — index

**Scope.** How a manufacturer's official retail price travels from the crawler into the catalog and is published: crawler, `tbl_RAW_Catalog`, MAP (`tbl_MAP_RawCatalog_CatalogCountry`), draft `tbl_CAT_CatalogRetailPrice_d`, publish into `tbl_CAT_CatalogRetailPrice`. Out of scope: the EveryWatch app database, `tblReferenceNumberMSRP*`, views and feeds, `tbl_CAT_RetailPriceUSD` (not in use).

**Describes the flow as it runs today.** No proposals or planned changes. Start with [CONTEXT.md](CONTEXT.md) for a short summary to give a new chat.

## Reading order

| # | Document | For whom |
|---|---|---|
| 0 | [CONTEXT.md](CONTEXT.md) | A new chat or a new person: the short context. |
| 1 | [01-overview-and-glossary.md](01-overview-and-glossary.md) | Everyone. What retail price is, the flow in one picture, the terms. |
| 2 | [02-end-to-end-flow.md](02-end-to-end-flow.md) | Everyone. Each stage, the order things run, where data is added. |
| 3 | [03-data-reference.md](03-data-reference.md) | Data / analytics, engineers. Tables, key columns, what each value means. |
| 4 | [sp/index.md](sp/index.md) | Engineers. One document per stored procedure, step by step. |
| 5 | [05-data-snapshot-flag-groups.md](05-data-snapshot-flag-groups.md) | Everyone. What the draft table contains by flag combination (with counts). |
| 6 | [06-cases-management-non-technical.md](06-cases-management-non-technical.md) | Management. Every price case in plain words, with reasons and date points. |
| 7 | [07-cases-technical.md](07-cases-technical.md) | Engineers / data. Same cases with flags and rules. |
| 8 | [08-cases-combined.md](08-cases-combined.md) | Mixed audience. One-page overview of the cases. |
| 9 | [09-cases-simple.md](09-cases-simple.md) | Management. Short version: words, sources, cases with reasons, points to discuss. |
| 10 | [10-last-seen-seen-flag-production-status.md](10-last-seen-seen-flag-production-status.md) | Everyone planning changes. `PriceLastSeenDate` and `IsSeenInLastRun` for public verified prices: who writes what, the confirmed target rule, the gap, scope. |
| 11 | [11-mirror-effective-date-and-upstream-sync.md](11-mirror-effective-date-and-upstream-sync.md) | Engineers / data. Where `tbl_RAW_Catalog` comes from upstream (`sp_SYNC_SyncWatchesCatalog`), the mirror EffectiveDate S1/S2/S3 model, and the `IsDeleted=1` exclusion fix. |

## Related files elsewhere in CatalogBrain

- Queries: [../../Queries/Janvi/RetailPrice/index.md](../../Queries/Janvi/RetailPrice/index.md) — the group and edge-case queries these documents cite.
- Plans: [../../Plans/janvi/isseen_retail_price_sync.plan.md](../../Plans/janvi/isseen_retail_price_sync.plan.md), [../../Plans/janvi/mapping_pricelastseen_isseen.plan.md](../../Plans/janvi/mapping_pricelastseen_isseen.plan.md) and [../../Plans/janvi/raw_catalog_retail_mapping_and_price_sync.plan.md](../../Plans/janvi/raw_catalog_retail_mapping_and_price_sync.plan.md) — earlier plans for the mapping and price sync.

## Conventions

- Facts come from `D:\EW\ew-db\MasterDB`. Line numbers are approximate.
- Anything not in a repository (SQL Agent job names, schedules, who runs what) is marked **to confirm**.
- No SQL was run to produce these documents.
