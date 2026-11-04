---
type: Document
title: Data Reference
description: Retail price tables, key columns and what each value means (RAW, MAP, draft, published, sync log).
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
---

# Data Reference

## In plain words

Think of the data as five layers, each a table or a small group of tables:

| Layer | Table | What it holds |
|---|---|---|
| What the crawler saw | `tbl_RAW_Catalog` | One row per listing: reference, price, currency, still listed or not |
| What it used to say | `tbl_raw_catalog_m` (Mirror) | Previous versions of those rows |
| Which watch and country | `tbl_MAP_RawCatalog_CatalogCountry` | Link from a listing to a catalog watch and country |
| Clean price history (working) | `tbl_CAT_CatalogRetailPrice_d` | One row per price change, per watch, country, currency |
| Clean price history (live) | `tbl_CAT_CatalogRetailPrice` | Published copy |

Helper tables: `tbl_sourceManufacturer_mapping` (which sources are official, their country and currency), `tbl_CAT_RawCatalogMapping` (manual alternative reference spellings), `tbl_cat_RetailPrice_SyncLog` (how far the daily job has read), `tbl_CAT_Currency_d` (currency list).

All tables are in MasterDB (EWMaster). Paths: `MasterDB\dbo\table\` and `MasterDB\mirror\`.

## tbl_RAW_Catalog

- **Key:** `Id bigint IDENTITY` (PK). Natural key: unique `(AuctionId, SourceId, ArtworkId)`.
- The table has about 150 descriptive columns (watch attributes, media, text). Only the ones relevant to retail price are listed.

| Column | Type | Meaning for retail price |
|---|---|---|
| `Price` | float | Listing price in the listing's currency. Copied from the crawler untouched. |
| `Currency` | varchar(5) | Currency text, matched later to `tbl_CAT_Currency_d.CurrencyName`. |
| `IsSeenInLastRun` | tinyint | From the crawler. The load SP only pulls rows with 0 or 1. 1 = seen in the last crawl; 0 = not seen. Values 2 and 3 exist in the crawler but are not loaded. |
| `UpdatedDate` | datetime | The crawler's "listing last changed" date (not the load time). Becomes the price's effective date. |
| `SyncDate` | datetime | When the row was last loaded. |
| `TransactionId` | bigint NOT NULL | Id of the load batch that created or updated the row. The daily job's watermark compares to this. |
| `ReferenceNo`, `ReferenceRaw` | nvarchar | Reference number as parsed and as seen. Used for catalog matching. |
| `SourceId` | int | Crawl source; joins to `tbl_sourceManufacturer_mapping`. |
| `ArtworkId` | varchar(30) | Crawler's listing id. For Rolex it can carry the full reference with an `m` prefix. |
| `IsDeleted` | bit | Listing deleted. |
| `IsPriceTaxIncluded` | bit NULL | Tax flag. **Not written by the load SP** (see known issues). |
| `BuyNowPrice`, `ShippingPrice`, `BuyersFee`, `EstimatePriceFrom/To`, `PriceFirstSeenDate`, `SuspiciousPriceDate` | various | Copied from the crawler; not used by the retail flow. |

## tbl_raw_catalog_m (Mirror)

- Same columns as RAW, minus `IsPriceTaxIncluded`, plus `IdMirror bigint IDENTITY` (PK) and `MirrorDate datetime` (when the old version was saved, default `GETDATE()`). `Id` is the RAW row's id, not an identity.
- Filled by trigger `tr_UD_tbl_raw_catalog` on RAW: **after UPDATE or DELETE it saves the old version of the row.** Nothing is saved on INSERT, so a new listing has no mirror row until it is first changed.
- `MirrorDate` is when the row was overwritten, not when the price was observed.
- The trigger skips copying when `SESSION_CONTEXT('SkipMirror') = 1`.
- The retail SPs read it as `MIRROR.EWMaster.tbl_raw_catalog_m` (linked server).

## tbl_MAP_RawCatalog_CatalogCountry

| Column | Type | Meaning |
|---|---|---|
| `RawCatalogId` | bigint PK | The RAW row. One map row per RAW row. |
| `CatalogId` | int | The catalog watch. |
| `CountryId` | bigint | Country, from the source's country in `tbl_sourceManufacturer_mapping`. |
| `IsSeenInLastRun` | tinyint | 1 if the RAW row is seen, else 0. |
| `IsDeleted` | bit | Follows RAW deletion. |
| `PriceLastSeenDate` | datetime2(3) NULL | Last date the catalog's latest price was seen. NULL on insert. Written only by `sp_UpdateMap_PriceLastSeen`. |
| `RawCatalogUpdatedDate` | datetime2(7) NULL | Not written by the daily SPs. |
| `IsPriceTaxIncluded` | bit NULL | Locked to the first non-null value seen on RAW. |
| `ResolutionNote` | nvarchar(100) | How the catalog was found: `MappingTable` or `CatalogFallback`. |
| `MappingCreatedAt`, `MappingUpdatedAt` | datetime2(7) | Audit. |

**Unique rule:** a filtered unique index on `(CatalogId, CountryId) WHERE IsDeleted = 0` means only one active listing per catalog and country.

`tbl_MAP_RawCatalog_CatalogCountry_Ambiguous`: `AmbiguousId` (PK), `RawCatalogId`, `CountryId`, `ReasonCode` (`MAP_REF_TRIM_AMBIGUOUS` or `CATALOG_KEY_AMBIGUOUS`), `CandidateCatalogIds` (comma list), `CreatedAt`.

## tbl_sourceManufacturer_mapping

One row per crawl source (unique on `SourceId`). Key columns: `CatSourceName` (contains "OFFICIAL" for official sources), `CatManufacturerId`, `CatCountryLocationId` (becomes the CountryId), `Currency` (expected currency for the source; used by the currency gate), `IsActive` (default 1).

## tbl_CAT_RawCatalogMapping

Manual list of alternative reference spellings: `CatalogId`, `RawCatalogId`, `RawReferenceNumber`. A heap with no keys or indexes.

## tbl_CAT_CatalogRetailPrice_d (draft)

| Column | Type | Meaning |
|---|---|---|
| `CatalogRetailPriceID` | bigint IDENTITY PK | |
| `CatalogID` | int | Catalog watch (FK). |
| `Price` | money | The price. |
| `CurrencyId` | int | FK to `tbl_CAT_Currency_d`. |
| `CountryId` | bigint NULL | FK to `tbl_CAT_Country_d`. |
| `CreatedAt` | datetime | The price's effective date (not the insert time). |
| `StatusID` | tinyint | 1 normal, 2 pending (outlier), 3 deleted. |
| `TransactionId` | bigint NULL | Insert batch id (FK `tblTransaction`). Publish compares it. |
| `IsPrivate` | bit | 0 for everything the daily flow inserts. |
| `IsSeenInLastRun` | bit | 0 at insert. |
| `PriceLastSeenDate` | datetime2(3) NULL | NULL at insert. |
| `IsVerified` | bit NOT NULL (no default) | 1 for rows from the daily flow. |
| `IsPriceTaxIncluded` | bit NULL | Not written at insert. |

Only index: the clustered PK. Trigger `tr_UD_tbl_CAT_CatalogRetailPrice_d` (after update or delete) saves the old row to `MIRROR.EWMaster.tbl_CAT_CatalogRetailPrice_d_m`; it copies 11 columns and **not** `IsVerified` or `IsPriceTaxIncluded`.

## tbl_CAT_CatalogRetailPrice (published)

Same columns as the draft minus `StatusID`; `CatalogRetailPriceID` is copied from the draft (not an identity); `TransactionID` NOT NULL. Filled only by `sp_PublishAllDataNew` step 7.

## tbl_cat_RetailPrice_SyncLog

| Column | Meaning |
|---|---|
| `RetailPriceSyncLogId` | bigint IDENTITY PK |
| `RunCompletedAt` | datetime2(3), UTC |
| `MaxRawCatalogTransactionId` | The watermark reached by that run |
| `RowsInserted` | Rows added by that run |
| `Status` | `Success` or `Failed` (no constraint) |
| `ErrorMessage` | Error text on failure |

## Value meanings

| Field | Value | Meaning |
|---|---|---|
| Retail `StatusID` | 1 | Normal; published |
| | 2 | Pending review (outlier, or repeat of the old price after an unresolved outlier); never published |
| | 3 | Deleted; publish removes the live row |
| `IsVerified` | 1 | Official manufacturer website price |
| `IsPrivate` | 1 | Private stream; the daily flow neither creates nor uses it |
| `tblTransaction.TransactionTypeID` | 1 | Create (retail insert, RAW insert) |
| | 2 | Update (RAW update, sync of `IsSeenInLastRun`) |

## Currency table

`tbl_CAT_Currency_d`: `CurrencyId`, `CurrencyName`, `CurrencyCode`, `CurrencySymbol`, `IsActive`, `StatusID`, etc. The update SP matches the RAW/Mirror `Currency` text to `CurrencyName` (with `StatusID = 1`) to get `CurrencyId`; a row with no match is dropped.

## Not documented (not used by this flow)

`tbl_cat_privateRetailPriceSourceLink_d` and `tbl_cat_privateRetailMapping_d` (private price source links; nothing in MasterDB uses them), `tbl_CAT_RetailPriceUSD*` (not in use), personal/scratch/backup copies (`_delete_me`, `_jnv_`, `_vishva_`, `Ravi`, `tbl_test_*`, `AllRaw*`).
