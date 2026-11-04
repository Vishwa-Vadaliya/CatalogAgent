-- =====================================================================================
-- Full summary for ManufacturerId = 8 -- watches, reference numbers, enrichments,
-- raw refs, and published counts.
--
-- "Active"/"not deleted" conventions used below:
--   tblWatch_d / tblWatch          : IsDeleted = 0 OR IsDeleted IS NULL
--                                     AND EntityStatusId <> 3 (3 = Deleted, per
--                                     usp_AutoPublishMarketplace's own check)
--   tblReferenceNumber             : IsDeleted = 0 OR IsDeleted IS NULL
--   tbl_RE_ReferenceEnrichment     : EntityStatusId <> 3
--
-- "Published" = rows in tblWatch (the published watch table), which links back to
-- its draft via tblWatch.WatchListingDraftId = tblWatch_d.WatchId.
-- =====================================================================================

DECLARE @ManufacturerId BIGINT = 8;

-- Step 1: Stage draft watches for this manufacturer (per the EveryWatch DB
-- tblWatch_d staging rule -- never join tblWatch_d inline)
IF OBJECT_ID('tempdb..#Watches') IS NOT NULL DROP TABLE #Watches;
SELECT
    wd.WatchId,
    wd.ReferenceNumberId,
    wd.ReferenceEnrichmentId,
    wd.RawReferenceNumber,
    wd.ReferenceNumber
INTO #Watches
FROM dbo.tblWatch_d AS wd WITH (NOLOCK)
WHERE wd.ManufacturerId = @ManufacturerId
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL)
  AND (wd.EntityStatusId IS NULL OR wd.EntityStatusId <> 3);

-- Step 2: Stage reference numbers for this manufacturer
IF OBJECT_ID('tempdb..#RefNumbers') IS NOT NULL DROP TABLE #RefNumbers;
SELECT
    rn.ReferenceNumberId,
    rn.ReferenceNumber
INTO #RefNumbers
FROM dbo.tblReferenceNumber AS rn WITH (NOLOCK)
WHERE rn.ManufacturerId = @ManufacturerId
  AND (rn.IsDeleted = 0 OR rn.IsDeleted IS NULL);

-- Step 3: Stage enrichments for this manufacturer
IF OBJECT_ID('tempdb..#Enrichments') IS NOT NULL DROP TABLE #Enrichments;
SELECT
    re.ReferenceEnrichmentId,
    re.ReferenceNumberId
INTO #Enrichments
FROM dbo.tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
WHERE re.ManufacturerId = @ManufacturerId
  AND re.EntityStatusId <> 3;

-- Step 4: Stage published watches (tblWatch) for this manufacturer, joined back
-- to the staged draft watches via WatchListingDraftId
IF OBJECT_ID('tempdb..#PublishedWatches') IS NOT NULL DROP TABLE #PublishedWatches;
SELECT
    tw.WatchId,
    tw.WatchListingDraftId
INTO #PublishedWatches
FROM dbo.tblWatch AS tw WITH (NOLOCK)
JOIN #Watches AS w ON w.WatchId = tw.WatchListingDraftId
WHERE tw.ManufacturerId = @ManufacturerId
  AND (tw.IsDeleted = 0 OR tw.IsDeleted IS NULL);

