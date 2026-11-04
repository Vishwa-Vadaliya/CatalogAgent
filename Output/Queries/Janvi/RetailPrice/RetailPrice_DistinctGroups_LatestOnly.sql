/*
================================================================================
 Retail price (catalog side) - distinct groups, LATEST row per catalog + country
================================================================================
 Purpose   : Same flag groups as RetailPrice_DistinctGroups_Simple.sql, but only
             ONE row per catalog + country pair is counted: the latest active
             row. Shows which flag combinations the latest price of each pair
             sits in today.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.

 Definitions:
   Pair        = (CatalogID, CountryId); a NULL CountryId is its own "no country" pair
   Latest row  = among the pair's rows with StatusID = 1, the row with the highest
                 CreatedAt (ties broken by the highest CatalogRetailPriceID)
   HasPLS      = PriceLastSeenDate IS NOT NULL
   Reference production status = tbl_CAT_Catalog_d.RefProductionStatusID ->
     tbl_CAT_Reference_ProductionStatus_d (1 In Production, 2 Out of Production,
     3 Phasing Out, NULL = no status)
   Pair has other streams = the pair also has an active row in a different
                 (IsPrivate, IsVerified, CurrencyId) stream than its latest row
   Pair has older rows    = the pair has more than one active row in total

 No DECLARE variables. Each step reads only earlier temp tables.
   - Latest row per pair: SELECT * FROM #Latest;
================================================================================
*/

USE [EWMaster];
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 1. Active rows with a rank per catalog + country pair (1 = latest)
--    tbl_CAT_CatalogRetailPrice_d
------------------------------------------------------------
DROP TABLE IF EXISTS #Ranked;
SELECT
    rp.CatalogRetailPriceID,
    rp.CatalogID,
    ISNULL(rp.CountryId, -1)                          AS CountryKey,   -- -1 = no country
    rp.CurrencyId,
    CAST(rp.IsSeenInLastRun AS int)                   AS IsSeenInLastRun,
    CAST(rp.IsVerified AS int)                        AS IsVerified,
    CAST(rp.IsPrivate AS int)                         AS IsPrivate,
    CASE WHEN rp.PriceLastSeenDate IS NOT NULL THEN 1 ELSE 0 END AS HasPLS,
    ROW_NUMBER() OVER (PARTITION BY rp.CatalogID, ISNULL(rp.CountryId, -1)
                       ORDER BY rp.CreatedAt DESC, rp.CatalogRetailPriceID DESC) AS rn,
    COUNT(*)     OVER (PARTITION BY rp.CatalogID, ISNULL(rp.CountryId, -1))       AS RowsInPair
INTO #Ranked
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
WHERE rp.StatusID = 1;

------------------------------------------------------------
-- 2. Latest row per pair, with production status and stream flags
--    + tbl_CAT_Catalog_d + tbl_CAT_Reference_ProductionStatus_d
------------------------------------------------------------
DROP TABLE IF EXISTS #Latest;
SELECT
    r.CatalogRetailPriceID,
    r.CatalogID,
    r.CountryKey,
    cat.RefProductionStatusID,
    ISNULL(ps.Name, 'No status')                      AS RefProductionStatus,
    r.IsSeenInLastRun,
    r.IsVerified,
    r.IsPrivate,
    r.HasPLS,
    r.RowsInPair,
    -- 1 = pair has more than one active row in total (older rows exist)
    CASE WHEN r.RowsInPair > 1 THEN 1 ELSE 0 END      AS HasOlderRows
INTO #Latest
FROM #Ranked AS r
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
       ON cat.CatalogId = r.CatalogID
LEFT JOIN dbo.tbl_CAT_Reference_ProductionStatus_d AS ps WITH (NOLOCK)
       ON ps.RefProductionStatusID = cat.RefProductionStatusID
WHERE r.rn = 1;

CREATE INDEX IX_Latest_Group ON #Latest (RefProductionStatusID, IsSeenInLastRun, IsVerified, IsPrivate, HasPLS) INCLUDE (CatalogID);

