/*
================================================================================
 Retail price (catalog side) - edge-case inventory
================================================================================
 Purpose   : Find every kind of unusual / edge-case row around
             tbl_CAT_CatalogRetailPrice_d (draft) and its neighbours, grouped by
             category, so the next team knows "we have data like this".
             The REASON for each category is left blank on purpose (last column
             of the final result) - fill it in after review.

 Database  : EWMaster (MasterDB)
 Read-only : SELECT / temp tables only. Nothing is modified.

 Definitions used (confirmed in project rules):
   Public verified price = IsPrivate = 0 AND IsVerified = 1 AND StatusID = 1
   StatusID  : 1 active, 2 outlier / pending review, 3 deleted
   Stream    : (CatalogID, CountryId, CurrencyId, IsPrivate, IsVerified)
   Pair      : (CatalogID, CountryId)  - one active MAP row per pair
   Latest    : newest by CreatedAt DESC, CatalogRetailPriceID DESC within a stream

 How to use:
   1. Run the whole script. Only the LAST step returns a result set (summary).
   2. Look at the rows of one category:
        SELECT * FROM #Edge WHERE EdgeCode = 'E21' ORDER BY CatalogID, CreatedAt;
   3. Group-level categories (E18, E19, E31, E34, E45, E42) have
      CatalogRetailPriceID = NULL and the explanation in Detail.

 Tunable thresholds are in the #Params temp table (step 0a). No DECLARE variables
 are used, so every step can be run on its own after the earlier temp tables exist.
================================================================================
*/

USE [EWMaster];
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 0a. Thresholds (temp table, not variables, so any step can be run on its own)
--     JumpPct        : outlier rule used by sp_update_CatalogRetailPrice_FromMapping
--     PendingAgeDays : StatusID 2 older than this is "stale pending"
--     ChurnRows      : a stream with more rows than this = price churn
--     MismatchAbs    : RAW vs retail price difference (same currency) treated as a change
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT CAST(50.0 AS float) AS JumpPct,
       90                  AS PendingAgeDays,
       20                  AS ChurnRows,
       CAST(1.0 AS float)  AS MismatchAbs
INTO #Params;

------------------------------------------------------------
-- 0. Edge-case catalogue (code, group, name, what it means)
--    The Reason column is for the user to fill in later.
------------------------------------------------------------
DROP TABLE IF EXISTS #EdgeMeta;
CREATE TABLE #EdgeMeta (
    EdgeCode   varchar(4)     NOT NULL PRIMARY KEY,
    GroupName  varchar(40)    NOT NULL,
    EdgeName   varchar(120)   NOT NULL,
    WhatItIs   nvarchar(300)  NOT NULL
);
INSERT INTO #EdgeMeta (EdgeCode, GroupName, EdgeName, WhatItIs) VALUES
('E01','A Structure','Price is zero or negative','Price <= 0 in the draft table'),
('E02','A Structure','CountryId is NULL','Price without a country (cannot map to a catalog + country pair)'),
('E03','A Structure','Active price on a non-active catalog','Price StatusID 1 but tbl_CAT_Catalog_d.StatusID <> 1'),
('E04','A Structure','Currency inactive or not StatusID 1','Price uses a currency that is inactive / not active in tbl_CAT_Currency_d'),
('E05','A Structure','Currency differs from the country currency','Currency code differs from the country''s own currency (informational, can be legitimate)'),
('E06','A Structure','Catalog is not a Watch entity','Price on a catalog whose EntityType is not Watch (for example partial reference)'),
('E07','B Status','Pending (StatusID 2) rows with age','Rows waiting for review; Detail shows how many days old'),
('E08','B Status','Pending row not an outlier by the 50% rule','StatusID 2 but jump vs previous active price is <= threshold or there is no previous price'),
('E09','C Draft vs published','Deleted in draft but still live','Draft StatusID 3 and a published row with the same id still exists'),
('E10','C Draft vs published','Active in draft, not published','Draft StatusID 1 and no published row with the same id'),
('E11','C Draft vs published','Pending in draft but live','Draft StatusID 2 and a published row exists (publish never updates or deletes it)'),
('E12','C Draft vs published','Published row with no draft row','Orphan in tbl_CAT_CatalogRetailPrice'),
('E13','C Draft vs published','Draft and published values differ','Both StatusID 1 but a column differs; Detail lists which'),
('E14','D History shape','Same-day duplicates (StatusID 1)','More than one active row for the same catalog, country, currency and calendar day'),
('E15','D History shape','Same price repeated on a later day','Active row with the same price as the previous row in its stream'),
('E16','D History shape','Same day, different status','Same catalog, country, currency and day with both StatusID 1 and 2'),
('E17','D History shape','Back-dated insert','Row inserted later (higher id) but dated earlier than the previous row of its stream'),
('E18','D History shape','Several currencies for one catalog + country','Public verified prices in more than one currency for the same pair'),
('E19','D History shape','Verified and unverified in the same series','Same catalog, country, currency has both IsVerified 1 and 0 public rows'),
('E21','E Outliers','Active price jumps more than the threshold','StatusID 1 but price differs from the previous row by more than JumpPct (#Params)'),
('E23','E Outliers','Magnitude error (x10 / x100 / x1000)','Price is about 10, 100 or 1000 times (or 1/10 ...) the previous price'),
('E24','E Outliers','Spike that returns','Price jumps away and the next price is back to the earlier value'),
('E25','F Dates','CreatedAt in the future','CreatedAt later than now'),
('E26','F Dates','CreatedAt before year 2000','Implausibly old effective date'),
('E27','F Dates','PriceLastSeenDate in the future','Last-seen date later than now'),
('E28','F Dates','CreatedAt is after PriceLastSeenDate','Price starts after the date it was last seen (date compare)'),
('E29','F Dates','PriceLastSeenDate is NULL on public verified','No last-seen date; Detail shows the IsSeenInLastRun value'),
('E30','F Dates','IsSeenInLastRun = 1 but PriceLastSeenDate not NULL on latest','Latest public verified row is listed and has a last-seen date'),
('E31','F Dates','Same PriceLastSeenDate on several prices','Several active rows of one pair share one last-seen date'),
('E32','G Flags','IsSeenInLastRun = 1 on an older (not latest) price','Flag set on history rows, not only the latest'),
('E33','G Flags','IsSeenInLastRun differs from MAP','Latest public verified row flag differs from the active MAP row'),
('E34','G Flags','Flag combinations (StatusID / IsPrivate / IsVerified)','Count per combination, to see which streams exist'),
('E35','G Flags','Tax flag differs from MAP','Latest public verified row IsPriceTaxIncluded NULL or different from MAP'),
('E36','G Flags','TransactionId is NULL','Draft row without a transaction stamp'),
('E38','H Mapping','Public verified price with no active MAP row','Price for a pair that no active RAW listing is mapped to'),
('E39','H Mapping','Mapped, seen, priced listing with no retail price','Active MAP, RAW seen with Price > 0, but no public verified row for the pair'),
('E40','H Mapping','RAW price differs from latest retail price','Listing seen with a price different from the latest public verified price (same currency)'),
('E42','I Job log','SyncLog runs with 0 rows or not Success','Watermark runs that inserted nothing or failed (including the Dummy seed)'),
('E45','J Churn','Very long price series','A stream with more rows than ChurnRows (#Params)');

