------------------------------------------------------------
-- Credor: active draft watches with NO enrichment, as a unique list of references.
-- DB: EveryWatch.
-- Rows WITH a ReferenceNumberId: one row per reference number; RawReferenceNumber is left NULL.
-- Rows WITHOUT a ReferenceNumberId: one row per distinct raw reference text;
--   RawReferenceNumber is filled. Watches with neither are not listed.
-- No enrichment = ReferenceEnrichmentId IS NULL.
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT m.ManufacturerId
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Credor';

------------------------------------------------------------
-- 1. Active Credor draft watches (tblWatch_d staged first); blank raw refs become NULL
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorWatches;
SELECT wd.WatchId, wd.ReferenceNumberId,
       NULLIF(LTRIM(RTRIM(wd.RawReferenceNumber)), '') AS RawReferenceNumber,
       wd.ReferenceEnrichmentId
INTO #CredorWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_CredorWatches_Watch ON #CredorWatches (WatchId);

------------------------------------------------------------
-- 2. Unique reference list: per ReferenceNumberId, or per raw text when the id is NULL
------------------------------------------------------------
DROP TABLE IF EXISTS #PerRef;
SELECT
    w.ReferenceNumberId,
    CASE WHEN w.ReferenceNumberId IS NULL THEN w.RawReferenceNumber END AS RawReferenceNumber,
    COUNT(*) AS TotalWatches,
    SUM(CASE WHEN w.ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END) AS WatchesWithoutEnrichment,
    MIN(CASE WHEN w.ReferenceEnrichmentId IS NULL THEN w.WatchId END) AS FirstWatchIdWithoutEnrichment
INTO #PerRef
FROM #CredorWatches AS w WITH (NOLOCK)
GROUP BY w.ReferenceNumberId,
         CASE WHEN w.ReferenceNumberId IS NULL THEN w.RawReferenceNumber END;

------------------------------------------------------------
-- 3. Result: every reference with unenriched watches
--    (watches with neither a reference number nor a raw reference are left out)
------------------------------------------------------------
SELECT
    pr.ReferenceNumberId,
    rn.ReferenceNumber,
    pr.RawReferenceNumber,
    pr.TotalWatches,
    pr.WatchesWithoutEnrichment,
    CAST(100.0 * pr.WatchesWithoutEnrichment / NULLIF(pr.TotalWatches, 0) AS DECIMAL(6,2)) AS PctWithoutEnrichment,
    pr.FirstWatchIdWithoutEnrichment
FROM #PerRef AS pr WITH (NOLOCK)
LEFT JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK) ON rn.ReferenceNumberId = pr.ReferenceNumberId
WHERE pr.WatchesWithoutEnrichment > 0
  AND (pr.ReferenceNumberId IS NOT NULL OR pr.RawReferenceNumber IS NOT NULL)
ORDER BY pr.WatchesWithoutEnrichment DESC, rn.ReferenceNumber, pr.RawReferenceNumber;
