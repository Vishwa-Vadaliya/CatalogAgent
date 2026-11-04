------------------------------------------------------------
-- Distinct dial color + case material variations per ##watches ROW.
-- Input: ##watches (RowSeq INT IDENTITY PK, WatchId NVARCHAR(MAX) = comma-separated
-- DRAFT watch ids, ReferenceNumberId INT NULL), created and populated before this runs.
-- DB: EveryWatch.
--
-- Grouping is by the source row (RowSeq), never by ReferenceNumberId, so rows
-- with a NULL ReferenceNumberId stay separate and can be mapped back through
-- RowSeq / FirstWatchId.
--
-- A variation = (root dial color, root case material). Root =
-- COALESCE(ParentId, Id) from tblColor / tblCaseMaterial, so 18k / 14k yellow
-- gold roll into Yellow Gold while White Gold stays separate.
-- Dial color / case material are many-to-many per watch (tblWatchToDialColor_d,
-- tblWatchToCaseMaterial_d): a watch counts once per distinct root pair it has.
-- Every distinct variation is returned, even if only one watch has it.
-- A missing side shows as 'Unknown'; a variation where BOTH sides are Unknown is
-- left out (those watches still count in SourceRowWatchCount / SharePct).
--
-- Result = one row per variation. VariationWatchIds = all its watch ids. From that
-- list the first TopWatchesPerVariation (smallest ids) are taken: TopWatchIds and
-- Images list them side by side, Images = the PRIMARY image (IsPrimary = 1) of each
-- of those watches in the same order (an empty slot where a watch has none).
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT 5 AS TopWatchesPerVariation   -- watches (and their primary images) shown per variation
INTO #Params;

------------------------------------------------------------
-- 1. Split each ##watches row's WatchId list into one row per watch
--    (RowSeq is the per-row identity)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchList;
SELECT DISTINCT
    w.RowSeq AS SourceRowId,
    w.ReferenceNumberId,
    TRY_CAST(LTRIM(RTRIM(s.value)) AS BIGINT) AS WatchId
INTO #WatchList
FROM ##watches AS w WITH (NOLOCK)
CROSS APPLY STRING_SPLIT(w.WatchId, ',') AS s
WHERE TRY_CAST(LTRIM(RTRIM(s.value)) AS BIGINT) IS NOT NULL;
CREATE CLUSTERED INDEX IX_WatchList_Watch ON #WatchList (WatchId);

------------------------------------------------------------
-- 2. Draft watch core: model name (tblWatch_d staged here)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchCore;
SELECT
    wl.SourceRowId,
    wl.ReferenceNumberId,
    wd.WatchId,
    m.ModelName
INTO #WatchCore
FROM #WatchList AS wl WITH (NOLOCK)
JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.WatchId = wl.WatchId
LEFT JOIN dbo.tblModel AS m WITH (NOLOCK) ON m.ModelId = wd.ModelId;
CREATE CLUSTERED INDEX IX_WatchCore_Watch ON #WatchCore (WatchId);

------------------------------------------------------------
-- 3. Distinct root dial colors and root case materials per watch
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchColor;
SELECT DISTINCT
    wc.WatchId,
    COALESCE(c.ParentId, c.ColorId) AS DialColorRootId
INTO #WatchColor
FROM #WatchCore AS wc WITH (NOLOCK)
JOIN dbo.tblWatchToDialColor_d AS wdcd WITH (NOLOCK) ON wdcd.WatchId = wc.WatchId
JOIN dbo.tblColor AS c WITH (NOLOCK) ON c.ColorId = wdcd.DialColorId;
CREATE CLUSTERED INDEX IX_WatchColor_Watch ON #WatchColor (WatchId);

DROP TABLE IF EXISTS #WatchMaterial;
SELECT DISTINCT
    wc.WatchId,
    COALESCE(cm.ParentId, cm.CaseMaterialId) AS CaseMaterialRootId
INTO #WatchMaterial
FROM #WatchCore AS wc WITH (NOLOCK)
JOIN dbo.tblWatchToCaseMaterial_d AS wcmd WITH (NOLOCK) ON wcmd.WatchId = wc.WatchId
JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK) ON cm.CaseMaterialId = wcmd.CaseMaterialId;
CREATE CLUSTERED INDEX IX_WatchMaterial_Watch ON #WatchMaterial (WatchId);

------------------------------------------------------------
-- 4. One row per watch + distinct root pair (0 = Unknown); both-Unknown pairs dropped
------------------------------------------------------------
DROP TABLE IF EXISTS #VarWatch;
SELECT
    wc.SourceRowId,
    wc.WatchId,
    COALESCE(c.DialColorRootId, 0)       AS DialColorRootId,
    COALESCE(m.CaseMaterialRootId, 0)    AS CaseMaterialRootId
INTO #VarWatch
FROM #WatchCore AS wc WITH (NOLOCK)
LEFT JOIN #WatchColor AS c WITH (NOLOCK) ON c.WatchId = wc.WatchId
LEFT JOIN #WatchMaterial AS m WITH (NOLOCK) ON m.WatchId = wc.WatchId
WHERE c.DialColorRootId IS NOT NULL OR m.CaseMaterialRootId IS NOT NULL;
CREATE CLUSTERED INDEX IX_VarWatch_Row ON #VarWatch (SourceRowId, DialColorRootId, CaseMaterialRootId);

------------------------------------------------------------
-- 5. Watches per source row, and per variation within the row
------------------------------------------------------------
DROP TABLE IF EXISTS #RowTotals;
SELECT SourceRowId, MAX(ReferenceNumberId) AS ReferenceNumberId, COUNT(*) AS SourceRowWatchCount,
       MIN(WatchId) AS FirstWatchId
