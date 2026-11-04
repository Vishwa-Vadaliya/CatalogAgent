/*
================================================================================
 Reference production status - one-row-per-brand analysis
================================================================================
 Purpose   : One result set (one row per brand + a TOTAL row) with everything
             needed to decide the daily RefProductionStatusID rule:
               - which brands have an official crawl source / map rows
               - current status counts per brand
               - mapped catalogs: what the rule (MAX map seen) would change
               - NOT mapped catalogs: status, variations (ParentCatalogId),
                 new catalogs, retail prices - to decide "brand in mapping but
                 catalog not mapped -> Out of Production" vs manual / untouched
             Plan: Plans/janvi/ref_production_status_continuous.plan.md

 Rule used for "would change" columns (mapped catalogs):
   active map row seen (MAX IsSeenInLastRun = 1) -> 1 In Production
   otherwise (active rows all 0, or only deleted rows) -> 2 Out of Production
 Status ids: 1 In Production, 2 Out of Production, 3 Phasing Out, NULL none.

 Database  : EWMaster (MasterDB). Read-only: SELECT / temp tables only.
 Scope     : active catalogs (tbl_CAT_Catalog_d.StatusID = 1).

 No DECLARE variables. Each step reads only earlier temp tables.
   - Inspect any step with SELECT * FROM #<Step>;
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- 1. Map state per catalog
------------------------------------------------------------
DROP TABLE IF EXISTS #MapCatalog;
SELECT
      map.CatalogId
    , MAX(CASE WHEN map.IsDeleted = 0 THEN 1 ELSE 0 END) AS HasActive
    , MAX(CASE WHEN map.IsDeleted = 0 AND ISNULL(map.IsSeenInLastRun, 0) >= 1 THEN 1 ELSE 0 END) AS MaxSeenActive
INTO #MapCatalog
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
GROUP BY map.CatalogId;

CREATE UNIQUE CLUSTERED INDEX CX_MapCatalog ON #MapCatalog (CatalogId);

------------------------------------------------------------
-- 2. Official crawl sources per brand (tbl_sourceManufacturer_mapping)
------------------------------------------------------------
DROP TABLE IF EXISTS #BrandSource;
SELECT
      sm.CatManufacturerId AS ManufacturerId
    , COUNT(DISTINCT sm.SourceId) AS Sources
    , COUNT(DISTINCT CASE WHEN ISNULL(sm.IsActive, 0) = 1 THEN sm.SourceId END) AS ActiveSources
    , COUNT(DISTINCT CASE WHEN UPPER(ISNULL(sm.CatSourceName, N'')) LIKE N'%OFFICIAL%' THEN sm.SourceId END) AS OfficialSources
INTO #BrandSource
FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
WHERE sm.CatManufacturerId IS NOT NULL
GROUP BY sm.CatManufacturerId;

CREATE UNIQUE CLUSTERED INDEX CX_BrandSource ON #BrandSource (ManufacturerId);

------------------------------------------------------------
-- 3. Retail presence per catalog (active draft rows)
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogRetail;
SELECT
      rp.CatalogID
    , MAX(CASE WHEN ISNULL(rp.IsPrivate, 0) = 0 AND rp.IsVerified = 1 THEN 1 ELSE 0 END) AS HasPublicVerified
    , MAX(CASE WHEN ISNULL(rp.IsPrivate, 0) = 0 AND ISNULL(rp.IsVerified, 0) = 0 THEN 1 ELSE 0 END) AS HasNonVerified
    , MAX(CASE WHEN ISNULL(rp.IsPrivate, 0) = 1 THEN 1 ELSE 0 END) AS HasPrivate
INTO #CatalogRetail
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
WHERE rp.StatusID = 1
GROUP BY rp.CatalogID;

CREATE UNIQUE CLUSTERED INDEX CX_CatalogRetail ON #CatalogRetail (CatalogID);

------------------------------------------------------------
-- 4. One row per active catalog with all flags
------------------------------------------------------------
DROP TABLE IF EXISTS #Cat;
SELECT
      cd.CatalogId
    , cd.ManufacturerId
    , cd.RefProductionStatusID AS StatusId
    , cd.CreatedDate
    , cd.DiscontinuedDate
    , cd.ParentCatalogId
    , par.RefProductionStatusID AS ParentStatusId
    , CASE WHEN pmc.CatalogId IS NOT NULL THEN 1 ELSE 0 END AS ParentMapped
    , CASE WHEN mc.CatalogId IS NOT NULL THEN 1 ELSE 0 END AS IsMapped
    , ISNULL(mc.HasActive, 0) AS HasActiveMap
    , ISNULL(mc.MaxSeenActive, 0) AS MaxSeen
    , CASE
          WHEN mc.CatalogId IS NULL THEN NULL
          WHEN mc.HasActive = 1 AND mc.MaxSeenActive = 1 THEN 1
          ELSE 2
      END AS RuleStatusId
    , ISNULL(cr.HasPublicVerified, 0) AS HasPublicVerified
    , ISNULL(cr.HasNonVerified, 0) AS HasNonVerified
    , ISNULL(cr.HasPrivate, 0) AS HasPrivate
    , CASE WHEN cd.CreatedDate >= DATEADD(DAY, -90, GETDATE()) THEN 1 ELSE 0 END AS IsNew90d
INTO #Cat
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
LEFT JOIN #MapCatalog AS mc
    ON mc.CatalogId = cd.CatalogId
LEFT JOIN #CatalogRetail AS cr
    ON cr.CatalogID = cd.CatalogId
LEFT JOIN dbo.tbl_CAT_Catalog_d AS par WITH (NOLOCK)
    ON par.CatalogId = cd.ParentCatalogId
LEFT JOIN #MapCatalog AS pmc
    ON pmc.CatalogId = cd.ParentCatalogId
WHERE cd.StatusID = 1;

CREATE UNIQUE CLUSTERED INDEX CX_Cat ON #Cat (CatalogId);

------------------------------------------------------------
-- 5. Brands that have at least one mapped catalog
------------------------------------------------------------
DROP TABLE IF EXISTS #MappedBrand;
SELECT DISTINCT c.ManufacturerId
INTO #MappedBrand
FROM #Cat AS c
WHERE c.IsMapped = 1
  AND c.ManufacturerId IS NOT NULL;

------------------------------------------------------------
-- 6. RESULT: one row per brand (+ TOTAL)
--    Column groups:
--      Brand    : crawl source / map presence
--      Cat_*    : all active catalogs by current status
--      Map_*    : mapped catalogs and what the rule would change
--      NoMap_*  : catalogs not in the map table (decision area)
--      Disc_*   : DiscontinuedDate vs status
------------------------------------------------------------
DROP TABLE IF EXISTS #Result;
SELECT
      c.ManufacturerId
    , ISNULL(mf.ManufacturerName, N'(no brand)') AS ManufacturerName
    , CASE WHEN mb.ManufacturerId IS NOT NULL THEN 1 ELSE 0 END AS BrandInMapping
    , ISNULL(bs.Sources, 0) AS SourceRows
    , ISNULL(bs.ActiveSources, 0) AS ActiveSources
    , ISNULL(bs.OfficialSources, 0) AS OfficialSources

    , COUNT(*) AS Cat_Total
    , SUM(CASE WHEN c.StatusId = 1 THEN 1 ELSE 0 END) AS Cat_In
    , SUM(CASE WHEN c.StatusId = 2 THEN 1 ELSE 0 END) AS Cat_Out
    , SUM(CASE WHEN c.StatusId = 3 THEN 1 ELSE 0 END) AS Cat_Phasing
    , SUM(CASE WHEN c.StatusId IS NULL THEN 1 ELSE 0 END) AS Cat_NULL

    , SUM(c.IsMapped) AS Map_Catalogs
    , SUM(CASE WHEN c.IsMapped = 1 AND c.HasActiveMap = 0 THEN 1 ELSE 0 END) AS Map_DeletedOnly
    , SUM(CASE WHEN c.IsMapped = 1 AND c.RuleStatusId = 1 THEN 1 ELSE 0 END) AS Map_RuleIn
    , SUM(CASE WHEN c.IsMapped = 1 AND c.RuleStatusId = 2 THEN 1 ELSE 0 END) AS Map_RuleOut
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId = c.RuleStatusId THEN 1 ELSE 0 END) AS Map_AlreadyCorrect
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId = 2 AND c.RuleStatusId = 1 THEN 1 ELSE 0 END) AS Map_2to1
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId = 1 AND c.RuleStatusId = 2 THEN 1 ELSE 0 END) AS Map_1to2
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId = 3 AND c.RuleStatusId = 1 THEN 1 ELSE 0 END) AS Map_3to1
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId = 3 AND c.RuleStatusId = 2 THEN 1 ELSE 0 END) AS Map_3to2
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId IS NULL AND c.RuleStatusId = 1 THEN 1 ELSE 0 END) AS Map_NULLto1
    , SUM(CASE WHEN c.IsMapped = 1 AND c.StatusId IS NULL AND c.RuleStatusId = 2 THEN 1 ELSE 0 END) AS Map_NULLto2

    , SUM(CASE WHEN c.IsMapped = 0 THEN 1 ELSE 0 END) AS NoMap_Catalogs
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId = 1 THEN 1 ELSE 0 END) AS NoMap_In
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId = 2 THEN 1 ELSE 0 END) AS NoMap_Out
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId = 3 THEN 1 ELSE 0 END) AS NoMap_Phasing
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL THEN 1 ELSE 0 END) AS NoMap_NULL
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL AND c.IsNew90d = 1 THEN 1 ELSE 0 END) AS NoMap_NULL_New90d
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL AND c.ParentCatalogId IS NOT NULL THEN 1 ELSE 0 END) AS NoMap_NULL_HasParent
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL AND c.ParentStatusId IS NOT NULL THEN 1 ELSE 0 END) AS NoMap_NULL_ParentHasStatus
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL AND c.ParentMapped = 1 THEN 1 ELSE 0 END) AS NoMap_NULL_ParentMapped
    , SUM(CASE WHEN c.IsMapped = 0 AND c.StatusId = 1 AND c.ParentCatalogId IS NOT NULL THEN 1 ELSE 0 END) AS NoMap_In_HasParent
    , SUM(CASE WHEN c.IsMapped = 0 AND c.HasPublicVerified = 1 THEN 1 ELSE 0 END) AS NoMap_HasPublicVerified
    , SUM(CASE WHEN c.IsMapped = 0 AND c.HasNonVerified = 1 THEN 1 ELSE 0 END) AS NoMap_HasNonVerified
    , SUM(CASE WHEN c.IsMapped = 0 AND c.HasPrivate = 1 THEN 1 ELSE 0 END) AS NoMap_HasPrivate
    , SUM(CASE WHEN c.IsMapped = 0 AND c.HasPublicVerified = 0 AND c.HasNonVerified = 0 AND c.HasPrivate = 0 THEN 1 ELSE 0 END) AS NoMap_NoRetail
    , MIN(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL THEN c.CreatedDate END) AS NoMap_NULL_FirstCreated
    , MAX(CASE WHEN c.IsMapped = 0 AND c.StatusId IS NULL THEN c.CreatedDate END) AS NoMap_NULL_LastCreated

    , SUM(CASE WHEN c.DiscontinuedDate IS NOT NULL THEN 1 ELSE 0 END) AS Disc_HasDate
    , SUM(CASE WHEN c.DiscontinuedDate IS NOT NULL AND c.StatusId = 1 THEN 1 ELSE 0 END) AS Disc_HasDate_ButIn
    , SUM(CASE WHEN c.DiscontinuedDate IS NOT NULL AND c.IsMapped = 1 AND c.RuleStatusId = 1 THEN 1 ELSE 0 END) AS Disc_HasDate_RuleIn
INTO #Result
FROM #Cat AS c
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = c.ManufacturerId
LEFT JOIN #MappedBrand AS mb
    ON mb.ManufacturerId = c.ManufacturerId
LEFT JOIN #BrandSource AS bs
    ON bs.ManufacturerId = c.ManufacturerId
GROUP BY
      c.ManufacturerId
    , mf.ManufacturerName
    , mb.ManufacturerId
    , bs.Sources
    , bs.ActiveSources
    , bs.OfficialSources;

SELECT r.*
FROM (
    SELECT 0 AS SortKey, r.*
    FROM #Result AS r
    UNION ALL
    SELECT
          1
        , NULL
        , N'TOTAL'
        , SUM(BrandInMapping), SUM(SourceRows), SUM(ActiveSources), SUM(OfficialSources)
        , SUM(Cat_Total), SUM(Cat_In), SUM(Cat_Out), SUM(Cat_Phasing), SUM(Cat_NULL)
        , SUM(Map_Catalogs), SUM(Map_DeletedOnly), SUM(Map_RuleIn), SUM(Map_RuleOut), SUM(Map_AlreadyCorrect)
        , SUM(Map_2to1), SUM(Map_1to2), SUM(Map_3to1), SUM(Map_3to2), SUM(Map_NULLto1), SUM(Map_NULLto2)
        , SUM(NoMap_Catalogs), SUM(NoMap_In), SUM(NoMap_Out), SUM(NoMap_Phasing), SUM(NoMap_NULL)
        , SUM(NoMap_NULL_New90d), SUM(NoMap_NULL_HasParent), SUM(NoMap_NULL_ParentHasStatus), SUM(NoMap_NULL_ParentMapped)
        , SUM(NoMap_In_HasParent)
        , SUM(NoMap_HasPublicVerified), SUM(NoMap_HasNonVerified), SUM(NoMap_HasPrivate), SUM(NoMap_NoRetail)
        , MIN(NoMap_NULL_FirstCreated), MAX(NoMap_NULL_LastCreated)
        , SUM(Disc_HasDate), SUM(Disc_HasDate_ButIn), SUM(Disc_HasDate_RuleIn)
    FROM #Result
) AS r
ORDER BY
      r.SortKey DESC
    , r.BrandInMapping DESC
    , r.Map_Catalogs DESC
    , r.Cat_Total DESC;