------------------------------------------------------------
-- 1. Base: every draft retail row with currency, country and catalog attributes
--    tbl_CAT_CatalogRetailPrice_d + currency_d + country_d + catalog_d (LEFT JOINs)
------------------------------------------------------------
DROP TABLE IF EXISTS #Base;
SELECT
    rp.CatalogRetailPriceID,
    rp.CatalogID,
    rp.Price,
    rp.CurrencyId,
    cur.CurrencyName,
    cur.CurrencyCode,
    cur.StatusID           AS CurrencyStatusID,
    cur.IsActive           AS CurrencyIsActive,
    rp.CountryId,
    co.CountryName,
    co.currency            AS CountryCurrencyCode,
    rp.CreatedAt,
    CAST(rp.CreatedAt AS date) AS CreatedDate,
    rp.StatusID,
    rp.TransactionId,
    rp.IsPrivate,
    rp.IsVerified,
    rp.IsSeenInLastRun,
    rp.PriceLastSeenDate,
    rp.IsPriceTaxIncluded,
    cat.StatusID           AS CatalogStatusID,
    cat.ReferenceNumber,
    cat.ManufacturerId,
    cat.EntityType
INTO #Base
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
       ON cur.CurrencyId = rp.CurrencyId
LEFT JOIN dbo.tbl_CAT_Country_d AS co WITH (NOLOCK)
       ON co.CountryId = rp.CountryId
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
       ON cat.CatalogId = rp.CatalogID;

CREATE UNIQUE CLUSTERED INDEX IX_Base_Id ON #Base (CatalogRetailPriceID);
CREATE INDEX IX_Base_Stream ON #Base (CatalogID, CurrencyId, StatusID) INCLUDE (CountryId, IsPrivate, IsVerified, CreatedAt, Price);

------------------------------------------------------------
-- 2. Published table (id and values) for the draft vs published checks
--    tbl_CAT_CatalogRetailPrice
------------------------------------------------------------
DROP TABLE IF EXISTS #Pub;
SELECT
    p.CatalogRetailPriceID,
    p.CatalogID,
    p.Price,
    p.CurrencyId,
    p.CountryId,
    p.CreatedAt,
    p.TransactionID,
    p.IsPrivate,
    p.IsSeenInLastRun,
    p.PriceLastSeenDate,
    p.IsVerified,
    p.isPriceTaxIncluded AS IsPriceTaxIncluded
INTO #Pub
FROM dbo.tbl_CAT_CatalogRetailPrice AS p WITH (NOLOCK);

CREATE UNIQUE CLUSTERED INDEX IX_Pub_Id ON #Pub (CatalogRetailPriceID);

