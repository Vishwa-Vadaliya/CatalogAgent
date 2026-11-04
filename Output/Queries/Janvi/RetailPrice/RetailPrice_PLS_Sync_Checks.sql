/*
================================================================================
 Retail price - PriceLastSeenDate / IsSeenInLastRun sync checks
================================================================================
 Purpose   : Check that public verified retail rows follow the rules of
             dbo.sp_Sync_PriceLastSeenDate_isSeenInLastRun (new version):
               Older price  -> PriceLastSeenDate = CreatedAt of the next price
               Latest price -> map PriceLastSeenDate (strict copy) when the pair
                               has an active map row; unchanged otherwise
               IsSeenInLastRun (all rows of the pair) -> map flag (active map),
                               0 (only deleted map rows), unchanged (no map)
             Run before the change (expect differences) and after the sync has
             run (expect 0 in checks C1-C4).

 Database  : EWMaster (MasterDB). Steps 1-5 are read-only.
             Step 0 creates a permanent backup table (run once, before the first
             real run of the new sync).

 Definitions:
   Rows   = tbl_CAT_CatalogRetailPrice_d, StatusID = 1, IsPrivate = 0,
            IsVerified = 1, CountryId NOT NULL, catalog StatusID = 1
   Pair   = (CatalogID, CountryId)
   Order  = CreatedAt, then CatalogRetailPriceID; Latest = no next price
   Map    = tbl_MAP_RawCatalog_CatalogCountry; active = IsDeleted = 0

 No DECLARE variables. Each step reads only earlier temp tables.
   - Inspect any step with SELECT * FROM #<Step>;
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 0. ONE-TIME BACKUP before the first real run of the new sync
--    Public verified active rows: flags, date and TransactionId
--    (run once; skip if the table already exists)
------------------------------------------------------------
-- SELECT
--       crp.CatalogRetailPriceID
--     , crp.CatalogID
--     , crp.CountryId
--     , crp.CreatedAt
--     , crp.IsSeenInLastRun
--     , crp.PriceLastSeenDate
--     , crp.TransactionId
--     , GETDATE() AS BackupAt
-- INTO dbo.tbl_CAT_CatalogRetailPrice_d_PLS_BK_28102026
-- FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp WITH (NOLOCK)
-- WHERE crp.StatusID = 1
--   AND crp.IsPrivate = 0
--   AND crp.IsVerified = 1;

------------------------------------------------------------
-- 1. Active map per pair (one active row per pair)
------------------------------------------------------------
DROP TABLE IF EXISTS #MapActive;
SELECT
      map.CatalogId
    , map.CountryId
    , CAST(MAX(CASE WHEN ISNULL(map.IsSeenInLastRun, 0) >= 1 THEN 1 ELSE 0 END) AS tinyint) AS MapIsSeen
    , MAX(CAST(map.PriceLastSeenDate AS datetime2(3))) AS MapPLS
INTO #MapActive
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
WHERE ISNULL(map.IsDeleted, 0) = 0
GROUP BY map.CatalogId, map.CountryId;

CREATE CLUSTERED INDEX CX_MapActive ON #MapActive (CatalogId, CountryId);

------------------------------------------------------------
-- 2. Pairs with only deleted map rows
------------------------------------------------------------
DROP TABLE IF EXISTS #MapDeletedOnly;
SELECT DISTINCT
      map.CatalogId
    , map.CountryId
INTO #MapDeletedOnly
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
WHERE ISNULL(map.IsDeleted, 0) = 1
  AND NOT EXISTS (
        SELECT 1
        FROM #MapActive AS a
        WHERE a.CatalogId = map.CatalogId
          AND a.CountryId = map.CountryId
    );

CREATE CLUSTERED INDEX CX_MapDeletedOnly ON #MapDeletedOnly (CatalogId, CountryId);

------------------------------------------------------------
-- 3. Price chain: public verified rows with next price's CreatedAt
--    and the pair's map state
------------------------------------------------------------
DROP TABLE IF EXISTS #Chain;
SELECT
      crp.CatalogRetailPriceID
    , crp.CatalogID
    , crp.CountryId
    , crp.CurrencyId
    , crp.Price
    , crp.CreatedAt
    , crp.IsSeenInLastRun
    , CAST(crp.PriceLastSeenDate AS datetime2(3)) AS PLS
    , CAST(LEAD(crp.CreatedAt) OVER (
          PARTITION BY crp.CatalogID, crp.CountryId
          ORDER BY crp.CreatedAt ASC, crp.CatalogRetailPriceID ASC
      ) AS datetime2(3)) AS NextCreatedAt
INTO #Chain
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
    ON cd.CatalogId = crp.CatalogID
   AND cd.StatusID = 1
WHERE crp.StatusID = 1
  AND crp.IsPrivate = 0
  AND crp.IsVerified = 1
  AND crp.CountryId IS NOT NULL;

CREATE UNIQUE CLUSTERED INDEX CX_Chain ON #Chain (CatalogRetailPriceID);

DROP TABLE IF EXISTS #ChainState;
SELECT
      c.*
    , CAST(CASE WHEN c.NextCreatedAt IS NULL THEN 'Latest' ELSE 'Older' END AS varchar(10)) AS RowRole
    , CAST(CASE
          WHEN a.CatalogId IS NOT NULL THEN 'Active'
          WHEN d.CatalogId IS NOT NULL THEN 'DeletedOnly'
          ELSE 'None'
      END AS varchar(15)) AS MapState
    , a.MapIsSeen
    , a.MapPLS
INTO #ChainState
FROM #Chain AS c
LEFT JOIN #MapActive AS a
    ON a.CatalogId = c.CatalogID
   AND a.CountryId = c.CountryId
LEFT JOIN #MapDeletedOnly AS d
    ON d.CatalogId = c.CatalogID
   AND d.CountryId = c.CountryId;

CREATE UNIQUE CLUSTERED INDEX CX_ChainState ON #ChainState (CatalogRetailPriceID);

------------------------------------------------------------
-- 4. Rows breaking a rule (one row per rule hit)
--    C1 Older: PLS <> next CreatedAt                      (expect 0)
--    C2 Latest, active map: PLS <> map date (NULL-safe)   (expect 0)
--    C3 Active map: IsSeenInLastRun <> map flag           (expect 0)
--    C4 Deleted-only map: IsSeenInLastRun <> 0            (expect 0)
--    C5 Latest, Seen = 0, no date                          (info)
--    C6 Latest, active map: map date earlier than CreatedAt (info, UpdateMap rule 3)
------------------------------------------------------------
DROP TABLE IF EXISTS #RuleHits;
SELECT CAST('C1 Older PLS <> next CreatedAt' AS varchar(60)) AS RuleCode, s.*
INTO #RuleHits
FROM #ChainState AS s
WHERE s.RowRole = 'Older'
  AND (s.PLS IS NULL OR s.PLS <> s.NextCreatedAt);

INSERT INTO #RuleHits
SELECT 'C2 Latest PLS <> map date', s.*
FROM #ChainState AS s
WHERE s.RowRole = 'Latest'
  AND s.MapState = 'Active'
  AND (   (s.PLS IS NULL AND s.MapPLS IS NOT NULL)
       OR (s.PLS IS NOT NULL AND s.MapPLS IS NULL)
       OR s.PLS <> s.MapPLS);

INSERT INTO #RuleHits
SELECT 'C3 Seen <> map flag', s.*
FROM #ChainState AS s
WHERE s.MapState = 'Active'
  AND CAST(s.IsSeenInLastRun AS tinyint) <> s.MapIsSeen;

INSERT INTO #RuleHits
SELECT 'C4 Deleted map, Seen <> 0', s.*
FROM #ChainState AS s
WHERE s.MapState = 'DeletedOnly'
  AND s.IsSeenInLastRun <> 0;

INSERT INTO #RuleHits
SELECT 'C5 Latest Seen = 0 without date (info)', s.*
FROM #ChainState AS s
WHERE s.RowRole = 'Latest'
  AND s.IsSeenInLastRun = 0
  AND s.PLS IS NULL;

INSERT INTO #RuleHits
SELECT 'C6 Latest map date < CreatedAt (info)', s.*
FROM #ChainState AS s
WHERE s.RowRole = 'Latest'
  AND s.MapState = 'Active'
  AND s.MapPLS IS NOT NULL
  AND CAST(s.MapPLS AS date) < CAST(s.CreatedAt AS date);

------------------------------------------------------------
-- 5. Summary per rule and map state
--    Detail rows: SELECT * FROM #RuleHits WHERE RuleCode LIKE 'C1%';
------------------------------------------------------------
SELECT
      h.RuleCode
    , h.MapState
    , COUNT(*) AS RowsHit
    , COUNT(DISTINCT CAST(h.CatalogID AS varchar(20)) + '-' + CAST(h.CountryId AS varchar(20))) AS Pairs
FROM #RuleHits AS h
GROUP BY h.RuleCode, h.MapState
ORDER BY h.RuleCode, h.MapState;

------------------------------------------------------------
-- 6. (After the real run) Latest rows of pairs without map must be unchanged
--    vs the backup from step 0                                 (expect 0)
------------------------------------------------------------
-- SELECT s.*, bk.PriceLastSeenDate AS BackupPLS, bk.IsSeenInLastRun AS BackupSeen
-- FROM #ChainState AS s
-- INNER JOIN dbo.tbl_CAT_CatalogRetailPrice_d_PLS_BK_28102026 AS bk WITH (NOLOCK)
--     ON bk.CatalogRetailPriceID = s.CatalogRetailPriceID
-- WHERE s.RowRole = 'Latest'
--   AND s.MapState = 'None'
--   AND (   ISNULL(CAST(bk.PriceLastSeenDate AS datetime2(3)), '00010101') <> ISNULL(s.PLS, '00010101')
--        OR bk.IsSeenInLastRun <> s.IsSeenInLastRun);
