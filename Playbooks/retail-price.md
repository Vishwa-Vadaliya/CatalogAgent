---
type: Playbook
title: Retail price
description: Retail price work — price last seen, seen-status, private and public prices, outliers, production status, and the daily job chain.
tags: [playbook, retail-price, pricing, isseen, pricelastseen]
timestamp: 2026-11-04
---

# Playbook — retail price

## Read first

- [../Knowledge/retail-price.md](../Knowledge/retail-price.md) — tables, ids, definitions, the job chain. The whole file; the definitions are easy to half-remember.
- [../Documents/RetailPrice/CONTEXT.md](../Documents/RetailPrice/CONTEXT.md) — then the numbered documents for the area in question, and the per-procedure documents under `sp/`.
- [../Rules/10-sql-style.md](../Rules/10-sql-style.md).
- Existing work worth checking before writing anything new: `Output/Queries/Janvi/RetailPrice/` and `Output/Plans/janvi/` (several price plans already exist).

## Steps

1. **Fix the definition first.** "In production", "last seen", "active price", "private" each have a
   precise meaning in `Knowledge/retail-price.md`. Quote the one you're using back to the user before
   building on it — a wrong definition here produces a confident wrong answer.
2. **Identify the layer** the question lives in: crawler (`tbl_RAW_Catalog`), mapping
   (`tbl_MAP_RawCatalog_CatalogCountry`), price (`tbl_CAT_CatalogRetailPrice_d`), or the app-side copy
   (`tblReferenceNumberMSRP`). Most confusion is a question asked at the wrong layer.
3. **Check the existing procedure before writing a replacement.** If a job already does part of the
   work, read it in `ew-db` and reuse its filters rather than inventing new ones.
4. **Write the query** — temp tables, a `#Params` table instead of `DECLARE` (B2), currency filtered
   by **name**, country and currency **LEFT** joined off the retail row.
5. **Updates** per B7, with a fresh TransactionId (B6). No publish call (A9).
6. **Deliver** per [OUTPUT.md](OUTPUT.md).

## Traps

- `IsSeenInLastRun` — **NULL is not 0.** Count only 0 and 1.
- Never overwrite a `PriceLastSeenDate` with NULL.
- Unverified prices often have no `CountryId` — an INNER JOIN to country silently drops them.
- Rolex raw refs carry a leading `m`; the reference guard does **not** strip it, which blocks
  ~21,400 raws. Strip it yourself for any Rolex pull from `tbl_RAW_Catalog`.
- Read `tbl_MAP_RawCatalog_CatalogCountry` directly per (CatalogId, CountryId) — no MAX/GROUP BY, no
  `IsDeleted` filter.
- The mirror table is read **by id** with a date filter, never scanned.
- Once the map's `IsPriceTaxIncluded` is set to 0/1, a later flip or NULL from raw is a crawl problem
  → abort and report, don't "fix" it.
