-- Add ManufacturingScore column to tbl_CAT_Catalog_d (MasterDB / EWMaster)
-- INT, nullable, defaults to NULL (no DEFAULT constraint added)
ALTER TABLE dbo.tbl_CAT_Catalog_d
ADD EnrichmentSimilarityScore INT NULL;

ALTER TABLE dbo.tbl_CAT_Catalog
ADD EnrichmentSimilarityScore INT NULL;
exec sp_Create_Transaction 2,6

Select *
From tbl_CAT_Catalog (NOLOCK)
where EnrichmentSimilarityScore =2

update tbl_CAT_Catalog
set EnrichmentSimilarityScore = 2, TransactionID=346012
where CatalogId in (227672, 227675, 227769, 227808, 227954)
exec sp_PublishAllDataNew ;

-- ============================================================
-- Images + ReferenceNumber per brand, from enrichment, for watches
-- linked to enrichments that have a FULL reference number.
-- Reference numbers are now taken from the ENRICHMENT side
-- (tbl_RE_ReferenceEnrichment -> tblReferenceNumber), not pulled
-- straight from tblReferenceNumber. "Full ref" pattern is brand-specific:
--   Rolex             -> contains '-'   (e.g. 116610-LN)
--   Audemars Piguet    -> contains '.'   (e.g. 15710ST.OO.A002CA.01)
--   Patek Philippe     -> contains '-' or '/'
-- Broken into staged temp tables so each step only works off an
-- already-narrowed set, instead of one heavy query.
-- ============================================================

-- Step 1: Distinct reference numbers that actually come from the
-- enrichment side, for just the brands we care about here
IF OBJECT_ID('tempdb..#EnrichmentRefs') IS NOT NULL DROP TABLE #EnrichmentRefs;
SELECT DISTINCT
    re.ReferenceEnrichmentId,
    re.ReferenceNumberId,
    rn.ReferenceNumber,
    re.ManufacturerId,
    m.ManufacturerName
INTO #EnrichmentRefs
FROM tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
JOIN tblReferenceNumber AS rn WITH (NOLOCK) ON re.ReferenceNumberId = rn.ReferenceNumberId
JOIN tblManufacturer AS m WITH (NOLOCK) ON re.ManufacturerId = m.ManufacturerId
WHERE m.ManufacturerName IN ('Rolex', 'Audemars Piguet', 'Patek Philippe')
  AND rn.ReferenceNumber IS NOT NULL;

-- Step 2: Apply the brand-specific "full ref" pattern
IF OBJECT_ID('tempdb..#FullRefEnrichment') IS NOT NULL DROP TABLE #FullRefEnrichment;
SELECT
    ReferenceEnrichmentId,
    ReferenceNumberId,
    ReferenceNumber,
    ManufacturerName
INTO #FullRefEnrichment
FROM #EnrichmentRefs
WHERE (ManufacturerName = 'Rolex' AND ReferenceNumber LIKE '%-%')
   OR (ManufacturerName = 'Audemars Piguet' AND ReferenceNumber LIKE '%.%')
   OR (ManufacturerName = 'Patek Philippe' AND (ReferenceNumber LIKE '%-%' OR ReferenceNumber LIKE '%/%'));

-- Step 3: Stage the linked watches (per the EveryWatch DB tblWatch_d staging rule)
IF OBJECT_ID('tempdb..#EnrichmentWatches') IS NOT NULL DROP TABLE #EnrichmentWatches;
SELECT
    wd.WatchId,
    wd.ReferenceEnrichmentId
INTO #EnrichmentWatches
FROM tblWatch_d AS wd WITH (NOLOCK)
JOIN #FullRefEnrichment AS f WITH (NOLOCK) ON wd.ReferenceEnrichmentId = f.ReferenceEnrichmentId
WHERE wd.IsDeleted = 0;

-- Step 4: Stage the images for just those watches
IF OBJECT_ID('tempdb..#EnrichmentWatchImages') IS NOT NULL DROP TABLE #EnrichmentWatchImages;
SELECT
    ew.WatchId,
    mad.Url AS Image
