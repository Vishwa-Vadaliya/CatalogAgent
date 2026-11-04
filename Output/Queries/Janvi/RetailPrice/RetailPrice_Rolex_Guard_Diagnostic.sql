/*
================================================================================
 Retail price - Rolex reference guard diagnostic
================================================================================
 Purpose   : For every active Rolex map row, show whether the CURRENT reference
             guard of sp_update_CatalogRetailPrice_FromMapping lets the RAW row
             through, whether the NEW Rolex-aware guard would, whether the pair
             already has public retail, and whether the RAW row is behind the
             watermark (would not be re-read by the incremental run).
             Plan: Plans/janvi/retail_price_rolex_reference_guard.plan.md

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.

 Definitions:
   Rolex row     = active map row (IsDeleted = 0) whose RAW SourceId has
                   tbl_sourceManufacturer_mapping.CatManufacturerName = 'ROLEX'
   Current guard = fn_ExtractNumbersAndAlphabets(RAW ReferenceNo) not empty and
                   = catalog key or in tbl_CAT_RawCatalogMapping for the catalog
   New guard     = same, with the Rolex key (map SP rules on ReferenceNo /
                   ArtworkId: blank ref -> ArtworkId without m; ref starting m
                   -> strip m; truncated ref inside m-ArtworkId -> ArtworkId
                   without m; else ref)
   HasRetail     = pair has a StatusID = 1, IsPrivate = 0 retail row
                   (same as #CatalogCountryHasRetail in the SP)
   Watermark     = MAX(MaxRawCatalogTransactionId) in tbl_cat_RetailPrice_SyncLog

 No DECLARE variables. Each step reads only earlier temp tables.
   - Inspect any step with SELECT * FROM #<Step>;
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 1. Watermark
------------------------------------------------------------
DROP TABLE IF EXISTS #Watermark;
SELECT MAX(l.MaxRawCatalogTransactionId) AS LastMaxTransactionId
INTO #Watermark
FROM dbo.tbl_cat_RetailPrice_SyncLog AS l WITH (NOLOCK);

------------------------------------------------------------
-- 2. Active Rolex map rows with RAW and catalog reference
--    map.IsDeleted = 0, RAW not deleted, catalog StatusID = 1
------------------------------------------------------------
DROP TABLE IF EXISTS #RolexMap;
SELECT
      map.RawCatalogId
    , map.CatalogId
    , map.CountryId
    , map.ResolutionNote
    , trc.SourceId
    , trc.ReferenceNo
    , trc.ArtworkId
    , trc.Price
    , trc.Currency
    , trc.UpdatedDate
    , trc.TransactionId AS RawTransactionId
    , trc.IsSeenInLastRun
    , cat.ReferenceNumber AS CatalogReference
    , CAST(LTRIM(RTRIM(ISNULL(trc.ReferenceNo, N''))) AS nvarchar(255)) AS RefTrim
    , CAST(LTRIM(RTRIM(ISNULL(trc.ArtworkId, N''))) AS nvarchar(255)) AS ArtTrim
INTO #RolexMap
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
INNER JOIN dbo.tbl_RAW_Catalog AS trc WITH (NOLOCK)
    ON trc.Id = map.RawCatalogId
   AND ISNULL(trc.IsDeleted, 0) = 0
INNER JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = trc.SourceId
   AND UPPER(LTRIM(RTRIM(ISNULL(sm.CatManufacturerName, N'')))) = N'ROLEX'
INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
    ON cat.CatalogId = map.CatalogId
   AND cat.StatusID = 1
WHERE map.IsDeleted = 0;

CREATE UNIQUE CLUSTERED INDEX CX_RolexMap ON #RolexMap (RawCatalogId);

------------------------------------------------------------
-- 3. Guard keys: current (ref as is) and new (Rolex rule)
------------------------------------------------------------
DROP TABLE IF EXISTS #RolexKeys;
SELECT
      r.*
    , dbo.fn_ExtractNumbersAndAlphabets(CAST(LEFT(r.CatalogReference, 255) AS varchar(255))) AS CatKey
    , dbo.fn_ExtractNumbersAndAlphabets(CAST(LEFT(r.RefTrim, 255) AS varchar(255))) AS CurrentKey
    , dbo.fn_ExtractNumbersAndAlphabets(CAST(LEFT(
          CASE
              WHEN r.ArtTrim <> N'' THEN
                  CASE
                      WHEN r.RefTrim = N'' AND r.ArtTrim LIKE N'm%'
                          THEN RIGHT(r.ArtTrim, LEN(r.ArtTrim) - 1)
                      WHEN r.RefTrim LIKE N'm%'
                          THEN RIGHT(r.RefTrim, LEN(r.RefTrim) - 1)
                      WHEN LEN(r.RefTrim) < LEN(r.ArtTrim)
                           AND r.ArtTrim LIKE (N'%' + r.RefTrim + N'%')
                           AND r.ArtTrim LIKE N'm%'
                          THEN RIGHT(r.ArtTrim, LEN(r.ArtTrim) - 1)
                      ELSE r.RefTrim
                  END
              WHEN r.RefTrim LIKE N'm%'
                  THEN RIGHT(r.RefTrim, LEN(r.RefTrim) - 1)
              ELSE r.RefTrim
          END, 255) AS varchar(255))) AS NewKey
INTO #RolexKeys
FROM #RolexMap AS r;

CREATE UNIQUE CLUSTERED INDEX CX_RolexKeys ON #RolexKeys (RawCatalogId);

------------------------------------------------------------
-- 4. Manual alternative spellings for these catalogs
------------------------------------------------------------
DROP TABLE IF EXISTS #RcmKeys;
SELECT DISTINCT
      rcm.CatalogId
    , dbo.fn_ExtractNumbersAndAlphabets(
          CAST(LEFT(LTRIM(RTRIM(ISNULL(rcm.RawReferenceNumber, N''))), 255) AS varchar(255))
      ) AS RcmKey
INTO #RcmKeys
FROM dbo.tbl_CAT_RawCatalogMapping AS rcm WITH (NOLOCK)
INNER JOIN (SELECT DISTINCT k.CatalogId FROM #RolexKeys AS k) AS c
    ON c.CatalogId = rcm.CatalogId
WHERE NULLIF(LTRIM(RTRIM(ISNULL(rcm.RawReferenceNumber, N''))), N'') IS NOT NULL;

CREATE CLUSTERED INDEX CX_RcmKeys ON #RcmKeys (CatalogId, RcmKey);

------------------------------------------------------------
-- 5. Pairs with public retail; latest public verified price per pair
------------------------------------------------------------
DROP TABLE IF EXISTS #PairRetail;
SELECT
      rp.CatalogID
    , rp.CountryId
    , COUNT(*) AS PublicRows
    , SUM(CASE WHEN rp.IsVerified = 1 THEN 1 ELSE 0 END) AS PublicVerifiedRows
    , MAX(CASE WHEN rp.IsVerified = 1 THEN rp.CreatedAt END) AS LatestVerifiedCreatedAt
INTO #PairRetail
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
INNER JOIN (SELECT DISTINCT k.CatalogId, k.CountryId FROM #RolexKeys AS k) AS p
    ON p.CatalogId = rp.CatalogID
   AND p.CountryId = rp.CountryId
WHERE rp.StatusID = 1
  AND ISNULL(rp.IsPrivate, 0) = 0
GROUP BY rp.CatalogID, rp.CountryId;

CREATE UNIQUE CLUSTERED INDEX CX_PairRetail ON #PairRetail (CatalogID, CountryId);

------------------------------------------------------------
-- 6. One row per Rolex map row with all flags
------------------------------------------------------------
DROP TABLE IF EXISTS #RolexDiag;
SELECT
      k.RawCatalogId
    , k.CatalogId
    , k.CountryId
    , k.SourceId
    , k.ReferenceNo
    , k.ArtworkId
    , k.CatalogReference
    , k.CatKey
    , k.CurrentKey
    , k.NewKey
    , k.Price
    , k.Currency
    , k.UpdatedDate
    , k.RawTransactionId
    , k.ResolutionNote
    , CAST(CASE WHEN k.CurrentKey <> '' AND (k.CurrentKey = k.CatKey OR rc.CatalogId IS NOT NULL)
                THEN 1 ELSE 0 END AS bit) AS PassCurrentGuard
    , CAST(CASE WHEN k.NewKey <> '' AND (k.NewKey = k.CatKey OR rn.CatalogId IS NOT NULL)
                THEN 1 ELSE 0 END AS bit) AS PassNewGuard
    , CAST(CASE WHEN pr.CatalogID IS NOT NULL THEN 1 ELSE 0 END AS bit) AS HasRetail
    , ISNULL(pr.PublicVerifiedRows, 0) AS PublicVerifiedRows
    , pr.LatestVerifiedCreatedAt
    , CAST(CASE WHEN k.RawTransactionId <= w.LastMaxTransactionId THEN 1 ELSE 0 END AS bit) AS RawBehindWatermark
    , CAST(CASE WHEN pr.LatestVerifiedCreatedAt IS NULL
                  OR CAST(k.UpdatedDate AS date) > CAST(pr.LatestVerifiedCreatedAt AS date)
                THEN 1 ELSE 0 END AS bit) AS RawNewerThanLatestRetail
INTO #RolexDiag
FROM #RolexKeys AS k
CROSS JOIN #Watermark AS w
LEFT JOIN #RcmKeys AS rc
    ON rc.CatalogId = k.CatalogId
   AND rc.RcmKey = k.CurrentKey
LEFT JOIN #RcmKeys AS rn
    ON rn.CatalogId = k.CatalogId
   AND rn.RcmKey = k.NewKey
LEFT JOIN #PairRetail AS pr
    ON pr.CatalogID = k.CatalogId
   AND pr.CountryId = k.CountryId;

------------------------------------------------------------
-- 7. Summary
--    Detail: SELECT TOP (100) * FROM #RolexDiag WHERE PassCurrentGuard = 0 AND PassNewGuard = 0;
--    Key shape samples: SELECT TOP (50) ReferenceNo, ArtworkId, CatalogReference, CurrentKey, NewKey, CatKey FROM #RolexDiag;
------------------------------------------------------------
SELECT
      d.PassCurrentGuard
    , d.PassNewGuard
    , d.HasRetail
    , d.RawBehindWatermark
    , d.RawNewerThanLatestRetail
    , COUNT(*) AS MapRows
    , COUNT(DISTINCT d.CatalogId) AS Catalogs
    , COUNT(DISTINCT d.CountryId) AS Countries
    , COUNT(DISTINCT d.SourceId) AS Sources
FROM #RolexDiag AS d
GROUP BY
      d.PassCurrentGuard
    , d.PassNewGuard
    , d.HasRetail
    , d.RawBehindWatermark
    , d.RawNewerThanLatestRetail
ORDER BY
      d.PassCurrentGuard
    , d.PassNewGuard
    , d.HasRetail DESC
    , d.RawBehindWatermark DESC;
