-- ============================================================

-- 1. Table DDL: dbo.tbl_RAW_ArtworkTax (EWMaster)
--    Tracked source: D:\EW\ew-db\MasterDB\dbo\table\tbl_RAW_ArtworkTax.sql
-- ============================================================
-- USE [EWMaster]
-- GO
-- /****** Object:  Table [dbo].[tbl_RAW_ArtworkTax] ******/
-- SET ANSI_NULLS ON
-- GO
-- SET QUOTED_IDENTIFIER ON
-- GO
-- CREATE TABLE [dbo].[tbl_RAW_ArtworkTax](
-- 	[Id] [bigint] IDENTITY(1,1) NOT NULL,
-- 	[SourceId] [int] NOT NULL,
-- 	[AuctionId] [varchar](30) NOT NULL,
-- 	[ArtworkId] [varchar](30) NOT NULL,
-- 	[Tax] [nvarchar](50) NULL,
-- 	[CreatedDate] [datetime] NOT NULL,
-- PRIMARY KEY CLUSTERED
-- (
-- 	[Id] ASC
-- )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
-- ) ON [PRIMARY]
-- GO
-- ALTER TABLE [dbo].[tbl_RAW_ArtworkTax] ADD DEFAULT (getdate()) FOR [CreatedDate]
-- GO
-- /****** Object:  Index [idx_tbl_RAW_ArtworkTax]    Prevents duplicate loads for the same crawler artwork ******/
-- CREATE UNIQUE NONCLUSTERED INDEX [idx_tbl_RAW_ArtworkTax] ON [dbo].[tbl_RAW_ArtworkTax]
-- (
-- 	[SourceId] ASC,
-- 	[AuctionId] ASC,
-- 	[ArtworkId] ASC
-- )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
-- GO
--
--
-- -- ============================================================
-- -- 2. Batched load: Artworks (crawler) -> dbo.tbl_RAW_ArtworkTax (EWMaster)
-- --    Tracked source: D:\EW\Scripts\Queries\Ravi\Sync Issues\ArtworkTax-Load.sql
-- --
-- --    - Filters to the same source scope sp_SYNC_SyncWatchesCatalog uses:
-- --      Sources.SourceDataType = 5 AND Sources.Project = 'w'.
-- --    - Does NOT rely on ArtworkId being numeric/sortable. Instead:
-- --        Step 1: one filtered pass over the remote data (no ORDER BY needed)
-- --                pulling only the narrow key columns into a local #temp table
-- --                with a LOCAL IDENTITY column (#ArtworkKeys.BatchSeq).
-- --        Step 2: batch-loop over that local, guaranteed-numeric BatchSeq
-- --                range, joining back to remote Artworks by exact key match
-- --                (SourceId + AuctionId + ArtworkId) to fetch Tax per batch.
-- --    - Resumable: Step 1's NOT EXISTS skips rows already loaded, so re-running
-- --      after an interruption only stages/loads what's still missing.
-- -- ============================================================
-- USE [EWMaster]
-- GO
--
-- SET NOCOUNT ON;
--
-- DECLARE @BatchSize INT = 5000;   -- tune based on linked-server/network performance
--
-- IF OBJECT_ID('tempdb..#ArtworkKeys') IS NOT NULL DROP TABLE #ArtworkKeys;
--
-- CREATE TABLE #ArtworkKeys
-- (
--     BatchSeq  INT IDENTITY(1,1) PRIMARY KEY,
--     SourceId  INT NOT NULL,
--     AuctionId VARCHAR(30) NOT NULL,
--     ArtworkId VARCHAR(30) NOT NULL
-- );
--
-- -- Step 1: stage the qualifying, not-yet-loaded keys locally (single filtered scan, no remote sort)
-- INSERT INTO #ArtworkKeys (SourceId, AuctionId, ArtworkId)
-- SELECT a.SourceId,
--        a.AuctionId,
--        a.Id
-- FROM [EC2AMAZ-K9AGUNN].MACrawler_.dbo.Artworks AS a WITH (NOLOCK)
--     INNER JOIN [EC2AMAZ-K9AGUNN].MACrawler_.dbo.Sources AS s WITH (NOLOCK)
--         ON s.Id = a.SourceId
-- WHERE s.SourceDataType = 5
--   AND s.Project = 'w'
--   AND NOT EXISTS (
--         SELECT 1
--         FROM dbo.tbl_RAW_ArtworkTax AS t WITH (NOLOCK)
--         WHERE t.SourceId = a.SourceId
--           AND t.AuctionId = a.AuctionId
--           AND t.ArtworkId = a.Id
--       );
--
-- -- Step 2: batch-process using the local BatchSeq range (always numeric, always ordered)
-- DECLARE @MinSeq INT, @MaxSeq INT;
-- SELECT @MinSeq = MIN(BatchSeq), @MaxSeq = MAX(BatchSeq) FROM #ArtworkKeys;
--
-- WHILE @MinSeq IS NOT NULL AND @MinSeq <= @MaxSeq
-- BEGIN
--     INSERT INTO dbo.tbl_RAW_ArtworkTax (SourceId, AuctionId, ArtworkId, Tax)
--     SELECT k.SourceId,
--            k.AuctionId,
--            k.ArtworkId,
--            a.Tax
--     FROM #ArtworkKeys AS k
--         INNER JOIN [EC2AMAZ-K9AGUNN].MACrawler_.dbo.Artworks AS a WITH (NOLOCK)
--             ON a.SourceId = k.SourceId
--            AND a.AuctionId = k.AuctionId
--            AND a.Id = k.ArtworkId
--     WHERE k.BatchSeq BETWEEN @MinSeq AND @MinSeq + @BatchSize - 1;
--
--     PRINT CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows inserted for BatchSeq ' + CAST(@MinSeq AS VARCHAR(20)) + '-' + CAST(@MinSeq + @BatchSize - 1 AS VARCHAR(20));
--
--     SET @MinSeq = @MinSeq + @BatchSize;
-- END
--
-- DROP TABLE #ArtworkKeys;





Select *
From dbo.tbl_CAT_Edition_d tCEd (NOLOCK)

Select *
From tbl_CAT_RawCatalogMapping (NOLOCK)

Select *
From dbo.tbl_MAP_RawCatalog_CatalogCountry tMRCCC (NOLOCK)


select *
from dbo.tbl_CAT_CatalogRetailPrice_d tCCRPd (nolock)
where tCCRPd.StatusID=2
;

Select *
From dbo.tbl_CAT_Manufacturer_d tCMd (NOLOCK)


INSERT INTO EWMaster.dbo.tbl_CAT_Manufacturer_d (ManufacturerName, CreatedDate, UpdatedDate, UserId, TransactionID, StatusID) VALUES (N'Accutron', N'2023-09-27 18:54:55.070', N'2023-09-27 18:54:55.070', null, 1, 1);

Select *
From dbo.tbl_CAT_Material_d tCMd (NOLOCK)

INSERT INTO EWMaster.dbo.tbl_CAT_Material_d (MaterialName, CreatedDate, UpdatedDate, UserId, TransactionID, StatusID) VALUES (N'Moissanite', getutcdate(), getutcdate(), 6, 343676, 1);


use everywatch
SELECT v.Tier,
COUNT(DISTINCT m.WatchId) AS Watches,
COUNT(DISTINCT v.CandidateVariationId) AS Variations
FROM tbl_AG_CandidateVariationMember m
JOIN tbl_AG_CandidateVariation v ON v.CandidateVariationId = m.CandidateVariationId
WHERE v.ManufacturerId = 193
GROUP BY v.Tier;


Select *
From tbl_AG_CandidateVariationMember (NOLOCK)

Select *
From tbl_AG_CandidateVariation (NOLOCK)
WHERE ManufacturerId=193

use ewmaster
exec sp_map_rawCatalog_catalogCountry
-- ============================================================
-- Rename detection: for each active draft catalog row, show EVERY mirror
-- (history) row for that CatalogId whose ReferenceNumber and/or ModelName
-- differs from the current active values -- not just the latest mirror row.
--
-- Schema notes (confirmed against D:\EW\ew-db\MasterDB):
--   - dbo.tbl_CAT_Catalog_d has no ModelName column; ModelName lives on
--     dbo.tbl_CAT_Model_d and is joined via ModelId, so a "model rename"
--     here means the catalog row now points at a different ModelId.
--   - "Active" = StatusID = 1 (confirmed via sp_Get_CatalogDetails.sql /
--     sp_Delete_Catalog.sql usage; StatusID = 3 is soft-deleted).
--   - MIRROR.EWMaster.tbl_CAT_Catalog_d_m is populated by trigger
--     tr_UD_tbl_CAT_Catalog_d on UPDATE/DELETE of tbl_CAT_Catalog_d, i.e.
--     it holds the PRIOR row values before each change -- a CatalogId can
--     have multiple history rows, one per change. All of them are returned
--     here (no "latest only" filter), so a CatalogId that was renamed more
--     than once will appear multiple times, one row per differing mirror
--     snapshot.
--
-- ASSUMPTION TO VERIFY BEFORE RUNNING (mirror table lives on a linked
-- server, not in this repo, so it could not be confirmed here):
--   tbl_CAT_Catalog_d_m is assumed to have a MirrorDate column (matching
--   the pattern documented in
--   Queries\Ravi\Retail Price\mirror-updated-date-issue.md for
--   tbl_raw_catalog_m), included below for ordering/context only -- it is
--   not used to filter rows. Run the check below first to confirm it
--   exists / is named this.
-- ============================================================

-- Step 0: confirm the mirror table's actual columns
SELECT TOP 5 *
FROM MIRROR.EWMaster.tbl_CAT_Catalog_d_m WITH (NOLOCK)
ORDER BY CatalogId DESC;

-- Step 1: rename detection -- one row per active CatalogId: the EARLIEST
-- mirror row (by MirrorDate) that differs from current on
-- ReferenceNumber/ModelName, i.e. the first-observed occurrence of the
-- change. (Repeated mirror snapshots that carry the same pre-change value
-- -- e.g. from unrelated updates before the actual rename took effect --
-- collapse down to this single earliest row via ROW_NUMBER.)
;WITH ChangedRows AS (
    SELECT
        tccd.CatalogId,
        tccd.ManufacturerId,
        tccd.StatusID,
        tccd.ReferenceNumber   AS Current_ReferenceNumber,
        tccdm.ReferenceNumber  AS Mirror_ReferenceNumber,
        curModel.ModelName     AS Current_ModelName,
        prevModel.ModelName    AS Mirror_ModelName,
        tccd.ModelId           AS Current_ModelId,
        tccdm.ModelId           AS Mirror_ModelId,
        tccdm.MirrorDate        AS MirrorDate,
        CASE
            WHEN ISNULL(tccd.ReferenceNumber,'') <> ISNULL(tccdm.ReferenceNumber,'')
                 AND ISNULL(curModel.ModelName,'') <> ISNULL(prevModel.ModelName,'')
                THEN 'ReferenceNumber + ModelName changed'
            WHEN ISNULL(tccd.ReferenceNumber,'') <> ISNULL(tccdm.ReferenceNumber,'')
                THEN 'ReferenceNumber changed'
            WHEN ISNULL(curModel.ModelName,'') <> ISNULL(prevModel.ModelName,'')
                THEN 'ModelName changed'
        END AS ChangeType,
        ROW_NUMBER() OVER (PARTITION BY tccd.CatalogId ORDER BY tccdm.MirrorDate ASC) AS rn
    FROM dbo.tbl_CAT_Catalog_d AS tccd WITH (NOLOCK)
    INNER JOIN MIRROR.EWMaster.tbl_CAT_Catalog_d_m AS tccdm WITH (NOLOCK)
        ON tccdm.CatalogId = tccd.CatalogId
    LEFT JOIN dbo.tbl_CAT_Model_d AS curModel WITH (NOLOCK) ON curModel.ModelId = tccd.ModelId
    LEFT JOIN dbo.tbl_CAT_Model_d AS prevModel WITH (NOLOCK) ON prevModel.ModelId = tccdm.ModelId
    WHERE tccd.ManufacturerId IN (10,11,37,49,56,63,64,68,83,101,125,133,147,190,193,232,233,234,235,236,237,241,242,243,244,245,250,251,252,253,254,256,257)
      AND tccd.StatusID = 1
      AND (
            ISNULL(tccd.ReferenceNumber,'') <> ISNULL(tccdm.ReferenceNumber,'')
            OR ISNULL(curModel.ModelName,'') <> ISNULL(prevModel.ModelName,'')
          )
)
SELECT
    CatalogId, ManufacturerId, StatusID,
    Current_ReferenceNumber, Mirror_ReferenceNumber,
    Current_ModelName, Mirror_ModelName,
    Current_ModelId, Mirror_ModelId,
    MirrorDate, ChangeType
FROM ChangedRows
WHERE rn = 1
ORDER BY ManufacturerId, CatalogId;


-- ============================================================
-- Orphaned soft-deleted catalogs: rows in tbl_CAT_Catalog_d with
-- StatusID = 3 (soft-deleted via sp_Delete_Catalog -- the row still
-- physically exists, just marked deleted) whose ReferenceNumber is not
-- used by any OTHER row in tbl_CAT_Catalog_d (any status), and whose
-- ModelId is likewise not used by any other row.
--
-- "Unused elsewhere" is checked against the whole table (regardless of
-- status), excluding the deleted row itself. If you want "unused" to
-- mean only among currently-active (StatusID = 1) rows, add
-- "AND t2.StatusID = 1" / "AND t3.StatusID = 1" to the two NOT EXISTS
-- subqueries below.
--
-- ReferenceNumberUnusedElsewhere / ModelUnusedElsewhere are exposed as
-- flags so you can see each signal individually; the WHERE clause
-- currently requires BOTH to be true (fully orphaned -- no trace of
-- either the old reference number or the old model left in the table).
-- Change the WHERE's AND to OR if you want either condition alone to
-- qualify.
-- ============================================================
SELECT
    del.CatalogId,
    del.ManufacturerId,
    del.ReferenceNumber,
    del.ModelId,
    delModel.ModelName AS ModelName,
    del.StatusID,
    CASE WHEN NOT EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t2 WITH (NOLOCK)
            WHERE t2.ReferenceNumber = del.ReferenceNumber
              AND t2.CatalogId <> del.CatalogId
              AND t2.StatusID <> 3
        ) THEN 1 ELSE 0 END AS ReferenceNumberUnusedElsewhere,
    CASE WHEN del.ModelId IS NULL OR NOT EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t3 WITH (NOLOCK)
            WHERE t3.ModelId = del.ModelId
              AND t3.CatalogId <> del.CatalogId
              AND t3.StatusID <> 3
        ) THEN 1 ELSE 0 END AS ModelUnusedElsewhere