INTO #EnrichmentWatchImages
FROM #EnrichmentWatches AS ew WITH (NOLOCK)
JOIN tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = ew.WatchId AND mad.IsDeleted = 0;

-- Step 5: Final combine -- only joins the small staged tables together
SELECT
    f.ManufacturerName,
    f.ReferenceNumber,
    img.Image
FROM #EnrichmentWatches AS ew WITH (NOLOCK)
JOIN #FullRefEnrichment AS f WITH (NOLOCK) ON ew.ReferenceEnrichmentId = f.ReferenceEnrichmentId
JOIN #EnrichmentWatchImages AS img WITH (NOLOCK) ON ew.WatchId = img.WatchId
ORDER BY f.ManufacturerName, f.ReferenceNumber;

-- ============================================================
-- From the enrichments above that have >= 200 linked watches,
-- take a RANDOM 200 watches per ReferenceEnrichmentId, spread across
-- DIFFERENT sources (tblInfoSource via tblWatch_d.InfoSourceId) --
-- i.e. a round-robin random pick across sources, not a plain random
-- 200 that could end up mostly from one dominant source.
-- Builds on #EnrichmentWatches / #FullRefEnrichment from above.
-- Staged into temp tables so each step only works off an
-- already-narrowed set.
-- ============================================================

-- Step 1: Enrichments with >= 200 linked watches (as given)
IF OBJECT_ID('tempdb..#QualifyingEnrichments') IS NOT NULL DROP TABLE #QualifyingEnrichments;
SELECT
    ew.ReferenceEnrichmentId,
    COUNT(ew.WatchId) AS WatchCount
INTO #QualifyingEnrichments
FROM #EnrichmentWatches AS ew WITH (NOLOCK)
GROUP BY ew.ReferenceEnrichmentId
HAVING COUNT(ew.WatchId) >= 200;

-- Step 2: Stage WatchId + InfoSourceId only for watches in those
-- qualifying enrichments (per the EveryWatch DB tblWatch_d staging rule)
IF OBJECT_ID('tempdb..#QualifyingWatchesWithSource') IS NOT NULL DROP TABLE #QualifyingWatchesWithSource;
SELECT
    wd.WatchId,
    wd.ReferenceEnrichmentId,
    wd.InfoSourceId
INTO #QualifyingWatchesWithSource
FROM tblWatch_d AS wd WITH (NOLOCK)
JOIN #QualifyingEnrichments AS q WITH (NOLOCK) ON wd.ReferenceEnrichmentId = q.ReferenceEnrichmentId
WHERE wd.IsDeleted = 0;

-- Step 3: Random rank WITHIN each (enrichment, source) pair --
-- this is what makes the later pick spread across sources instead
-- of just picking whichever source happens to have the most rows
IF OBJECT_ID('tempdb..#SourceRanked') IS NOT NULL DROP TABLE #SourceRanked;
SELECT
    WatchId,
    ReferenceEnrichmentId,
    InfoSourceId,
    ROW_NUMBER() OVER (
        PARTITION BY ReferenceEnrichmentId, InfoSourceId
        ORDER BY NEWID()
    ) AS SourceRank
INTO #SourceRanked
FROM #QualifyingWatchesWithSource;

-- Step 4: Round-robin across sources per enrichment -- rank 1 from
-- every source first, then rank 2 from every source, etc. (ties broken
-- randomly), then cap at 200 per enrichment
IF OBJECT_ID('tempdb..#RoundRobinRanked') IS NOT NULL DROP TABLE #RoundRobinRanked;
SELECT
    WatchId,
    ReferenceEnrichmentId,
    InfoSourceId,
    ROW_NUMBER() OVER (
        PARTITION BY ReferenceEnrichmentId
        ORDER BY SourceRank, NEWID()
    ) AS FinalRank
INTO #RoundRobinRanked
FROM #SourceRanked;

IF OBJECT_ID('tempdb..#Random200PerEnrichment') IS NOT NULL DROP TABLE #Random200PerEnrichment;
SELECT WatchId, ReferenceEnrichmentId, InfoSourceId
INTO #Random200PerEnrichment
FROM #RoundRobinRanked
WHERE FinalRank <= 200;

