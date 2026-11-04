/*
================================================================================
 Map table - why is a catalog not in tbl_MAP_RawCatalog_CatalogCountry?
================================================================================
 Purpose   : For one catalog (#Input), repeat the checks of
             sp_map_rawCatalog_catalogCountry and show, per RAW row that carries
             the same reference, the first check that stops the mapping.
             Example: CatalogId 230412, ref 26643TI.OO.D002CA.01.

             Checks (same order as the map SP):
               Catalog : StatusID = 1, EntityType = 'Watch'
               Source  : in tbl_sourceManufacturer_mapping, IsActive, Official
                         CatSourceName, CatManufacturerId = catalog brand
               RAW     : IsDeleted = 0, key not blank
               Lookup  : 1) tbl_CAT_RawCatalogMapping key -> exactly 1 catalog
                            (wins over the catalog lookup, any brand)
                         2) else tbl_CAT_Catalog_d same brand -> exactly 1 catalog
               Insert  : RawCatalogId not already in the map table (any
                         CatalogId, also IsDeleted = 1), and (CatalogId,
                         CountryId) not already active from another RAW row

 Key       : dbo.fn_ExtractNumbersAndAlphabets (the deployed map SP version).
             If the old map SP is still deployed it used
             EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets - see column
             KeyOldFunction.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.
 No DECLARE variables. Change the CatalogId in step 0.
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 0. Input
------------------------------------------------------------
DROP TABLE IF EXISTS #Input;
SELECT v.CatalogId
INTO #Input
FROM (VALUES (230412)) AS v (CatalogId);

------------------------------------------------------------
-- 1. The catalog and its key
------------------------------------------------------------
DROP TABLE IF EXISTS #Cat;
SELECT
      cd.CatalogId
    , cd.ManufacturerId
    , mf.ManufacturerName
    , cd.ReferenceNumber
    , cd.StatusID
    , cd.EntityType
    , cd.ParentCatalogId
    , cd.RefProductionStatusID
    , dbo.fn_ExtractNumbersAndAlphabets(cd.ReferenceNumber) AS CatKey
    , EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(cd.ReferenceNumber) AS CatKeyOldFunction
INTO #Cat
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
INNER JOIN #Input AS i
    ON i.CatalogId = cd.CatalogId
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = cd.ManufacturerId;

SELECT 'Catalog' AS Result, c.* FROM #Cat AS c;

------------------------------------------------------------
-- 2. Other catalogs with the same key (ambiguity in the catalog lookup)
------------------------------------------------------------
SELECT
      'SameKeyCatalogs' AS Result
    , cd.CatalogId
    , cd.ManufacturerId
    , cd.ReferenceNumber
    , cd.StatusID
    , cd.EntityType
    , CASE WHEN cd.ManufacturerId = c.ManufacturerId AND cd.StatusID = 1 AND cd.EntityType = 'Watch'
           THEN 1 ELSE 0 END AS CountsInMapSpLookup
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
INNER JOIN #Cat AS c
    ON cd.ManufacturerId = c.ManufacturerId
   AND dbo.fn_ExtractNumbersAndAlphabets(cd.ReferenceNumber) = c.CatKey
ORDER BY cd.CatalogId;

------------------------------------------------------------
-- 3. tbl_CAT_RawCatalogMapping rows with the same key (lookup 1, any brand)
------------------------------------------------------------
SELECT
      'RawCatalogMappingSameKey' AS Result
    , m.CatalogId
    , m.RawReferenceNumber
    , cd.ManufacturerId
    , cd.ReferenceNumber AS CatalogReferenceNumber
    , cd.StatusID
FROM dbo.tbl_CAT_RawCatalogMapping AS m WITH (NOLOCK)
INNER JOIN #Cat AS c
    ON dbo.fn_ExtractNumbersAndAlphabets(m.RawReferenceNumber) = c.CatKey
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
    ON cd.CatalogId = m.CatalogId
WHERE m.CatalogId IS NOT NULL
  AND m.RawReferenceNumber IS NOT NULL
ORDER BY m.CatalogId;

------------------------------------------------------------
-- 4. RAW rows of the brand's sources with the same key
------------------------------------------------------------
DROP TABLE IF EXISTS #Raw;
SELECT
      r.Id AS RawCatalogId
    , r.SourceId
    , sm.RawSourceName
    , sm.CatSourceName
    , sm.IsActive
    , sm.CatManufacturerId
    , sm.CatCountryLocationId
    , r.ReferenceNo
    , r.ArtworkId
    , r.IsDeleted
    , r.IsSeenInLastRun
    , r.UpdatedDate
    , dbo.fn_ExtractNumbersAndAlphabets(r.ReferenceNo) AS RawKey
INTO #Raw
FROM dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
INNER JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = r.SourceId
INNER JOIN #Cat AS c
    ON sm.CatManufacturerId = c.ManufacturerId
WHERE dbo.fn_ExtractNumbersAndAlphabets(r.ReferenceNo) = c.CatKey;

------------------------------------------------------------
-- 5. Per RAW row: map / ambiguous state and the first failing check
------------------------------------------------------------
SELECT
      'RawRows' AS Result
    , r.*
    , m.CatalogId AS MapCatalogIdForThisRaw
    , m.CountryId AS MapCountryId
    , m.IsDeleted AS MapIsDeleted
    , m.ResolutionNote AS MapResolutionNote
    , pair.RawCatalogId AS PairAlreadyMappedFromRawId
    , amb.ReasonCode AS AmbiguousReason
    , amb.CandidateCatalogIds AS AmbiguousCandidates
    , CASE
          WHEN c.StatusID <> 1                                                         THEN '1 Catalog StatusID <> 1'
          WHEN ISNULL(c.EntityType, N'') <> N'Watch'                                   THEN '2 Catalog EntityType is not Watch'
          WHEN ISNULL(r.IsActive, 1) = 0                                               THEN '3 Source IsActive = 0'
          WHEN UPPER(ISNULL(r.CatSourceName, N'')) NOT LIKE N'%OFFICIAL%'              THEN '4 CatSourceName not Official'
          WHEN ISNULL(r.IsDeleted, 0) = 1                                              THEN '5 RAW row IsDeleted = 1'
          WHEN m.RawCatalogId IS NOT NULL AND m.CatalogId <> c.CatalogId               THEN '6 RAW row already mapped to another catalog (never re-mapped)'
          WHEN m.RawCatalogId IS NOT NULL AND m.IsDeleted = 1                          THEN '7 RAW row has a deleted map row for this catalog'
          WHEN m.RawCatalogId IS NOT NULL                                              THEN 'OK - mapped'
          WHEN amb.RawCatalogId IS NOT NULL                                            THEN '8 In ambiguous queue'
          WHEN pair.RawCatalogId IS NOT NULL                                           THEN '9 Catalog + country already mapped from another RAW row'
          WHEN sm.CatCountryLocationId IS NULL                                         THEN '10 Source has no country (needs the new map SP)'
          ELSE '11 Should map on the next run - check the deployed SP version / key function'
      END AS FirstFailingCheck
FROM #Raw AS r
CROSS JOIN #Cat AS c
LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = r.SourceId
LEFT JOIN dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
    ON m.RawCatalogId = r.RawCatalogId
LEFT JOIN dbo.tbl_MAP_RawCatalog_CatalogCountry AS pair WITH (NOLOCK)
    ON pair.CatalogId = c.CatalogId
   AND (pair.CountryId = sm.CatCountryLocationId
        OR (pair.CountryId IS NULL AND sm.CatCountryLocationId IS NULL))
   AND pair.IsDeleted = 0
   AND pair.RawCatalogId <> r.RawCatalogId
LEFT JOIN dbo.tbl_MAP_RawCatalog_CatalogCountry_Ambiguous AS amb WITH (NOLOCK)
    ON amb.RawCatalogId = r.RawCatalogId
ORDER BY r.SourceId, r.RawCatalogId;

------------------------------------------------------------
-- 6. Any map rows that point at this catalog
------------------------------------------------------------
SELECT 'MapRowsForCatalog' AS Result, m.*
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
INNER JOIN #Input AS i
    ON i.CatalogId = m.CatalogId;

------------------------------------------------------------
-- 7. All brands: non-active catalogs (StatusID <> 1) that still have retail prices
--    (not limited to #Input). PriceRowsSeenInLastRun > 0 = still refreshed through
--    old map rows, like 226577.
------------------------------------------------------------
SELECT
      'NonActiveCatalogWithRetailPrice' AS Result
    , cd.CatalogId
    , cd.ManufacturerId
    , mf.ManufacturerName
    , cd.ReferenceNumber
    , cd.StatusID                                             AS CatalogStatusID
    , cd.EntityType
    , COUNT(*)                                                AS PriceRows
    , SUM(CASE WHEN rp.StatusID = 1 THEN 1 ELSE 0 END)        AS PriceRowsStatus1
    , SUM(CASE WHEN rp.IsSeenInLastRun = 1 THEN 1 ELSE 0 END) AS PriceRowsSeenInLastRun
    , COUNT(DISTINCT rp.CountryId)                            AS Countries
    , MIN(rp.CreatedAt)                                       AS FirstPriceCreatedAt
    , MAX(rp.CreatedAt)                                       AS LastPriceCreatedAt
    , MAX(rp.PriceLastSeenDate)                               AS LastPriceSeenDate
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
    ON rp.CatalogID = cd.CatalogId
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = cd.ManufacturerId
WHERE cd.StatusID <> 1
GROUP BY
      cd.CatalogId
    , cd.ManufacturerId
    , mf.ManufacturerName
    , cd.ReferenceNumber
    , cd.StatusID
    , cd.EntityType
ORDER BY
      mf.ManufacturerName
    , cd.CatalogId;