------------------------------------------------------------
-- 3. Active MAP rows (one per CatalogId + CountryId) joined to their RAW row
--    tbl_MAP_RawCatalog_CatalogCountry (IsDeleted = 0) + tbl_RAW_Catalog
------------------------------------------------------------
DROP TABLE IF EXISTS #MapActive;
SELECT
    m.RawCatalogId,
    m.CatalogId,
    m.CountryId,
    CASE WHEN m.IsSeenInLastRun >= 1 THEN 1 ELSE 0 END AS MapIsSeen,
    m.PriceLastSeenDate     AS MapPriceLastSeenDate,
    m.IsPriceTaxIncluded    AS MapTax,
    rc.Price                AS RawPrice,
    rc.Currency             AS RawCurrency,
    rc.ReferenceNo          AS RawReferenceNo,
    rc.SourceId             AS RawSourceId,
    rc.IsSeenInLastRun      AS RawIsSeenInLastRun,
    rc.IsDeleted            AS RawIsDeleted,
    rc.UpdatedDate          AS RawUpdatedDate
INTO #MapActive
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_RAW_Catalog AS rc WITH (NOLOCK)
        ON rc.Id = m.RawCatalogId
WHERE m.IsDeleted = 0;

CREATE INDEX IX_MapActive_Pair ON #MapActive (CatalogId, CountryId);

------------------------------------------------------------
-- 4. Active-price series with previous / next price per stream
--    Stream = (CatalogID, CountryId, CurrencyId, IsPrivate, IsVerified), StatusID = 1 only
------------------------------------------------------------
DROP TABLE IF EXISTS #Series;
SELECT
    b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.CurrencyName,
    b.Price, b.CreatedAt, b.CreatedDate, b.IsPrivate, b.IsVerified,
    b.IsSeenInLastRun, b.PriceLastSeenDate, b.IsPriceTaxIncluded,
    LAG(b.Price)  OVER (PARTITION BY b.CatalogID, b.CountryId, b.CurrencyId, b.IsPrivate, b.IsVerified
                        ORDER BY b.CreatedAt, b.CatalogRetailPriceID) AS PrevPrice,
    LEAD(b.Price) OVER (PARTITION BY b.CatalogID, b.CountryId, b.CurrencyId, b.IsPrivate, b.IsVerified
                        ORDER BY b.CreatedAt, b.CatalogRetailPriceID) AS NextPrice,
    LAG(b.CreatedAt) OVER (PARTITION BY b.CatalogID, b.CountryId, b.CurrencyId, b.IsPrivate, b.IsVerified
                        ORDER BY b.CatalogRetailPriceID) AS PrevCreatedAtById,
    ROW_NUMBER() OVER (PARTITION BY b.CatalogID, b.CountryId, b.CurrencyId, b.IsPrivate, b.IsVerified
                        ORDER BY b.CreatedAt DESC, b.CatalogRetailPriceID DESC) AS RnDesc,
    COUNT(*) OVER (PARTITION BY b.CatalogID, b.CountryId, b.CurrencyId, b.IsPrivate, b.IsVerified) AS RowsInStream
INTO #Series
FROM #Base AS b
WHERE b.StatusID = 1;

CREATE UNIQUE CLUSTERED INDEX IX_Series_Id ON #Series (CatalogRetailPriceID);

------------------------------------------------------------
-- 5. Series with percentage change vs previous price
------------------------------------------------------------
DROP TABLE IF EXISTS #S2;
SELECT
    s.*,
    CASE WHEN s.PrevPrice > 0
         THEN (CAST(s.Price AS float) - CAST(s.PrevPrice AS float)) / CAST(s.PrevPrice AS float) * 100.0 END AS PctFromPrev,
    CASE WHEN s.PrevPrice > 0 AND s.Price > 0
         THEN CAST(s.Price AS float) / CAST(s.PrevPrice AS float) END AS RatioToPrev
INTO #S2
FROM #Series AS s;

CREATE UNIQUE CLUSTERED INDEX IX_S2_Id ON #S2 (CatalogRetailPriceID);

------------------------------------------------------------
-- 6. Edge-case rows go here (one INSERT per category below)
------------------------------------------------------------
DROP TABLE IF EXISTS #Edge;
CREATE TABLE #Edge (
    EdgeCode             varchar(4)    NOT NULL,
    CatalogRetailPriceID bigint        NULL,
    CatalogID            int           NULL,
    CountryId            bigint        NULL,
    CurrencyId           int           NULL,
    Price                money         NULL,
    CreatedAt            datetime      NULL,
    StatusID             tinyint       NULL,
    IsPrivate            bit           NULL,
    IsVerified           bit           NULL,
    Detail               nvarchar(400) NULL
);

------------------------------------------------------------
-- E01 Price is zero or negative
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E01', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('Price=', b.Price)
FROM #Base AS b
WHERE b.Price <= 0;

------------------------------------------------------------
-- E02 CountryId is NULL (active rows)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E02', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('Currency=', b.CurrencyName)
FROM #Base AS b
WHERE b.CountryId IS NULL
  AND b.StatusID = 1;

