/*
================================================================================
 Retail price (catalog side) - every distinct group of the data
================================================================================
 Purpose   : Show every distinct combination that exists in
             tbl_CAT_CatalogRetailPrice_d, with row / catalog / pair counts, so
             the next team can see "these kinds of data exist".
             Dimensions: reference production status, retail StatusID,
             public / private, verified / unverified, IsSeenInLastRun,
             has PriceLastSeenDate or not, latest or older price, tax flag,
             currency, country present, catalog attributes, MAP state, ...

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.

 Definitions (confirmed in project rules):
   Public verified = IsPrivate = 0 AND IsVerified = 1 AND StatusID = 1
   Retail StatusID : 1 active, 2 outlier / pending review, 3 deleted
   Reference production status (tbl_CAT_Catalog_d.RefProductionStatusID ->
     tbl_CAT_Reference_ProductionStatus_d): 1 In Production, 2 Out of Production,
     3 Phasing Out, NULL = no status
   Stream  = (CatalogID, CountryId, CurrencyId, IsPrivate, IsVerified)
   Latest  = newest StatusID 1 row of a stream (CreatedAt DESC, id DESC);
             rows with StatusID 2 / 3 are labelled "n/a"
   Pair    = (CatalogID, CountryId)

 No DECLARE variables: every step reads only earlier temp tables, so any step can
 be run on its own. Re-running a group step first deletes its own rows from #G.

 How to read:
   - The LAST step returns all groups in one long list (GroupSet, GroupKey, counts).
   - Drill into one set:  SELECT * FROM #G WHERE GroupSet = 'G1' ORDER BY Rows DESC;
   - Row-level data behind every group:  SELECT * FROM #Rows;  (filter by the labels)
   - Catalog-level data:  SELECT * FROM #CatProfile;

 Group sets
   G1  Main combination (every flag together)        rows / catalogs / pairs
   G2  Catalog profile (which price kinds a catalog has) x production status   catalogs
   G3  Catalog consistency on latest public verified (seen / PLS / MAP) x production status   catalogs
   G4  PriceLastSeenDate recency on latest public verified x seen x production status
   G5  Currency x country present x stream x status
   G6  Tax flag x stream x latest
   G7  Catalog attributes (status, entity, discontinued) x retail status
   G8  Retail vs MAP state on latest public verified
   G9  Series length x stream
================================================================================
*/

USE [EWMaster];
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 1. Rank within stream (StatusID 1 only): latest = RnDesc 1, plus stream length
--    tbl_CAT_CatalogRetailPrice_d
------------------------------------------------------------
DROP TABLE IF EXISTS #Rn;
SELECT
    rp.CatalogRetailPriceID,
    ROW_NUMBER() OVER (PARTITION BY rp.CatalogID, rp.CountryId, rp.CurrencyId, rp.IsPrivate, rp.IsVerified
                       ORDER BY rp.CreatedAt DESC, rp.CatalogRetailPriceID DESC) AS RnDesc,
    COUNT(*)     OVER (PARTITION BY rp.CatalogID, rp.CountryId, rp.CurrencyId, rp.IsPrivate, rp.IsVerified) AS RowsInStream
INTO #Rn
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
WHERE rp.StatusID = 1;

CREATE UNIQUE CLUSTERED INDEX IX_Rn_Id ON #Rn (CatalogRetailPriceID);

------------------------------------------------------------
-- 2. Active MAP per pair (one active row per CatalogId + CountryId)
--    tbl_MAP_RawCatalog_CatalogCountry, IsDeleted = 0
------------------------------------------------------------
DROP TABLE IF EXISTS #MapPair;
SELECT
    m.CatalogId,
    m.CountryId,
    COUNT(*)                                               AS ActiveMapRows,
    MAX(CASE WHEN m.IsSeenInLastRun >= 1 THEN 1 ELSE 0 END) AS MapSeen,
    MAX(m.PriceLastSeenDate)                               AS MapPriceLastSeenDate
INTO #MapPair
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
WHERE m.IsDeleted = 0
GROUP BY m.CatalogId, m.CountryId;

CREATE UNIQUE CLUSTERED INDEX IX_MapPair ON #MapPair (CatalogId, CountryId);