FROM dbo.tbl_CAT_Catalog_d AS del WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Model_d AS delModel WITH (NOLOCK) ON delModel.ModelId = del.ModelId
WHERE del.ManufacturerId IN (10,11,37,49,56,63,64,68,83,101,125,133,147,190,193,232,233,234,235,236,237,241,242,243,244,245,250,251,252,253,254,256,257)
  AND del.StatusID = 3
  AND NOT EXISTS (
        SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t2 WITH (NOLOCK)
        WHERE t2.ReferenceNumber = del.ReferenceNumber
          AND t2.CatalogId <> del.CatalogId
          AND t2.StatusID <> 3
      )
  AND (
        del.ModelId IS NULL
        OR NOT EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t3 WITH (NOLOCK)
            WHERE t3.ModelId = del.ModelId
              AND t3.CatalogId <> del.CatalogId
              AND t3.StatusID <> 3
        )
      )
ORDER BY del.ManufacturerId, del.CatalogId;


-- ============================================================
-- Watches per InfoSource: total watches vs. total watches that have an
-- enrichment (ReferenceEnrichmentId IS NOT NULL), grouped by source name.
-- (EveryWatchDDL app DB -- tblWatch.InfoSourceId, tblWatch.ReferenceEnrichmentId,
-- tblInfoSource.Name confirmed in D:\EW\ew-db\EveryWatchDDL\dbo\table\)
-- ============================================================
IF OBJECT_ID('tempdb..#tblWatch') IS NOT NULL DROP TABLE #tblWatch;

SELECT
    WatchId,
    InfoSourceId,
    ReferenceEnrichmentId
INTO #tblWatch
FROM dbo.tblWatch WITH (NOLOCK);

SELECT
    ISNULL([is].Name, 'Unknown') AS SourceName,
    COUNT(*) AS TotalWatches,
    SUM(CASE WHEN w.ReferenceEnrichmentId IS NOT NULL THEN 1 ELSE 0 END) AS TotalWatchesWithEnrichment
FROM #tblWatch AS w
LEFT JOIN dbo.tblInfoSource AS [is] WITH (NOLOCK) ON w.InfoSourceId = [is].InfoSourceId
GROUP BY [is].Name
ORDER BY TotalWatches DESC;

DROP TABLE #tblWatch;


-- ============================================================
-- 1) Soft-deleted (StatusID = 3) catalogs whose ReferenceNumber is not
--    used by any OTHER row with StatusID <> 3 -- independent of what
--    happens with ModelId.
-- ============================================================
SELECT
    del.CatalogId,
    del.ManufacturerId,
    del.ReferenceNumber,
    del.ModelId,
    delModel.ModelName AS ModelName,
    del.StatusID
FROM dbo.tbl_CAT_Catalog_d AS del WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Model_d AS delModel WITH (NOLOCK) ON delModel.ModelId = del.ModelId
WHERE del.ManufacturerId IN (10,11,37,49,56,63,64,68,83,101,125,133,147,190,193,232,233,234,235,236,237,241,242,243,244,245,250,251,252,253,254,256,257)
  AND del.StatusID = 3
  AND NOT EXISTS (
        SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t2 WITH (NOLOCK)
        WHERE t2.ReferenceNumber = del.ReferenceNumber
          AND t2.CatalogId <> del.CatalogId
          AND t2.StatusID <> 3
      )
ORDER BY del.ManufacturerId, del.CatalogId;


-- ============================================================
-- 2) Soft-deleted (StatusID = 3) catalogs whose ModelId is not used by
--    any OTHER row with StatusID <> 3 -- independent of what happens
--    with ReferenceNumber.
-- ============================================================
SELECT
    del.CatalogId,
    del.ManufacturerId,
    del.ReferenceNumber,
    del.ModelId,
    delModel.ModelName AS ModelName,
    del.StatusID
FROM dbo.tbl_CAT_Catalog_d AS del WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Model_d AS delModel WITH (NOLOCK) ON delModel.ModelId = del.ModelId
WHERE del.ManufacturerId IN (10,11,37,49,56,63,64,68,83,101,125,133,147,190,193,232,233,234,235,236,237,241,242,243,244,245,250,251,252,253,254,256,257)
  AND del.StatusID = 3
  AND del.ModelId IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM dbo.tbl_CAT_Catalog_d AS t3 WITH (NOLOCK)
        WHERE t3.ModelId = del.ModelId
          AND t3.CatalogId <> del.CatalogId
          AND t3.StatusID <> 3
      )
ORDER BY del.ManufacturerId, del.CatalogId;