------------------------------------------------------------
-- E03 Active price (StatusID 1) on a non-active catalog
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E03', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('CatalogStatusID=', ISNULL(CAST(b.CatalogStatusID AS varchar(5)), 'NULL'), ' Ref=', b.ReferenceNumber)
FROM #Base AS b
WHERE b.StatusID = 1
  AND ISNULL(b.CatalogStatusID, 0) <> 1;

------------------------------------------------------------
-- E04 Currency inactive or not StatusID 1
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E04', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('Currency=', b.CurrencyName, ' CurrencyStatusID=', b.CurrencyStatusID, ' IsActive=', ISNULL(CAST(b.CurrencyIsActive AS varchar(1)), 'NULL'))
FROM #Base AS b
WHERE b.StatusID = 1
  AND (ISNULL(b.CurrencyStatusID, 0) <> 1 OR ISNULL(b.CurrencyIsActive, 1) = 0);

------------------------------------------------------------
-- E05 Currency differs from the country's currency (informational)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E05', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('Country=', b.CountryName, ' CountryCurrency=', b.CountryCurrencyCode, ' PriceCurrency=', b.CurrencyCode)
FROM #Base AS b
WHERE b.StatusID = 1
  AND b.CountryId IS NOT NULL
  AND b.CurrencyCode IS NOT NULL
  AND b.CountryCurrencyCode IS NOT NULL
  AND UPPER(LTRIM(RTRIM(b.CurrencyCode))) <> UPPER(LTRIM(RTRIM(b.CountryCurrencyCode)));

------------------------------------------------------------
-- E06 Catalog is not a Watch entity
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E06', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('EntityType=', ISNULL(b.EntityType, 'NULL'), ' Ref=', b.ReferenceNumber)
FROM #Base AS b
WHERE b.StatusID = 1
  AND ISNULL(b.EntityType, '') <> 'Watch';

------------------------------------------------------------
-- E07 Pending rows (StatusID 2) with age in days
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E07', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('AgeDays=', DATEDIFF(DAY, b.CreatedAt, GETDATE()),
              CASE WHEN DATEDIFF(DAY, b.CreatedAt, GETDATE()) > p.PendingAgeDays THEN ' (stale)' ELSE '' END)
FROM #Base AS b
CROSS JOIN #Params AS p
WHERE b.StatusID = 2;

------------------------------------------------------------
-- E08 Pending rows that are not an outlier by the threshold
--     previous StatusID 1 row in the same stream (OUTER APPLY on the small pending set)
------------------------------------------------------------
DROP TABLE IF EXISTS #Pend;
SELECT
    b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt,
    b.StatusID, b.IsPrivate, b.IsVerified,
    pv.Price AS PrevActivePrice
INTO #Pend
FROM #Base AS b
OUTER APPLY (
    SELECT TOP 1 x.Price
    FROM #Base AS x
    WHERE x.CatalogID  = b.CatalogID
      AND ISNULL(x.CountryId, -1) = ISNULL(b.CountryId, -1)
      AND x.CurrencyId = b.CurrencyId
      AND x.IsPrivate  = b.IsPrivate
      AND x.IsVerified = b.IsVerified
      AND x.StatusID   = 1
      AND x.CreatedAt  < b.CreatedAt
    ORDER BY x.CreatedAt DESC, x.CatalogRetailPriceID DESC
) AS pv
WHERE b.StatusID = 2;

INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E08', p.CatalogRetailPriceID, p.CatalogID, p.CountryId, p.CurrencyId, p.Price, p.CreatedAt, p.StatusID, p.IsPrivate, p.IsVerified,
       CASE WHEN p.PrevActivePrice IS NULL OR p.PrevActivePrice = 0
            THEN 'No previous active price'
            ELSE CONCAT('PrevActive=', p.PrevActivePrice, ' Pct=',
                        CAST(ROUND((CAST(p.Price AS float) - CAST(p.PrevActivePrice AS float)) / CAST(p.PrevActivePrice AS float) * 100.0, 2) AS varchar(20))) END
FROM #Pend AS p
CROSS JOIN #Params AS pr
WHERE p.PrevActivePrice IS NULL
   OR p.PrevActivePrice = 0
   OR ABS((CAST(p.Price AS float) - CAST(p.PrevActivePrice AS float)) / CAST(p.PrevActivePrice AS float) * 100.0) <= pr.JumpPct;

------------------------------------------------------------
-- E09 Deleted in draft (StatusID 3) but still in the published table
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E09', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('DraftTx=', b.TransactionId, ' PubTx=', p.TransactionID)
FROM #Base AS b
INNER JOIN #Pub AS p ON p.CatalogRetailPriceID = b.CatalogRetailPriceID
WHERE b.StatusID = 3;

------------------------------------------------------------
-- E10 Active in draft (StatusID 1) but not in the published table
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E10', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('DraftTx=', b.TransactionId)
FROM #Base AS b
LEFT JOIN #Pub AS p ON p.CatalogRetailPriceID = b.CatalogRetailPriceID
WHERE b.StatusID = 1
  AND p.CatalogRetailPriceID IS NULL;

