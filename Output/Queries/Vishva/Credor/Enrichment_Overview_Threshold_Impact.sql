------------------------------------------------------------
-- Credor: enrichment overview (draft + published) and projected
-- enrichment if the type-5 manufacturer-wide image match threshold is lowered
-- from 0.89 down to 0.60. DB: EveryWatch.
-- Newly enriched = no ENR today + type-5 discarded candidate with score >= new threshold
-- (and < current threshold). Published mapped via tblWatch.WatchListingDraftId.
-- Result goes to "Overview Data" columns A:I (30 Draft rows, then 30 Published rows).
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
WHERE m.ManufacturerName = 'Credor';

------------------------------------------------------------
-- 1. Active Credor draft watches (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorDraft;
SELECT wd.WatchId, wd.ReferenceEnrichmentId
INTO #CredorDraft
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_CredorDraft_WatchId ON #CredorDraft (WatchId);

------------------------------------------------------------
-- 2. Active Credor published watches (tblWatch staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorPublished;
SELECT w.WatchId, w.WatchListingDraftId, w.ReferenceEnrichmentId
INTO #CredorPublished
FROM dbo.tblWatch AS w WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE w.ManufacturerId = p.ManufacturerId
  AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_CredorPublished_Draft ON #CredorPublished (WatchListingDraftId);

------------------------------------------------------------
-- 3. Type-5 candidates (score < current threshold) for draft watches with no ENR
------------------------------------------------------------
DROP TABLE IF EXISTS #Candidates;
SELECT d.WatchId, dw.ImageMatchScore
INTO #Candidates
FROM #CredorDraft AS d WITH (NOLOCK)
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
FROM #CredorDraft WITH (NOLOCK)
UNION ALL
SELECT 'Published',
       COUNT(*),
       SUM(CASE WHEN ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END)
FROM #CredorPublished WITH (NOLOCK);

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
LEFT JOIN #CredorPublished AS pw WITH (NOLOCK)
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