-- Step 5: Image + source name, keyed only on the capped 200-per-enrichment set.
-- Pulled in batches of 5000 distinct WatchIds at a time so the join against
-- tblMediaAsset_d never has to scan against the full capped set in one shot.
IF OBJECT_ID('tempdb..#Random200WatchBatches') IS NOT NULL DROP TABLE #Random200WatchBatches;
SELECT DISTINCT
    WatchId,
    (ROW_NUMBER() OVER (ORDER BY WatchId) - 1) / 5000 AS BatchNumber
INTO #Random200WatchBatches
FROM #Random200PerEnrichment;

-- Permanent table (not a temp table) so the fetched images persist across sessions.
-- Created once if missing; cleared before each run so re-running this script doesn't
-- keep piling up duplicate rows.
IF OBJECT_ID('dbo.tbl_RE_Random200Images') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_RE_Random200Images
    (
        WatchId BIGINT NOT NULL,
        Image NVARCHAR(MAX) NULL
    );
END
ELSE
BEGIN
    DELETE FROM dbo.tbl_RE_Random200Images;
END

DECLARE @BatchNumber INT, @MaxBatchNumber INT;
SELECT @BatchNumber = MIN(BatchNumber), @MaxBatchNumber = MAX(BatchNumber) FROM #Random200WatchBatches;

WHILE @BatchNumber IS NOT NULL AND @BatchNumber <= @MaxBatchNumber
BEGIN
    INSERT INTO dbo.tbl_RE_Random200Images (WatchId, Image)
    SELECT
        b.WatchId,
        mad.Url AS Image
    FROM #Random200WatchBatches AS b WITH (NOLOCK)
    LEFT JOIN tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = b.WatchId AND mad.IsDeleted = 0 AND mad.IsPrimary = 1
    WHERE b.BatchNumber = @BatchNumber;

    SET @BatchNumber = @BatchNumber + 1;
END

-- Step 6: Final combine -- only joins the small staged tables together
SELECT
    f.ManufacturerName,
    r.ReferenceEnrichmentId,
    f.ReferenceNumber,
    r.WatchId,
    src.Name AS InfoSource,
    img.Image
FROM #Random200PerEnrichment AS r WITH (NOLOCK)
JOIN #FullRefEnrichment AS f WITH (NOLOCK) ON r.ReferenceEnrichmentId = f.ReferenceEnrichmentId
LEFT JOIN tblInfoSource AS src WITH (NOLOCK) ON r.InfoSourceId = src.InfoSourceId
LEFT JOIN dbo.tbl_RE_Random200Images AS img WITH (NOLOCK) ON r.WatchId = img.WatchId
ORDER BY f.ManufacturerName, f.ReferenceNumber, r.ReferenceEnrichmentId;

-- ============================================================
-- No full-ref filter this time -- simply take the TOP 100 watches
-- per enrichment by ImageMatchScore, from TblWatchEnrichmentResults.
-- NOTE: TblWatchEnrichmentResults has no ReferenceEnrichmentId column
-- and is unique per WatchId (one row per watch) -- so ReferenceEnrichmentId
-- is pulled from tblWatch_d first, then the ranking is partitioned by it.
-- Output: ManufacturerName, EnrichmentId, ReferenceNumber, Image, ImageMatchScore
-- Staged into temp tables so each step only works off an
-- already-narrowed set.
-- ============================================================

-- Step 1: Stage watch -> enrichment mapping (per the EveryWatch DB
-- tblWatch_d staging rule), excluding deleted watches / watches with
-- no enrichment
IF OBJECT_ID('tempdb..#EnrichedWatches') IS NOT NULL DROP TABLE #EnrichedWatches;
SELECT
    wd.WatchId,
    wd.ReferenceEnrichmentId
INTO #EnrichedWatches
FROM tblWatch_d AS wd WITH (NOLOCK)
WHERE wd.IsDeleted = 0
  AND wd.ReferenceEnrichmentId IS NOT NULL;