------------------------------------------------------------
-- E11 Pending in draft (StatusID 2) but present in the published table
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E11', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('DraftPrice=', b.Price, ' PublishedPrice=', p.Price)
FROM #Base AS b
INNER JOIN #Pub AS p ON p.CatalogRetailPriceID = b.CatalogRetailPriceID
WHERE b.StatusID = 2;

------------------------------------------------------------
-- E12 Published row with no draft row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E12', p.CatalogRetailPriceID, p.CatalogID, p.CountryId, p.CurrencyId, p.Price, p.CreatedAt, NULL, p.IsPrivate, p.IsVerified,
       'Exists in tbl_CAT_CatalogRetailPrice only'
FROM #Pub AS p
LEFT JOIN #Base AS b ON b.CatalogRetailPriceID = p.CatalogRetailPriceID
WHERE b.CatalogRetailPriceID IS NULL;

------------------------------------------------------------
-- E13 Draft and published values differ (both StatusID 1); Detail lists which columns
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E13', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT(
         CASE WHEN b.Price <> p.Price THEN 'Price ' ELSE '' END,
         CASE WHEN b.CurrencyId <> p.CurrencyId THEN 'Currency ' ELSE '' END,
         CASE WHEN ISNULL(b.CountryId, -1) <> ISNULL(p.CountryId, -1) THEN 'Country ' ELSE '' END,
         CASE WHEN b.CreatedAt <> p.CreatedAt THEN 'CreatedAt ' ELSE '' END,
         CASE WHEN b.IsPrivate <> p.IsPrivate THEN 'IsPrivate ' ELSE '' END,
         CASE WHEN b.IsVerified <> p.IsVerified THEN 'IsVerified ' ELSE '' END,
         CASE WHEN b.IsSeenInLastRun <> p.IsSeenInLastRun THEN 'IsSeen ' ELSE '' END,
         CASE WHEN ISNULL(b.PriceLastSeenDate, '19000101') <> ISNULL(p.PriceLastSeenDate, '19000101') THEN 'PriceLastSeenDate ' ELSE '' END,
         CASE WHEN ISNULL(CAST(b.IsPriceTaxIncluded AS int), -1) <> ISNULL(CAST(p.IsPriceTaxIncluded AS int), -1) THEN 'Tax ' ELSE '' END,
         CASE WHEN ISNULL(b.TransactionId, 0) > p.TransactionID THEN '[draft Tx newer: waiting for publish] ' ELSE '' END)
FROM #Base AS b
INNER JOIN #Pub AS p ON p.CatalogRetailPriceID = b.CatalogRetailPriceID
WHERE b.StatusID = 1
  AND (   b.Price <> p.Price
       OR b.CurrencyId <> p.CurrencyId
       OR ISNULL(b.CountryId, -1) <> ISNULL(p.CountryId, -1)
       OR b.CreatedAt <> p.CreatedAt
       OR b.IsPrivate <> p.IsPrivate
       OR b.IsVerified <> p.IsVerified
       OR b.IsSeenInLastRun <> p.IsSeenInLastRun
       OR ISNULL(b.PriceLastSeenDate, '19000101') <> ISNULL(p.PriceLastSeenDate, '19000101')
       OR ISNULL(CAST(b.IsPriceTaxIncluded AS int), -1) <> ISNULL(CAST(p.IsPriceTaxIncluded AS int), -1));

------------------------------------------------------------
-- E14 Same-day duplicates (StatusID 1): catalog + country + currency + calendar day
--     all rows of each duplicate group
------------------------------------------------------------
DROP TABLE IF EXISTS #DupDay;
SELECT b.CatalogID, b.CountryId, b.CurrencyId, b.CreatedDate, COUNT(*) AS Cnt
INTO #DupDay
FROM #Base AS b
WHERE b.StatusID = 1
GROUP BY b.CatalogID, b.CountryId, b.CurrencyId, b.CreatedDate
HAVING COUNT(*) > 1;

INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E14', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('RowsThatDay=', d.Cnt)
FROM #Base AS b
INNER JOIN #DupDay AS d
        ON d.CatalogID = b.CatalogID
       AND ISNULL(d.CountryId, -1) = ISNULL(b.CountryId, -1)
       AND d.CurrencyId = b.CurrencyId
       AND d.CreatedDate = b.CreatedDate
WHERE b.StatusID = 1;

------------------------------------------------------------
-- E15 Same price repeated on a later day (active, same stream)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E15', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PrevPrice=', s.PrevPrice)
FROM #S2 AS s
WHERE s.PrevPrice = s.Price;

------------------------------------------------------------
-- E16 Same day, both StatusID 1 and 2 (same catalog + country + currency)
------------------------------------------------------------
DROP TABLE IF EXISTS #MixedStatusDay;
SELECT b.CatalogID, b.CountryId, b.CurrencyId, b.CreatedDate
INTO #MixedStatusDay
FROM #Base AS b
WHERE b.StatusID IN (1, 2)
GROUP BY b.CatalogID, b.CountryId, b.CurrencyId, b.CreatedDate
HAVING MIN(b.StatusID) = 1 AND MAX(b.StatusID) = 2;

INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E16', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       'Status 1 and 2 on the same day'
FROM #Base AS b
INNER JOIN #MixedStatusDay AS d
        ON d.CatalogID = b.CatalogID
       AND ISNULL(d.CountryId, -1) = ISNULL(b.CountryId, -1)
       AND d.CurrencyId = b.CurrencyId
       AND d.CreatedDate = b.CreatedDate
WHERE b.StatusID IN (1, 2);

------------------------------------------------------------
-- E17 Back-dated insert: higher id but CreatedAt earlier than the previous id's row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E17', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PreviousRowDate=', CONVERT(varchar(10), s.PrevCreatedAtById, 120))
FROM #S2 AS s
WHERE s.PrevCreatedAtById IS NOT NULL
  AND s.CreatedAt < s.PrevCreatedAtById;

------------------------------------------------------------
-- E18 Several currencies for one catalog + country (public verified, active)
--     group-level rows
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E18', NULL, b.CatalogID, b.CountryId, NULL, NULL, NULL, 1, 0, 1,
       CONCAT('Currencies=', COUNT(DISTINCT b.CurrencyId), ' (', STRING_AGG(CAST(b.CurrencyName AS nvarchar(20)), ',') WITHIN GROUP (ORDER BY b.CurrencyName), ')')
FROM (SELECT DISTINCT CatalogID, CountryId, CurrencyId, CurrencyName
      FROM #Base WHERE StatusID = 1 AND IsPrivate = 0 AND IsVerified = 1) AS b
GROUP BY b.CatalogID, b.CountryId
HAVING COUNT(DISTINCT b.CurrencyId) > 1;

------------------------------------------------------------
-- E19 Verified and unverified public rows in the same catalog + country + currency
--     group-level rows
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E19', NULL, b.CatalogID, b.CountryId, b.CurrencyId, NULL, NULL, 1, 0, NULL,
       CONCAT('VerifiedRows=', SUM(CASE WHEN b.IsVerified = 1 THEN 1 ELSE 0 END),
              ' UnverifiedRows=', SUM(CASE WHEN b.IsVerified = 0 THEN 1 ELSE 0 END))
FROM #Base AS b
WHERE b.StatusID = 1
  AND b.IsPrivate = 0
GROUP BY b.CatalogID, b.CountryId, b.CurrencyId
HAVING MIN(CAST(b.IsVerified AS int)) = 0 AND MAX(CAST(b.IsVerified AS int)) = 1;

------------------------------------------------------------
-- E21 Active price jumps more than the threshold vs previous row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E21', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PrevPrice=', s.PrevPrice, ' Pct=', CAST(ROUND(s.PctFromPrev, 2) AS varchar(20)))
FROM #S2 AS s
CROSS JOIN #Params AS pr
WHERE ABS(s.PctFromPrev) > pr.JumpPct;

------------------------------------------------------------
-- E23 Magnitude error: price is about 10x / 100x / 1000x (or 1/10 ...) of the previous price
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E23', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PrevPrice=', s.PrevPrice, ' Ratio=', CAST(ROUND(s.RatioToPrev, 4) AS varchar(30)))
FROM #S2 AS s
WHERE s.RatioToPrev IS NOT NULL
  AND ABS(LOG10(s.RatioToPrev) - ROUND(LOG10(s.RatioToPrev), 0)) < 0.03
  AND ABS(ROUND(LOG10(s.RatioToPrev), 0)) BETWEEN 1 AND 3;

------------------------------------------------------------
-- E24 Spike that returns: previous and next price within 1% of each other,
--     this row differs from the previous by more than the threshold
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E24', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('Prev=', s.PrevPrice, ' Next=', s.NextPrice, ' Pct=', CAST(ROUND(s.PctFromPrev, 2) AS varchar(20)))
FROM #S2 AS s
CROSS JOIN #Params AS pr
WHERE s.PrevPrice > 0
  AND s.NextPrice > 0
  AND ABS(CAST(s.PrevPrice AS float) - CAST(s.NextPrice AS float)) / CAST(s.PrevPrice AS float) * 100.0 <= 1.0
  AND ABS(s.PctFromPrev) > pr.JumpPct;

------------------------------------------------------------
-- E25 CreatedAt in the future
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E25', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('DaysAhead=', DATEDIFF(DAY, GETDATE(), b.CreatedAt))
FROM #Base AS b
WHERE b.CreatedAt > GETDATE();

------------------------------------------------------------
-- E26 CreatedAt before year 2000
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E26', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('CreatedAt=', CONVERT(varchar(10), b.CreatedAt, 120))
FROM #Base AS b
WHERE b.CreatedAt < '20000101';