------------------------------------------------------------
-- 3. Row-level data with every dimension and its label
--    tbl_CAT_CatalogRetailPrice_d + catalog_d + production status_d + currency_d + #Rn + #MapPair
------------------------------------------------------------
DROP TABLE IF EXISTS #Rows;
SELECT
    rp.CatalogRetailPriceID,
    rp.CatalogID,
    rp.CountryId,
    rp.CurrencyId,
    cur.CurrencyName,
    rp.Price,
    rp.CreatedAt,
    rp.StatusID,
    rp.IsPrivate,
    rp.IsVerified,
    rp.IsSeenInLastRun,
    rp.PriceLastSeenDate,
    rp.IsPriceTaxIncluded,
    cat.StatusID           AS CatalogStatusID,
    cat.EntityType,
    cat.IsDiscontinued,
    cat.DiscontinuedDate,
    cat.RefProductionStatusID,
    ps.Name                AS RefProductionStatusName,
    rn.RnDesc,
    rn.RowsInStream,
    mp.ActiveMapRows,
    mp.MapSeen,
    mp.MapPriceLastSeenDate,
    -- labels
    CASE rp.StatusID WHEN 1 THEN 'S1 active' WHEN 2 THEN 'S2 pending' WHEN 3 THEN 'S3 deleted'
         ELSE CONCAT('S', rp.StatusID, ' other') END                                         AS StatusLbl,
    CONCAT(CASE WHEN rp.IsPrivate = 1 THEN 'Private' ELSE 'Public' END, ' ',
           CASE WHEN rp.IsVerified = 1 THEN 'Verified' ELSE 'Unverified' END)               AS StreamLbl,
    CASE WHEN rp.IsSeenInLastRun = 1 THEN 'Seen=1' ELSE 'Seen=0' END                         AS SeenLbl,
    CASE WHEN rp.PriceLastSeenDate IS NOT NULL THEN 'HasPLS' ELSE 'NoPLS' END                AS PlsLbl,
    CASE WHEN rp.StatusID <> 1 THEN 'Latest n/a'
         WHEN rn.RnDesc = 1 THEN 'Latest' ELSE 'Older' END                                   AS LatestLbl,
    CONCAT(ISNULL(CAST(cat.RefProductionStatusID AS varchar(5)), 'NULL'), ' ',
           ISNULL(ps.Name, 'No status'))                                                     AS RefProdLbl,
    CASE WHEN rp.PriceLastSeenDate IS NULL THEN 'PLS NULL'
         WHEN rp.PriceLastSeenDate > GETDATE() THEN 'PLS future'
         WHEN DATEDIFF(DAY, rp.PriceLastSeenDate, GETDATE()) <= 30  THEN 'PLS 0-30d'
         WHEN DATEDIFF(DAY, rp.PriceLastSeenDate, GETDATE()) <= 90  THEN 'PLS 31-90d'
         WHEN DATEDIFF(DAY, rp.PriceLastSeenDate, GETDATE()) <= 365 THEN 'PLS 91-365d'
         ELSE 'PLS >365d' END                                                                AS PlsBucket,
    CASE WHEN rp.IsPriceTaxIncluded IS NULL THEN 'Tax NULL'
         WHEN rp.IsPriceTaxIncluded = 1 THEN 'Tax incl' ELSE 'Tax excl' END                  AS TaxLbl,
    CASE WHEN rp.CountryId IS NULL THEN 'NoCountry' ELSE 'HasCountry' END                    AS CountryLbl,
    CASE WHEN rp.CountryId IS NULL THEN 'No pair'
         WHEN mp.CatalogId IS NULL THEN 'No active MAP'
         WHEN mp.MapSeen = 1 THEN 'MAP seen' ELSE 'MAP not seen' END                         AS MapState,
    CASE WHEN mp.MapPriceLastSeenDate IS NOT NULL THEN 'MapHasPLS' ELSE 'MapNoPLS' END       AS MapPlsLbl,
    CASE WHEN rp.StatusID <> 1 OR rn.RowsInStream IS NULL THEN 'n/a'
         WHEN rn.RowsInStream = 1  THEN 'len 1'
         WHEN rn.RowsInStream <= 5 THEN 'len 2-5'
         WHEN rn.RowsInStream <= 10 THEN 'len 6-10'
         WHEN rn.RowsInStream <= 20 THEN 'len 11-20'
         ELSE 'len >20' END                                                                  AS LenBucket
INTO #Rows
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
       ON cat.CatalogId = rp.CatalogID
LEFT JOIN dbo.tbl_CAT_Reference_ProductionStatus_d AS ps WITH (NOLOCK)
       ON ps.RefProductionStatusID = cat.RefProductionStatusID
LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
       ON cur.CurrencyId = rp.CurrencyId
LEFT JOIN #Rn AS rn
       ON rn.CatalogRetailPriceID = rp.CatalogRetailPriceID
LEFT JOIN #MapPair AS mp
       ON mp.CatalogId = rp.CatalogID
      AND mp.CountryId = rp.CountryId;

CREATE UNIQUE CLUSTERED INDEX IX_Rows_Id ON #Rows (CatalogRetailPriceID);
CREATE INDEX IX_Rows_Cat ON #Rows (CatalogID);

