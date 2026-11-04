------------------------------------------------------------
-- Cartier: manufacturer-wide image match (type 5) - watches per score band
-- and expected (cumulative) watch count, for the review summary table.
-- DB: EveryWatch.
-- Watches = active draft Cartier watches with no ENR today (ReferenceEnrichmentId IS NULL).
-- Each watch is counted once, at its best (highest) type-5 ImageMatchScore.
-- Band watches        = watches whose best score is in that 0.01 band.
-- Expected WatchCount = running total of Band watches from the top band down
--                       (= watches that would be enriched at ">= band").
-- Top band is ">=0.96" (everything 0.96 and above), lowest band 0.60.
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT
    m.ManufacturerId,
    CAST(0.96 AS DECIMAL(5,4)) AS TopBand,      -- top band start (">= 0.96" holds everything above too)
    CAST(0.60 AS DECIMAL(5,4)) AS LowerScore,   -- lowest band to count (inclusive)
    5 AS EnrichmentType
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Cartier';

------------------------------------------------------------
-- 1. Active Cartier draft watches with no ENR today (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #CartierWatches;
SELECT wd.WatchId
INTO #CartierWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND wd.ReferenceEnrichmentId IS NULL;
CREATE CLUSTERED INDEX IX_CartierWatches_WatchId ON #CartierWatches (WatchId);

------------------------------------------------------------
-- 2. Best type-5 score per watch (one row per watch)
------------------------------------------------------------
DROP TABLE IF EXISTS #BestScore;
SELECT
    w.WatchId,
    MAX(dw.ImageMatchScore) AS BestScore
INTO #BestScore
FROM #CartierWatches AS w WITH (NOLOCK)
CROSS JOIN #Params AS p
JOIN dbo.tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = w.WatchId
   AND dw.ReferenceEnrichmentType = p.EnrichmentType
WHERE dw.ImageMatchScore >= p.LowerScore
GROUP BY w.WatchId;

------------------------------------------------------------
-- 3. Band per watch (0.01 band; everything >= TopBand goes into the top band)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchBand;
SELECT
    b.WatchId,
    CASE WHEN b.BestScore >= p.TopBand THEN p.TopBand
         ELSE FLOOR(b.BestScore * 100) / 100.0 END AS BandStart
INTO #WatchBand
FROM #BestScore AS b WITH (NOLOCK)
CROSS JOIN #Params AS p;

------------------------------------------------------------
-- 4. Watches per band (only bands that have watches)
------------------------------------------------------------
DROP TABLE IF EXISTS #BandCounts;
SELECT
    wb.BandStart,
    COUNT(*) AS BandWatches
INTO #BandCounts
FROM #WatchBand AS wb WITH (NOLOCK)
GROUP BY wb.BandStart;

------------------------------------------------------------
-- 5. Every band from TopBand down to LowerScore (so empty bands still show a row)
------------------------------------------------------------
DROP TABLE IF EXISTS #AllBands;
SELECT
    CAST(p.TopBand - n.N * 0.01 AS DECIMAL(5,4)) AS BandStart
INTO #AllBands
FROM #Params AS p
CROSS JOIN (
    SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS N
    FROM sys.all_objects
) AS n
WHERE p.TopBand - n.N * 0.01 >= p.LowerScore;

------------------------------------------------------------
-- 6. Result: watches per band + running total from the top band down
------------------------------------------------------------
SELECT
    '>=' + FORMAT(ab.BandStart, '0.00') AS [Image Match Score Range],
    ISNULL(bc.BandWatches, 0) AS [Band watches],
    SUM(ISNULL(bc.BandWatches, 0)) OVER (ORDER BY ab.BandStart DESC ROWS UNBOUNDED PRECEDING) AS [Expected WatchCount]
FROM #AllBands AS ab
LEFT JOIN #BandCounts AS bc
    ON bc.BandStart = ab.BandStart
ORDER BY ab.BandStart DESC;