------------------------------------------------------------
-- 3. FINAL: one row per distinct combination for the LATEST row of each pair
--    (the only result set). Pairs = latest rows = number of pairs in the group.
------------------------------------------------------------
SELECT
    l.RefProductionStatus,
    l.IsSeenInLastRun,
    l.IsVerified,
    l.IsPrivate,
    l.HasPLS,
    COUNT(*)                                          AS Pairs,
    COUNT(DISTINCT l.CatalogID)                       AS Catalogs,
    SUM(CASE WHEN l.HasOlderRows = 0 THEN 1 ELSE 0 END) AS PairsSingleRow,
    SUM(CASE WHEN l.HasOlderRows = 1 THEN 1 ELSE 0 END) AS PairsWithHistory
FROM #Latest AS l
GROUP BY l.RefProductionStatusID, l.RefProductionStatus, l.IsSeenInLastRun, l.IsVerified, l.IsPrivate, l.HasPLS
ORDER BY l.RefProductionStatusID, l.IsPrivate, l.IsVerified DESC, l.IsSeenInLastRun DESC, l.HasPLS DESC;

------------------------------------------------------------
-- 4. Catalogs with NO reference production status (RefProductionStatusID IS NULL),
--    by manufacturer. Uses the latest row per pair from #Latest.
--    + tbl_CAT_Catalog_d + tbl_CAT_Manufacturer_d
--    Run steps 1-2 first, then this step alone returns the manufacturer list.
------------------------------------------------------------
SELECT
    cat.ManufacturerId,
    ISNULL(m.ManufacturerName, 'No manufacturer')     AS ManufacturerName,
    COUNT(DISTINCT l.CatalogID)                       AS CatalogsNoStatus,
    COUNT(*)                                          AS PairsNoStatus,
    SUM(CASE WHEN l.IsPrivate = 0 AND l.IsVerified = 1 THEN 1 ELSE 0 END) AS PairsPublicVerified,
    SUM(CASE WHEN l.IsPrivate = 0 AND l.IsVerified = 0 THEN 1 ELSE 0 END) AS PairsPublicUnverified,
    SUM(CASE WHEN l.IsPrivate = 1 THEN 1 ELSE 0 END)  AS PairsPrivate
FROM #Latest AS l
INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
        ON cat.CatalogId = l.CatalogID
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS m WITH (NOLOCK)
       ON m.ManufacturerId = cat.ManufacturerId
WHERE l.RefProductionStatusID IS NULL
GROUP BY cat.ManufacturerId, m.ManufacturerName
ORDER BY CatalogsNoStatus DESC, ManufacturerName;

------------------------------------------------------------
-- 5a. Which group to look at (edit the values; default = the No status / public /
--     Seen 1 / verified / has last-seen date group). RefProductionStatus: use the
--     name shown in the summary, e.g. 'No status', 'In Production'.
------------------------------------------------------------
DROP TABLE IF EXISTS #PickGroup;
SELECT
    CAST('No status' AS varchar(50)) AS RefProductionStatus,
    CAST(0 AS int)                   AS IsPrivate,
    CAST(1 AS int)                   AS IsSeenInLastRun,
    CAST(1 AS int)                   AS IsVerified,
    CAST(1 AS int)                   AS HasPLS
INTO #PickGroup;

------------------------------------------------------------
-- 5b. FINAL: catalog, reference number, manufacturer and the latest price row
--     of every pair in the picked group (the only result set of this step).
--     + tbl_CAT_Catalog_d + tbl_CAT_Manufacturer_d + tbl_CAT_Country_d
--     + tbl_CAT_Currency_d + tbl_CAT_CatalogRetailPrice_d
--     Run steps 1-2 and 5a first.
------------------------------------------------------------
SELECT
    l.CatalogID,
    cat.ReferenceNumber,
    cat.ManufacturerId,
    ISNULL(m.ManufacturerName, 'No manufacturer')     AS ManufacturerName,
    l.RefProductionStatus,
    l.CountryKey                                      AS CountryId,
    co.CountryName,
    rp.Price,
    cur.CurrencyCode,
    rp.CreatedAt,
    rp.PriceLastSeenDate,
    l.RowsInPair,
    rp.CatalogRetailPriceID