------------------------------------------------------------
-- E27 PriceLastSeenDate in the future
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E27', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('PriceLastSeenDate=', CONVERT(varchar(10), b.PriceLastSeenDate, 120))
FROM #Base AS b
WHERE b.PriceLastSeenDate > GETDATE();

------------------------------------------------------------
-- E28 CreatedAt is after PriceLastSeenDate (compare as date)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E28', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('CreatedAt=', CONVERT(varchar(10), b.CreatedAt, 120), ' PriceLastSeenDate=', CONVERT(varchar(10), b.PriceLastSeenDate, 120))
FROM #Base AS b
WHERE b.StatusID = 1
  AND b.PriceLastSeenDate IS NOT NULL
  AND b.CreatedDate > CAST(b.PriceLastSeenDate AS date);

------------------------------------------------------------
-- E29 PriceLastSeenDate is NULL on public verified active rows
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E29', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('IsSeenInLastRun=', s.IsSeenInLastRun, CASE WHEN s.RnDesc = 1 THEN ' (latest)' ELSE ' (older)' END)
FROM #S2 AS s
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.PriceLastSeenDate IS NULL;

------------------------------------------------------------
-- E30 Latest public verified row listed (IsSeenInLastRun = 1) but PriceLastSeenDate is set
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E30', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PriceLastSeenDate=', CONVERT(varchar(10), s.PriceLastSeenDate, 120))
FROM #S2 AS s
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc = 1
  AND s.IsSeenInLastRun = 1
  AND s.PriceLastSeenDate IS NOT NULL;

------------------------------------------------------------
-- E31 Same PriceLastSeenDate on several active prices of one stream (group-level)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E31', NULL, s.CatalogID, s.CountryId, s.CurrencyId, NULL, NULL, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PriceLastSeenDate=', CONVERT(varchar(10), s.PriceLastSeenDate, 120), ' RowsSharingIt=', COUNT(*))
FROM #S2 AS s
WHERE s.PriceLastSeenDate IS NOT NULL
GROUP BY s.CatalogID, s.CountryId, s.CurrencyId, s.IsPrivate, s.IsVerified, CAST(s.PriceLastSeenDate AS date), CONVERT(varchar(10), s.PriceLastSeenDate, 120)
HAVING COUNT(*) > 1;

------------------------------------------------------------
-- E32 IsSeenInLastRun = 1 on an older (not latest) public verified price
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E32', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('PositionFromLatest=', s.RnDesc, ' of ', s.RowsInStream)
FROM #S2 AS s
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc > 1
  AND s.IsSeenInLastRun = 1;

------------------------------------------------------------
-- E33 Latest public verified row: IsSeenInLastRun differs from the active MAP row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E33', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('Retail=', s.IsSeenInLastRun, ' Map=', m.MapIsSeen, ' RawId=', m.RawCatalogId)
FROM #S2 AS s
INNER JOIN #MapActive AS m
        ON m.CatalogId = s.CatalogID
       AND m.CountryId = s.CountryId
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc = 1
  AND CAST(s.IsSeenInLastRun AS int) <> m.MapIsSeen;

------------------------------------------------------------
-- E34 Flag combinations (StatusID / IsPrivate / IsVerified) with row counts (group-level)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E34', NULL, NULL, NULL, NULL, NULL, NULL, b.StatusID, b.IsPrivate, b.IsVerified,
       CONCAT('Rows=', COUNT(*), ' Catalogs=', COUNT(DISTINCT b.CatalogID))
FROM #Base AS b
GROUP BY b.StatusID, b.IsPrivate, b.IsVerified;

------------------------------------------------------------
-- E35 Latest public verified row: tax flag NULL or different from the active MAP row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E35', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('Retail=', ISNULL(CAST(s.IsPriceTaxIncluded AS varchar(1)), 'NULL'), ' Map=', ISNULL(CAST(m.MapTax AS varchar(1)), 'NULL'))
FROM #S2 AS s
INNER JOIN #MapActive AS m
        ON m.CatalogId = s.CatalogID
       AND m.CountryId = s.CountryId
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc = 1
  AND ISNULL(CAST(s.IsPriceTaxIncluded AS int), -1) <> ISNULL(CAST(m.MapTax AS int), -1);

------------------------------------------------------------
-- E36 TransactionId is NULL
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E36', b.CatalogRetailPriceID, b.CatalogID, b.CountryId, b.CurrencyId, b.Price, b.CreatedAt, b.StatusID, b.IsPrivate, b.IsVerified,
       'TransactionId IS NULL'
FROM #Base AS b
WHERE b.TransactionId IS NULL;

------------------------------------------------------------
-- E38 Latest public verified price whose pair has no active MAP row
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E38', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       'No active MAP row for this catalog + country'
FROM #S2 AS s
LEFT JOIN #MapActive AS m
       ON m.CatalogId = s.CatalogID
      AND m.CountryId = s.CountryId
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc = 1
  AND s.CountryId IS NOT NULL
  AND m.RawCatalogId IS NULL;