-- Step 2: Rank each watch's ImageMatchScore within its enrichment,
-- keep only the top 100 per ReferenceEnrichmentId
IF OBJECT_ID('tempdb..#TopWatchesPerEnrichment') IS NOT NULL DROP TABLE #TopWatchesPerEnrichment;
SELECT
    ew.WatchId,
    ew.ReferenceEnrichmentId,
    wer.ImageMatchScore,
    ROW_NUMBER() OVER (
        PARTITION BY ew.ReferenceEnrichmentId
        ORDER BY wer.ImageMatchScore DESC
    ) AS rn
INTO #TopWatchesPerEnrichment
FROM #EnrichedWatches AS ew WITH (NOLOCK)
JOIN TblWatchEnrichmentResults AS wer WITH (NOLOCK) ON wer.WatchId = ew.WatchId
WHERE wer.ImageMatchScore > 0.70;

IF OBJECT_ID('tempdb..#Top100PerEnrichment') IS NOT NULL DROP TABLE #Top100PerEnrichment;
SELECT WatchId, ReferenceEnrichmentId, ImageMatchScore
INTO #Top100PerEnrichment
FROM #TopWatchesPerEnrichment
WHERE rn <= 100;

-- Step 3: Re-stage the capped watch set (small now, just carries the
-- columns needed downstream)
IF OBJECT_ID('tempdb..#Top100Watches') IS NOT NULL DROP TABLE #Top100Watches;
SELECT
    WatchId,
    ReferenceEnrichmentId,
    ImageMatchScore
INTO #Top100Watches
FROM #Top100PerEnrichment;

-- Step 4: Enrichment -> brand + reference number, keyed only on the
-- distinct enrichments present in the capped set
IF OBJECT_ID('tempdb..#Top100EnrichmentInfo') IS NOT NULL DROP TABLE #Top100EnrichmentInfo;
SELECT DISTINCT
    re.ReferenceEnrichmentId,
    m.ManufacturerName,
    rn.ReferenceNumber
INTO #Top100EnrichmentInfo
FROM #Top100Watches AS t WITH (NOLOCK)
JOIN tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK) ON re.ReferenceEnrichmentId = t.ReferenceEnrichmentId
LEFT JOIN tblManufacturer AS m WITH (NOLOCK) ON re.ManufacturerId = m.ManufacturerId
LEFT JOIN tblReferenceNumber AS rn WITH (NOLOCK) ON re.ReferenceNumberId = rn.ReferenceNumberId;

-- Step 5: Image, keyed only on the capped set
IF OBJECT_ID('tempdb..#Top100Images') IS NOT NULL DROP TABLE #Top100Images;
SELECT
    t.WatchId,
    mad.Url AS Image
INTO #Top100Images
FROM #Top100Watches AS t WITH (NOLOCK)
LEFT JOIN tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = t.WatchId AND mad.IsDeleted = 0 AND mad.IsPrimary = 1;

-- Step 6: Final combine -- only joins the small staged tables together
SELECT
    e.ManufacturerName,
    t.ReferenceEnrichmentId,
    e.ReferenceNumber,
    img.Image,
    t.ImageMatchScore
FROM #Top100Watches AS t WITH (NOLOCK)
JOIN #Top100EnrichmentInfo AS e WITH (NOLOCK) ON t.ReferenceEnrichmentId = e.ReferenceEnrichmentId
LEFT JOIN #Top100Images AS img WITH (NOLOCK) ON t.WatchId = img.WatchId
ORDER BY e.ManufacturerName, e.ReferenceNumber, t.ImageMatchScore DESC;

-- ============================================================
-- Third variant: same top-100-per-enrichment + ImageMatchScore > 0.70
-- pipeline as above, but restricted to "full ref" enrichments -- this
-- time defined by the LENGTH trick instead of the '-' check:
-- per ManufacturerId, the reference number(s) with the MAX LEN(ReferenceNumber)
-- for that brand are treated as the full refs.
-- Kept separate from the two queries above -- does not overwrite them.
-- ============================================================