-- ============================================================
-- Repurpose the EXISTING dbo.tbl_CAT_Catalog_d.RefProductionStatusID
-- column to encode "seen in last run", derived from
-- dbo.tbl_MAP_RawCatalog_CatalogCountry (one row per CatalogId+CountryId):
--   RefProductionStatusID = 1  when the catalog counts as SEEN
--   RefProductionStatusID = 2  when the catalog counts as NOT SEEN
--
-- CONFIRMED WITH YOU: RefProductionStatusID is an existing, actively-used
-- column (joined in sp_Get_CatalogDetails.sql, propagated into
-- tbl_RE_ReferenceEnrichment.RefProductionStatusId per CMS-11756, and
-- consumed by several reporting views/SPs) -- this intentionally
-- overwrites its prior "reference production status" meaning with this
-- new seen/not-seen meaning. Confirm tbl_CAT_Reference_ProductionStatus_d
-- rows 1 and 2 (Name column) match your intent before running -- that
-- table's seed data isn't tracked in the ew-db repo so it could not be
-- checked here.
--
-- IMPORTANT CAVEAT: tbl_MAP_RawCatalog_CatalogCountry and
-- tbl_MAP_RawCatalog_CatalogCountry_Ambiguous are NOT tracked in the
-- ew-db repo -- their columns below are inferred only from the
-- sp_map_rawCatalog_catalogCountry body you pasted, not verified against
-- an actual DDL file. Confirm column names/types before running.
--
-- Rules confirmed with you:
--   - tbl_MAP_RawCatalog_CatalogCountry_Ambiguous IS now included as an
--     additional vote source, but collapsed BEFORE voting: many different
--     RawCatalogIds can share the exact same CandidateCatalogIds list
--     (i.e. many raw listings hit the same ambiguous candidate set). All
--     RawCatalogIds sharing one CandidateCatalogIds string are grouped
--     together, their IsSeenInLastRun values (from dbo.tbl_RAW_Catalog via
--     RawCatalogId = Id) are collapsed via MAX(), and that ONE resulting
--     value becomes a SINGLE vote applied to EACH candidate CatalogId in
--     that shared list -- not one vote per RawCatalogId. Duplicate
--     CatalogIds repeated within one CandidateCatalogIds string (a
--     separate data artifact from missing DISTINCT in the SP's
--     STRING_AGG) are also collapsed via SELECT DISTINCT.
--   - These ambiguous-derived votes are pooled together with the
--     confirmed map-table votes (unchanged, one vote per non-deleted
--     CatalogId+CountryId row) into one combined per-CatalogId vote count
--     before the majority calculation.
--   - A CatalogId can have multiple votes (from either source). "Seen" =
--     MAJORITY vote across ALL of that CatalogId's votes: counts as seen
--     only if strictly more than half are IsSeenInLastRun = 1. An exact
--     tie (e.g. 5 of 10) counts as NOT seen. A CatalogId with zero votes
--     from either source also counts as NOT seen (RefProductionStatusID = 2).
-- ============================================================

;WITH ConfirmedVotes AS (
    SELECT
        m.CatalogId,
        CAST(ISNULL(m.IsSeenInLastRun, 0) AS INT) AS Vote
    FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS m WITH (NOLOCK)
    WHERE ISNULL(m.IsDeleted, 0) = 0
),
AmbiguousGroupVote AS (
    SELECT
        a.CandidateCatalogIds,
        MAX(CAST(ISNULL(r.IsSeenInLastRun, 0) AS INT)) AS Vote
    FROM dbo.tbl_MAP_RawCatalog_CatalogCountry_Ambiguous AS a WITH (NOLOCK)
    INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
        ON r.Id = a.RawCatalogId
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(a.CandidateCatalogIds, N''))), N'') IS NOT NULL
    GROUP BY a.CandidateCatalogIds
),
AmbiguousVotes AS (
    SELECT DISTINCT
        TRY_CAST(LTRIM(RTRIM(s.value)) AS INT) AS CatalogId,
        g.Vote
    FROM AmbiguousGroupVote AS g
    CROSS APPLY STRING_SPLIT(g.CandidateCatalogIds, ',') AS s
    WHERE TRY_CAST(LTRIM(RTRIM(s.value)) AS INT) IS NOT NULL
),
AllVotes AS (
    SELECT CatalogId, Vote FROM ConfirmedVotes
    UNION ALL
    SELECT CatalogId, Vote FROM AmbiguousVotes
),
CatalogSeenAgg AS (
    SELECT
        CatalogId,
        MAX(Vote) AS IsSeen
    FROM AllVotes
    GROUP BY CatalogId
)
UPDATE cd
SET cd.RefProductionStatusID = CASE WHEN ISNULL(agg.IsSeen, 0) = 1 THEN 1 ELSE 2 END
FROM dbo.tbl_CAT_Catalog_d AS cd
JOIN CatalogSeenAgg AS agg
    ON agg.CatalogId = cd.CatalogId;


-- ============================================================
-- Top 10 watches per (ReferenceNumber, DialColor, CaseMaterial), images
-- comma-separated. EveryWatch app DB -- tblWatch_d staged into #temp per
-- standing project rule before joining.
--
-- Schema per the reference query you provided:
--   - DialColor is many-to-many: tblWatchToDialColor_d (WatchId, DialColorId)
--     -> tblColor.ColorName. A watch's dial colors are folded into one
--     comma-joined string via STRING_AGG (a watch can have >1 dial color).
--   - CaseMaterial is many-to-many: tblWatchToCaseMaterial_d
--     (WatchId, CaseMaterialId) -> tblCaseMaterial.CaseMaterialName. Same
--     STRING_AGG treatment.
--   - "Both having the values" = watch has at least one dial-color row AND
--     at least one case-material row (i.e. both aggregated strings are
--     NOT NULL).
--   - Image = PrimaryImage per watch from tblMediaAsset_d, using the same
--     TOP 1 / COALESCE / IsPrimary DESC, MediaAssetId ASC pattern as your
--     reference query, filtered to the draft WatchId (tblWatch_d.WatchId).
--   - Output is grouped by the (ReferenceNumber, DialColorName,
--     CaseMaterialName) combination -- if a reference has watches with
--     different dial-color/case-material combinations, each distinct
--     combination gets its own output row (needed to keep DialColor/
--     CaseMaterial single-valued per row while still listing up to 10
--     watches' images for that row).
--
-- Fill in your reference numbers in #RefList below.
-- ============================================================

IF OBJECT_ID('tempdb..#RefList') IS NOT NULL DROP TABLE #RefList;
CREATE TABLE #RefList (ReferenceNumber NVARCHAR(200));
INSERT INTO #RefList (ReferenceNumber) VALUES
    (N'REPLACE_ME_1'),
    (N'REPLACE_ME_2');
    -- add as many as you have

-- Step 1: start from ALL of #RefList first, then LEFT JOIN out to
-- tblReferenceNumber and tblWatch_d to pick up whatever WatchIds exist --
-- every reference number you listed is kept here even if it turns out to
-- have zero matching watches (WatchId comes back NULL in that case).
IF OBJECT_ID('tempdb..#WatchIds') IS NOT NULL DROP TABLE #WatchIds;
SELECT
    rl.ReferenceNumber,
    wd.WatchId
INTO #WatchIds
FROM #RefList AS rl WITH (NOLOCK)
LEFT JOIN dbo.tblReferenceNumber AS r WITH (NOLOCK)
    ON r.CleanName = rl.ReferenceNumber
LEFT JOIN dbo.tblWatch_d AS wd WITH (NOLOCK)
    ON wd.ReferenceNumberId = r.ReferenceNumberId;

-- Step 2: pull full watch details (dial color / case material / primary
-- image / publish watch id) ONLY for those WatchIds -- the expensive
-- per-watch subqueries run against this small, pre-filtered set instead
-- of all of tblWatch_d.
IF OBJECT_ID('tempdb..#tblWatch') IS NOT NULL DROP TABLE #tblWatch;
SELECT
    wi.ReferenceNumber,
    wi.WatchId,
    DialColorName = (
        SELECT STRING_AGG(c.ColorName, ', ') WITHIN GROUP (ORDER BY c.ColorName)
        FROM dbo.tblWatchToDialColor_d AS wdcd WITH (NOLOCK)
        INNER JOIN dbo.tblColor AS c WITH (NOLOCK)
            ON c.ColorId = wdcd.DialColorId
        WHERE wdcd.WatchId = wi.WatchId
    ),
    CaseMaterialName = (
        SELECT STRING_AGG(cm.CaseMaterialName, ', ') WITHIN GROUP (ORDER BY cm.CaseMaterialName)
        FROM dbo.tblWatchToCaseMaterial_d AS wcmd WITH (NOLOCK)
        INNER JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK)
            ON cm.CaseMaterialId = wcmd.CaseMaterialId
        WHERE wcmd.WatchId = wi.WatchId
    ),
    PrimaryImage = (
        SELECT TOP 1 COALESCE(ma.Original, ma.Preview1366, ma.Preview768, ma.Preview480, ma.Preview320)
        FROM dbo.tblMediaAsset_d AS ma WITH (NOLOCK)
        WHERE ma.WatchId = wi.WatchId
          AND (ma.IsDeleted = 0 OR ma.IsDeleted IS NULL)
        ORDER BY ma.IsPrimary DESC, ma.MediaAssetId ASC
    ),
    PublishWatchId = (
        SELECT TOP 1 tw.WatchId
        FROM dbo.tblWatch AS tw WITH (NOLOCK)
        WHERE tw.WatchListingDraftId = wi.WatchId
    )
INTO #tblWatch
FROM #WatchIds AS wi WITH (NOLOCK);

