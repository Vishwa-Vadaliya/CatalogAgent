------------------------------------------------------------
-- Louis Vuitton: enrichment overview (draft + published) and projected
-- enrichment if the type-5 manufacturer-wide image match threshold is lowered
-- from 0.89 down to 0.60. DB: EveryWatch.
-- Newly enriched = no ENR today + type-5 discarded candidate with score >= new threshold
-- (and < current threshold). Published mapped via tblWatch.WatchListingDraftId.
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT
    m.ManufacturerId,
    CAST(0.89 AS DECIMAL(5,4)) AS CurrentThreshold,
    5 AS EnrichmentType
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Louis Vuitton';

------------------------------------------------------------
-- 1. Active LV draft watches (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #LvDraft;
SELECT wd.WatchId, wd.ReferenceEnrichmentId
INTO #LvDraft
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_LvDraft_WatchId ON #LvDraft (WatchId);

------------------------------------------------------------
-- 2. Active LV published watches (tblWatch staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #LvPublished;
SELECT w.WatchId, w.WatchListingDraftId, w.ReferenceEnrichmentId
INTO #LvPublished
FROM dbo.tblWatch AS w WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE w.ManufacturerId = p.ManufacturerId
  AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_LvPublished_Draft ON #LvPublished (WatchListingDraftId);

------------------------------------------------------------
-- 3. Type-5 candidates (score < current threshold) for draft watches with no ENR
------------------------------------------------------------
DROP TABLE IF EXISTS #Candidates;
SELECT d.WatchId, dw.ImageMatchScore
INTO #Candidates
FROM #LvDraft AS d WITH (NOLOCK)
CROSS JOIN #Params AS p
JOIN dbo.tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = d.WatchId
   AND dw.ReferenceEnrichmentType = p.EnrichmentType
WHERE d.ReferenceEnrichmentId IS NULL
  AND dw.ImageMatchScore < p.CurrentThreshold;
CREATE CLUSTERED INDEX IX_Candidates_WatchId ON #Candidates (WatchId);

------------------------------------------------------------
-- 4. Thresholds: 0.89 (today) down to 0.60
------------------------------------------------------------
DROP TABLE IF EXISTS #Thresholds;
SELECT TOP (30)
    CAST(0.90 - 0.01 * ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS DECIMAL(4,2)) AS NewThreshold
INTO #Thresholds
FROM sys.all_objects AS o WITH (NOLOCK);

------------------------------------------------------------
-- 5. Totals + currently enriched, draft and published
------------------------------------------------------------
DROP TABLE IF EXISTS #Totals;
SELECT 'Draft' AS WatchType,
       COUNT(*) AS TotalActiveWatches,
       SUM(CASE WHEN ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) AS EnrichedNow
INTO #Totals
FROM #LvDraft WITH (NOLOCK)
UNION ALL
SELECT 'Published',
       COUNT(*),
       SUM(CASE WHEN ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END)
FROM #LvPublished WITH (NOLOCK);

------------------------------------------------------------
-- 6. Newly enriched per threshold, draft and published
------------------------------------------------------------
DROP TABLE IF EXISTS #NewlyEnriched;
SELECT 'Draft' AS WatchType, t.NewThreshold, COUNT(DISTINCT c.WatchId) AS NewlyEnriched
INTO #NewlyEnriched
FROM #Thresholds AS t
LEFT JOIN #Candidates AS c WITH (NOLOCK) ON c.ImageMatchScore >= t.NewThreshold
GROUP BY t.NewThreshold
UNION ALL
SELECT 'Published', t.NewThreshold, COUNT(DISTINCT pw.WatchId)
FROM #Thresholds AS t
LEFT JOIN #Candidates AS c WITH (NOLOCK) ON c.ImageMatchScore >= t.NewThreshold
LEFT JOIN #LvPublished AS pw WITH (NOLOCK)
    ON pw.WatchListingDraftId = c.WatchId AND pw.ReferenceEnrichmentId IS NULL
GROUP BY t.NewThreshold;

------------------------------------------------------------
-- 7. Result: counts and percentages per threshold
------------------------------------------------------------
SELECT
    tt.WatchType,
    n.NewThreshold,
    tt.TotalActiveWatches,
    tt.EnrichedNow,
    CAST(100.0 * tt.EnrichedNow / NULLIF(tt.TotalActiveWatches, 0) AS DECIMAL(6,2)) AS EnrichedNowPct,
    n.NewlyEnriched,
    tt.EnrichedNow + n.NewlyEnriched AS EnrichedAfter,
    CAST(100.0 * (tt.EnrichedNow + n.NewlyEnriched) / NULLIF(tt.TotalActiveWatches, 0) AS DECIMAL(6,2)) AS EnrichedAfterPct,
    CAST(100.0 * n.NewlyEnriched / NULLIF(tt.TotalActiveWatches, 0) AS DECIMAL(6,2)) AS IncreasePctPoints
FROM #Totals AS tt WITH (NOLOCK)
JOIN #NewlyEnriched AS n WITH (NOLOCK) ON n.WatchType = tt.WatchType
ORDER BY tt.WatchType, n.NewThreshold DESC;

------------------------------------------------------------
-- 8. Summary at ONE threshold: two rows (Draft, Published), same layout as the
-- Cartier overview. Reuses #LvDraft, #LvPublished, #Candidates from above.
-- Newly enriched = no ENR today + type-5 candidate with score in
-- [@NewThreshold, current threshold 0.89).
------------------------------------------------------------
DECLARE @NewThreshold DECIMAL(5,4) = 0.80;

DROP TABLE IF EXISTS #NewlyEnrichedOne;
SELECT DISTINCT c.WatchId
INTO #NewlyEnrichedOne
FROM #Candidates AS c WITH (NOLOCK)
WHERE c.ImageMatchScore >= @NewThreshold;
CREATE CLUSTERED INDEX IX_NewOne_WatchId ON #NewlyEnrichedOne (WatchId);

SELECT
    'Draft' AS WatchType,
    @NewThreshold AS NewThreshold,
    COUNT(*) AS TotalActiveWatches,
    SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) AS EnrichedNow,
    CAST(100.0 * SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS EnrichedNowPct,
    COUNT(n.WatchId) AS NewlyEnriched,
    SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId) AS EnrichedAfter,
    CAST(100.0 * (SUM(CASE WHEN d.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId)) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS EnrichedAfterPct,
    CAST(100.0 * COUNT(n.WatchId) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS IncreasePctPoints
FROM #LvDraft AS d WITH (NOLOCK)
LEFT JOIN #NewlyEnrichedOne AS n WITH (NOLOCK) ON n.WatchId = d.WatchId
UNION ALL
SELECT
    'Published',
    @NewThreshold,
    COUNT(*),
    SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END),
    CAST(100.0 * SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)),
    COUNT(n.WatchId),
    SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId),
    CAST(100.0 * (SUM(CASE WHEN p.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) + COUNT(n.WatchId)) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)),
    CAST(100.0 * COUNT(n.WatchId) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2))
FROM #LvPublished AS p WITH (NOLOCK)
LEFT JOIN #NewlyEnrichedOne AS n WITH (NOLOCK)
    ON n.WatchId = p.WatchListingDraftId AND p.ReferenceEnrichmentId IS NULL;
