------------------------------------------------------------
-- Jaeger-LeCoultre: multiple-ENR watches by image-similarity score band
-- (enrichment type 1), 0.01 bands from 1.00 down to 0.50. DB: EveryWatch.
--
-- Multiple ENR = active draft watch with ReferenceEnrichmentId IS NULL and candidate
--   rows in tbl_RE_DataToFix (WatchId = draft id). No IsFixed filter.
-- Score: tbl_RE_DataToFix has no score column, so the score is the ImageMatchScore of
--   the watch's type-1 (Image Similarity) rows in tbl_RE_DiscardedWatch.
-- A watch can have several type-1 rows, so each watch is placed in ONE band, by its
--   HIGHEST type-1 score. Bands therefore add up to the watch count (no double counting).
-- Draft watches only (tbl_RE_DataToFix is keyed on the draft WatchId).
-- Details at any step: SELECT * FROM #Step.
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT
    m.ManufacturerId,
    1 AS EnrichmentType
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Jaeger-LeCoultre';

------------------------------------------------------------
-- 1. Active JLC draft watches with no ENR assigned (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #JlcWatches;
SELECT wd.WatchId
INTO #JlcWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND wd.ReferenceEnrichmentId IS NULL;
CREATE CLUSTERED INDEX IX_JlcWatches_WatchId ON #JlcWatches (WatchId);

------------------------------------------------------------
-- 2. Multiple-ENR watches: those with candidate ENRs in tbl_RE_DataToFix
------------------------------------------------------------
DROP TABLE IF EXISTS #MultiEnr;
SELECT
    w.WatchId,
    COUNT(DISTINCT dtf.RefEnrichmentId) AS CandidateEnrs
INTO #MultiEnr
FROM #JlcWatches AS w WITH (NOLOCK)
INNER JOIN dbo.tbl_RE_DataToFix AS dtf WITH (NOLOCK)
    ON dtf.WatchId = w.WatchId
WHERE dtf.RefEnrichmentId IS NOT NULL
GROUP BY w.WatchId;
CREATE CLUSTERED INDEX IX_MultiEnr_WatchId ON #MultiEnr (WatchId);

------------------------------------------------------------
-- 3. Highest type-1 (Image Similarity) score per multiple-ENR watch,
--    and its 0.01 band (tbl_RE_DiscardedWatch, seek by WatchId)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchBand;
SELECT
    m.WatchId,
    MAX(dw.ImageMatchScore) AS BestScore,
    CAST(FLOOR(ROUND(MAX(dw.ImageMatchScore) * 100, 6)) / 100.0 AS DECIMAL(4,2)) AS BandStart
INTO #WatchBand
FROM #MultiEnr AS m WITH (NOLOCK)
CROSS JOIN #Params AS p
INNER JOIN dbo.tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = m.WatchId
   AND dw.ReferenceEnrichmentType = p.EnrichmentType
GROUP BY m.WatchId;
CREATE CLUSTERED INDEX IX_WatchBand_WatchId ON #WatchBand (WatchId);

------------------------------------------------------------
-- 4. Bands: 1.00 down to 0.50 (51 bands of 0.01)
------------------------------------------------------------
DROP TABLE IF EXISTS #Bands;
SELECT TOP (51)
    CAST(1.01 - 0.01 * ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS DECIMAL(4,2)) AS BandStart
INTO #Bands
FROM sys.all_objects AS o WITH (NOLOCK);

------------------------------------------------------------
-- 5. Result: multiple-ENR watches per band (empty bands show 0)
--    Cumulative = watches with a type-1 score at or above that band.
--    Pct = share of ALL JLC multiple-ENR watches.
------------------------------------------------------------
SELECT
    b.BandStart,
    CAST(b.BandStart + 0.01 AS DECIMAL(4,2)) AS BandEndExclusive,
    COUNT(wb.WatchId) AS Watches,
    SUM(COUNT(wb.WatchId)) OVER (ORDER BY b.BandStart DESC ROWS UNBOUNDED PRECEDING) AS CumulativeWatches,
    (SELECT COUNT(*) FROM #MultiEnr WITH (NOLOCK)) AS TotalMultiEnrWatches,
    CAST(100.0 * COUNT(wb.WatchId)
         / NULLIF((SELECT COUNT(*) FROM #MultiEnr WITH (NOLOCK)), 0) AS DECIMAL(6,2)) AS PctOfMultiEnr
FROM #Bands AS b WITH (NOLOCK)
LEFT JOIN #WatchBand AS wb WITH (NOLOCK)
    ON wb.BandStart = b.BandStart
GROUP BY b.BandStart
ORDER BY b.BandStart DESC;