;WITH Matched AS (
    SELECT
        t.ReferenceNumber,
        t.DialColorName,
        t.CaseMaterialName,
        t.WatchId,
        t.PrimaryImage,
        t.PublishWatchId
    FROM #tblWatch AS t WITH (NOLOCK)
    WHERE t.DialColorName IS NOT NULL
      AND t.CaseMaterialName IS NOT NULL
),
Ranked AS (
    SELECT
        m.*,
        ROW_NUMBER() OVER (
            PARTITION BY m.ReferenceNumber, m.DialColorName, m.CaseMaterialName
            ORDER BY m.WatchId
        ) AS rn
    FROM Matched AS m
)
SELECT
    ReferenceNumber,
    DialColorName AS DialColor,
    CaseMaterialName AS CaseMaterial,
    STRING_AGG(PrimaryImage, ',') WITHIN GROUP (ORDER BY WatchId) AS Images,
    STRING_AGG(CAST(PublishWatchId AS VARCHAR(20)), ',') WITHIN GROUP (ORDER BY WatchId) AS PublishWatchIds
FROM Ranked
WHERE rn <= 10
GROUP BY ReferenceNumber, DialColorName, CaseMaterialName;


-- ============================================================
-- Diagnostic: which #RefList reference numbers dropped out before the
-- final output, and why. #tblWatch already holds every row from #WatchIds
-- (built as a plain pull with no filtering), including the WatchId IS NULL
-- placeholder rows for refs with zero matching watches -- so this queries
-- #tblWatch directly rather than needing to re-touch #WatchIds.
-- Run this in the SAME session/batch right after the main query above,
-- since these are session-scoped temp tables.
-- ============================================================
SELECT
    t.ReferenceNumber,
    COUNT(*) AS TotalWatchRows,
    SUM(CASE WHEN t.WatchId IS NULL THEN 1 ELSE 0 END) AS NoWatchAtAll,
    SUM(CASE WHEN t.WatchId IS NOT NULL AND t.DialColorName IS NULL THEN 1 ELSE 0 END) AS WatchesMissingDialColor,
    SUM(CASE WHEN t.WatchId IS NOT NULL AND t.CaseMaterialName IS NULL THEN 1 ELSE 0 END) AS WatchesMissingCaseMaterial,
    SUM(CASE WHEN t.DialColorName IS NOT NULL AND t.CaseMaterialName IS NOT NULL THEN 1 ELSE 0 END) AS WatchesWithBoth
FROM #tblWatch AS t WITH (NOLOCK)
GROUP BY t.ReferenceNumber
HAVING SUM(CASE WHEN t.DialColorName IS NOT NULL AND t.CaseMaterialName IS NOT NULL THEN 1 ELSE 0 END) = 0
ORDER BY t.ReferenceNumber;


-- ============================================================
-- dbo.tbl_CAT_Model_d: find ModelName "duplicates" that only differ by
-- spaces/special characters -- e.g. "Sea-Dweller" vs "SeaDweller " vs
-- "sea dweller" would all normalize to the same value.
--
-- Reuses the EXISTING dbo.fn_ExtractNumbersAndAlphabets function (EWMaster,
-- confirmed in MasterDB\dbo\function\fn_ExtractNumbersAndAlphabets.sql)
-- rather than writing new normalization logic -- it strips every
-- non-alphanumeric character and lowercases the result.
--
-- Scope confirmed with you:
--   - Duplicates are checked WITHIN the same ManufacturerId only (two
--     different brands sharing a normalized model name is not a dup).
--   - Only StatusID = 1 (active) rows are compared.
-- ============================================================
;WITH ModelNormalized AS (
    SELECT
        m.ModelId,
        m.ManufacturerId,
        m.ModelName,
        dbo.fn_ExtractNumbersAndAlphabets(m.ModelName) AS NormalizedModelName
    FROM dbo.tbl_CAT_Model_d AS m WITH (NOLOCK)
    WHERE m.StatusID = 1
      AND m.ModelName IS NOT NULL
)
SELECT
    mn.ManufacturerId,
    mn.NormalizedModelName,
    COUNT(*) AS DuplicateCount,
    STRING_AGG(CAST(mn.ModelId AS VARCHAR(11)), ', ') WITHIN GROUP (ORDER BY mn.ModelId) AS ModelIds,
    STRING_AGG(mn.ModelName, ' | ') WITHIN GROUP (ORDER BY mn.ModelId) AS ModelNameVariants
FROM ModelNormalized AS mn
GROUP BY mn.ManufacturerId, mn.NormalizedModelName
HAVING COUNT(*) > 1
ORDER BY mn.ManufacturerId, mn.NormalizedModelName;


-- ============================================================
-- Per reference number (Richard Mille, via your existing
-- sp_Get_CatalogDetails ##richardm pattern): how many catalogs are
-- assigned to it in tbl_CAT_Catalog_d, how many of those have an active
-- retail price row in tbl_CAT_CatalogRetailPrice_d, and which CatalogIds
-- those are.
--
-- Note: ##richardm's contents are whatever sp_Get_CatalogDetails already
-- filters to (confirmed earlier as StatusID IN (1,2) on tbl_CAT_Catalog_d)
-- -- this query doesn't add its own StatusID filter on top of that, it
-- just counts what the SP already returned.
--
-- "Has retail price" = EXISTS at least one tbl_CAT_CatalogRetailPrice_d
-- row for that CatalogID with StatusID = 1 (active), matching the filter
-- in the example query you pasted. A catalog with multiple retail price
-- rows (different countries/currencies) still only counts once.
-- ============================================================
EXEC sp_Get_CatalogDetails @ManufacturerName = 'richard mille', @TempTableName = '##richardm';

;WITH CatalogRetailFlag AS (
    SELECT
        r.CatalogId,
        r.ReferenceNumber,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_CatalogRetailPrice_d AS tccrpd WITH (NOLOCK)
            WHERE tccrpd.CatalogID = r.CatalogId
              AND tccrpd.StatusID = 1
        ) THEN 1 ELSE 0 END AS HasRetailPrice
    FROM ##richardm AS r WITH (NOLOCK)
)
SELECT
    ReferenceNumber,
    COUNT(DISTINCT CatalogId) AS CatalogsAssigned,
    COUNT(DISTINCT CASE WHEN HasRetailPrice = 1 THEN CatalogId END) AS CatalogsWithRetailPrice,
    STRING_AGG(CAST(CASE WHEN HasRetailPrice = 1 THEN CatalogId END AS VARCHAR(11)), ',')
        WITHIN GROUP (ORDER BY CatalogId) AS CatalogIdsWithRetailPrice
FROM CatalogRetailFlag
GROUP BY ReferenceNumber
ORDER BY ReferenceNumber;


-- ============================================================
-- #temp3 (Manufacturer 304, un-enriched published watches) rolled up per
-- ReferenceNumber: comma-separated WatchIds, comma-separated images, and
-- the single MOST-OCCURRING DialColor / CaseMaterial for that reference.
--
-- Schema confirmed against EveryWatchDDL: tblWatchToDialColor(WatchId,
-- DialColorId) -> tblColor.ColorName; tblWatchToCaseMaterial(WatchId,
-- CaseMaterialId) -> tblCaseMaterial.CaseMaterialName -- published
-- (non-_d) equivalents of the draft tables used earlier.
--
-- "Most occurring" = mode by simple frequency: count every (watch, color)
-- tagging row across all of that reference's watches (a watch with
-- multiple dial colors contributes one count per color, not deduped to
-- one vote per watch), then take the color/material with the highest
-- count. Ties are broken alphabetically (ColorName/CaseMaterialName ASC)
-- for a deterministic result -- say if you want a different tie-break.
-- DialColor and CaseMaterial are computed independently of each other,
-- not as a joint (color, material) combination like the earlier
-- reference-number task.
-- ============================================================

Select w.WatchId, w.ReferenceNumberId, w.ModelId
INTO #tempw
From tblWatch w (NOLOCK)
WHERE w.ManufacturerId=304 AND w.ReferenceEnrichmentId IS NULL AND w.IsDeleted=0;

Select t.*, m.ModelName, rn.ReferenceNumber, rn.TotalWatchCount,ma.Url
INTO #temp3
From #tempw t (NOLOCK)
JOIN tblReferenceNumber rn (NOLOCK) ON t.ReferenceNumberId = rn.ReferenceNumberId
JOIN tblmodel m (NOLOCK) ON t.ModelId = m.ModelId
JOIN tblMediaAsset ma (NOLOCK) ON t.WatchId = ma.WatchId AND ma.IsPrimary=1;

IF OBJECT_ID('tempdb..#ColorVotes') IS NOT NULL DROP TABLE #ColorVotes;
SELECT
    t3.ReferenceNumber,
    c.ColorName,
    COUNT(*) AS VoteCount
INTO #ColorVotes
FROM #temp3 AS t3 WITH (NOLOCK)
JOIN dbo.tblWatchToDialColor AS wdc WITH (NOLOCK) ON wdc.WatchId = t3.WatchId
JOIN dbo.tblColor AS c WITH (NOLOCK) ON c.ColorId = wdc.DialColorId
GROUP BY t3.ReferenceNumber, c.ColorName;

IF OBJECT_ID('tempdb..#MaterialVotes') IS NOT NULL DROP TABLE #MaterialVotes;
SELECT
    t3.ReferenceNumber,
    cm.CaseMaterialName,
    COUNT(*) AS VoteCount
INTO #MaterialVotes
FROM #temp3 AS t3 WITH (NOLOCK)
JOIN dbo.tblWatchToCaseMaterial AS wcm WITH (NOLOCK) ON wcm.WatchId = t3.WatchId
JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK) ON cm.CaseMaterialId = wcm.CaseMaterialId
GROUP BY t3.ReferenceNumber, cm.CaseMaterialName;

