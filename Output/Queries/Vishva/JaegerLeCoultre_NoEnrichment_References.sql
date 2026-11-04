------------------------------------------------------------
-- Jaeger-LeCoultre: active draft watches with NO enrichment, per reference number,
-- plus the unique raw reference numbers among those watches. DB: EveryWatch.
-- Rows with a ReferenceNumberId: UniqueRawReferences lists the distinct non-blank
-- RawReferenceNumber values of that reference's unenriched watches.
-- Rows without one are grouped by their raw text (that text is the single raw reference).
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT m.ManufacturerId
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Jaeger-LeCoultre';

------------------------------------------------------------
-- 1. Active JLC draft watches (tblWatch_d staged first); blank raw refs become NULL
------------------------------------------------------------
DROP TABLE IF EXISTS #JlcWatches;
SELECT wd.WatchId, wd.ReferenceNumberId,
       NULLIF(LTRIM(RTRIM(wd.RawReferenceNumber)), '') AS RawReferenceNumber,
       wd.ReferenceEnrichmentId
INTO #JlcWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_JlcWatches_Watch ON #JlcWatches (WatchId);

------------------------------------------------------------
-- 2. Per reference: total watches, watches without enrichment
------------------------------------------------------------
DROP TABLE IF EXISTS #PerRef;
SELECT
    w.ReferenceNumberId,
    CASE WHEN w.ReferenceNumberId IS NULL THEN w.RawReferenceNumber END AS RawReferenceNumber,
    COUNT(*) AS TotalWatches,
    SUM(CASE WHEN w.ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END) AS WatchesWithoutEnrichment,
    MIN(CASE WHEN w.ReferenceEnrichmentId IS NULL THEN w.WatchId END) AS FirstWatchIdWithoutEnrichment
INTO #PerRef
FROM #JlcWatches AS w WITH (NOLOCK)
GROUP BY w.ReferenceNumberId,
         CASE WHEN w.ReferenceNumberId IS NULL THEN w.RawReferenceNumber END;

------------------------------------------------------------
-- 3. Unique raw references of the unenriched watches, per ReferenceNumberId
------------------------------------------------------------
DROP TABLE IF EXISTS #UniqueRaw;
SELECT DISTINCT ReferenceNumberId, RawReferenceNumber
INTO #UniqueRaw
FROM #JlcWatches WITH (NOLOCK)
WHERE ReferenceEnrichmentId IS NULL
  AND ReferenceNumberId IS NOT NULL
  AND RawReferenceNumber IS NOT NULL;

DROP TABLE IF EXISTS #UniqueRawAgg;
SELECT ReferenceNumberId,
       COUNT(*) AS UniqueRawReferenceCount,
       STRING_AGG(CAST(RawReferenceNumber AS NVARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY RawReferenceNumber) AS UniqueRawReferences
INTO #UniqueRawAgg
FROM #UniqueRaw WITH (NOLOCK)
GROUP BY ReferenceNumberId;
CREATE CLUSTERED INDEX IX_UniqueRawAgg_Ref ON #UniqueRawAgg (ReferenceNumberId);

------------------------------------------------------------
-- 4. Result: TOTAL row first, then every reference with unenriched watches
------------------------------------------------------------
SELECT 0 AS SortKey,
       CAST('TOTAL' AS NVARCHAR(1000)) AS ReferenceNumber,
       CAST(NULL AS NVARCHAR(1000)) AS RawReferenceNumber,
       CAST(NULL AS BIGINT) AS ReferenceNumberId,
       COUNT(*) AS TotalWatches,
       SUM(CASE WHEN ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END) AS WatchesWithoutEnrichment,
       CAST(100.0 * SUM(CASE WHEN ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS PctWithoutEnrichment,
       CAST(NULL AS BIGINT) AS FirstWatchIdWithoutEnrichment,
       COUNT(DISTINCT CASE WHEN ReferenceEnrichmentId IS NULL THEN RawReferenceNumber END) AS UniqueRawReferenceCount,
       CAST(NULL AS NVARCHAR(MAX)) AS UniqueRawReferences
FROM #JlcWatches WITH (NOLOCK)
UNION ALL
SELECT 1,
       rn.ReferenceNumber,
       CASE WHEN pr.ReferenceNumberId IS NULL
            THEN COALESCE(pr.RawReferenceNumber, '(no reference)') END,
       pr.ReferenceNumberId,
       pr.TotalWatches,
       pr.WatchesWithoutEnrichment,
       CAST(100.0 * pr.WatchesWithoutEnrichment / NULLIF(pr.TotalWatches, 0) AS DECIMAL(6,2)),
       pr.FirstWatchIdWithoutEnrichment,
       CASE WHEN pr.ReferenceNumberId IS NULL
            THEN CASE WHEN pr.RawReferenceNumber IS NULL THEN 0 ELSE 1 END
            ELSE COALESCE(ur.UniqueRawReferenceCount, 0) END,
       ur.UniqueRawReferences
FROM #PerRef AS pr WITH (NOLOCK)
LEFT JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK) ON rn.ReferenceNumberId = pr.ReferenceNumberId
LEFT JOIN #UniqueRawAgg AS ur WITH (NOLOCK) ON ur.ReferenceNumberId = pr.ReferenceNumberId
WHERE pr.WatchesWithoutEnrichment > 0
ORDER BY SortKey, WatchesWithoutEnrichment DESC, ReferenceNumber, RawReferenceNumber;