INTO #RowTotals
FROM #WatchCore WITH (NOLOCK)
GROUP BY SourceRowId;
CREATE CLUSTERED INDEX IX_RowTotals_Row ON #RowTotals (SourceRowId);

DROP TABLE IF EXISTS #VarCounts;
SELECT
    SourceRowId, DialColorRootId, CaseMaterialRootId,
    COUNT(*) AS VariationWatchCount,
    STRING_AGG(CAST(WatchId AS NVARCHAR(MAX)), ',') WITHIN GROUP (ORDER BY WatchId) AS VariationWatchIds
INTO #VarCounts
FROM #VarWatch WITH (NOLOCK)
GROUP BY SourceRowId, DialColorRootId, CaseMaterialRootId;
CREATE CLUSTERED INDEX IX_VarCounts_Row ON #VarCounts (SourceRowId);

------------------------------------------------------------
-- 6. Top watches per variation (first TopWatchesPerVariation ids of the Step 5 list),
--    each with its primary image (IsPrimary = 1; lowest MediaAssetId if several)
--    and publish id. Lookups run only for these watches.
------------------------------------------------------------
DROP TABLE IF EXISTS #VarRanked;
SELECT
    SourceRowId, WatchId, DialColorRootId, CaseMaterialRootId,
    ROW_NUMBER() OVER (
        PARTITION BY SourceRowId, DialColorRootId, CaseMaterialRootId
        ORDER BY WatchId ASC
    ) AS rn
INTO #VarRanked
FROM #VarWatch WITH (NOLOCK);

DROP TABLE IF EXISTS #VarTop;
SELECT
    r.SourceRowId, r.WatchId, r.DialColorRootId, r.CaseMaterialRootId, r.rn,
    PrimaryImage = (
        SELECT TOP 1 COALESCE(ma.Original, ma.Preview1366, ma.Preview768, ma.Preview480, ma.Preview320)
        FROM dbo.tblMediaAsset_d AS ma WITH (NOLOCK)
        WHERE ma.WatchId = r.WatchId
          AND ma.IsPrimary = 1
          AND (ma.IsDeleted = 0 OR ma.IsDeleted IS NULL)
        ORDER BY ma.MediaAssetId ASC
    ),
    PublishWatchId = (
        SELECT TOP 1 tw.WatchId
        FROM dbo.tblWatch AS tw WITH (NOLOCK)
        WHERE tw.WatchListingDraftId = r.WatchId
    )
INTO #VarTop
FROM #VarRanked AS r WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE r.rn <= p.TopWatchesPerVariation;

DROP TABLE IF EXISTS #VarImages;
SELECT
    SourceRowId, DialColorRootId, CaseMaterialRootId,
    MAX(CASE WHEN rn = 1 THEN WatchId END)        AS VariationFirstWatchId,
    MAX(CASE WHEN rn = 1 THEN PublishWatchId END) AS VariationFirstPublishWatchId,
    STRING_AGG(CAST(WatchId AS NVARCHAR(MAX)), ',') WITHIN GROUP (ORDER BY rn) AS TopWatchIds,
    STRING_AGG(COALESCE(PrimaryImage, ''), ',')     WITHIN GROUP (ORDER BY rn) AS Images
INTO #VarImages
FROM #VarTop WITH (NOLOCK)
GROUP BY SourceRowId, DialColorRootId, CaseMaterialRootId;
CREATE CLUSTERED INDEX IX_VarImages_Row ON #VarImages (SourceRowId);

------------------------------------------------------------
-- 7. Most-occurring model name per source row (ties alphabetical)
------------------------------------------------------------
DROP TABLE IF EXISTS #ModelRank;
SELECT
    SourceRowId, ModelName,
    ROW_NUMBER() OVER (PARTITION BY SourceRowId ORDER BY COUNT(*) DESC, ModelName ASC) AS rn
INTO #ModelRank
FROM #WatchCore WITH (NOLOCK)
WHERE ModelName IS NOT NULL
GROUP BY SourceRowId, ModelName;
CREATE CLUSTERED INDEX IX_ModelRank_Row ON #ModelRank (SourceRowId);

------------------------------------------------------------
-- 8. Result: one row per ##watches row + distinct variation
------------------------------------------------------------
SELECT
    rt.SourceRowId,
    rt.ReferenceNumberId,
    rt.FirstWatchId,
    mr.ModelName,
    COALESCE(dc.ColorName, 'Unknown')         AS DialColor,
    COALESCE(cm.CaseMaterialName, 'Unknown')  AS CaseMaterial,
    vc.VariationWatchCount,
    rt.SourceRowWatchCount,
    CAST(100.0 * vc.VariationWatchCount / rt.SourceRowWatchCount AS DECIMAL(6,2)) AS SharePct,
    vc.VariationWatchIds,
    vi.VariationFirstWatchId,
    vi.VariationFirstPublishWatchId,
    vi.TopWatchIds,
    vi.Images
FROM #VarCounts AS vc WITH (NOLOCK)
JOIN #RowTotals AS rt WITH (NOLOCK) ON rt.SourceRowId = vc.SourceRowId
JOIN #VarImages AS vi WITH (NOLOCK)
    ON vi.SourceRowId = vc.SourceRowId
   AND vi.DialColorRootId = vc.DialColorRootId
   AND vi.CaseMaterialRootId = vc.CaseMaterialRootId
LEFT JOIN dbo.tblColor AS dc WITH (NOLOCK) ON dc.ColorId = vc.DialColorRootId
LEFT JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK) ON cm.CaseMaterialId = vc.CaseMaterialRootId
LEFT JOIN #ModelRank AS mr WITH (NOLOCK) ON mr.SourceRowId = vc.SourceRowId AND mr.rn = 1
ORDER BY rt.SourceRowId, vc.VariationWatchCount DESC;