;WITH TopColor AS (
    SELECT
        ReferenceNumber,
        ColorName,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumber ORDER BY VoteCount DESC, ColorName ASC) AS rn
    FROM #ColorVotes
),
TopMaterial AS (
    SELECT
        ReferenceNumber,
        CaseMaterialName,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumber ORDER BY VoteCount DESC, CaseMaterialName ASC) AS rn
    FROM #MaterialVotes
)
SELECT
    t3.ReferenceNumber,
    MAX(t3.TotalWatchCount) AS TotalWatchCount,
    MAX(t3.ModelName) AS ModelName,
    STRING_AGG(CAST(t3.WatchId AS VARCHAR(20)), ',') WITHIN GROUP (ORDER BY t3.WatchId) AS WatchIds,
    MAX(tc.ColorName) AS DialColor,
    MAX(tm.CaseMaterialName) AS CaseMaterial,
    STRING_AGG(t3.Url, ',') WITHIN GROUP (ORDER BY t3.WatchId) AS Images
FROM #temp3 AS t3 WITH (NOLOCK)
LEFT JOIN TopColor AS tc ON tc.ReferenceNumber = t3.ReferenceNumber AND tc.rn = 1
LEFT JOIN TopMaterial AS tm ON tm.ReferenceNumber = t3.ReferenceNumber AND tm.rn = 1
GROUP BY t3.ReferenceNumber
ORDER BY t3.ReferenceNumber;


exec sp_Get_CatalogDetails


-- ============================================================
-- Catalogs with the same CountryId, CurrencyId, and date (CreatedAt cast
-- to date) but DIFFERENT prices -- i.e. a real price conflict, not just
-- a harmless duplicate row with the same price recorded twice.
--
-- HAVING COUNT(DISTINCT Price) > 1 is the key difference from your
-- pasted query: that one flags any group with more than one ROW
-- (duplicates included even if all rows share the same price); this one
-- only flags groups where the price itself actually varies.
-- ============================================================
SELECT
    tccrpd.CatalogID,
    tccrpd.CountryId,
    tccrpd.CurrencyId,
    CAST(tccrpd.CreatedAt AS DATE) AS PriceDate,
    COUNT(*) AS PriceRowCount,
    COUNT(DISTINCT tccrpd.Price) AS DistinctPriceCount,
    STRING_AGG(CAST(tccrpd.Price AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY tccrpd.Price) AS Prices
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS tccrpd WITH (NOLOCK)
GROUP BY tccrpd.CatalogID, tccrpd.CountryId, tccrpd.CurrencyId, CAST(tccrpd.CreatedAt AS DATE)
HAVING COUNT(DISTINCT tccrpd.Price) > 1
ORDER BY tccrpd.CatalogID, PriceDate;


-- ============================================================
-- Catalogs where, among their IsSeenInLastRun = 1 rows, PriceLastSeenDate
-- is a MIX -- some rows NULL, some rows NOT NULL, within the same
-- CatalogID. Catalogs where PriceLastSeenDate is uniformly all-NULL or
-- all-NOT-NULL across their IsSeenInLastRun=1 rows are excluded.
--
-- NOTE: dbo.tbl_CAT_CatalogRetailPrice_d.PriceLastSeenDate is not in the
-- tracked repo DDL (D:\EW\ew-db\MasterDB\dbo\table\tbl_CAT_CatalogRetailPrice_d.sql
-- is stale) -- confirmed to exist on the live table via your schema
-- screenshot (datetime2(3), nullable).
-- ============================================================
;WITH MixedCatalogs AS (
    SELECT
        tccrpd.CatalogID
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS tccrpd WITH (NOLOCK)
    WHERE tccrpd.IsSeenInLastRun = 1
      AND tccrpd.StatusID = 1
    GROUP BY tccrpd.CatalogID
    HAVING SUM(CASE WHEN tccrpd.PriceLastSeenDate IS NULL THEN 1 ELSE 0 END) > 0
       AND SUM(CASE WHEN tccrpd.PriceLastSeenDate IS NOT NULL THEN 1 ELSE 0 END) > 0
)
SELECT tccrpd.*
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS tccrpd WITH (NOLOCK)
INNER JOIN MixedCatalogs AS mc ON mc.CatalogID = tccrpd.CatalogID
WHERE tccrpd.IsSeenInLastRun = 1
  AND tccrpd.StatusID = 1
ORDER BY tccrpd.CatalogID, tccrpd.PriceLastSeenDate;


-- ============================================================
-- Backfill dbo.tbl_CAT_CatalogRetailPrice_d.PriceLastSeenDate for public
-- (IsPrivate = 0), verified (IsVerified = 1), active (StatusID = 1) rows
-- that currently have it NULL -- but per CatalogID, leave exactly ONE row
-- NULL and fill the rest with that row's own CreatedAt.
--
-- "One row to keep NULL" per CatalogID = the row with the smallest
-- CatalogRetailPriceID (rn = 1 below, i.e. the earliest-created qualifying
-- row for that catalog). Every other qualifying row for that catalog
-- (rn > 1) gets PriceLastSeenDate = its own CreatedAt.
--
-- NOTE: per project convention, no WITH (NOLOCK) is used here -- this is
-- an UPDATE ... FROM, and NOLOCK is not used on tables inside UPDATE
-- blocks (normal locking semantics apply).
--
-- Edge case: a CatalogID with only ONE qualifying row stays fully NULL --
-- there's no "rest" to fill in that case.
-- ============================================================
;WITH TargetRows AS (
    SELECT
        crp.CatalogRetailPriceID,
        crp.CatalogID,
        ROW_NUMBER() OVER (PARTITION BY crp.CatalogID ORDER BY crp.CatalogRetailPriceID) AS rn
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
      AND crp.PriceLastSeenDate IS NULL
)
UPDATE crp
SET crp.PriceLastSeenDate = crp.CreatedAt
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp
INNER JOIN TargetRows AS t ON t.CatalogRetailPriceID = crp.CatalogRetailPriceID
WHERE t.rn > 1;


-- ============================================================
-- Same "mixed NULL / NOT NULL" check as before, now on
-- dbo.tbl_MAP_RawCatalog_CatalogCountry: find CatalogIds where, among
-- their active (IsDeleted = 0) mapping rows, PriceLastSeenDate has BOTH
-- some NULL rows and some NOT NULL rows -- grouped by CatalogId alone
-- (across all CountryId rows for that catalog, same as "for that one
-- catalogid" -- not split out per country).
-- ============================================================
;WITH MixedMapCatalogs AS (
    SELECT
        map.CatalogId
    FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
    WHERE ISNULL(map.IsDeleted, 0) = 0
      AND ISNULL(map.IsSeenInLastRun, 0) = 1
    GROUP BY map.CatalogId
    HAVING SUM(CASE WHEN map.PriceLastSeenDate IS NULL THEN 1 ELSE 0 END) > 0
       AND SUM(CASE WHEN map.PriceLastSeenDate IS NOT NULL THEN 1 ELSE 0 END) > 0
)
SELECT map.*
FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
INNER JOIN MixedMapCatalogs AS mc ON mc.CatalogId = map.CatalogId
WHERE ISNULL(map.IsDeleted, 0) = 0
  AND ISNULL(map.IsSeenInLastRun, 0) = 1
ORDER BY map.CatalogId, map.PriceLastSeenDate;

Select *
From tbl_MAP_RawCatalog_CatalogCountry (NOLOCK)
where IsSeenInLastRun=1 ;

Select *
From tbl_CAT_Catalog_d (NOLOCK)

exec sp_PublishAllDataNew

exec sp_UpdateMap_PriceLastSeen


-- ============================================================
-- Backfill dbo.tbl_CAT_CatalogRetailPrice_d.PriceLastSeenDate for
-- public (IsPrivate = 0), verified (IsVerified = 1), active
-- (StatusID = 1) rows, per your two-case example:
--   - Every price row's PriceLastSeenDate = the CreatedAt of the NEXT
--     price row (chronologically) for the same (CatalogID, CountryId) --
--     "this price was seen until it was replaced."
--   - For the LAST (most recent) row in a (CatalogID, CountryId) group:
--       - If that group is "in current production" (its latest row has
--         IsSeenInLastRun = 1) -> PriceLastSeenDate = NULL (no next price
--         exists yet, still ongoing).
--       - If NOT in current production (latest row IsSeenInLastRun = 0)
--         -> treat GETDATE() as a virtual "next" checkpoint, so the last
--         real row's PriceLastSeenDate = GETDATE() (today) -- same LEAD
--         logic as every other row, just with GETDATE() standing in for
--         the next row that doesn't exist.
--
-- ASSUMPTION (not explicitly confirmed): partitioned by
-- (CatalogID, CountryId), not just CatalogID, since retail prices exist
-- per country and "in current production" is evaluated per that group's
-- own latest row. Adjust the PARTITION BY if you wanted this scoped
-- differently (e.g. CatalogID alone, or including CurrencyId too).
-- ============================================================

-- Step 0: preview before running the UPDATE below
;WITH PriceRows AS (
    SELECT
        crp.CatalogRetailPriceID,
        crp.CatalogID,
        crp.CountryId,
        crp.CreatedAt,
        crp.IsSeenInLastRun,
        ROW_NUMBER() OVER (
            PARTITION BY crp.CatalogID, crp.CountryId
            ORDER BY crp.CreatedAt DESC, crp.CatalogRetailPriceID DESC
        ) AS rn_desc
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
),
GroupStatus AS (
    SELECT CatalogID, CountryId, IsSeenInLastRun AS IsInCurrentProduction
    FROM PriceRows
    WHERE rn_desc = 1
),
Combined AS (
    SELECT CatalogRetailPriceID, CatalogID, CountryId, CreatedAt, CAST(0 AS BIT) AS IsSynthetic
    FROM PriceRows
    UNION ALL
    SELECT NULL, gs.CatalogID, gs.CountryId, GETDATE(), CAST(1 AS BIT)
    FROM GroupStatus AS gs
    WHERE gs.IsInCurrentProduction = 0
),
WithNext AS (
    SELECT
        CatalogRetailPriceID,
        CatalogID,
        CountryId,
        CreatedAt,
        IsSynthetic,
        LEAD(CreatedAt) OVER (
            PARTITION BY CatalogID, CountryId
            ORDER BY CreatedAt ASC, IsSynthetic ASC
        ) AS ExpectedPriceLastSeenDate
    FROM Combined
)
SELECT
    CatalogRetailPriceID,
    CatalogID,
    CountryId,
    CreatedAt,
    ExpectedPriceLastSeenDate
FROM WithNext
WHERE IsSynthetic = 0
ORDER BY CatalogID, CountryId, CreatedAt;

-- Step 1: the actual backfill (run only after checking the preview above).
-- No WITH (NOLOCK) per project convention -- UPDATE ... FROM tables use
-- normal locking semantics.
;WITH PriceRows AS (
    SELECT
        crp.CatalogRetailPriceID,
        crp.CatalogID,
        crp.CountryId,
        crp.CreatedAt,
        crp.IsSeenInLastRun,
        ROW_NUMBER() OVER (
            PARTITION BY crp.CatalogID, crp.CountryId
            ORDER BY crp.CreatedAt DESC, crp.CatalogRetailPriceID DESC
        ) AS rn_desc
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
),
GroupStatus AS (
    SELECT CatalogID, CountryId, IsSeenInLastRun AS IsInCurrentProduction
    FROM PriceRows
    WHERE rn_desc = 1
),
Combined AS (
    SELECT CatalogRetailPriceID, CatalogID, CountryId, CreatedAt, CAST(0 AS BIT) AS IsSynthetic
    FROM PriceRows
    UNION ALL
    SELECT NULL, gs.CatalogID, gs.CountryId, GETDATE(), CAST(1 AS BIT)
    FROM GroupStatus AS gs
    WHERE gs.IsInCurrentProduction = 0
),
WithNext AS (
    SELECT
        CatalogRetailPriceID,
        IsSynthetic,
        LEAD(CreatedAt) OVER (
            PARTITION BY CatalogID, CountryId
            ORDER BY CreatedAt ASC, IsSynthetic ASC
        ) AS ExpectedPriceLastSeenDate
    FROM Combined
)
UPDATE crp
SET crp.PriceLastSeenDate = wn.ExpectedPriceLastSeenDate
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp
INNER JOIN WithNext AS wn
    ON wn.CatalogRetailPriceID = crp.CatalogRetailPriceID
WHERE wn.IsSynthetic = 0;


-- ============================================================
-- Verification: after running the #d_Plan-based backfill (the pasted
-- script with @Commit = 1), check how many rows in
-- dbo.tbl_CAT_CatalogRetailPrice_d actually now match the plan's
-- NewPriceLastSeenDate vs how many still don't (should only be rows in
-- flagged chains, if @ExcludeFlagged = 1 was used).
-- Run in the SAME session, right after the real UPDATE, since #d_Plan is
-- a session-scoped temp table.
-- ============================================================
SELECT
    'DRAFT' AS Src,
    p.CatalogRetailPriceID,
    p.CatalogID,
    p.CountryId,
    p.CurrencyId,
    p.FlagReason,
    t.PriceLastSeenDate AS CurrentValueInTable,
    p.NewPriceLastSeenDate AS ExpectedValue,
    CASE
        WHEN ISNULL(t.PriceLastSeenDate, '1900-01-01') = ISNULL(p.NewPriceLastSeenDate, '1900-01-01')
            THEN 'Matches plan'
        ELSE 'MISMATCH'
    END AS VerificationStatus
