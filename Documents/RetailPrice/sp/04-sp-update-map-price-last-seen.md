---
type: Document
title: sp_UpdateMap_PriceLastSeen
description: How sp_UpdateMap_PriceLastSeen sets PriceLastSeenDate on the MAP table.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_UpdateMap_PriceLastSeen.sql (~203 lines)
---

# sp_UpdateMap_PriceLastSeen

## In plain words

For each catalog watch and country, this answers: "when did a listing last show our current retail price?" It looks at the latest official price we hold, then checks whether the crawler still shows that same price right now. If the listing is currently live with a price, there is no "last seen" date yet (it is still being seen), so the date stays empty. If the listing no longer shows that price, it works out the date from the listing's history. The answer is stored on the MAP row.

**Status:** in use; the update SP calls it at its end.

## Technical detail

**Parameters:** none. Returns `MappingRowsUpdated`. One transaction, `XACT_ABORT ON`.
**Reads:** MAP, `tbl_CAT_CatalogRetailPrice_d`, `tbl_RAW_Catalog`, `tbl_CAT_Currency_d`, Mirror.
**Writes:** MAP `PriceLastSeenDate` and `MappingUpdatedAt` only.

### Steps
1. **Latest price per MAP row.** For each active MAP row, take the newest draft price of its (CatalogId, CountryId) with `StatusID = 1`, `IsPrivate = 0`, `IsVerified = 1` (ordered by `CreatedAt` desc, then id desc).
2. **Does the current RAW row still show that price?** Yes when: RAW not deleted, `UpdatedDate` not null, `Price` non-zero, price equals the retail price (both converted to money then whole-number compare), and RAW `Currency` equals the retail currency name (trimmed, case-insensitive).
3. **Which listings need history?** Active MAP rows whose RAW row is not deleted, are **not** (seen and non-zero price), and did not pass step 2.
4. **Mirror history for those.** For each mirror row (not deleted) work out an EffectiveDate: its `UpdatedDate` if present; else `CreatedDate` if it is the first row; else the previous row's `MirrorDate`. Partition by (listing id, location), ordered by `MirrorDate`.
5. **Pick the mirror date.** The mirror row with the greatest EffectiveDate whose price and currency equal the latest retail price.
6. **Set `PriceLastSeenDate`** on each active MAP row, first matching rule wins:
   1. Listing currently seen (`IsSeenInLastRun = 1`) with non-zero price: **NULL**.
   2. No latest retail price found: **NULL**.
   3. RAW still shows the catalog price: RAW `UpdatedDate`.
   4. Otherwise: the mirror date (NULL if no mirror row matched).
   - Only written when the **date part** changes (time-only changes are ignored).