-- Final summary scorecard
SELECT 'Total Watches' AS Metric, COUNT(*) AS Value FROM #Watches
UNION ALL
SELECT 'Watches With A Reference Number', COUNT(*) FROM #Watches WHERE ReferenceNumberId IS NOT NULL
UNION ALL
SELECT 'Watches With An Enrichment', COUNT(*) FROM #Watches WHERE ReferenceEnrichmentId IS NOT NULL
UNION ALL
SELECT 'Watches With A Reference Number AND An Enrichment', COUNT(*) FROM #Watches WHERE ReferenceNumberId IS NOT NULL AND ReferenceEnrichmentId IS NOT NULL
UNION ALL
SELECT 'Distinct Reference Numbers Used On Watches', COUNT(DISTINCT ReferenceNumberId) FROM #Watches WHERE ReferenceNumberId IS NOT NULL
UNION ALL
SELECT 'Distinct Raw Reference Numbers On Watches', COUNT(DISTINCT RawReferenceNumber) FROM #Watches WHERE RawReferenceNumber IS NOT NULL
UNION ALL
SELECT 'Total Reference Numbers (tblReferenceNumber)', COUNT(*) FROM #RefNumbers
UNION ALL
SELECT 'Distinct Reference Number Text (tblReferenceNumber)', COUNT(DISTINCT ReferenceNumber) FROM #RefNumbers
UNION ALL
SELECT 'Total Enrichments (tbl_RE_ReferenceEnrichment)', COUNT(*) FROM #Enrichments
UNION ALL
SELECT 'Distinct Reference Numbers That Have An Enrichment', COUNT(DISTINCT ReferenceNumberId) FROM #Enrichments WHERE ReferenceNumberId IS NOT NULL
UNION ALL
SELECT 'Published Watch Count (tblWatch)', COUNT(*) FROM #PublishedWatches;

-- =====================================================================================
-- Top 10 images per reference number, given a list of reference numbers staged into
-- ##referenceNumbers (RowSeq INT IDENTITY(1,1) PRIMARY KEY, ReferenceNumber NVARCHAR(200))
-- =====================================================================================

-- Step 1: Match each entered ReferenceNumber to tblReferenceNumber (active only)
IF OBJECT_ID('tempdb..#MatchedRefNumbers') IS NOT NULL DROP TABLE #MatchedRefNumbers;
SELECT
    r.RowSeq,
    r.ReferenceNumber,
    rn.ReferenceNumberId
INTO #MatchedRefNumbers
FROM ##referenceNumbers AS r WITH (NOLOCK)
JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK)
    ON rn.ReferenceNumber = LTRIM(RTRIM(r.ReferenceNumber))
WHERE (rn.IsDeleted = 0 OR rn.IsDeleted IS NULL);

-- Step 2: Stage the watches linked to those reference numbers (per the
-- EveryWatch DB tblWatch_d staging rule)
IF OBJECT_ID('tempdb..#tblWatch') IS NOT NULL DROP TABLE #tblWatch;
SELECT
    wd.WatchId,
    m.RowSeq,
    m.ReferenceNumber
INTO #tblWatch
FROM #MatchedRefNumbers AS m
JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.ReferenceNumberId = m.ReferenceNumberId
WHERE (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);

-- Step 3: Stage the primary image only (IsPrimary = 1) for those watches
IF OBJECT_ID('tempdb..#WatchImages') IS NOT NULL DROP TABLE #WatchImages;
SELECT
    w.RowSeq,
    w.ReferenceNumber,
    w.WatchId,
    mad.MediaAssetId,
    COALESCE(mad.Original, mad.Preview1366, mad.Preview768, mad.Preview480, mad.Preview320) AS Image
INTO #WatchImages
FROM #tblWatch AS w
JOIN dbo.tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = w.WatchId
WHERE (mad.IsDeleted = 0 OR mad.IsDeleted IS NULL)
  AND mad.IsPrimary = 1;

-- Step 4: Rank the (one-per-watch) primary images per ReferenceNumber by
-- MediaAssetId, and keep only the top 10 per ReferenceNumber
IF OBJECT_ID('tempdb..#Top10Images') IS NOT NULL DROP TABLE #Top10Images;
;WITH Ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY RowSeq ORDER BY MediaAssetId ASC) AS rn
    FROM #WatchImages
)
SELECT
    RowSeq,
    ReferenceNumber,
    WatchId,
    MediaAssetId,
    Image,
    rn AS ImageRank
INTO #Top10Images
FROM Ranked
WHERE rn <= 10;

-- Step 5: One row per ReferenceNumber, images comma-separated in rank order
SELECT
    RowSeq,
    ReferenceNumber,
    STRING_AGG(Image, ', ') WITHIN GROUP (ORDER BY ImageRank) AS Images
FROM #Top10Images
GROUP BY RowSeq, ReferenceNumber
ORDER BY RowSeq;
