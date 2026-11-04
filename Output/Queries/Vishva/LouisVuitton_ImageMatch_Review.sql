------------------------------------------------------------
-- Louis Vuitton: review sample from tbl_RE_DiscardedWatch (type 5),
-- watch image vs candidate enrichment image, random 150 per 0.01 band
-- below the current threshold (0.89), watches with no ENR today.
-- DB: EveryWatch. Images = primary only (IsPrimary = 1).
------------------------------------------------------------

------------------------------------------------------------
-- 0. Parameters (re-resolves the manufacturer id)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT
    m.ManufacturerId,
    CAST(0.89 AS DECIMAL(5,4)) AS UpperScore,   -- current threshold (exclusive)
    CAST(0.60 AS DECIMAL(5,4)) AS LowerScore,   -- lowest band to review (inclusive)
    5 AS EnrichmentType,
    150 AS PerBand
INTO #Params
FROM dbo.tblManufacturer AS m WITH (NOLOCK)
WHERE m.ManufacturerName = 'Louis Vuitton';

------------------------------------------------------------
-- 1. Active LV draft watches with no ENR today (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #LvWatches;
SELECT wd.WatchId, wd.ReferenceNumberId
INTO #LvWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND wd.ReferenceEnrichmentId IS NULL;
CREATE CLUSTERED INDEX IX_LvWatches_WatchId ON #LvWatches (WatchId);

------------------------------------------------------------
-- 2. Type-5 discarded candidates in the score range, with 0.01 band + rank
------------------------------------------------------------
DROP TABLE IF EXISTS #Banded;
SELECT
    w.WatchId,
    w.ReferenceNumberId AS WatchReferenceNumberId,
    dw.ReferenceEnrichmentId AS CandidateEnrichmentId,
    dw.ImageMatchScore,
    dw.MatchConfidence,
    FLOOR(dw.ImageMatchScore * 100) / 100.0 AS BandStart,
    ROW_NUMBER() OVER (
        PARTITION BY FLOOR(dw.ImageMatchScore * 100)
        ORDER BY NEWID()   -- random pick within each band (not sorted)
    ) AS rn
INTO #Banded
FROM #LvWatches AS w WITH (NOLOCK)
CROSS JOIN #Params AS p
JOIN dbo.tbl_RE_DiscardedWatch AS dw WITH (NOLOCK)
    ON dw.WatchId = w.WatchId
   AND dw.ReferenceEnrichmentType = p.EnrichmentType
WHERE dw.ImageMatchScore >= p.LowerScore
  AND dw.ImageMatchScore <  p.UpperScore;

------------------------------------------------------------
-- 3. Cap to N random rows per band first (everything below joins only this small set)
------------------------------------------------------------
DROP TABLE IF EXISTS #Sample;
SELECT b.*
INTO #Sample
FROM #Banded AS b WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE b.rn <= p.PerBand;
CREATE CLUSTERED INDEX IX_Sample_WatchId ON #Sample (WatchId);

------------------------------------------------------------
-- 4. Watch primary image (tblMediaAsset_d)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchImage;
SELECT s.WatchId, mad.Url AS WatchImage
INTO #WatchImage
FROM #Sample AS s WITH (NOLOCK)
LEFT JOIN dbo.tblMediaAsset_d AS mad WITH (NOLOCK)
    ON mad.WatchId = s.WatchId
   AND mad.IsPrimary = 1;
CREATE CLUSTERED INDEX IX_WatchImage_WatchId ON #WatchImage (WatchId);

------------------------------------------------------------
-- 5. Candidate enrichment: its reference number + primary image
--    (tbl_RE_ReferenceEnrichment, tbl_RE_ReferenceEnrichmentMediaAsset)
------------------------------------------------------------
DROP TABLE IF EXISTS #EnrichmentInfo;
SELECT DISTINCT
    s.CandidateEnrichmentId,
    rn.ReferenceNumber AS CandidateReferenceNumber,
    rem.Original AS EnrichmentImage
INTO #EnrichmentInfo
FROM #Sample AS s WITH (NOLOCK)
LEFT JOIN dbo.tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
    ON re.ReferenceEnrichmentId = s.CandidateEnrichmentId
LEFT JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK)
    ON rn.ReferenceNumberId = re.ReferenceNumberId
LEFT JOIN dbo.tbl_RE_ReferenceEnrichmentMediaAsset AS rem WITH (NOLOCK)
    ON rem.ReferenceEnrichmentId = s.CandidateEnrichmentId
   AND rem.IsPrimary = 1;
CREATE CLUSTERED INDEX IX_EnrichmentInfo_Id ON #EnrichmentInfo (CandidateEnrichmentId);

------------------------------------------------------------
-- 6. Result: score, watch ref vs candidate ref, watch image vs enrichment image
------------------------------------------------------------
SELECT
    s.WatchId,
    wrn.ReferenceNumber AS WatchReferenceNumber,
    s.CandidateEnrichmentId,
    ei.CandidateReferenceNumber,
    s.ImageMatchScore,
    s.MatchConfidence,
    wi.WatchImage,
    ei.EnrichmentImage,
    s.BandStart,
    s.rn,
    CAST(NULL AS INT) AS [Review 0 - Correct 1 - Incorrect]
FROM #Sample AS s WITH (NOLOCK)
LEFT JOIN #WatchImage AS wi WITH (NOLOCK) ON wi.WatchId = s.WatchId
LEFT JOIN #EnrichmentInfo AS ei WITH (NOLOCK) ON ei.CandidateEnrichmentId = s.CandidateEnrichmentId
LEFT JOIN dbo.tblReferenceNumber AS wrn WITH (NOLOCK) ON wrn.ReferenceNumberId = s.WatchReferenceNumberId
ORDER BY s.BandStart DESC, s.WatchId DESC;