------------------------------------------------------------
-- 4. Catalog-level profile: which kinds of price each catalog has + latest public verified flags
--    one row per CatalogID found in the retail table
------------------------------------------------------------
DROP TABLE IF EXISTS #CatProfile;
SELECT
    r.CatalogID,
    MAX(r.RefProdLbl)                                                                   AS RefProdLbl,
    MAX(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 THEN 1 ELSE 0 END) AS HasPublicVerified,
    MAX(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 0 THEN 1 ELSE 0 END) AS HasPublicUnverified,
    MAX(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 1 THEN 1 ELSE 0 END)                  AS HasPrivate,
    MAX(CASE WHEN r.StatusID = 2 THEN 1 ELSE 0 END)                                      AS HasPending,
    MAX(CASE WHEN r.StatusID = 3 THEN 1 ELSE 0 END)                                      AS HasDeleted,
    -- latest public verified rows (one per stream)
    COUNT(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1 THEN 1 END) AS LatestPvRows,
    MAX(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
             THEN CAST(r.IsSeenInLastRun AS int) END)                                    AS LatestPvAnySeen,
    MIN(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
             THEN CAST(r.IsSeenInLastRun AS int) END)                                    AS LatestPvAllSeen,
    SUM(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
              AND r.PriceLastSeenDate IS NOT NULL THEN 1 ELSE 0 END)                     AS LatestPvWithPls,
    MAX(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
             THEN r.MapSeen END)                                                         AS LatestPvMapSeenMax,
    SUM(CASE WHEN r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
              AND r.MapState = 'No active MAP' THEN 1 ELSE 0 END)                        AS LatestPvNoMap
INTO #CatProfile
FROM #Rows AS r
GROUP BY r.CatalogID;

CREATE UNIQUE CLUSTERED INDEX IX_CatProfile ON #CatProfile (CatalogID);

------------------------------------------------------------
-- 5. Group results go here (long format, one INSERT per group set)
------------------------------------------------------------
DROP TABLE IF EXISTS #G;
CREATE TABLE #G (
    GroupSet  varchar(4)     NOT NULL,
    GroupKey  nvarchar(400)  NOT NULL,
    Rows      int            NOT NULL,
    Catalogs  int            NOT NULL,
    Pairs     int            NULL
);

