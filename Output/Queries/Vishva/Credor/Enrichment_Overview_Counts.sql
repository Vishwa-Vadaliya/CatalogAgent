------------------------------------------------------------
-- Credor enrichment overview, draft and published (active watches).
-- No enrichment = ReferenceEnrichmentId IS NULL.
-- Raw reference = RawReferenceNumber that is not NULL and not blank after trimming.
-- Published watches have no raw column: it comes from the linked draft
-- (tblWatch.WatchListingDraftId = tblWatch_d.WatchId). DB: EveryWatch.
-- Result goes to the "Enrichment Overview" tab (Draft row, Published row).
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
-- 1. Active Credor draft watches (tblWatch_d staged first)
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorDraft;
SELECT wd.WatchId, wd.ReferenceNumberId, wd.RawReferenceNumber, wd.ReferenceEnrichmentId
INTO #CredorDraft
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE wd.ManufacturerId = p.ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_CredorDraft_Watch ON #CredorDraft (WatchId);

------------------------------------------------------------
-- 2. Active Credor published watches (tblWatch staged first), raw ref from the linked draft
------------------------------------------------------------
DROP TABLE IF EXISTS #CredorPublishedBase;
SELECT w.WatchId, w.WatchListingDraftId, w.ReferenceNumberId, w.ReferenceEnrichmentId
INTO #CredorPublishedBase
FROM dbo.tblWatch AS w WITH (NOLOCK)
CROSS JOIN #Params AS p
WHERE w.ManufacturerId = p.ManufacturerId
  AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);
CREATE CLUSTERED INDEX IX_CredorPublishedBase_Draft ON #CredorPublishedBase (WatchListingDraftId);

DROP TABLE IF EXISTS #CredorPublished;
SELECT pb.WatchId, pb.ReferenceNumberId, pb.ReferenceEnrichmentId, wd.RawReferenceNumber
INTO #CredorPublished
FROM #CredorPublishedBase AS pb WITH (NOLOCK)
LEFT JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.WatchId = pb.WatchListingDraftId;

------------------------------------------------------------
-- 3. Result: one row for draft, one for published
------------------------------------------------------------
SELECT
    'Draft' AS WatchType,
    COUNT(*) AS TotalWatches,
    SUM(CASE WHEN ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) AS WithEnrichment,
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END) AS WithoutEnrichment,
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NOT NULL THEN 1 ELSE 0 END) AS WithoutEnr_WithReferenceNumber,
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL THEN 1 ELSE 0 END) AS WithoutEnr_NullReferenceNumber,
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
              AND NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') IS NOT NULL THEN 1 ELSE 0 END) AS NullRef_WithRawReference,
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
              AND NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') IS NULL THEN 1 ELSE 0 END) AS NullRef_WithoutRawReference,
    COUNT(DISTINCT CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
                        THEN NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') END) AS NullRef_UniqueRawReferences
FROM #CredorDraft WITH (NOLOCK)
UNION ALL
SELECT
    'Published',
    COUNT(*),
    SUM(CASE WHEN ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
              AND NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
              AND NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT CASE WHEN ReferenceEnrichmentId IS NULL AND ReferenceNumberId IS NULL
                        THEN NULLIF(LTRIM(RTRIM(RawReferenceNumber)), '') END)
FROM #CredorPublished WITH (NOLOCK);