-- Step 1: Distinct reference numbers that actually come from the
-- enrichment side (tbl_RE_ReferenceEnrichment), per brand -- NOT
-- every reference number in tblReferenceNumber
IF OBJECT_ID('tempdb..#EnrichmentRefNumbers') IS NOT NULL DROP TABLE #EnrichmentRefNumbers;
SELECT DISTINCT
    re.ManufacturerId,
    rn.ReferenceNumberId,
    rn.ReferenceNumber
INTO #EnrichmentRefNumbers
FROM tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
JOIN tblReferenceNumber AS rn WITH (NOLOCK) ON re.ReferenceNumberId = rn.ReferenceNumberId
WHERE rn.ReferenceNumber IS NOT NULL;

-- Step 2: Max ReferenceNumber length per brand, computed only from
-- enrichment-side reference numbers
IF OBJECT_ID('tempdb..#RefMaxLenPerBrand') IS NOT NULL DROP TABLE #RefMaxLenPerBrand;
SELECT
    ManufacturerId,
    MAX(LEN(ReferenceNumber)) AS MaxLen
INTO #RefMaxLenPerBrand
FROM #EnrichmentRefNumbers
GROUP BY ManufacturerId;

-- Step 3: Enrichment-side reference numbers whose length equals their
-- brand's max (the "full refs")
IF OBJECT_ID('tempdb..#LongestRefsPerBrand') IS NOT NULL DROP TABLE #LongestRefsPerBrand;
SELECT
    r.ReferenceNumberId,
    r.ReferenceNumber,
    r.ManufacturerId,
    m.ManufacturerName
INTO #LongestRefsPerBrand
FROM #EnrichmentRefNumbers AS r WITH (NOLOCK)
JOIN #RefMaxLenPerBrand AS mx WITH (NOLOCK) ON mx.ManufacturerId = r.ManufacturerId AND LEN(r.ReferenceNumber) = mx.MaxLen
JOIN tblManufacturer AS m WITH (NOLOCK) ON r.ManufacturerId = m.ManufacturerId;

-- Step 4: Enrichment rows tied to those longest/full refs only
IF OBJECT_ID('tempdb..#LenFullRefEnrichment') IS NOT NULL DROP TABLE #LenFullRefEnrichment;
SELECT
    re.ReferenceEnrichmentId,
    r.ReferenceNumberId,
    r.ReferenceNumber,
    r.ManufacturerName
INTO #LenFullRefEnrichment
FROM tbl_RE_ReferenceEnrichment AS re WITH (NOLOCK)
JOIN #LongestRefsPerBrand AS r WITH (NOLOCK) ON re.ReferenceNumberId = r.ReferenceNumberId;

-- Step 5: Stage watch -> enrichment mapping, restricted to those enrichments
-- (per the EveryWatch DB tblWatch_d staging rule)
IF OBJECT_ID('tempdb..#LenEnrichedWatches') IS NOT NULL DROP TABLE #LenEnrichedWatches;
SELECT
    wd.WatchId,
    wd.ReferenceEnrichmentId
INTO #LenEnrichedWatches
FROM tblWatch_d AS wd WITH (NOLOCK)
JOIN #LenFullRefEnrichment AS f WITH (NOLOCK) ON wd.ReferenceEnrichmentId = f.ReferenceEnrichmentId
WHERE wd.IsDeleted = 0;

-- Step 6: Rank each watch's ImageMatchScore within its enrichment,
-- keep only scores > 0.70 and the top 100 per ReferenceEnrichmentId
IF OBJECT_ID('tempdb..#LenTopWatchesPerEnrichment') IS NOT NULL DROP TABLE #LenTopWatchesPerEnrichment;
SELECT
    ew.WatchId,
    ew.ReferenceEnrichmentId,
    wer.ImageMatchScore,
    ROW_NUMBER() OVER (
        PARTITION BY ew.ReferenceEnrichmentId
        ORDER BY wer.ImageMatchScore DESC
    ) AS rn
INTO #LenTopWatchesPerEnrichment
FROM #LenEnrichedWatches AS ew WITH (NOLOCK)
JOIN TblWatchEnrichmentResults AS wer WITH (NOLOCK) ON wer.WatchId = ew.WatchId
WHERE wer.ImageMatchScore > 0.70;

