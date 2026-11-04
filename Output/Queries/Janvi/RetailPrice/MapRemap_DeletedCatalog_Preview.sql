/*
================================================================================
 Map table - preview of the "remap from draft / deleted catalog" step
================================================================================
 Purpose   : Shows what the new remap step in sp_map_rawCatalog_catalogCountry
             will do, before deploying it. Same logic as the SP:
               - active map rows (IsDeleted = 0) whose catalog has StatusID 2
                 (draft) or 3 (deleted); StatusID 2 because a reference is
                 sometimes re-created as a new active catalog instead of the
                 draft being activated (e.g. new active AP 230637, 230639,
                 230964 whose map rows sit on a draft catalog)
               - matched to active watch catalogs (StatusID = 1, EntityType
                 'Watch') of the same brand with the same
                 dbo.fn_ExtractNumbersAndAlphabets(ReferenceNumber) key
             Outcome per map row:
               Move       1 match, new (CatalogId, CountryId) free -> CatalogId updated
               PairTaken  1 match, but the new pair already has an active map
                          row, or another row wins the same new pair -> left as is
               Ambiguous  more than 1 match -> ambiguous queue
               NoMatch    no active catalog with the same key -> left as is
               BlankKey   deleted catalog has no reference key -> left as is

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 1. Active map rows on deleted catalogs
------------------------------------------------------------
DROP TABLE IF EXISTS #RemapSource;
SELECT
      m.RawCatalogId
    , m.CatalogId AS OldCatalogId
    , oc.StatusID AS OldStatusID
    , m.CountryId
    , m.IsSeenInLastRun
    , oc.ManufacturerId
    , oc.ReferenceNumber AS OldReferenceNumber
    , dbo.fn_ExtractNumbersAndAlphabets(oc.ReferenceNumber) AS RefKey
    , r.UpdatedDate
INTO #RemapSource
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_Catalog_d AS oc WITH (NOLOCK)
    ON oc.CatalogId = m.CatalogId
INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
    ON r.Id = m.RawCatalogId
WHERE ISNULL(m.IsDeleted, 0) = 0
  AND oc.StatusID IN (2, 3);

------------------------------------------------------------
-- 2. Active watch catalog keys of those brands
------------------------------------------------------------
DROP TABLE IF EXISTS #RemapActiveKey;
SELECT
      cd.CatalogId
    , cd.ManufacturerId
    , cd.ReferenceNumber
    , dbo.fn_ExtractNumbersAndAlphabets(cd.ReferenceNumber) AS RefKey
INTO #RemapActiveKey
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
WHERE cd.StatusID = 1
  AND cd.EntityType = 'Watch'
  AND cd.ManufacturerId IN (SELECT s.ManufacturerId FROM #RemapSource AS s);

------------------------------------------------------------
-- 3. Matches per map row
------------------------------------------------------------
DROP TABLE IF EXISTS #RemapMatch;
SELECT
      s.RawCatalogId
    , s.OldCatalogId
    , s.CountryId
    , s.UpdatedDate
    , ak.CatalogId AS NewCatalogId
    , COUNT(*) OVER (PARTITION BY s.RawCatalogId) AS MatchCount
INTO #RemapMatch
FROM #RemapSource AS s
INNER JOIN #RemapActiveKey AS ak
    ON ak.ManufacturerId = s.ManufacturerId
   AND ak.RefKey = s.RefKey
WHERE ISNULL(s.RefKey, '') <> '';

------------------------------------------------------------
-- 4. Rows that will move (same rule as #RemapBest in the SP)
------------------------------------------------------------
DROP TABLE IF EXISTS #RemapBest;
SELECT
      rk.RawCatalogId
    , rk.NewCatalogId
INTO #RemapBest
FROM (
    SELECT
          x.RawCatalogId
        , x.NewCatalogId
        , ROW_NUMBER() OVER (
              PARTITION BY x.NewCatalogId, x.CountryId
              ORDER BY x.UpdatedDate DESC, x.RawCatalogId DESC
          ) AS rn
    FROM #RemapMatch AS x
    WHERE x.MatchCount = 1
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS ex WITH (NOLOCK)
            WHERE ex.CatalogId = x.NewCatalogId
              AND (ex.CountryId = x.CountryId
                   OR (ex.CountryId IS NULL AND x.CountryId IS NULL))
              AND ISNULL(ex.IsDeleted, 0) = 0
        )
) AS rk
WHERE rk.rn = 1;

------------------------------------------------------------
-- 5. Detail: one row per map row
------------------------------------------------------------
DROP TABLE IF EXISTS #RemapPreview;
SELECT
      s.RawCatalogId
    , s.ManufacturerId
    , mf.ManufacturerName
    , s.CountryId
    , s.IsSeenInLastRun
    , s.OldCatalogId
    , s.OldStatusID
    , s.OldReferenceNumber
    , s.RefKey
    , mc.MatchCount
    , mc.Candidates
    , b.NewCatalogId
    , CASE
          WHEN ISNULL(s.RefKey, '') = ''  THEN 'BlankKey'
          WHEN mc.MatchCount IS NULL      THEN 'NoMatch'
          WHEN mc.MatchCount > 1          THEN 'Ambiguous'
          WHEN b.RawCatalogId IS NOT NULL THEN 'Move'
          ELSE 'PairTaken'
      END AS Outcome
INTO #RemapPreview
FROM #RemapSource AS s
LEFT JOIN (
    SELECT
          x.RawCatalogId
        , MAX(x.MatchCount) AS MatchCount
        , STRING_AGG(CAST(x.NewCatalogId AS varchar(11)), ',') WITHIN GROUP (ORDER BY x.NewCatalogId) AS Candidates
    FROM #RemapMatch AS x
    GROUP BY x.RawCatalogId
) AS mc
    ON mc.RawCatalogId = s.RawCatalogId
LEFT JOIN #RemapBest AS b
    ON b.RawCatalogId = s.RawCatalogId
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = s.ManufacturerId;

SELECT 'Detail' AS Result, p.*
FROM #RemapPreview AS p
ORDER BY p.ManufacturerName, p.Outcome, p.OldCatalogId, p.RawCatalogId;

------------------------------------------------------------
-- 6. Summary per brand and outcome
------------------------------------------------------------
SELECT
      'Summary' AS Result
    , p.ManufacturerName
    , p.Outcome
    , COUNT(*) AS MapRows
    , COUNT(DISTINCT p.OldCatalogId) AS OldCatalogs
    , COUNT(DISTINCT p.NewCatalogId) AS NewCatalogs
FROM #RemapPreview AS p
GROUP BY p.ManufacturerName, p.Outcome
ORDER BY p.ManufacturerName, p.Outcome;