FROM #d_Plan AS p
INNER JOIN dbo.tbl_CAT_CatalogRetailPrice_d AS t WITH (NOLOCK)
    ON t.CatalogRetailPriceID = p.CatalogRetailPriceID
WHERE ISNULL(t.PriceLastSeenDate, '1900-01-01') <> ISNULL(p.NewPriceLastSeenDate, '1900-01-01')
ORDER BY p.CatalogID, p.CountryId, p.CurrencyId, p.CreatedAt;

-- Summary counts for the same check
SELECT
    COUNT(*) AS TotalPlannedRows,
    SUM(CASE WHEN ISNULL(t.PriceLastSeenDate, '1900-01-01') = ISNULL(p.NewPriceLastSeenDate, '1900-01-01')
             THEN 1 ELSE 0 END) AS MatchesPlan,
    SUM(CASE WHEN ISNULL(t.PriceLastSeenDate, '1900-01-01') <> ISNULL(p.NewPriceLastSeenDate, '1900-01-01')
             THEN 1 ELSE 0 END) AS StillMismatched,
    SUM(CASE WHEN ISNULL(t.PriceLastSeenDate, '1900-01-01') <> ISNULL(p.NewPriceLastSeenDate, '1900-01-01')
                  AND p.FlagReason IS NULL
             THEN 1 ELSE 0 END) AS MismatchedButNotFlagged  -- should be 0 if the update ran cleanly
FROM #d_Plan AS p
INNER JOIN dbo.tbl_CAT_CatalogRetailPrice_d AS t WITH (NOLOCK)
    ON t.CatalogRetailPriceID = p.CatalogRetailPriceID;


-- ============================================================
-- Separate check: in dbo.tbl_CAT_CatalogRetailPrice_d, for public
-- (IsPrivate = 0), verified (IsVerified = 1), active (StatusID = 1)
-- rows, grouped by (CatalogID, CountryId, CurrencyId) -- is each group
-- "latest only" (exactly 1 row = no price history sitting around) or
-- does it have multiple rows (history present)?
-- ============================================================

-- Detail: one row per (CatalogID, CountryId, CurrencyId) group
SELECT
    crp.CatalogID,
    crp.CountryId,
    crp.CurrencyId,
    COUNT(*) AS RowCounts,
    CASE WHEN COUNT(*) = 1 THEN 'Latest only' ELSE 'Multiple rows (history present)' END AS ChainStatus,
    MIN(crp.CreatedAt) AS EarliestCreatedAt,
    MAX(crp.CreatedAt) AS LatestCreatedAt
FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp (NOLOCK)
WHERE crp.IsPrivate = 0
  AND crp.IsVerified = 1
  AND crp.StatusID = 1
and PriceLastSeenDate is null
GROUP BY crp.CatalogID, crp.CountryId, crp.CurrencyId
ORDER BY RowCounts DESC, crp.CatalogID, crp.CountryId, crp.CurrencyId;

-- Summary: how many groups are "latest only" vs "multiple rows"
SELECT
    CASE WHEN x.RowCount = 1 THEN 'Latest only' ELSE 'Multiple rows' END AS ChainStatus,
    COUNT(*) AS ChainCount,
    SUM(x.RowCount) AS TotalRows
FROM (
    SELECT crp.CatalogID, crp.CountryId, crp.CurrencyId, COUNT(*) AS RowCount
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp WITH (NOLOCK)
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
    GROUP BY crp.CatalogID, crp.CountryId, crp.CurrencyId
) AS x
GROUP BY CASE WHEN x.RowCount = 1 THEN 'Latest only' ELSE 'Multiple rows' END;


-- ============================================================
-- Refined check: history (multiple rows per chain) is fine -- the actual
-- rule is that ONLY the latest-CreatedAt row in a (CatalogID, CountryId,
-- CurrencyId) group should ever have PriceLastSeenDate = NULL. Any
-- EARLIER (non-latest) row that is still NULL is a violation -- it was
-- superseded by a later price, so it should have a known last-seen date.
-- ============================================================
;WITH PriceRows AS (
    SELECT
        crp.CatalogRetailPriceID,
        crp.CatalogID,
        crp.CountryId,
        crp.CurrencyId,
        crp.CreatedAt,
        crp.PriceLastSeenDate,
        ROW_NUMBER() OVER (
            PARTITION BY crp.CatalogID, crp.CountryId, crp.CurrencyId
            ORDER BY crp.CreatedAt DESC, crp.CatalogRetailPriceID DESC
        ) AS rn_desc
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp WITH (NOLOCK)
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
)
-- Detail: the violating rows themselves (non-latest, but NULL)
SELECT
    CatalogRetailPriceID,
    CatalogID,
    CountryId,
    CurrencyId,
    CreatedAt,
    PriceLastSeenDate,
    rn_desc AS PositionFromLatest,
    'Historical row with NULL PriceLastSeenDate' AS Issue
FROM PriceRows
WHERE PriceLastSeenDate IS NULL
  AND rn_desc <> 1
ORDER BY CatalogID, CountryId, CurrencyId, CreatedAt;

-- Summary: how many (CatalogID, CountryId, CurrencyId) chains have at
-- least one such violation, and how many rows total
;WITH PriceRows2 AS (
    SELECT
        crp.CatalogID,
        crp.CountryId,
        crp.CurrencyId,
        crp.PriceLastSeenDate,
        ROW_NUMBER() OVER (
            PARTITION BY crp.CatalogID, crp.CountryId, crp.CurrencyId
            ORDER BY crp.CreatedAt DESC, crp.CatalogRetailPriceID DESC
        ) AS rn_desc
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS crp WITH (NOLOCK)
    WHERE crp.IsPrivate = 0
      AND crp.IsVerified = 1
      AND crp.StatusID = 1
)
SELECT
    COUNT(DISTINCT CASE WHEN PriceLastSeenDate IS NULL AND rn_desc <> 1
                        THEN CONCAT(CatalogID, '|', CountryId, '|', CurrencyId) END) AS ChainsWithViolation,
    SUM(CASE WHEN PriceLastSeenDate IS NULL AND rn_desc <> 1 THEN 1 ELSE 0 END) AS ViolatingRows
FROM PriceRows2;


