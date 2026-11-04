/*
================================================================================
 Retail price (catalog side) - simple distinct groups
================================================================================
 Purpose   : For tbl_CAT_CatalogRetailPrice_d rows with StatusID = 1, count every
             distinct combination of:
               reference production status | IsSeenInLastRun | IsVerified |
               IsPrivate | has PriceLastSeenDate (0/1)
             with number of ROWS, CATALOGS and CATALOG+COUNTRY PAIRS, and how many
             pairs have HISTORY (more than one row) versus only a SINGLE (latest) row.
             History is checked per catalog + country pair, not per catalog.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.

 Definitions:
   Reference production status = tbl_CAT_Catalog_d.RefProductionStatusID ->
     tbl_CAT_Reference_ProductionStatus_d  (1 In Production, 2 Out of Production,
     3 Phasing Out, NULL = no status)
   HasPLS = PriceLastSeenDate IS NOT NULL
   Pair        = (CatalogID, CountryId); a NULL CountryId is its own "no country" pair
   Single row  = the pair has exactly 1 row in that group  (only the latest price)
   Has history = the pair has 2 or more rows in that group
   (to include pending / deleted rows, change the StatusID filter in step 1)

 No DECLARE variables. Each step reads only earlier temp tables.
   - Row-level data:        SELECT * FROM #Rows;
   - Pair per group:        SELECT * FROM #PairInGroup;
   - Pair over whole table: SELECT * FROM #PairOverall;
================================================================================
*/

USE [EWMaster];
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 1. Rows with the five flags (StatusID = 1 only)
--    tbl_CAT_CatalogRetailPrice_d + tbl_CAT_Catalog_d + tbl_CAT_Reference_ProductionStatus_d
------------------------------------------------------------
DROP TABLE IF EXISTS #Rows;
SELECT
    rp.CatalogRetailPriceID,
    rp.CatalogID,
    ISNULL(rp.CountryId, -1)                          AS CountryKey,   -- -1 = no country
    cat.RefProductionStatusID,
    ISNULL(ps.Name, 'No status')                      AS RefProductionStatus,
    CAST(rp.IsSeenInLastRun AS int)                   AS IsSeenInLastRun,
    CAST(rp.IsVerified AS int)                        AS IsVerified,
    CAST(rp.IsPrivate AS int)                         AS IsPrivate,
    CASE WHEN rp.PriceLastSeenDate IS NOT NULL THEN 1 ELSE 0 END AS HasPLS
INTO #Rows
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
       ON cat.CatalogId = rp.CatalogID
LEFT JOIN dbo.tbl_CAT_Reference_ProductionStatus_d AS ps WITH (NOLOCK)
       ON ps.RefProductionStatusID = cat.RefProductionStatusID
WHERE rp.StatusID = 1;

CREATE INDEX IX_Rows_Group ON #Rows (RefProductionStatusID, IsSeenInLastRun, IsVerified, IsPrivate, HasPLS) INCLUDE (CatalogID, CountryKey);

------------------------------------------------------------
-- 2. Rows per catalog + country pair inside each group
--    (a pair with 1 row = single latest row, 2+ rows = has history)
------------------------------------------------------------
DROP TABLE IF EXISTS #PairInGroup;
SELECT
    r.RefProductionStatusID,
    r.RefProductionStatus,
    r.IsSeenInLastRun,
    r.IsVerified,
    r.IsPrivate,
    r.HasPLS,
    r.CatalogID,
    r.CountryKey,
    COUNT(*) AS RowsOfPair
INTO #PairInGroup
FROM #Rows AS r
GROUP BY r.RefProductionStatusID, r.RefProductionStatus, r.IsSeenInLastRun, r.IsVerified, r.IsPrivate, r.HasPLS, r.CatalogID, r.CountryKey;

CREATE INDEX IX_PairInGroup ON #PairInGroup (RefProductionStatusID, IsSeenInLastRun, IsVerified, IsPrivate, HasPLS);

------------------------------------------------------------
-- 3. Rows per catalog + country pair over the whole table (all groups together)
--    shows how many pairs have history overall vs one single row
------------------------------------------------------------
DROP TABLE IF EXISTS #PairOverall;
SELECT
    r.CatalogID,
    r.CountryKey,
    MAX(r.RefProductionStatus) AS RefProductionStatus,
    COUNT(*)                   AS TotalRows
INTO #PairOverall
FROM #Rows AS r
GROUP BY r.CatalogID, r.CountryKey;

------------------------------------------------------------
-- 4. FINAL: one row per distinct combination (the only result set)
--    Rows, Catalogs, Pairs, PairsSingleRow, PairsWithHistory
------------------------------------------------------------
SELECT
    g.RefProductionStatus,
    g.IsSeenInLastRun,
    g.IsVerified,
    g.IsPrivate,
    g.HasPLS,
    SUM(g.RowsOfPair)                                        AS Rows,
    COUNT(DISTINCT g.CatalogID)                              AS Catalogs,
    COUNT(*)                                                 AS Pairs,
    SUM(CASE WHEN g.RowsOfPair = 1 THEN 1 ELSE 0 END)        AS PairsSingleRow,
    SUM(CASE WHEN g.RowsOfPair > 1 THEN 1 ELSE 0 END)        AS PairsWithHistory
FROM #PairInGroup AS g
GROUP BY g.RefProductionStatusID, g.RefProductionStatus, g.IsSeenInLastRun, g.IsVerified, g.IsPrivate, g.HasPLS
ORDER BY g.RefProductionStatusID, g.IsPrivate, g.IsVerified DESC, g.IsSeenInLastRun DESC, g.HasPLS DESC;