IF OBJECT_ID('tempdb..#LenTop100PerEnrichment') IS NOT NULL DROP TABLE #LenTop100PerEnrichment;
SELECT WatchId, ReferenceEnrichmentId, ImageMatchScore
INTO #LenTop100PerEnrichment
FROM #LenTopWatchesPerEnrichment
WHERE rn <= 100;

-- Step 7: Image, keyed only on the capped set
IF OBJECT_ID('tempdb..#LenTop100Images') IS NOT NULL DROP TABLE #LenTop100Images;
SELECT
    t.WatchId,
    mad.Url AS Image
INTO #LenTop100Images
FROM #LenTop100PerEnrichment AS t WITH (NOLOCK)
LEFT JOIN tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = t.WatchId AND mad.IsDeleted = 0 AND mad.IsPrimary = 1;

-- Step 8: Final combine -- only joins the small staged tables together
SELECT
    f.ManufacturerName,
    t.ReferenceEnrichmentId,
    f.ReferenceNumber,
    img.Image,
    t.ImageMatchScore
FROM #LenTop100PerEnrichment AS t WITH (NOLOCK)
JOIN #LenFullRefEnrichment AS f WITH (NOLOCK) ON t.ReferenceEnrichmentId = f.ReferenceEnrichmentId
LEFT JOIN #LenTop100Images AS img WITH (NOLOCK) ON t.WatchId = img.WatchId
ORDER BY f.ManufacturerName, f.ReferenceNumber, t.ImageMatchScore DESC;

-- =====================================================================================
-- Per-brand count of unique reference structures used on the catalog side.
-- dbo.fn_ConvertToStructure() masks every letter to 'A' and every digit to 'X', keeping
-- separators (dashes, dots, slashes, spaces) as-is, e.g. "116610-LN" -> "XXXXXX-AA".
-- Counting DISTINCT results of that function per manufacturer tells us how many unique
-- reference structures are in use.
-- =====================================================================================

-- Step 1: Stage the catalog-side reference numbers (tbl_CAT_Catalog_d), active rows only
IF OBJECT_ID('tempdb..#CatalogRefs') IS NOT NULL DROP TABLE #CatalogRefs;
SELECT
    c.CatalogId,
    c.ManufacturerId,
    c.ReferenceNumber,
    dbo.fn_ConvertToStructure(c.ReferenceNumber) AS RefStructure
INTO #CatalogRefs
FROM tbl_CAT_Catalog_d AS c WITH (NOLOCK)
WHERE c.StatusID = 1
  AND c.ReferenceNumber IS NOT NULL
  AND c.ManufacturerId IS NOT NULL;

-- Step 2: Distinct reference structures per brand, staged once so the
-- comma-separated list in Step 3 aggregates over distinct values only
IF OBJECT_ID('tempdb..#DistinctCatalogRefStructures') IS NOT NULL DROP TABLE #DistinctCatalogRefStructures;
SELECT DISTINCT ManufacturerId, RefStructure
INTO #DistinctCatalogRefStructures
FROM #CatalogRefs;

-- Step 3: Count distinct reference structures per brand, plus a
-- comma-separated list of those distinct structures
SELECT
    m.ManufacturerId,
    m.ManufacturerName,
    COUNT(DISTINCT cr.RefStructure) AS RefStructureCount,
    COUNT(*) AS TotalCatalogRefs,
    dcr.RefStructures
FROM #CatalogRefs AS cr WITH (NOLOCK)
JOIN tbl_CAT_Manufacturer_d AS m WITH (NOLOCK) ON m.ManufacturerId = cr.ManufacturerId
CROSS APPLY (
    SELECT STRING_AGG(d.RefStructure, ', ') AS RefStructures
    FROM #DistinctCatalogRefStructures AS d
    WHERE d.ManufacturerId = cr.ManufacturerId
) AS dcr
GROUP BY m.ManufacturerId, m.ManufacturerName, dcr.RefStructures
ORDER BY RefStructureCount DESC;

