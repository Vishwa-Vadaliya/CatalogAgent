------------------------------------------------------------------------------
-- ECH-409: Duplicate "Brown ombrè" Dial Color entries in Master Management
-- DB: Run from EWMaster (cross-DB to EveryWatch via three-part names per
--     Knowledge/EW_DB_Knowledge.md §1).
-- Purpose: DIAGNOSTIC ONLY (read-only, no updates). Confirms:
--   1) The 3 duplicate app-side (EveryWatch.dbo.tblColor) "Brown ombrè" ids
--      reported in the ticket (4524, 4545, 4549) and any siblings missed.
--   2) Draft/published watch counts per id (app side) to pick a canonical
--      survivor id (per user: "check how many watches are linked" first).
--   3) Watches currently double/triple-assigned across the duplicate ids
--      (the "same watches assigned to all three" symptom in the ticket).
--   4) The matching catalog-side (tbl_CAT_Color / tbl_CAT_Color_d) rows,
--      both via tblColor.CatalogId (bridge column) and via name match, so
--      we can confirm/contradict Knowledge §1's note that dial color ids
--      must be resolved by name (not CatalogId) between the two DBs.
-- Run each step's SELECT independently to inspect; only the last step
-- returns a combined result set.
------------------------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters — the 3 ids named in the ticket
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT CAST(x.value AS BIGINT) AS ColorId
INTO #Params
FROM (VALUES (4524), (4545), (4549)) AS x(value);

------------------------------------------------------------
-- 1. App-side (EveryWatch.dbo.tblColor) master rows for the 3 ids,
--    plus a CleanName sweep to catch any other sibling duplicates
--    the ticket didn't list.
------------------------------------------------------------
DROP TABLE IF EXISTS #AppColors;
SELECT c.ColorId,
       c.ColorName,
       c.CleanName,
       c.IsActive,
       c.IsDeleted,
       c.IsPending,
       c.ParentId,
       c.CatalogId        AS AppSide_CatalogIdBridge,
       c.CreatedDate,
       c.UpdatedDate,
       c.DialColorWatchCount,
       c.BezelColorWatchCount