-- ============================================================
-- ##watches: one row per ReferenceNumberId, WatchId = comma-separated
-- DRAFT watch ids for that reference. For each ##watches ROW, find the
-- most-occurring DialColor, CaseMaterial, and ModelName across its
-- watches, plus all their images comma-separated.
--
-- IMPORTANT: grouping is by the SOURCE ROW of ##watches (a synthetic
-- SourceRowId), NOT by ReferenceNumberId directly. ##watches can have
-- multiple rows with ReferenceNumberId = NULL; grouping by
-- ReferenceNumberId would collapse ALL of those NULL rows into one
-- combined bucket (SQL GROUP BY treats every NULL as the same group),
-- making them impossible to map back to your sheet. Grouping by
-- SourceRowId keeps every original row distinct regardless of whether
-- its ReferenceNumberId is populated. FirstWatchId (MIN(WatchId) in that
-- row's list) is also always shown, so a NULL-ReferenceNumberId row can
-- still be mapped back using that watch id instead.
--
-- Draft tables used (per your "draft watchids" note): tblWatch_d,
-- tblWatchToDialColor_d, tblWatchToCaseMaterial_d, tblMediaAsset_d.
-- ModelName uses the shared dbo.tblModel (confirmed: no tblModel_d
-- exists -- lookup tables like tblModel/tblColor/tblCaseMaterial aren't
-- duplicated per draft/published, only the WatchTo* junction tables and
-- tblMediaAsset are).
--
-- "Most occurring" = same vote-counting approach as the earlier
-- manufacturer-304 query: count every (watch, value) occurrence across
-- all watches for that row, take the highest count, ties broken
-- alphabetically. DialColor/CaseMaterial are many-to-many per watch
-- (each occurrence counted separately); ModelName is one-per-watch.
-- Assumes ##watches is already created and populated before this runs.
-- ============================================================

-- Step 0: give ##watches rows a stable per-row identity -- it has no
-- primary key of its own, and NULL ReferenceNumberId can't serve as one.
IF OBJECT_ID('tempdb..#WatchesKeyed') IS NOT NULL DROP TABLE #WatchesKeyed;
SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SourceRowId,
    w.ReferenceNumberId,
    w.WatchId AS WatchIdList
INTO #WatchesKeyed
FROM ##watches AS w WITH (NOLOCK);

-- Step 1: split each row's comma-separated WatchId list into individual
-- (SourceRowId, ReferenceNumberId, WatchId) rows.
IF OBJECT_ID('tempdb..#WatchList') IS NOT NULL DROP TABLE #WatchList;
SELECT
    wk.SourceRowId,
    wk.ReferenceNumberId,
    TRY_CAST(LTRIM(RTRIM(s.value)) AS BIGINT) AS WatchId
INTO #WatchList
FROM #WatchesKeyed AS wk WITH (NOLOCK)
CROSS APPLY STRING_SPLIT(wk.WatchIdList, ',') AS s
WHERE TRY_CAST(LTRIM(RTRIM(s.value)) AS BIGINT) IS NOT NULL;

-- Step 2a: stage CHEAP per-watch attributes for ALL watches (no
-- correlated subqueries here) -- this is what vote-counting uses, so
-- accuracy is unaffected by the top-10 image cap below.
IF OBJECT_ID('tempdb..#tblWatchCore') IS NOT NULL DROP TABLE #tblWatchCore;
SELECT
    wl.SourceRowId,
    wl.ReferenceNumberId,
    wd.WatchId,
    wd.ModelId,
    m.ModelName
INTO #tblWatchCore
FROM #WatchList AS wl WITH (NOLOCK)
INNER JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.WatchId = wl.WatchId
LEFT JOIN dbo.tblModel AS m WITH (NOLOCK) ON m.ModelId = wd.ModelId;

-- Step 2b: cap to the 10 smallest WatchIds per SourceRowId, and ONLY for
-- these run the expensive correlated subqueries (PrimaryImage,
-- PublishWatchId) -- avoids running them for every watch when a group
-- has 100+. Ordering by WatchId ASC also means rn = 1 here is exactly
-- FirstWatchId, so the same ranking serves both purposes.
IF OBJECT_ID('tempdb..#tblWatchTop10') IS NOT NULL DROP TABLE #tblWatchTop10;
;WITH Ranked AS (
    SELECT
        SourceRowId,
        ReferenceNumberId,
        WatchId,
        ROW_NUMBER() OVER (PARTITION BY SourceRowId ORDER BY WatchId ASC) AS rn
    FROM #tblWatchCore
)
SELECT
    r.SourceRowId,
    r.ReferenceNumberId,
    r.WatchId,
    r.rn,
    PrimaryImage = (
        SELECT TOP 1 COALESCE(ma.Original, ma.Preview1366, ma.Preview768, ma.Preview480, ma.Preview320)
        FROM dbo.tblMediaAsset_d AS ma WITH (NOLOCK)
        WHERE ma.WatchId = r.WatchId
          AND (ma.IsDeleted = 0 OR ma.IsDeleted IS NULL)
        ORDER BY ma.IsPrimary DESC, ma.MediaAssetId ASC
    ),
    PublishWatchId = (
        SELECT TOP 1 tw.WatchId
        FROM dbo.tblWatch AS tw WITH (NOLOCK)
        WHERE tw.WatchListingDraftId = r.WatchId
    )
INTO #tblWatchTop10
FROM Ranked AS r
WHERE r.rn <= 10;

-- Step 3: vote-count each attribute per SourceRowId, over ALL watches
-- (from #tblWatchCore, not capped).
IF OBJECT_ID('tempdb..#ColorVotes') IS NOT NULL DROP TABLE #ColorVotes;
SELECT
    t.SourceRowId,
    c.ColorName,
    COUNT(*) AS VoteCount
INTO #ColorVotes
FROM #tblWatchCore AS t WITH (NOLOCK)
JOIN dbo.tblWatchToDialColor_d AS wdcd WITH (NOLOCK) ON wdcd.WatchId = t.WatchId
JOIN dbo.tblColor AS c WITH (NOLOCK) ON c.ColorId = wdcd.DialColorId
GROUP BY t.SourceRowId, c.ColorName;

IF OBJECT_ID('tempdb..#MaterialVotes') IS NOT NULL DROP TABLE #MaterialVotes;
SELECT
    t.SourceRowId,
    cm.CaseMaterialName,
    COUNT(*) AS VoteCount
INTO #MaterialVotes
FROM #tblWatchCore AS t WITH (NOLOCK)
JOIN dbo.tblWatchToCaseMaterial_d AS wcmd WITH (NOLOCK) ON wcmd.WatchId = t.WatchId
JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK) ON cm.CaseMaterialId = wcmd.CaseMaterialId
GROUP BY t.SourceRowId, cm.CaseMaterialName;

IF OBJECT_ID('tempdb..#ModelVotes') IS NOT NULL DROP TABLE #ModelVotes;
SELECT
    t.SourceRowId,
    t.ModelName,
    COUNT(*) AS VoteCount
INTO #ModelVotes
FROM #tblWatchCore AS t WITH (NOLOCK)
WHERE t.ModelName IS NOT NULL
GROUP BY t.SourceRowId, t.ModelName;

-- Step 4: pick the top (most-occurring) value per SourceRowId for each
-- attribute, ties broken alphabetically.
;WITH TopColor AS (
    SELECT
        SourceRowId, ColorName,
        ROW_NUMBER() OVER (PARTITION BY SourceRowId ORDER BY VoteCount DESC, ColorName ASC) AS rn
    FROM #ColorVotes
),
TopMaterial AS (
    SELECT
        SourceRowId, CaseMaterialName,
        ROW_NUMBER() OVER (PARTITION BY SourceRowId ORDER BY VoteCount DESC, CaseMaterialName ASC) AS rn
    FROM #MaterialVotes
),
TopModel AS (
    SELECT
        SourceRowId, ModelName,
        ROW_NUMBER() OVER (PARTITION BY SourceRowId ORDER BY VoteCount DESC, ModelName ASC) AS rn
    FROM #ModelVotes
),
-- FirstWatch: rn = 1 in #tblWatchTop10 is already exactly the smallest
-- WatchId (same ordering used to build the top-10 cap), so it's reused
-- directly here instead of re-ranking.
FirstWatch AS (
    SELECT
        SourceRowId,
        WatchId AS FirstWatchId,
        PublishWatchId AS FirstWatchPublishWatchId
    FROM #tblWatchTop10
    WHERE rn = 1
)
SELECT
    t.SourceRowId,
    MAX(t.ReferenceNumberId) AS ReferenceNumberId,
    fw.FirstWatchId,
    fw.FirstWatchPublishWatchId,
    MAX(tc.ColorName) AS DialColor,
    MAX(tm.CaseMaterialName) AS CaseMaterial,
    MAX(tmo.ModelName) AS ModelName,
    STRING_AGG(t.PrimaryImage, ',') WITHIN GROUP (ORDER BY t.WatchId) AS Images
FROM #tblWatchTop10 AS t WITH (NOLOCK)
LEFT JOIN TopColor AS tc ON tc.SourceRowId = t.SourceRowId AND tc.rn = 1
LEFT JOIN TopMaterial AS tm ON tm.SourceRowId = t.SourceRowId AND tm.rn = 1
LEFT JOIN TopModel AS tmo ON tmo.SourceRowId = t.SourceRowId AND tmo.rn = 1
INNER JOIN FirstWatch AS fw ON fw.SourceRowId = t.SourceRowId
GROUP BY t.SourceRowId, fw.FirstWatchId, fw.FirstWatchPublishWatchId
ORDER BY t.SourceRowId;


Select *
From tbl_CAT_Catalog_d (NOLOCK)


Select *
From tbl_CAT_Manufacturer_d (NOLOCK)


-- ============================================================
-- Same analysis as the ##watches query (most-occurring DialColor /
-- CaseMaterial / ModelName, top-10 images, FirstWatchId + its
-- PublishWatchId) -- but driven purely by a list of ReferenceNumberIds.
-- The query itself finds every draft watch for each ReferenceNumberId
-- via tblWatch_d, instead of you pre-listing the watch ids.
--
-- Grouping is by ReferenceNumberId directly (not a synthetic
-- SourceRowId) -- unlike ##watches, ReferenceNumberId is the input here,
-- so it's never NULL and can't collapse distinct input rows together.
-- ============================================================

