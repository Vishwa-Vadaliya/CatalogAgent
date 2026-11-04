-- ============================================================
-- Active (IsDeleted = 0 or NULL) draft + published watch counts, how many
-- have an enrichment today, enrichment %, and the projected enrichment if the
-- manufacturer-wide image match (type 5) threshold drops from 0.89 to 0.80.
-- Scope: @ManufacturerId (23 = Cartier). Set to NULL for all brands.
-- Newly enriched = type-5 discarded candidates with score in [@NewThreshold, @CurrentThreshold)
-- on watches that have NO ReferenceEnrichmentId today (one row per WatchId + type).
-- ============================================================
DECLARE @ManufacturerId INT = 23;
DECLARE @CurrentThreshold DECIMAL(5,4) = 0.89;
DECLARE @NewThreshold DECIMAL(5,4) = 0.80;

-- Step 1: active draft watches in scope
IF OBJECT_ID('tempdb..#Draft') IS NOT NULL DROP TABLE #Draft;
SELECT wd.WatchId, wd.ReferenceEnrichmentId
INTO #Draft
FROM tblWatch_d AS wd WITH (NOLOCK)
WHERE (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND (@ManufacturerId IS NULL OR wd.ManufacturerId = @ManufacturerId);
CREATE CLUSTERED INDEX IX_Draft_WatchId ON #Draft (WatchId);

-- Step 2: draft watches that would newly get an ENR at the lower threshold
IF OBJECT_ID('tempdb..#NewlyEnriched') IS NOT NULL DROP TABLE #NewlyEnriched;
SELECT DISTINCT d.WatchId
INTO #NewlyEnriched
FROM #Draft AS d WITH (NOLOCK)
JOIN tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = d.WatchId
   AND dw.ReferenceEnrichmentType = 5
WHERE d.ReferenceEnrichmentId IS NULL
  AND dw.ImageMatchScore >= @NewThreshold
  AND dw.ImageMatchScore <  @CurrentThreshold;
CREATE CLUSTERED INDEX IX_New_WatchId ON #NewlyEnriched (WatchId);

-- Step 3: active published watches in scope (linked to the draft id)
IF OBJECT_ID('tempdb..#Published') IS NOT NULL DROP TABLE #Published;
SELECT w.WatchId, w.WatchListingDraftId, w.ReferenceEnrichmentId
INTO #Published
FROM tblWatch AS w WITH (NOLOCK)
WHERE (w.IsDeleted = 0 OR w.IsDeleted IS NULL)
  AND (@ManufacturerId IS NULL OR w.ManufacturerId = @ManufacturerId);

-- Step 4: result, one row for draft and one for published
SELECT
    'Draft' AS WatchType,
    COUNT(*) AS TotalActiveWatches,
    SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) AS EnrichedNow,
    CAST(100.0 * SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)) AS EnrichedNowPct,
    COUNT(n.WatchId) AS NewlyEnrichedAt080,
    SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId) AS EnrichedAfter,
    CAST(100.0 * (SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId)) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)) AS EnrichedAfterPct,
    CAST(100.0 * COUNT(n.WatchId) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)) AS IncreasePctPoints
FROM #Draft AS d WITH (NOLOCK)
LEFT JOIN #NewlyEnriched AS n WITH (NOLOCK) ON n.WatchId = d.WatchId
UNION ALL
SELECT
    'Published',
    COUNT(*),
    SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END),
    CAST(100.0 * SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)),
    COUNT(n.WatchId),
    SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId),
    CAST(100.0 * (SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId)) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)),
    CAST(100.0 * COUNT(n.WatchId) / NULLIF(COUNT(*),0) AS DECIMAL(6,2))
FROM #Published AS p WITH (NOLOCK)
LEFT JOIN #NewlyEnriched AS n WITH (NOLOCK)
    ON n.WatchId = p.WatchListingDraftId AND p.ReferenceEnrichmentId IS NULL;