FROM #Latest AS l
INNER JOIN #PickGroup AS pg
        ON pg.RefProductionStatus = l.RefProductionStatus
       AND pg.IsPrivate           = l.IsPrivate
       AND pg.IsSeenInLastRun     = l.IsSeenInLastRun
       AND pg.IsVerified          = l.IsVerified
       AND pg.HasPLS              = l.HasPLS
INNER JOIN dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
        ON rp.CatalogRetailPriceID = l.CatalogRetailPriceID
INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
        ON cat.CatalogId = l.CatalogID
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS m WITH (NOLOCK)
       ON m.ManufacturerId = cat.ManufacturerId
LEFT JOIN dbo.tbl_CAT_Country_d AS co WITH (NOLOCK)
       ON co.CountryId = rp.CountryId
LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
       ON cur.CurrencyId = rp.CurrencyId
ORDER BY ManufacturerName, cat.ReferenceNumber, co.CountryName;

------------------------------------------------------------
-- 6a. Non-verified active rows where PriceLastSeenDate is later than CreatedAt
--     (independent of steps 1-5; reads the table directly)
--     + tbl_CAT_CatalogRetailPrice_d
--     To include pending / deleted rows, remove the StatusID filter.
------------------------------------------------------------
DROP TABLE IF EXISTS #NonVerSeenAfterCreated;
SELECT
    rp.CatalogRetailPriceID,
    rp.CatalogID,
    rp.CountryId,
    rp.CurrencyId,
    rp.Price,
    rp.IsPrivate,
    rp.IsSeenInLastRun,
    rp.StatusID,
    rp.CreatedAt,
    rp.PriceLastSeenDate,
    DATEDIFF(DAY, rp.CreatedAt, rp.PriceLastSeenDate) AS DaysSeenAfterCreated,
    -- 1 = this is the latest active row of its catalog + country pair
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY rp.CatalogID, ISNULL(rp.CountryId, -1)
                                 ORDER BY rp.CreatedAt DESC, rp.CatalogRetailPriceID DESC) = 1
         THEN 1 ELSE 0 END                            AS IsLatestOfPair
INTO #NonVerSeenAfterCreated
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
WHERE rp.StatusID = 1
  AND rp.IsVerified = 0
  AND rp.PriceLastSeenDate IS NOT NULL
  AND rp.PriceLastSeenDate > rp.CreatedAt;

------------------------------------------------------------
-- 6b. FINAL: the rows with catalog, reference, manufacturer, country, currency
--     and production status (the only result set of this step).
--     + tbl_CAT_Catalog_d + tbl_CAT_Manufacturer_d + tbl_CAT_Country_d
--     + tbl_CAT_Currency_d + tbl_CAT_Reference_ProductionStatus_d
------------------------------------------------------------
SELECT
    n.CatalogRetailPriceID,
    n.CatalogID,
    cat.ReferenceNumber,
    ISNULL(m.ManufacturerName, 'No manufacturer')     AS ManufacturerName,
    ISNULL(ps.Name, 'No status')                      AS RefProductionStatus,
    co.CountryName,
    n.Price,
    cur.CurrencyCode,
    n.IsPrivate,
    n.IsSeenInLastRun,
    n.IsLatestOfPair,
    n.CreatedAt,
    n.PriceLastSeenDate,
    n.DaysSeenAfterCreated
FROM #NonVerSeenAfterCreated AS n
INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
        ON cat.CatalogId = n.CatalogID
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS m WITH (NOLOCK)
       ON m.ManufacturerId = cat.ManufacturerId
LEFT JOIN dbo.tbl_CAT_Reference_ProductionStatus_d AS ps WITH (NOLOCK)
       ON ps.RefProductionStatusID = cat.RefProductionStatusID
LEFT JOIN dbo.tbl_CAT_Country_d AS co WITH (NOLOCK)
       ON co.CountryId = n.CountryId
LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
       ON cur.CurrencyId = n.CurrencyId
ORDER BY n.DaysSeenAfterCreated DESC, ManufacturerName, cat.ReferenceNumber;
