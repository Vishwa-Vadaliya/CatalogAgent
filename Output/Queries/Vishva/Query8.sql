-- ============================================================
-- Cartier Manufacturer-Wide Image Match (type 5): expected watch count
-- per ImageMatchScore threshold -- fills "expected watch count" in
-- Table 3 (Summary tab) of "Cartier ManufacWideImageMatch Review".
--
-- Source = tbl_RE_DiscardedWatch (candidates that did NOT get an ENR),
-- ReferenceEnrichmentType = 5. One row per (WatchId, type) so each watch
-- is counted once.
-- ExpectedWatchCount_GE = watches that WOULD be enriched if the type-5
-- threshold were set at ">= BandStart" (cumulative, matches Table 3 rows
-- >=0.96, >=0.95, ...).
-- BandWatchCount = watches in that single 0.01 band only (matches the
-- right-hand Upper/Lower Range table).
-- The *_NoCurrentEnr columns count only watches that have no
-- ReferenceEnrichmentId on tblWatch_d today (i.e. truly newly enriched).
-- ============================================================

-- Step 1: Cartier draft watches (staged first, per the tblWatch_d rule)
IF OBJECT_ID('tempdb..#cartier') IS NOT NULL DROP TABLE #cartier;
SELECT wd.WatchId, wd.ReferenceEnrichmentId
INTO #cartier
FROM tblWatch_d AS wd WITH (NOLOCK)
WHERE wd.ManufacturerId = 23
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);

CREATE CLUSTERED INDEX IX_cartier_WatchId ON #cartier (WatchId);

-- Step 2: type-5 discarded candidates for those watches, with 0.01 band
IF OBJECT_ID('tempdb..#Type5') IS NOT NULL DROP TABLE #Type5;
SELECT
    dw.WatchId,
    dw.ImageMatchScore,
    CAST(FLOOR(dw.ImageMatchScore * 100) / 100.0 AS DECIMAL(4,2)) AS BandStart,
    CASE WHEN c.ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END AS NoCurrentEnr
INTO #Type5
FROM #cartier AS c WITH (NOLOCK)
JOIN tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = c.WatchId
   AND dw.ReferenceEnrichmentType = 5
WHERE dw.ImageMatchScore >= 0.60;

-- Step 3: per band + cumulative ">= BandStart"
;WITH Bands AS (
    SELECT
        BandStart,
        COUNT(*)                                   AS BandWatchCount,
        SUM(NoCurrentEnr)                          AS BandWatchCount_NoCurrentEnr
    FROM #Type5
    GROUP BY BandStart
)
SELECT
    CONCAT('>=', FORMAT(BandStart, 'N2'))                                   AS [Image Match Score Range],
    BandStart,
    BandStart + 0.01                                                        AS BandEnd,
    BandWatchCount,
    SUM(BandWatchCount) OVER (ORDER BY BandStart DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                   AS ExpectedWatchCount_GE,
    BandWatchCount_NoCurrentEnr,
    SUM(BandWatchCount_NoCurrentEnr) OVER (ORDER BY BandStart DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)                   AS ExpectedWatchCount_GE_NoCurrentEnr
FROM Bands
ORDER BY BandStart DESC;
