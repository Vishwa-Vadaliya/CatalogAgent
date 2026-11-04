------------------------------------------------------------
-- Credor: tbl_RE_DataToFix candidates (multiple-ENR watches), watch image vs
-- candidate enrichment image. DB: EveryWatch. Active draft watches with no ENR
-- today; no IsFixed filter. Images = primary only (IsPrimary = 1).
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
-- 1. Active Credor draft watches with no ENR today (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorWatches;
SELECT wd.WatchId, wd.ReferenceNumberId
INTO #CredorWatches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND wd.ReferenceEnrichmentId IS NULL;
CREATE CLUSTERED INDEX IX_CredorWatches_WatchId ON #CredorWatches (WatchId);

------------------------------------------------------------
-- 2. Candidate rows from tbl_RE_DataToFix (one row per watch + candidate ENR)
------------------------------------------------------------
DROP TABLE IF EXISTS #Candidates;
SELECT DISTINCT
    w.WatchId,
    w.ReferenceNumberId AS WatchReferenceNumberId,
    dtf.RefEnrichmentId AS CandidateEnrichmentId
INTO #Candidates
FROM #CredorWatches AS w WITH (NOLOCK)
JOIN dbo.tbl_RE_DataToFix AS dtf WITH (NOLOCK) ON dtf.WatchId = w.WatchId
WHERE dtf.RefEnrichmentId IS NOT NULL;
CREATE CLUSTERED INDEX IX_Candidates_WatchId ON #Candidates (WatchId);

------------------------------------------------------------
-- 3. Candidates per watch
------------------------------------------------------------
DROP TABLE IF EXISTS #CandidateCount;
SELECT WatchId, COUNT(*) AS CandidateCount
INTO #CandidateCount
FROM #Candidates WITH (NOLOCK)
GROUP BY WatchId;
CREATE CLUSTERED INDEX IX_CandidateCount_WatchId ON #CandidateCount (WatchId);

------------------------------------------------------------
-- 4. Watch primary image (tblMediaAsset_d)
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchImage;
SELECT cw.WatchId, mad.Url AS WatchImage
INTO #WatchImage
FROM #CandidateCount AS cw WITH (NOLOCK)
LEFT JOIN dbo.tblMediaAsset_d AS mad WITH (NOLOCK)
    ON mad.WatchId = cw.WatchId
   AND mad.IsPrimary = 1
   AND (mad.IsDeleted = 0 OR mad.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_WatchImage_WatchId ON #WatchImage (WatchId);

------------------------------------------------------------
-- 5. Candidate enrichment: reference number + primary image
------------------------------------------------------------
DROP TABLE IF EXISTS #EnrichmentInfo;
SELECT DISTINCT
    c.CandidateEnrichmentId,
    rn.ReferenceNumber AS CandidateReferenceNumber,
    rem.Original AS EnrichmentImage
INTO #EnrichmentInfo
FROM #Candidates AS c WITH (NOLOCK)
LEFT JOIN dbo.tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
    ON re.ReferenceEnrichmentId = c.CandidateEnrichmentId
LEFT JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK)
    ON rn.ReferenceNumberId = re.ReferenceNumberId
LEFT JOIN dbo.tbl_RE_ReferenceEnrichmentMediaAsset AS rem WITH (NOLOCK)
    ON rem.ReferenceEnrichmentId = c.CandidateEnrichmentId
   AND rem.IsPrimary = 1
   AND (rem.IsDeleted = 0 OR rem.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_EnrichmentInfo_Id ON #EnrichmentInfo (CandidateEnrichmentId);

------------------------------------------------------------
-- 6. Result: one row per watch + candidate ENR
------------------------------------------------------------
SELECT
    c.WatchId,
    wrn.ReferenceNumber AS WatchReferenceNumber,
    cc.CandidateCount,
    c.CandidateEnrichmentId,
    ei.CandidateReferenceNumber,
    wi.WatchImage,
    ei.EnrichmentImage,
    CAST(NULL AS INT) AS [Review 0 - Correct 1 - Incorrect]
FROM #Candidates AS c WITH (NOLOCK)
JOIN #CandidateCount AS cc WITH (NOLOCK) ON cc.WatchId = c.WatchId
LEFT JOIN #WatchImage AS wi WITH (NOLOCK) ON wi.WatchId = c.WatchId
LEFT JOIN #EnrichmentInfo AS ei WITH (NOLOCK) ON ei.CandidateEnrichmentId = c.CandidateEnrichmentId
LEFT JOIN dbo.tblReferenceNumber AS wrn WITH (NOLOCK) ON wrn.ReferenceNumberId = c.WatchReferenceNumberId
ORDER BY c.WatchId DESC, c.CandidateEnrichmentId;