INTO #AppColors
FROM EveryWatch.dbo.tblColor AS c WITH (NOLOCK)
WHERE c.ColorId IN (SELECT ColorId FROM #Params)
   OR c.CleanName IN (
        SELECT DISTINCT c2.CleanName
        FROM EveryWatch.dbo.tblColor AS c2 WITH (NOLOCK)
        WHERE c2.ColorId IN (SELECT ColorId FROM #Params)
      );

------------------------------------------------------------
-- 2. App-side draft watch counts per duplicate id
--    (tblWatchToDialColor_d -> tblWatch_d, staged per B8; IsDeleted
--    is only maintained on tblWatch/tblWatch_d per Knowledge §3).
------------------------------------------------------------
DROP TABLE IF EXISTS #AppWatchDraft;
SELECT wd.WatchId,
       wdc.DialColorId
INTO #AppWatchDraft
FROM EveryWatch.dbo.tblWatchToDialColor_d AS wdc WITH (NOLOCK)
INNER JOIN EveryWatch.dbo.tblWatch_d AS wd WITH (NOLOCK)
    ON wd.WatchId = wdc.WatchId
WHERE wdc.DialColorId IN (SELECT ColorId FROM #AppColors)
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);

DROP TABLE IF EXISTS #AppDraftCounts;
SELECT DialColorId AS ColorId,
       COUNT(DISTINCT WatchId) AS DraftWatchCount
INTO #AppDraftCounts
FROM #AppWatchDraft
GROUP BY DialColorId;

------------------------------------------------------------
-- 3. App-side published watch counts per duplicate id
--    (tblWatchToDialColor -> tblWatch, staged per B8).
------------------------------------------------------------
DROP TABLE IF EXISTS #AppWatchPublished;
SELECT w.WatchId,
       wdc.DialColorId
INTO #AppWatchPublished
FROM EveryWatch.dbo.tblWatchToDialColor AS wdc WITH (NOLOCK)
INNER JOIN EveryWatch.dbo.tblWatch AS w WITH (NOLOCK)
    ON w.WatchId = wdc.WatchId
WHERE wdc.DialColorId IN (SELECT ColorId FROM #AppColors)
  AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);

DROP TABLE IF EXISTS #AppPublishedCounts;
SELECT DialColorId AS ColorId,
       COUNT(DISTINCT WatchId) AS PublishedWatchCount
INTO #AppPublishedCounts
FROM #AppWatchPublished
GROUP BY DialColorId;

------------------------------------------------------------
-- 4. Overlap check — watches assigned to MORE THAN ONE of the
--    duplicate ids at once (draft side). This is the "same watches
--    assigned to all three" symptom from the ticket.
------------------------------------------------------------
DROP TABLE IF EXISTS #AppOverlapDraft;
SELECT WatchId,
       COUNT(DISTINCT DialColorId) AS DuplicateIdsAssigned,
       STRING_AGG(CAST(DialColorId AS NVARCHAR(20)), ',') AS DialColorIdsAssigned
INTO #AppOverlapDraft
FROM #AppWatchDraft
GROUP BY WatchId
HAVING COUNT(DISTINCT DialColorId) > 1;

------------------------------------------------------------
-- 5. Catalog-side (EWMaster) rows reachable via tblColor.CatalogId
--    bridge, for cross-check against the name-match approach below.
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogColorsByBridge;
SELECT ac.ColorId AS AppColorId,
       cd.ColorId AS CatalogColorId,
       cd.ColorName,
       cd.StatusID,
       cd.CreatedDate,
       cd.UpdatedDate
INTO #CatalogColorsByBridge
FROM #AppColors ac
INNER JOIN dbo.tbl_CAT_Color_d AS cd WITH (NOLOCK)
    ON cd.ColorId = ac.AppSide_CatalogIdBridge;

------------------------------------------------------------
-- 6. Catalog-side rows reachable via name match (the approach
--    Knowledge/EW_DB_Knowledge.md §1 says to trust for dial color).
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogColorsByName;
SELECT cd.ColorId AS CatalogColorId,
       cd.ColorName,
       cd.StatusID,
       cd.CreatedDate,
       cd.UpdatedDate
INTO #CatalogColorsByName
FROM dbo.tbl_CAT_Color_d AS cd WITH (NOLOCK)
WHERE cd.ColorName IN (SELECT DISTINCT ColorName FROM #AppColors);

------------------------------------------------------------
-- 7. Catalog-side watch (CatalogId) counts per catalog ColorId
--    found by name match — draft (StatusID = 1 active) and published.
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogDraftCounts;
SELECT wdc.DialColorId AS CatalogColorId,
       COUNT(DISTINCT wdc.CatalogId) AS CatalogDraftLinkCount
INTO #CatalogDraftCounts
FROM dbo.tbl_CAT_WatchToDialColor_d AS wdc WITH (NOLOCK)
WHERE wdc.DialColorId IN (SELECT CatalogColorId FROM #CatalogColorsByName)
  AND wdc.StatusID = 1
GROUP BY wdc.DialColorId;

DROP TABLE IF EXISTS #CatalogPublishedCounts;
SELECT wdc.DialColorId AS CatalogColorId,
       COUNT(DISTINCT wdc.CatalogId) AS CatalogPublishedLinkCount
INTO #CatalogPublishedCounts
FROM dbo.tbl_CAT_WatchToDialColor AS wdc WITH (NOLOCK)
WHERE wdc.DialColorId IN (SELECT CatalogColorId FROM #CatalogColorsByName)
GROUP BY wdc.DialColorId;

------------------------------------------------------------
-- 8. Overlap check — catalogs assigned to more than one of the
--    duplicate catalog-side ids at once.
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogOverlap;
SELECT wdc.CatalogId,
       COUNT(DISTINCT wdc.DialColorId) AS DuplicateIdsAssigned,
       STRING_AGG(CAST(wdc.DialColorId AS NVARCHAR(20)), ',') AS DialColorIdsAssigned
INTO #CatalogOverlap
FROM dbo.tbl_CAT_WatchToDialColor_d AS wdc WITH (NOLOCK)
WHERE wdc.DialColorId IN (SELECT CatalogColorId FROM #CatalogColorsByName)
  AND wdc.StatusID = 1
GROUP BY wdc.CatalogId
HAVING COUNT(DISTINCT wdc.DialColorId) > 1;

------------------------------------------------------------
-- 9. Final combined summary — one row per app-side duplicate id.
--    Use DraftWatchCount / PublishedWatchCount (never summed, per
--    Knowledge §3) to decide which id should survive the merge.
------------------------------------------------------------
SELECT ac.ColorId                                          AS App_ColorId,
       ac.ColorName,
       ac.IsActive                                         AS App_IsActive,
       ac.IsDeleted                                         AS App_IsDeleted,
       ac.CreatedDate                                       AS App_CreatedDate,
       ISNULL(adc.DraftWatchCount, 0)                       AS App_DraftWatchCount,
       ISNULL(apc.PublishedWatchCount, 0)                   AS App_PublishedWatchCount,
       ac.AppSide_CatalogIdBridge,
       cbb.CatalogColorId                                   AS Catalog_ColorId_ByBridge,
       cbn.CatalogColorId                                   AS Catalog_ColorId_ByName,
       cbn.StatusID                                         AS Catalog_StatusID,
       ISNULL(cdc.CatalogDraftLinkCount, 0)                 AS Catalog_DraftLinkCount,
       ISNULL(cpc.CatalogPublishedLinkCount, 0)              AS Catalog_PublishedLinkCount
FROM #AppColors ac
LEFT JOIN #AppDraftCounts adc ON adc.ColorId = ac.ColorId
LEFT JOIN #AppPublishedCounts apc ON apc.ColorId = ac.ColorId
LEFT JOIN #CatalogColorsByBridge cbb ON cbb.AppColorId = ac.ColorId
LEFT JOIN #CatalogColorsByName cbn ON cbn.ColorName = ac.ColorName
LEFT JOIN #CatalogDraftCounts cdc ON cdc.CatalogColorId = cbn.CatalogColorId
LEFT JOIN #CatalogPublishedCounts cpc ON cpc.CatalogColorId = cbn.CatalogColorId
ORDER BY ac.ColorId;

-- Also inspect separately:
-- SELECT * FROM #AppOverlapDraft;   -- watches double/triple-assigned (app side)
-- SELECT * FROM #CatalogOverlap;    -- catalogs double/triple-assigned (catalog side)