-- =====================================================================================
-- Watches with MatchConfidence < 0.4 in TblWatchEnrichmentResults, with their images.
-- =====================================================================================

-- Step 1: Stage the exact low-confidence records (per the EveryWatch DB tblWatch_d
-- staging rule, staged first before joining out to the media asset table)
IF OBJECT_ID('tempdb..#LowConfidenceWatches') IS NOT NULL DROP TABLE #LowConfidenceWatches;
SELECT twer.*
INTO #LowConfidenceWatches
FROM TblWatchEnrichmentResults AS twer WITH (NOLOCK)
WHERE twer.MatchConfidence < 0.1 and enrichmenttypeid = 5;

-- Step 2: How many watches are below 0.4 match confidence
SELECT COUNT(*) AS LowConfidenceWatchCount
FROM #LowConfidenceWatches;

-- Step 3: Primary image per watch from tblMediaAsset_d
IF OBJECT_ID('tempdb..#LowConfidenceImages') IS NOT NULL DROP TABLE #LowConfidenceImages;
SELECT
    lcw.WatchId,
    mad.Url AS Image
INTO #LowConfidenceImages
FROM #LowConfidenceWatches AS lcw WITH (NOLOCK)
LEFT JOIN tblMediaAsset_d AS mad WITH (NOLOCK) ON mad.WatchId = lcw.WatchId AND (mad.IsDeleted = 0 or IsDeleted is null) AND mad.IsPrimary = 1;

-- Step 3b: Each watch's own ReferenceEnrichmentId (per the EveryWatch DB
-- tblWatch_d staging rule -- staged here, not joined inline)
IF OBJECT_ID('tempdb..#LowConfidenceWatchEnrichmentIds') IS NOT NULL DROP TABLE #LowConfidenceWatchEnrichmentIds;
SELECT
    wd.WatchId,
    wd.ReferenceEnrichmentId
INTO #LowConfidenceWatchEnrichmentIds
FROM tblWatch_d AS wd WITH (NOLOCK)
WHERE wd.WatchId IN (SELECT WatchId FROM #LowConfidenceWatches)
  AND (wd.IsDeleted = 0 OR wd.IsDeleted IS NULL);

-- Step 3c: Primary enrichment image, from tbl_RE_ReferenceEnrichmentMediaAsset,
-- for that watch's ReferenceEnrichmentId
IF OBJECT_ID('tempdb..#LowConfidenceEnrichmentImages') IS NOT NULL DROP TABLE #LowConfidenceEnrichmentImages;
SELECT
    lwe.WatchId,
    rem.SourceUrl AS EnrichmentImage
INTO #LowConfidenceEnrichmentImages
FROM #LowConfidenceWatchEnrichmentIds AS lwe WITH (NOLOCK)
LEFT JOIN tbl_RE_ReferenceEnrichmentMediaAsset AS rem WITH (NOLOCK)
    ON rem.ReferenceEnrichmentId = lwe.ReferenceEnrichmentId
    AND (rem.IsDeleted = 0 OR rem.IsDeleted IS NULL)
    AND rem.IsPrimary = 1;

-- Step 4: Final detail -- the exact TblWatchEnrichmentResults records (all columns)
-- plus the watch's current primary image from tblMediaAsset_d, its
-- ReferenceEnrichmentId, and that enrichment's primary image
SELECT
    lcw.*,
    img.Image,
    lwe.ReferenceEnrichmentId,
    lei.EnrichmentImage
FROM #LowConfidenceWatches AS lcw WITH (NOLOCK)
LEFT JOIN #LowConfidenceImages AS img WITH (NOLOCK) ON lcw.WatchId = img.WatchId
LEFT JOIN #LowConfidenceWatchEnrichmentIds AS lwe WITH (NOLOCK) ON lcw.WatchId = lwe.WatchId
LEFT JOIN #LowConfidenceEnrichmentImages AS lei WITH (NOLOCK) ON lcw.WatchId = lei.WatchId
ORDER BY lcw.MatchConfidence ASC;

Select count(*)
From TblWatchEnrichmentResults (NOLOCK)
where MatchConfidence < 0.1
order by MatchConfidence asc;