------------------------------------------------------------
-- G1 Main combination: status | stream | seen | PLS | latest | production status
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G1';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G1',
       CONCAT(r.StatusLbl, ' | ', r.StreamLbl, ' | ', r.SeenLbl, ' | ', r.PlsLbl, ' | ', r.LatestLbl, ' | ', r.RefProdLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
GROUP BY r.StatusLbl, r.StreamLbl, r.SeenLbl, r.PlsLbl, r.LatestLbl, r.RefProdLbl;

------------------------------------------------------------
-- G2 Catalog profile: which price kinds a catalog has | production status  (counts = catalogs)
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G2';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G2',
       CONCAT(CASE WHEN c.HasPublicVerified = 1 THEN 'PubVerified ' ELSE '' END,
              CASE WHEN c.HasPublicUnverified = 1 THEN 'PubUnverified ' ELSE '' END,
              CASE WHEN c.HasPrivate = 1 THEN 'Private ' ELSE '' END,
              CASE WHEN c.HasPending = 1 THEN '+Pending ' ELSE '' END,
              CASE WHEN c.HasDeleted = 1 THEN '+Deleted ' ELSE '' END,
              CASE WHEN c.HasPublicVerified + c.HasPublicUnverified + c.HasPrivate = 0 THEN 'No active price ' ELSE '' END,
              '| ', c.RefProdLbl),
       COUNT(*), COUNT(*), NULL
FROM #CatProfile AS c
GROUP BY c.HasPublicVerified, c.HasPublicUnverified, c.HasPrivate, c.HasPending, c.HasDeleted, c.RefProdLbl;

------------------------------------------------------------
-- G3 Catalog consistency on latest public verified rows:
--    production status | any latest seen | latest with PLS | MAP seen | no-MAP pairs  (counts = catalogs)
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G3';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G3',
       CONCAT(c.RefProdLbl, ' | ',
              CASE WHEN c.LatestPvAnySeen IS NULL THEN 'no latest PV row'
                   WHEN c.LatestPvAllSeen = 1 THEN 'all latest seen'
                   WHEN c.LatestPvAnySeen = 1 THEN 'some latest seen'
                   ELSE 'none seen' END, ' | ',
              CASE WHEN c.LatestPvRows = 0 THEN 'PLS n/a'
                   WHEN c.LatestPvWithPls = c.LatestPvRows THEN 'all latest have PLS'
                   WHEN c.LatestPvWithPls = 0 THEN 'no latest has PLS'
                   ELSE 'some latest have PLS' END, ' | ',
              CASE WHEN c.LatestPvMapSeenMax IS NULL THEN 'MAP n/a'
                   WHEN c.LatestPvMapSeenMax = 1 THEN 'a MAP seen' ELSE 'MAP none seen' END, ' | ',
              CASE WHEN c.LatestPvNoMap > 0 THEN 'has no-MAP pair' ELSE 'all pairs mapped' END),
       COUNT(*), COUNT(*), NULL
FROM #CatProfile AS c
WHERE c.HasPublicVerified = 1
GROUP BY c.RefProdLbl, c.LatestPvAnySeen, c.LatestPvAllSeen, c.LatestPvRows, c.LatestPvWithPls, c.LatestPvMapSeenMax, c.LatestPvNoMap;

------------------------------------------------------------
-- G4 PriceLastSeenDate recency on latest public verified rows: bucket | seen | production status
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G4';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G4',
       CONCAT(r.PlsBucket, ' | ', r.SeenLbl, ' | ', r.RefProdLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
WHERE r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
GROUP BY r.PlsBucket, r.SeenLbl, r.RefProdLbl;

------------------------------------------------------------
-- G5 Currency | country present | stream | status
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G5';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G5',
       CONCAT(ISNULL(r.CurrencyName, 'NULL currency'), ' | ', r.CountryLbl, ' | ', r.StreamLbl, ' | ', r.StatusLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
GROUP BY r.CurrencyName, r.CountryLbl, r.StreamLbl, r.StatusLbl;

------------------------------------------------------------
-- G6 Tax flag | stream | latest (StatusID 1 rows)
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G6';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G6',
       CONCAT(r.TaxLbl, ' | ', r.StreamLbl, ' | ', r.LatestLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
WHERE r.StatusID = 1
GROUP BY r.TaxLbl, r.StreamLbl, r.LatestLbl;

------------------------------------------------------------
-- G7 Catalog attributes: catalog StatusID | EntityType | IsDiscontinued | DiscontinuedDate | retail status
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G7';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G7',
       CONCAT('CatalogStatus=', ISNULL(CAST(r.CatalogStatusID AS varchar(5)), 'NULL'),
              ' | Entity=', ISNULL(r.EntityType, 'NULL'),
              ' | IsDiscontinued=', ISNULL(CAST(r.IsDiscontinued AS varchar(1)), 'NULL'),
              ' | ', CASE WHEN r.DiscontinuedDate IS NULL THEN 'no DiscontinuedDate' ELSE 'has DiscontinuedDate' END,
              ' | ', r.StatusLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
GROUP BY r.CatalogStatusID, r.EntityType, r.IsDiscontinued,
         CASE WHEN r.DiscontinuedDate IS NULL THEN 'no DiscontinuedDate' ELSE 'has DiscontinuedDate' END,
         r.StatusLbl;

------------------------------------------------------------
-- G8 Retail vs MAP on latest public verified rows: MAP state | retail seen | retail PLS | MAP PLS
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G8';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G8',
       CONCAT(r.MapState, ' | retail ', r.SeenLbl, ' | retail ', r.PlsLbl, ' | ', r.MapPlsLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
WHERE r.StatusID = 1 AND r.IsPrivate = 0 AND r.IsVerified = 1 AND r.RnDesc = 1
GROUP BY r.MapState, r.SeenLbl, r.PlsLbl, r.MapPlsLbl;

------------------------------------------------------------
-- G9 Series length | stream (StatusID 1 rows)
------------------------------------------------------------
DELETE FROM #G WHERE GroupSet = 'G9';
INSERT INTO #G (GroupSet, GroupKey, Rows, Catalogs, Pairs)
SELECT 'G9',
       CONCAT(r.LenBucket, ' | ', r.StreamLbl),
       COUNT(*),
       COUNT(DISTINCT r.CatalogID),
       COUNT(DISTINCT CONCAT(r.CatalogID, '-', ISNULL(r.CountryId, -1)))
FROM #Rows AS r
WHERE r.StatusID = 1
GROUP BY r.LenBucket, r.StreamLbl;

------------------------------------------------------------
-- 6. FINAL: all groups in one list (the only result set)
--    Filter in the grid by GroupSet, or SELECT * FROM #G WHERE GroupSet = 'G1'
------------------------------------------------------------
SELECT
    g.GroupSet,
    g.GroupKey,
    g.Rows,
    g.Catalogs,
    g.Pairs
FROM #G AS g
ORDER BY g.GroupSet, g.Rows DESC, g.GroupKey;
