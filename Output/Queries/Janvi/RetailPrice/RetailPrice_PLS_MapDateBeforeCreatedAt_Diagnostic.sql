/*
================================================================================
 Retail price - map PriceLastSeenDate earlier than the latest price's CreatedAt
================================================================================
 Purpose   : For the pairs where sp_UpdateMap_PriceLastSeen gives the latest
             public verified price a PriceLastSeenDate BEFORE its CreatedAt
             (check C6 in RetailPrice_PLS_Sync_Checks.sql), show the RAW price
             history the date was built from: each version (Mirror rows +
             current RAW row) with
               EffectiveDate  = UpdateMap rule (UpdatedDate, else previous
                                MirrorDate, else CreatedDate) = start of version
               MirrorDate     = when the version was replaced (end of version)
               PriceMatch     = version price = latest retail price
             Expected cause: the matching Mirror row has a stale UpdatedDate
             (older than the version itself), so rule 4 returns a date before
             the retail CreatedAt.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.

 No DECLARE variables. Each step reads only earlier temp tables.
   - Inspect any step with SELECT * FROM #<Step>;
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 1. Pairs where the active map date is before the latest
--    public verified price's CreatedAt (date part)
------------------------------------------------------------
DROP TABLE IF EXISTS #LatestRetail;
SELECT
      x.CatalogID
    , x.CountryId
    , x.CatalogRetailPriceID
    , x.Price
    , x.CurrencyId
    , x.CreatedAt
INTO #LatestRetail
FROM (
    SELECT
          rp.CatalogID
        , rp.CountryId
        , rp.CatalogRetailPriceID
        , rp.Price
        , rp.CurrencyId
        , rp.CreatedAt
        , ROW_NUMBER() OVER (
              PARTITION BY rp.CatalogID, rp.CountryId
              ORDER BY rp.CreatedAt DESC, rp.CatalogRetailPriceID DESC
          ) AS rn
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
    WHERE rp.StatusID = 1
      AND ISNULL(rp.IsPrivate, 0) = 0
      AND rp.IsVerified = 1
      AND rp.CountryId IS NOT NULL
) AS x
WHERE x.rn = 1;

CREATE UNIQUE CLUSTERED INDEX CX_LatestRetail ON #LatestRetail (CatalogID, CountryId);

DROP TABLE IF EXISTS #Pairs;
SELECT
      map.RawCatalogId
    , map.CatalogId
    , map.CountryId
    , map.IsSeenInLastRun AS MapIsSeen
    , CAST(map.PriceLastSeenDate AS datetime2(3)) AS MapPLS
    , lr.CatalogRetailPriceID
    , lr.Price AS RetailPrice
    , cur.CurrencyName AS RetailCurrency
    , lr.CreatedAt AS RetailCreatedAt
INTO #Pairs
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
INNER JOIN #LatestRetail AS lr
    ON lr.CatalogID = map.CatalogId
   AND lr.CountryId = map.CountryId
LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
    ON cur.CurrencyId = lr.CurrencyId
WHERE map.IsDeleted = 0
  AND map.PriceLastSeenDate IS NOT NULL
  AND CAST(map.PriceLastSeenDate AS date) < CAST(lr.CreatedAt AS date);

CREATE UNIQUE CLUSTERED INDEX CX_Pairs ON #Pairs (RawCatalogId);

------------------------------------------------------------
-- 2. RAW price versions: Mirror rows + current RAW row
------------------------------------------------------------
DROP TABLE IF EXISTS #Versions;
SELECT
      mm.Id AS RawCatalogId
    , mm.Location
    , mm.Price
    , mm.Currency
    , mm.UpdatedDate
    , mm.CreatedDate
    , mm.MirrorDate
    , CAST(0 AS bit) AS IsCurrentRaw
INTO #Versions
FROM MIRROR.EWMaster.tbl_RAW_Catalog_m AS mm WITH (NOLOCK)
INNER JOIN #Pairs AS p
    ON p.RawCatalogId = mm.Id
WHERE ISNULL(mm.IsDeleted, 0) = 0;

INSERT INTO #Versions
SELECT
      r.Id
    , r.Location
    , r.Price
    , r.Currency
    , r.UpdatedDate
    , r.CreatedDate
    , NULL
    , CAST(1 AS bit)
FROM dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
INNER JOIN #Pairs AS p
    ON p.RawCatalogId = r.Id;

------------------------------------------------------------
-- 3. Version timeline with UpdateMap EffectiveDate and price match
------------------------------------------------------------
DROP TABLE IF EXISTS #Timeline;
SELECT
      v.RawCatalogId
    , p.CatalogId
    , p.CountryId
    , v.IsCurrentRaw
    , v.Price
    , v.Currency
    , v.UpdatedDate
    , v.MirrorDate
    , CAST(CASE
          WHEN v.UpdatedDate IS NOT NULL THEN v.UpdatedDate
          WHEN LAG(v.MirrorDate) OVER (PARTITION BY v.RawCatalogId ORDER BY ISNULL(v.MirrorDate, '99991231')) IS NULL
              THEN v.CreatedDate
          ELSE LAG(v.MirrorDate) OVER (PARTITION BY v.RawCatalogId ORDER BY ISNULL(v.MirrorDate, '99991231'))
      END AS datetime2(3)) AS EffectiveDate
    , CAST(CASE
          WHEN ISNULL(v.Price, 0) <> 0
           AND TRY_CAST(TRY_CAST(v.Price AS money) AS bigint) = TRY_CAST(TRY_CAST(p.RetailPrice AS money) AS bigint)
           AND UPPER(LTRIM(RTRIM(ISNULL(v.Currency, N'')))) = UPPER(LTRIM(RTRIM(ISNULL(p.RetailCurrency, N''))))
              THEN 1 ELSE 0
      END AS bit) AS PriceMatch
    , p.RetailPrice
    , p.RetailCreatedAt
    , p.MapPLS
INTO #Timeline
FROM #Versions AS v
INNER JOIN #Pairs AS p
    ON p.RawCatalogId = v.RawCatalogId;

------------------------------------------------------------
-- 4. Per pair: current map date vs the candidate dates
--    StartOfMatch   = latest matching version's EffectiveDate (today's rule 4)
--    EndOfMatch     = latest matching Mirror row's MirrorDate (price replaced)
--    NextChangeSeen = EffectiveDate of the first later version with another price
------------------------------------------------------------
DROP TABLE IF EXISTS #LastMatch;
SELECT
      t.RawCatalogId
    , MAX(t.EffectiveDate) AS StartOfMatch
    , MAX(t.MirrorDate)    AS EndOfMatch
    , MAX(CASE WHEN t.IsCurrentRaw = 1 THEN 1 ELSE 0 END) AS CurrentRawMatches
INTO #LastMatch
FROM #Timeline AS t
WHERE t.PriceMatch = 1
GROUP BY t.RawCatalogId;

SELECT
      p.CatalogId
    , p.CountryId
    , p.RawCatalogId
    , p.CatalogRetailPriceID
    , p.RetailPrice
    , p.RetailCurrency
    , p.RetailCreatedAt
    , p.MapPLS
    , p.MapIsSeen
    , lm.StartOfMatch
    , lm.EndOfMatch
    , lm.CurrentRawMatches
    , (SELECT MIN(t.EffectiveDate)
       FROM #Timeline AS t
       WHERE t.RawCatalogId = p.RawCatalogId
         AND t.PriceMatch = 0
         AND ISNULL(t.MirrorDate, '99991231') > lm.EndOfMatch) AS NextChangeSeen
FROM #Pairs AS p
LEFT JOIN #LastMatch AS lm
    ON lm.RawCatalogId = p.RawCatalogId
ORDER BY p.CatalogId, p.CountryId;

------------------------------------------------------------
-- 5. Full timeline per pair
------------------------------------------------------------
SELECT *
FROM #Timeline
ORDER BY RawCatalogId, ISNULL(MirrorDate, '99991231');