-- Input: just the reference number ids you want data for.
IF OBJECT_ID('tempdb..##referenceNumbers') IS NOT NULL DROP TABLE ##referenceNumbers;
CREATE TABLE ##referenceNumbers
(
    ReferenceNumberId INT
);
-- INSERT INTO ##referenceNumbers (ReferenceNumberId) VALUES (111111), (222222);

-- Step 1: find every draft watch for each ReferenceNumberId.
IF OBJECT_ID('tempdb..#WatchList2') IS NOT NULL DROP TABLE #WatchList2;
SELECT
    rn.ReferenceNumberId,
    wd.WatchId
INTO #WatchList2
FROM ##referenceNumbers AS rn WITH (NOLOCK)
INNER JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.ReferenceNumberId = rn.ReferenceNumberId;

-- Step 2a: cheap per-watch attributes for ALL watches (vote-counting
-- source -- unaffected by the top-10 image cap below).
IF OBJECT_ID('tempdb..#tblWatchCore2') IS NOT NULL DROP TABLE #tblWatchCore2;
SELECT
    wl.ReferenceNumberId,
    wd.WatchId,
    wd.ModelId,
    m.ModelName
INTO #tblWatchCore2
FROM #WatchList2 AS wl WITH (NOLOCK)
INNER JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.WatchId = wl.WatchId
LEFT JOIN dbo.tblModel AS m WITH (NOLOCK) ON m.ModelId = wd.ModelId;

-- Step 2b: cap to the 10 smallest WatchIds per ReferenceNumberId; only
-- for these run the expensive PrimaryImage/PublishWatchId subqueries.
IF OBJECT_ID('tempdb..#tblWatchTop10_2') IS NOT NULL DROP TABLE #tblWatchTop10_2;
;WITH Ranked AS (
    SELECT
        ReferenceNumberId,
        WatchId,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumberId ORDER BY WatchId ASC) AS rn
    FROM #tblWatchCore2
)
SELECT
    r.ReferenceNumberId,
    r.WatchId,
    r.rn,
    PrimaryImage = (
        SELECT TOP 1 COALESCE(ma.Original, ma.Preview1366, ma.Preview768, ma.Preview480, ma.Preview320)
        FROM dbo.tblMediaAsset_d AS ma WITH (NOLOCK)
        WHERE ma.WatchId = r.WatchId
          AND (ma.IsDeleted = 0 OR ma.IsDeleted IS NULL)
        ORDER BY ma.IsPrimary DESC, ma.MediaAssetId ASC
    ),
    PublishWatchId = (
        SELECT TOP 1 tw.WatchId
        FROM dbo.tblWatch AS tw WITH (NOLOCK)
        WHERE tw.WatchListingDraftId = r.WatchId
    )
INTO #tblWatchTop10_2
FROM Ranked AS r
WHERE r.rn <= 10;

-- Step 3: vote-count each attribute per ReferenceNumberId, over ALL
-- watches (from #tblWatchCore2, not capped).
IF OBJECT_ID('tempdb..#ColorVotes2') IS NOT NULL DROP TABLE #ColorVotes2;
SELECT
    t.ReferenceNumberId,
    c.ColorName,
    COUNT(*) AS VoteCount
INTO #ColorVotes2
FROM #tblWatchCore2 AS t WITH (NOLOCK)
JOIN dbo.tblWatchToDialColor_d AS wdcd WITH (NOLOCK) ON wdcd.WatchId = t.WatchId
JOIN dbo.tblColor AS c WITH (NOLOCK) ON c.ColorId = wdcd.DialColorId
GROUP BY t.ReferenceNumberId, c.ColorName;

IF OBJECT_ID('tempdb..#MaterialVotes2') IS NOT NULL DROP TABLE #MaterialVotes2;
SELECT
    t.ReferenceNumberId,
    cm.CaseMaterialName,
    COUNT(*) AS VoteCount
INTO #MaterialVotes2
FROM #tblWatchCore2 AS t WITH (NOLOCK)
JOIN dbo.tblWatchToCaseMaterial_d AS wcmd WITH (NOLOCK) ON wcmd.WatchId = t.WatchId
JOIN dbo.tblCaseMaterial AS cm WITH (NOLOCK) ON cm.CaseMaterialId = wcmd.CaseMaterialId
GROUP BY t.ReferenceNumberId, cm.CaseMaterialName;

IF OBJECT_ID('tempdb..#ModelVotes2') IS NOT NULL DROP TABLE #ModelVotes2;
SELECT
    t.ReferenceNumberId,
    t.ModelName,
    COUNT(*) AS VoteCount
INTO #ModelVotes2
FROM #tblWatchCore2 AS t WITH (NOLOCK)
WHERE t.ModelName IS NOT NULL
GROUP BY t.ReferenceNumberId, t.ModelName;

-- Step 4: pick the top (most-occurring) value per ReferenceNumberId for
-- each attribute, ties broken alphabetically.
;WITH TopColor2 AS (
    SELECT
        ReferenceNumberId, ColorName,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumberId ORDER BY VoteCount DESC, ColorName ASC) AS rn
    FROM #ColorVotes2
),
TopMaterial2 AS (
    SELECT
        ReferenceNumberId, CaseMaterialName,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumberId ORDER BY VoteCount DESC, CaseMaterialName ASC) AS rn
    FROM #MaterialVotes2
),
TopModel2 AS (
    SELECT
        ReferenceNumberId, ModelName,
        ROW_NUMBER() OVER (PARTITION BY ReferenceNumberId ORDER BY VoteCount DESC, ModelName ASC) AS rn
    FROM #ModelVotes2
),
FirstWatch2 AS (
    SELECT
        ReferenceNumberId,
        WatchId AS FirstWatchId,
        PublishWatchId AS FirstWatchPublishWatchId
    FROM #tblWatchTop10_2
    WHERE rn = 1
),
-- ALL matching WatchIds per ReferenceNumberId, comma-separated -- NOT
-- capped at 10 (that cap only applies to the Images column, for
-- performance). Sourced from #tblWatchCore2 since that holds every watch.
AllWatchIds2 AS (
    SELECT
        ReferenceNumberId,
        STRING_AGG(CAST(WatchId AS VARCHAR(20)), ',') WITHIN GROUP (ORDER BY WatchId) AS WatchIds
    FROM #tblWatchCore2
    GROUP BY ReferenceNumberId
)
SELECT
    t.ReferenceNumberId,
    aw.WatchIds,
    fw.FirstWatchId,
    fw.FirstWatchPublishWatchId,
    MAX(tc.ColorName) AS DialColor,
    MAX(tm.CaseMaterialName) AS CaseMaterial,
    MAX(tmo.ModelName) AS ModelName,
    STRING_AGG(t.PrimaryImage, ',') WITHIN GROUP (ORDER BY t.WatchId) AS Images
FROM #tblWatchTop10_2 AS t WITH (NOLOCK)
LEFT JOIN TopColor2 AS tc ON tc.ReferenceNumberId = t.ReferenceNumberId AND tc.rn = 1
LEFT JOIN TopMaterial2 AS tm ON tm.ReferenceNumberId = t.ReferenceNumberId AND tm.rn = 1
LEFT JOIN TopModel2 AS tmo ON tmo.ReferenceNumberId = t.ReferenceNumberId AND tmo.rn = 1
INNER JOIN FirstWatch2 AS fw ON fw.ReferenceNumberId = t.ReferenceNumberId
INNER JOIN AllWatchIds2 AS aw ON aw.ReferenceNumberId = t.ReferenceNumberId
GROUP BY t.ReferenceNumberId, aw.WatchIds, fw.FirstWatchId, fw.FirstWatchPublishWatchId
ORDER BY t.ReferenceNumberId;


-- ============================================================
-- Distinct reference-number "structure" (shape) for ManufacturerId = 26,
-- via dbo.fn_ConvertToStructure (confirmed: letters -> 'A', digits ->
-- 'X', everything else -- punctuation, spaces -- left as-is).
-- Active catalogs only (StatusID = 1); drop that filter if you want
-- structures across all statuses too.
-- ============================================================
SELECT DISTINCT
    dbo.fn_ConvertToStructure(cd.ReferenceNumber) AS Structure
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
WHERE cd.ManufacturerId = 26
  AND cd.StatusID = 1
ORDER BY Structure;

-- Same thing, but with a count of how many catalogs share each structure
-- (usually more useful than the bare distinct list above).
SELECT
    dbo.fn_ConvertToStructure(cd.ReferenceNumber) AS Structure,
    COUNT(*) AS CatalogCount
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
WHERE cd.ManufacturerId = 26
  AND cd.StatusID = 1
GROUP BY dbo.fn_ConvertToStructure(cd.ReferenceNumber)
ORDER BY CatalogCount DESC;




-- ============================================================
-- Title and Description of every draft watch assigned to a given
-- ReferenceNumberId. Reuses ##referenceNumbers (same input table as the
-- ReferenceNumberId-only query / Query3.sql) -- fill it in first.
-- ============================================================
IF OBJECT_ID('tempdb..#WatchTitleDesc') IS NOT NULL DROP TABLE #WatchTitleDesc;
SELECT
    wd.ReferenceNumberId,
    wd.WatchId,
    wd.Title,
    wd.Description
INTO #WatchTitleDesc
FROM ##referenceNumbers AS rn WITH (NOLOCK)
INNER JOIN dbo.tblWatch_d AS wd WITH (NOLOCK) ON wd.ReferenceNumberId = rn.ReferenceNumberId;

SELECT *
FROM #WatchTitleDesc WITH (NOLOCK)
ORDER BY ReferenceNumberId, WatchId;
