/*
================================================================================
 Reference production status - why do some brands have no map rows?
================================================================================
 Purpose   : For brands that have catalogs but no rows in
             tbl_MAP_RawCatalog_CatalogCountry (e.g. Nomos, Junghans, Ball,
             Glycine), walk each source through the gates that
             sp_map_rawCatalog_catalogCountry uses before it inserts a map row,
             and show the first gate that fails.

             Gates (same order as the map SP):
               1. Source is in tbl_sourceManufacturer_mapping
               2. IsActive = 1
               3. CatSourceName LIKE '%OFFICIAL%'
               4. CatManufacturerId IS NOT NULL
               5. CatCountryLocationId IS NOT NULL
               6. RAW rows exist (IsDeleted = 0)
               7. RAW rows have a ReferenceNo
               8. Reference matches exactly one active Watch catalog of the
                  same manufacturer (catalog fallback; the RawCatalogMapping
                  path of the SP is not repeated here)
               9. Active map rows exist

 Scope     : Every source of a brand with no active map row, plus the
             single-source Reconfigured brands from the Master Collection sheet
             (Others tab + F.P. Journe, Richard Mille, Laurent Ferrier,
             Parmigiani), so sources missing from tbl_sourceManufacturer_mapping
             also show.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.
 No DECLARE variables. Inspect any step with SELECT * FROM #<Step>;
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 1. Sources in scope
------------------------------------------------------------
DROP TABLE IF EXISTS #SheetSource;
SELECT v.SourceId, v.SheetBrand, v.SheetReconfigured
INTO #SheetSource
FROM (VALUES
      (14068, N'Glycine', 1), (14070, N'Doxa', 1), (14075, N'Ball', 1)
    , (14081, N'Speake-Marin', 1), (14166, N'Urwerk', 1), (14170, N'Armin Strom', 0)
    , (14171, N'Eberhard & Co', 1), (14176, N'Armand Nicolet', 0), (14072, N'MeisterSinger', 0)
    , (14180, N'Romain Jerome', 1), (14181, N'Rotary', 0), (14182, N'Angelus', 0)
    , (14064, N'Bulgari / Roamer', 0), (14184, N'U-Boat', 0), (14185, N'Rado', 0)
    , (14187, N'Junghans', 1), (14189, N'Nomos Glashutte', 1), (14191, N'Eterna', 1)
    , (14192, N'Marvin', 1), (14196, N'Reconvilier', 1), (14197, N'Wittnauer', 0)
    , (14198, N'Hanhart', 0), (14199, N'Roger Dubuis', 1), (14200, N'Andersen Geneve', 0)
    , (17168, N'H. Moser & Cie.', 1)
    , (14224, N'F.P. Journe', 1), (14178, N'Richard Mille', 1)
    , (14076, N'Laurent Ferrier', 1), (15983, N'Parmigiani Fleurier', 1)
) AS v (SourceId, SheetBrand, SheetReconfigured);

DROP TABLE IF EXISTS #MappedBrand;
SELECT DISTINCT cd.ManufacturerId
INTO #MappedBrand
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
    ON cd.CatalogId = m.CatalogId
WHERE ISNULL(m.IsDeleted, 0) = 0;

DROP TABLE IF EXISTS #Src;
SELECT sm.SourceId
INTO #Src
FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
WHERE sm.CatManufacturerId IS NULL
   OR NOT EXISTS (SELECT 1 FROM #MappedBrand AS mb WHERE mb.ManufacturerId = sm.CatManufacturerId)
UNION
SELECT ss.SourceId
FROM #SheetSource AS ss;

CREATE UNIQUE CLUSTERED INDEX CX_Src ON #Src (SourceId);

------------------------------------------------------------
-- 2. RAW rows per source (not deleted) with the match key
------------------------------------------------------------
DROP TABLE IF EXISTS #Raw;
SELECT
      r.Id AS RawCatalogId
    , r.SourceId
    , r.IsSeenInLastRun
    , r.CreatedDate
    , r.UpdatedDate
    , NULLIF(LTRIM(RTRIM(r.ReferenceNo)), N'') AS RefNo
    , EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(ISNULL(r.ReferenceNo, N'')) AS MatchKey
INTO #Raw
FROM dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
INNER JOIN #Src AS s
    ON s.SourceId = r.SourceId
WHERE ISNULL(r.IsDeleted, 0) = 0;

CREATE CLUSTERED INDEX CX_Raw ON #Raw (SourceId);

------------------------------------------------------------
-- 3. Catalog keys of the manufacturers involved (single / ambiguous)
------------------------------------------------------------
DROP TABLE IF EXISTS #CatKey;
SELECT
      cd.ManufacturerId
    , EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(cd.ReferenceNumber) AS RefExt
    , COUNT(DISTINCT cd.CatalogId) AS CatalogCount
INTO #CatKey
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
WHERE cd.StatusID = 1
  AND cd.EntityType = 'Watch'
  AND cd.ManufacturerId IN (
        SELECT sm.CatManufacturerId
        FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
        INNER JOIN #Src AS s
            ON s.SourceId = sm.SourceId
        WHERE sm.CatManufacturerId IS NOT NULL)
GROUP BY
      cd.ManufacturerId
    , EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets(cd.ReferenceNumber);

CREATE CLUSTERED INDEX CX_CatKey ON #CatKey (ManufacturerId, RefExt);

------------------------------------------------------------
-- 4. Per source: counts at each gate
------------------------------------------------------------
DROP TABLE IF EXISTS #RawAgg;
SELECT
      r.SourceId
    , COUNT(*) AS RawRows
    , SUM(CASE WHEN ISNULL(r.IsSeenInLastRun, 0) = 1 THEN 1 ELSE 0 END) AS RawSeen
    , SUM(CASE WHEN r.RefNo IS NOT NULL THEN 1 ELSE 0 END) AS RawWithRef
    , SUM(CASE WHEN ck.CatalogCount = 1 THEN 1 ELSE 0 END) AS RawMatchOneCatalog
    , SUM(CASE WHEN ck.CatalogCount > 1 THEN 1 ELSE 0 END) AS RawMatchManyCatalogs
    , MIN(r.CreatedDate) AS RawFirstCreated
    , MAX(COALESCE(r.UpdatedDate, r.CreatedDate)) AS RawLastUpdated
INTO #RawAgg
FROM #Raw AS r
LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = r.SourceId
LEFT JOIN #CatKey AS ck
    ON ck.ManufacturerId = sm.CatManufacturerId
   AND ck.RefExt = r.MatchKey
   AND r.RefNo IS NOT NULL
GROUP BY r.SourceId;

DROP TABLE IF EXISTS #MapAgg;
SELECT
      r.SourceId
    , SUM(CASE WHEN ISNULL(m.IsDeleted, 0) = 0 THEN 1 ELSE 0 END) AS MapActive
    , SUM(CASE WHEN ISNULL(m.IsDeleted, 0) = 1 THEN 1 ELSE 0 END) AS MapDeleted
INTO #MapAgg
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
    ON r.Id = m.RawCatalogId
INNER JOIN #Src AS s
    ON s.SourceId = r.SourceId
GROUP BY r.SourceId;

DROP TABLE IF EXISTS #AmbAgg;
SELECT r.SourceId, COUNT(*) AS AmbiguousRows
INTO #AmbAgg
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry_Ambiguous AS a WITH (NOLOCK)
INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
    ON r.Id = a.RawCatalogId
INNER JOIN #Src AS s
    ON s.SourceId = r.SourceId
GROUP BY r.SourceId;

DROP TABLE IF EXISTS #BrandCat;
SELECT cd.ManufacturerId, COUNT(*) AS BrandCatalogs
INTO #BrandCat
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
WHERE cd.StatusID = 1
GROUP BY cd.ManufacturerId;

------------------------------------------------------------
-- 5. Result: one row per source, first failing gate
------------------------------------------------------------
SELECT
      s.SourceId
    , ss.SheetBrand
    , ss.SheetReconfigured
    , sm.RawSourceName
    , sm.CatManufacturerId
    , sm.CatManufacturerName
    , mf.ManufacturerName AS CatalogManufacturerName
    , sm.CatSourceName
    , sm.IsActive
    , sm.CatCountryLocationId
    , sm.CatCountryLocation
    , ISNULL(bc.BrandCatalogs, 0) AS BrandCatalogs
    , ISNULL(ra.RawRows, 0) AS RawRows
    , ISNULL(ra.RawSeen, 0) AS RawSeen
    , ISNULL(ra.RawWithRef, 0) AS RawWithRef
    , ISNULL(ra.RawMatchOneCatalog, 0) AS RawMatchOneCatalog
    , ISNULL(ra.RawMatchManyCatalogs, 0) AS RawMatchManyCatalogs
    , ISNULL(aa.AmbiguousRows, 0) AS AmbiguousQueueRows
    , ISNULL(ma.MapActive, 0) AS MapActive
    , ISNULL(ma.MapDeleted, 0) AS MapDeleted
    , ra.RawFirstCreated
    , ra.RawLastUpdated
    , CASE
          WHEN sm.SourceId IS NULL                                                   THEN N'1 Not in tbl_sourceManufacturer_mapping'
          WHEN ISNULL(sm.IsActive, 1) = 0                                            THEN N'2 Source IsActive = 0'
          WHEN UPPER(ISNULL(sm.CatSourceName, N'')) NOT LIKE N'%OFFICIAL%'           THEN N'3 CatSourceName not Official'
          WHEN sm.CatManufacturerId IS NULL                                          THEN N'4 CatManufacturerId missing'
          WHEN sm.CatCountryLocationId IS NULL                                       THEN N'5 CatCountryLocationId missing'
          WHEN ISNULL(ra.RawRows, 0) = 0                                             THEN N'6 No RAW rows'
          WHEN ISNULL(ra.RawWithRef, 0) = 0                                          THEN N'7 RAW rows have no ReferenceNo'
          WHEN ISNULL(ra.RawMatchOneCatalog, 0) = 0 AND ISNULL(ma.MapActive, 0) = 0  THEN N'8 No reference matches a catalog'
          WHEN ISNULL(ma.MapActive, 0) = 0                                           THEN N'9 Matches exist but no map rows (map SP not run / other)'
          ELSE N'OK - mapped'
      END AS FirstFailingGate
FROM #Src AS s
LEFT JOIN #SheetSource AS ss
    ON ss.SourceId = s.SourceId
LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = s.SourceId
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = sm.CatManufacturerId
LEFT JOIN #BrandCat AS bc
    ON bc.ManufacturerId = sm.CatManufacturerId
LEFT JOIN #RawAgg AS ra
    ON ra.SourceId = s.SourceId
LEFT JOIN #MapAgg AS ma
    ON ma.SourceId = s.SourceId
LEFT JOIN #AmbAgg AS aa
    ON aa.SourceId = s.SourceId
ORDER BY
      CASE WHEN ss.SourceId IS NULL THEN 1 ELSE 0 END
    , ss.SheetReconfigured DESC
    , ISNULL(bc.BrandCatalogs, 0) DESC
    , s.SourceId;


Select EWMaster.dbo.fn_extractnumberandalphbet