------------------------------------------------------------
-- E39 Active MAP, RAW seen with Price > 0, but no public verified active price for the pair
--     (catches listings that never reached retail, e.g. reference guard / watermark cases)
------------------------------------------------------------
DROP TABLE IF EXISTS #PairsPublicVerified;
SELECT DISTINCT s.CatalogID, s.CountryId
INTO #PairsPublicVerified
FROM #S2 AS s
WHERE s.IsPrivate = 0 AND s.IsVerified = 1 AND s.CountryId IS NOT NULL;

CREATE INDEX IX_PPV ON #PairsPublicVerified (CatalogID, CountryId);

INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E39', NULL, m.CatalogId, m.CountryId, NULL, NULL, m.RawUpdatedDate, NULL, 0, 1,
       CONCAT('RawId=', m.RawCatalogId, ' SourceId=', m.RawSourceId, ' RawPrice=', m.RawPrice, ' ', m.RawCurrency, ' Ref=', m.RawReferenceNo)
FROM #MapActive AS m
LEFT JOIN #PairsPublicVerified AS p
       ON p.CatalogID = m.CatalogId
      AND p.CountryId = m.CountryId
WHERE ISNULL(m.RawIsDeleted, 0) = 0
  AND m.RawIsSeenInLastRun = 1
  AND m.RawPrice > 0
  AND p.CatalogID IS NULL;

------------------------------------------------------------
-- E40 Listing seen with a RAW price different from the latest public verified price (same currency)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E40', s.CatalogRetailPriceID, s.CatalogID, s.CountryId, s.CurrencyId, s.Price, s.CreatedAt, 1, s.IsPrivate, s.IsVerified,
       CONCAT('RetailPrice=', s.Price, ' RawPrice=', m.RawPrice, ' ', m.RawCurrency, ' RawId=', m.RawCatalogId, ' RawUpdated=', CONVERT(varchar(10), m.RawUpdatedDate, 120))
FROM #S2 AS s
INNER JOIN #MapActive AS m
        ON m.CatalogId = s.CatalogID
       AND m.CountryId = s.CountryId
       AND LTRIM(RTRIM(m.RawCurrency)) = s.CurrencyName
CROSS JOIN #Params AS pr
WHERE s.IsPrivate = 0
  AND s.IsVerified = 1
  AND s.RnDesc = 1
  AND ISNULL(m.RawIsDeleted, 0) = 0
  AND m.RawIsSeenInLastRun = 1
  AND m.RawPrice > 0
  AND ABS(CAST(m.RawPrice AS float) - CAST(s.Price AS float)) > pr.MismatchAbs;

------------------------------------------------------------
-- E42 Watermark runs that inserted 0 rows or did not succeed (tbl_cat_RetailPrice_SyncLog)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E42', NULL, NULL, NULL, NULL, NULL, CAST(l.RunCompletedAt AS datetime), NULL, NULL, NULL,
       CONCAT('LogId=', l.RetailPriceSyncLogId, ' Status=', l.Status, ' RowsInserted=', l.RowsInserted,
              ' Watermark=', l.MaxRawCatalogTransactionId, ' Error=', LEFT(ISNULL(l.ErrorMessage, ''), 150))
FROM dbo.tbl_cat_RetailPrice_SyncLog AS l WITH (NOLOCK)
WHERE l.RowsInserted = 0
   OR l.Status <> 'Success';

------------------------------------------------------------
-- E45 Very long price series (group-level)
------------------------------------------------------------
INSERT INTO #Edge (EdgeCode, CatalogRetailPriceID, CatalogID, CountryId, CurrencyId, Price, CreatedAt, StatusID, IsPrivate, IsVerified, Detail)
SELECT 'E45', NULL, s.CatalogID, s.CountryId, s.CurrencyId, NULL, NULL, 1, s.IsPrivate, s.IsVerified,
       CONCAT('RowsInStream=', MAX(s.RowsInStream))
FROM #S2 AS s
CROSS JOIN #Params AS pr
WHERE s.RowsInStream > pr.ChurnRows
GROUP BY s.CatalogID, s.CountryId, s.CurrencyId, s.IsPrivate, s.IsVerified;

------------------------------------------------------------
-- 7. FINAL: summary per category (the only result set)
--    Reason = empty, to be filled in after review.
--    Drill down with: SELECT * FROM #Edge WHERE EdgeCode = 'Exx';
------------------------------------------------------------
SELECT
    m.GroupName,
    m.EdgeCode,
    m.EdgeName,
    m.WhatItIs,
    COUNT(e.EdgeCode)                AS Rows,
    COUNT(DISTINCT e.CatalogID)      AS Catalogs,
    MIN(e.CreatedAt)                 AS OldestCreatedAt,
    MAX(e.CreatedAt)                 AS NewestCreatedAt,
    CAST(NULL AS nvarchar(500))      AS Reason
FROM #EdgeMeta AS m
LEFT JOIN #Edge AS e
       ON e.EdgeCode = m.EdgeCode
GROUP BY m.GroupName, m.EdgeCode, m.EdgeName, m.WhatItIs
ORDER BY m.GroupName, m.EdgeCode;
