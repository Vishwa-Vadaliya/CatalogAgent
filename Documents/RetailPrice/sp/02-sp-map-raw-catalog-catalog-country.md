---
type: Document
title: sp_map_rawCatalog_catalogCountry
description: How sp_map_rawCatalog_catalogCountry maps RAW rows to catalog + country (tax lock, Rolex m strip).
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_map_rawCatalog_catalogCountry.sql (~535 lines)
---

# sp_map_rawCatalog_catalogCountry

## In plain words

A raw listing says "reference 126610LN, price 10,400 USD, from Rolex US". Before we can use it we must know which watch in our catalog that is and which country it belongs to. This procedure makes that link and stores it in the MAP table. It only links listings from official sources. If a listing could match two catalog watches, it does not guess; it parks the listing in an "ambiguous" list for a person to look at. It also keeps the "still listed" and "deleted" flags of existing links up to date.

**Status:** in use. It is the first thing `sp_update_CatalogRetailPrice_FromMapping` runs.

## Technical detail

**Parameters:** none. Returns one result set: `MappingRowsUpdated`, `MappingRowsInserted`. Runs in one transaction (`XACT_ABORT ON`, TRY/CATCH with rollback and re-throw). Reads use `NOLOCK`.

**Reads:** `tbl_RAW_Catalog`, Mirror, `tbl_sourceManufacturer_mapping`, `tbl_CAT_RawCatalogMapping`, `tbl_CAT_Catalog_d`, existing MAP and Ambiguous tables.
**Writes:** `tbl_MAP_RawCatalog_CatalogCountry`, `tbl_MAP_RawCatalog_CatalogCountry_Ambiguous`.

### Steps
1. **Mirror fallback for blank references.** For RAW rows (not deleted, official source) with an empty `ReferenceNo`, take the latest non-empty `ReferenceNo` from the Mirror.
2. **Refresh existing MAP rows.** For every MAP row whose RAW row differs: `IsDeleted = (RAW IsDeleted = 1)`, `IsSeenInLastRun = (RAW IsSeenInLastRun = 1 ? 1 : 0)`, `MappingUpdatedAt = now`. (Not limited to official sources.)
3. **Lock the tax flag.** Where MAP `IsPriceTaxIncluded` is NULL and RAW's is not, copy it.
4. **Tax conflict guard.** For active MAP rows with a locked tax value, if RAW is now NULL or different, collect them; if any exist the procedure raises an error (severity 16) and the whole run, including steps 2 and 3, is rolled back. No mapping is updated or inserted until the data is fixed.
5. **Build the candidate list (`#RawBase`).** RAW rows joined to `tbl_sourceManufacturer_mapping` where: `IsActive` is null or 1, `CatSourceName` contains "OFFICIAL" (case-insensitive), `CatManufacturerId` and `CatCountryLocationId` are not null, and the RAW row is not deleted. `CountryId = CatCountryLocationId`.
6. **Clean the reference into a match key.**
   - **Rolex** (when the manufacturer is ROLEX and `ArtworkId` is present): if the reference is empty and `ArtworkId` starts with `m`, use `ArtworkId` without the `m`; else if the reference starts with `m`, strip it; else if the reference is shorter than `ArtworkId`, is contained in it and `ArtworkId` starts with `m`, use `ArtworkId` without `m` (repairs truncated references); else use the reference as is.
   - **Other manufacturers:** the reference as is.
   - In every case the key is reduced to letters and digits (`EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets`).
7. **Build lookup sets.** Manual spellings from `tbl_CAT_RawCatalogMapping` (single-catalog and ambiguous), and catalog references from `tbl_CAT_Catalog_d` (`StatusID = 1`, `EntityType = 'Watch'`), per manufacturer (single and ambiguous).
8. **Resolve the catalog** in this order: (a) manual mapping table (matched on key only, note `MappingTable`); (b) catalog by manufacturer + key (note `CatalogFallback`); (c) otherwise nothing is written.
9. **Clean the ambiguous list.** Remove Ambiguous rows for listings now resolved or already actively mapped.
10. **Ambiguous type `MAP_REF_TRIM_AMBIGUOUS`.** The key matches several catalogs in the manual mapping table and there is no single catalog hit: record the candidate catalog ids.
11. **Ambiguous type `CATALOG_KEY_AMBIGUOUS`.** The manufacturer + key matches more than one active Watch catalog (and the manual table has no single answer): record the candidates.
12. **Deduplicate resolved rows** per (RawCatalogId, CatalogId, CountryId); `IsSeenInLastRun = 1` if the RAW row is seen.
13. **Skip what is already mapped.** Keep only RAW rows with no MAP row and no active MAP row for the same (CatalogId, CountryId).
14. **One listing per catalog + country.** If several RAW rows compete, keep the one with the latest `UpdatedDate` (then highest id). Others are silently skipped (not recorded as ambiguous).
15. **Insert into MAP** with `IsDeleted = 0`, `PriceLastSeenDate = NULL`, `RawCatalogUpdatedDate = NULL`, `MappingCreatedAt = now`, the resolution note, the tax flag from RAW, and `IsSeenInLastRun`.
16. Commit and return the counts.

### Behaviour worth knowing
- A RAW row that is already mapped is never re-matched; if its reference is later corrected, its catalog link stays. Only `IsDeleted` and `IsSeenInLastRun` are refreshed.
- `PriceLastSeenDate` and `RawCatalogUpdatedDate` are left NULL here; `sp_UpdateMap_PriceLastSeen` fills the first.
