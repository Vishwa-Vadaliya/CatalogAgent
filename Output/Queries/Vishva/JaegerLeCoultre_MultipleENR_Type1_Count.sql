------------------------------------------------------------
-- Jaeger-LeCoultre: how many watches go to "multiple ENR", and how many of
-- them have enrichment type 1 (Image Similarity). DB: EveryWatch.
--
-- Multiple ENR (same definition as the Rolex multiple-ENR query):
--   active draft watch with ReferenceEnrichmentId IS NULL and candidate rows in
--   tbl_RE_DataToFix (WatchId = draft id). No IsFixed filter.
-- Enrichment type: tbl_RE_DataToFix has no type column, so the type comes from the
--   watch's candidate rows in tbl_RE_DiscardedWatch (ReferenceEnrichmentType;
--   1 = Image Similarity, per tbl_RE_ReferenceEnrichmentType).
-- Details at any step: SELECT * FROM #Step.
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT m.ManufacturerId, 1 AS EnrichmentType
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Jaeger-LeCoultre';

------------------------------------------------------------
-- 1. Active JLC draft watches with no ENR assigned (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #JlcWatches;
SELECT wd.WatchId, wd.ReferenceNumberId
INTO #JlcWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND wd.ReferenceEnrichmentId IS NULL;
CREATE CLUSTERED INDEX IX_JlcWatches_WatchId ON #JlcWatches (WatchId);

------------------------------------------------------------
-- 2. Multiple-ENR watches: those with candidate ENRs in tbl_RE_DataToFix
--    CandidateEnrs = number of distinct candidate ENRs for the watch
------------------------------------------------------------
DROP TABLE IF EXISTS #MultiEnr;
SELECT
    w.WatchId,
    w.ReferenceNumberId,
    COUNT(DISTINCT dtf.RefEnrichmentId) AS CandidateEnrs
INTO #MultiEnr
FROM #JlcWatches AS w WITH (NOLOCK)
INNER JOIN dbo.tbl_RE_DataToFix AS dtf WITH (NOLOCK)
    ON dtf.WatchId = w.WatchId
WHERE dtf.RefEnrichmentId IS NOT NULL
GROUP BY w.WatchId, w.ReferenceNumberId;
CREATE CLUSTERED INDEX IX_MultiEnr_WatchId ON #MultiEnr (WatchId);

------------------------------------------------------------
-- 3. Enrichment types of those watches (tbl_RE_DiscardedWatch, seek by WatchId)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchTypes;
SELECT DISTINCT
    m.WatchId,
    dw.ReferenceEnrichmentType
INTO #WatchTypes
FROM #MultiEnr AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = m.WatchId;
CREATE CLUSTERED INDEX IX_WatchTypes_WatchId ON #WatchTypes (WatchId, ReferenceEnrichmentType);

------------------------------------------------------------
-- 4. Result: total multiple-ENR watches, and watches per enrichment type
--    (a watch can have candidates of more than one type, so type rows can overlap)
------------------------------------------------------------
SELECT Metric, Watches
FROM (
    SELECT 1 AS SortOrder, 'JLC multiple-ENR watches (total)' AS Metric, COUNT(*) AS Watches
    FROM #MultiEnr WITH (NOLOCK)
    UNION ALL
    SELECT 2, 'JLC multiple-ENR watches with more than 1 distinct candidate ENR', COUNT(*)
    FROM #MultiEnr WITH (NOLOCK)
    WHERE CandidateEnrs > 1
    UNION ALL
    SELECT 3, 'Of those: enrichment type 1 (Image Similarity)', COUNT(DISTINCT wt.WatchId)
    FROM #WatchTypes AS wt WITH (NOLOCK)
    CROSS JOIN #Params AS p
    WHERE wt.ReferenceEnrichmentType = p.EnrichmentType
    UNION ALL
    SELECT 4, 'Of those: no row in tbl_RE_DiscardedWatch (type unknown)', COUNT(*)
    FROM #MultiEnr AS m WITH (NOLOCK)
    WHERE NOT EXISTS (SELECT 1 FROM #WatchTypes AS wt WITH (NOLOCK) WHERE wt.WatchId = m.WatchId)
    UNION ALL
    SELECT 5, 'By type: ' + CAST(wt.ReferenceEnrichmentType AS VARCHAR(10)) + ' - ' + ISNULL(ret.Name, '?'),
           COUNT(DISTINCT wt.WatchId)
    FROM #WatchTypes AS wt WITH (NOLOCK)
    LEFT JOIN dbo.tbl_RE_ReferenceEnrichmentType AS ret WITH (NOLOCK)
        ON ret.ReferenceEnrichmentTypeId = wt.ReferenceEnrichmentType
    GROUP BY wt.ReferenceEnrichmentType, ret.Name
) AS r
ORDER BY SortOrder, Metric;
