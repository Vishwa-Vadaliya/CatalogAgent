-- Diagnosing sp_PublishAllDataNew error:
-- "The DELETE statement conflicted with the REFERENCE constraint
--  'FK__tbl_CAT_W__Compl__37C5420D'... table 'dbo.tbl_CAT_WatchToComplication',
--  column 'ComplicationId'."
--
-- Root cause: in the Master DELETE step, the SP deletes rows from
-- dbo.tbl_CAT_Complication (the published lookup table) whenever the
-- matching dbo.tbl_CAT_Complication_d row has StatusID = 3 (deleted) with a
-- newer TransactionID. That delete is unconditional -- it does NOT check
-- whether dbo.tbl_CAT_WatchToComplication still has live rows pointing at
-- that same ComplicationId. If a Complication master value gets marked
-- deleted while a catalog is still mapped to it, the parent delete fails
-- with this FK violation.
--
-- This script finds exactly which ComplicationId(s) are causing it, and
-- which catalogs are still holding the stale mapping.

-- Step 1: Stage the Complication rows that the SP is trying to delete
-- (same predicate as the SP's Master DELETE step for tbl_CAT_Complication)
IF OBJECT_ID('tempdb..#ComplicationsPendingDelete') IS NOT NULL DROP TABLE #ComplicationsPendingDelete;
SELECT
    target.ComplicationId,
    target.ComplicationName,
    target.TransactionID AS PublishedTransactionID,
    source.TransactionID AS DraftTransactionID
INTO #ComplicationsPendingDelete
FROM dbo.tbl_CAT_Complication AS target WITH (NOLOCK)
JOIN dbo.tbl_CAT_Complication_d AS source WITH (NOLOCK)
    ON target.ComplicationId = source.ComplicationId
    AND source.TransactionID > target.TransactionID
WHERE source.StatusID = 3;

-- Step 2: Of those, which ones still have live rows in the published
-- mapping table tbl_CAT_WatchToComplication (this is what's blocking the delete)
IF OBJECT_ID('tempdb..#BlockingMappings') IS NOT NULL DROP TABLE #BlockingMappings;
SELECT
    wtc.CatalogId,
    wtc.ComplicationId,
    wtc.TransactionID AS MappingTransactionID
INTO #BlockingMappings
FROM dbo.tbl_CAT_WatchToComplication AS wtc WITH (NOLOCK)
JOIN #ComplicationsPendingDelete AS cpd WITH (NOLOCK) ON wtc.ComplicationId = cpd.ComplicationId;

-- Step 3: Result -- the exact blocking ComplicationId(s) + ComplicationName,
-- and every CatalogId still mapped to it
SELECT
    cpd.ComplicationId,
    cpd.ComplicationName,
    cpd.PublishedTransactionID,
    cpd.DraftTransactionID,
    bm.CatalogId
FROM #ComplicationsPendingDelete AS cpd WITH (NOLOCK)
JOIN #BlockingMappings AS bm WITH (NOLOCK) ON cpd.ComplicationId = bm.ComplicationId
ORDER BY cpd.ComplicationId, bm.CatalogId;

-- Step 4 (optional cross-check): for those same CatalogIds, is there a
-- matching draft row in tbl_CAT_WatchToComplication_d that ALSO marks the
-- mapping itself as deleted (StatusID = 3)? If not, that's the gap --
-- the mapping was never told to go away before the Complication master
-- value was deleted.
SELECT
    bm.CatalogId,
    bm.ComplicationId,
    wtcd.StatusID AS MappingDraftStatusID,
    wtcd.TransactionID AS MappingDraftTransactionID
FROM #BlockingMappings AS bm WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_WatchToComplication_d AS wtcd WITH (NOLOCK)
    ON wtcd.CatalogId = bm.CatalogId AND wtcd.ComplicationId = bm.ComplicationId
ORDER BY bm.CatalogId, bm.ComplicationId;

-- Step 5: For the rows where MappingDraftStatusID = 3 (i.e. the draft side
-- already says "deleted"), confirm whether the SP's own DELETE predicate
-- (source.TransactionID > target.TransactionID) would ever fire for them.
-- If MappingDraftTransactionID <= PublishedMappingTransactionID, that's why
-- the normal publish step never removes these rows -- the TransactionID
-- ordering condition never becomes true.
SELECT
    bm.CatalogId,
    bm.ComplicationId,
    bm.MappingTransactionID AS PublishedMappingTransactionID,
    wtcd.StatusID AS MappingDraftStatusID,
    wtcd.TransactionID AS MappingDraftTransactionID,
    CASE
        WHEN wtcd.StatusID = 3 AND wtcd.TransactionID > bm.MappingTransactionID
            THEN 'Should have been deleted by the SP -- investigate further'
        WHEN wtcd.StatusID = 3 AND wtcd.TransactionID <= bm.MappingTransactionID
            THEN 'TransactionID condition never true -- this is why it is stuck'
        WHEN wtcd.StatusID IS NULL
            THEN 'No draft row at all for this mapping'
        ELSE 'Draft row is not marked deleted (StatusID <> 3)'
    END AS Diagnosis
FROM #BlockingMappings AS bm WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_WatchToComplication_d AS wtcd WITH (NOLOCK)
    ON wtcd.CatalogId = bm.CatalogId AND wtcd.ComplicationId = bm.ComplicationId
ORDER BY bm.CatalogId, bm.ComplicationId;

-- =====================================================================================
-- Targeted check for a specific list of "already removed" ComplicationIds.
-- Checking tbl_CAT_WatchToComplication_d (draft) for StatusID = 1 only proves nothing
-- is ACTIVELY assigned in the draft -- it says nothing about whether the PUBLISHED
-- table (tbl_CAT_WatchToComplication) still has stale rows, or whether a proper
-- StatusID = 3 deletion marker even exists for them. This checks the actual table the
-- FK error is thrown against, and cross-references the draft to show why it's stuck.
-- =====================================================================================

DECLARE @CheckComplicationIds TABLE (ComplicationId INT PRIMARY KEY);
INSERT INTO @CheckComplicationIds (ComplicationId)
VALUES (71),(93),(98),(125),(131),(134),(146),(147),(166),(167),(175),(177),(178),(180),
       (182),(183),(184),(186),(187),(194),(195),(199),(200),(205),(206),(207),(212),(220),(222);

-- Step 1: Live rows still sitting in the PUBLISHED mapping table for these ComplicationIds
IF OBJECT_ID('tempdb..#PublishedRowsForList') IS NOT NULL DROP TABLE #PublishedRowsForList;
SELECT wtc.CatalogId, wtc.ComplicationId, wtc.TransactionID AS PublishedTransactionID
INTO #PublishedRowsForList
FROM dbo.tbl_CAT_WatchToComplication AS wtc WITH (NOLOCK)
JOIN @CheckComplicationIds AS c ON wtc.ComplicationId = c.ComplicationId;

-- Step 2: Cross-reference each one against the draft table, to see exactly why it's stuck
SELECT
    p.CatalogId,
    p.ComplicationId,
    p.PublishedTransactionID,
    wtcd.StatusID AS DraftStatusID,
    wtcd.TransactionID AS DraftTransactionID,
    CASE
        WHEN wtcd.CatalogId IS NULL
            THEN 'No draft row at all -- was hard-deleted from _d instead of soft-deleted (StatusID=3). The SP will NEVER remove this published row on its own.'
        WHEN wtcd.StatusID = 3 AND wtcd.TransactionID > p.PublishedTransactionID
            THEN 'Draft says delete and TransactionID is newer -- SP should remove this next run'
        WHEN wtcd.StatusID = 3 AND wtcd.TransactionID <= p.PublishedTransactionID
            THEN 'Draft says delete but TransactionID is not newer -- stuck, SP will never remove this'
        WHEN wtcd.StatusID = 1
            THEN 'Draft still shows this as ACTIVE (StatusID=1) -- it was not actually removed in the draft'
        ELSE 'Unexpected state -- check manually'
    END AS Diagnosis
FROM #PublishedRowsForList AS p WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_WatchToComplication_d AS wtcd WITH (NOLOCK)
    ON wtcd.CatalogId = p.CatalogId AND wtcd.ComplicationId = p.ComplicationId
ORDER BY p.ComplicationId, p.CatalogId;

Select *
From tbl_CAT_WatchToComplication_d (NOLOCK)

-- =====================================================================================
-- Catalog / enrichment / watch counts per ComplicationId, built on the same
-- CatalogId -> tblReferenceNumber -> tblWatch_d chain used above, now carrying
-- ComplicationId through so we can roll up per complication instead of per catalog.
-- =====================================================================================

-- Step 1: Distinct active (CatalogId, ComplicationId) pairs
IF OBJECT_ID('tempdb..#MappedComplicationCatalogs') IS NOT NULL DROP TABLE #MappedComplicationCatalogs;
SELECT DISTINCT wtc.ComplicationId, wtc.CatalogId
INTO #MappedComplicationCatalogs
FROM EWMaster.dbo.tbl_CAT_WatchToComplication_d AS wtc WITH (NOLOCK)
WHERE wtc.StatusID = 1;

-- Step 2: Stage the watch columns we need (per project rule: never join
-- tblWatch_d inline -- stage it first). Exclude deleted watches.
IF OBJECT_ID('tempdb..#tblWatchForComplications') IS NOT NULL DROP TABLE #tblWatchForComplications;
SELECT
    wd.WatchId,
    wd.ReferenceNumberId
INTO #tblWatchForComplications
FROM EveryWatch.dbo.tblWatch_d AS wd WITH (NOLOCK)
WHERE wd.IsDeleted = 0 OR wd.IsDeleted IS NULL;

-- Step 3: Resolve each mapped (ComplicationId, CatalogId) pair's reference
-- numbers, then the watches hanging off those reference numbers.
-- LEFT JOINs here (instead of INNER) so a ComplicationId whose catalogs have
-- no tblReferenceNumber match, or no non-deleted watches, still shows up in
-- the Step 4 rollup below -- with 0 catalogs/watches -- instead of silently
-- disappearing from the GROUP BY.
IF OBJECT_ID('tempdb..#ComplicationCatalogWatches') IS NOT NULL DROP TABLE #ComplicationCatalogWatches;
SELECT
    mcc.ComplicationId,
    mcc.CatalogId,
    w.WatchId
INTO #ComplicationCatalogWatches
FROM #MappedComplicationCatalogs AS mcc
LEFT JOIN EveryWatch.dbo.tblReferenceNumber AS rn WITH (NOLOCK) ON rn.CatalogId = mcc.CatalogId
LEFT JOIN #tblWatchForComplications AS w ON w.ReferenceNumberId = rn.ReferenceNumberId;

-- Step 4: Per complication -- distinct catalog count and distinct watch count
SELECT
    ComplicationId,
    COUNT(DISTINCT CatalogId) AS CatalogCount,
    COUNT(DISTINCT WatchId) AS TotalWatchCount
FROM #ComplicationCatalogWatches
GROUP BY ComplicationId
ORDER BY ComplicationId;

-- =====================================================================================
-- Merge ComplicationId 209 (B, merged away) into ComplicationId 142 (A, kept)
--
-- Everything here runs against the DRAFT (_d) tables only -- never the published
-- tables directly. The next sp_PublishAllDataNew run propagates this to the
-- published side.
--
-- Order matters (same reasoning as the FK-violation investigation above):
--   1. Make sure every catalog that has 209 active also has 142 active
--      (reactivate a soft-deleted 142 row, or insert a new one).
--   2. Soft-delete every active 209 mapping row.
--   3. Repoint any alternative/synonym names pointing at 209.
--   4. Only THEN soft-delete 209 itself in tbl_CAT_Complication_d -- doing this
--      before step 2 is exactly what produced the FK error diagnosed earlier.
--
-- The tr_AutoTran triggers on these _d tables are disabled, so TransactionID is
-- stamped manually here, mirroring what the trigger would otherwise do
-- (TransactionTypeID: 1 = INSERT, 2 = UPDATE, 3 = DELETE, per the trigger body).
--
-- Review the SELECTs at the end BEFORE committing. Nothing here commits itself --
-- uncomment COMMIT TRANSACTION only once the results look right, or ROLLBACK to
-- undo everything.
-- =====================================================================================

DECLARE @KeepComplicationId INT = 142;   -- A: kept
DECLARE @MergeComplicationId INT = 209;  -- B: merged away
DECLARE @UserId INT = NULL;              -- TODO: fill in your tblUser UserId before running
DECLARE @TransactionId BIGINT;

BEGIN TRANSACTION;

-- Step 1a: Reactivate any soft-deleted (StatusID=3) (CatalogId, Keep) row, for
-- catalogs that currently have Merge active
INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
VALUES (2, @UserId, GETDATE());
SET @TransactionId = SCOPE_IDENTITY();

UPDATE target
SET StatusID = 1,
    UpdatedDate = GETDATE(),
    UserId = @UserId,
    TransactionID = @TransactionId
FROM dbo.tbl_CAT_WatchToComplication_d AS target
JOIN dbo.tbl_CAT_WatchToComplication_d AS merge_row
    ON merge_row.CatalogId = target.CatalogId
WHERE target.ComplicationId = @KeepComplicationId
  AND target.StatusID = 3
  AND merge_row.ComplicationId = @MergeComplicationId
  AND merge_row.StatusID = 1;

-- Step 1b: Insert a new (CatalogId, Keep) row for catalogs that have Merge
-- active and have NO row at all yet for Keep
INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
VALUES (1, @UserId, GETDATE());
SET @TransactionId = SCOPE_IDENTITY();

INSERT INTO dbo.tbl_CAT_WatchToComplication_d
    (CatalogId, ComplicationId, CreatedDate, UpdatedDate, UserId, TransactionID, StatusID)
SELECT
    merge_row.CatalogId,
    @KeepComplicationId,
    GETDATE(),
    GETDATE(),
    @UserId,
    @TransactionId,
    1
FROM dbo.tbl_CAT_WatchToComplication_d AS merge_row
WHERE merge_row.ComplicationId = @MergeComplicationId
  AND merge_row.StatusID = 1
  AND NOT EXISTS (
      SELECT 1 FROM dbo.tbl_CAT_WatchToComplication_d AS existing_keep
      WHERE existing_keep.CatalogId = merge_row.CatalogId
        AND existing_keep.ComplicationId = @KeepComplicationId
  );

-- Step 1c: Soft-delete every active Merge mapping row -- must run AFTER 1a/1b
-- so every catalog that had Merge active now also has Keep active
INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
VALUES (3, @UserId, GETDATE());
SET @TransactionId = SCOPE_IDENTITY();

UPDATE dbo.tbl_CAT_WatchToComplication_d
SET StatusID = 3,
    UpdatedDate = GETDATE(),
    UserId = @UserId,
    TransactionID = @TransactionId
WHERE ComplicationId = @MergeComplicationId
  AND StatusID = 1;

-- Step 2: Repoint any alternative/synonym names from Merge to Keep, so they
-- aren't left orphaned once Merge is retired
INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
VALUES (2, @UserId, GETDATE());
SET @TransactionId = SCOPE_IDENTITY();

UPDATE dbo.tbl_CAT_ComplicationAlternative_d
SET ComplicationId = @KeepComplicationId,
    UpdatedDate = GETDATE(),
    UserId = @UserId,
    TransactionID = @TransactionId
WHERE ComplicationId = @MergeComplicationId;

-- Step 3: Retire the Merge complication itself -- must run LAST, after every
-- mapping row and alternative-name row pointing at it is gone
INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
VALUES (3, @UserId, GETDATE());
SET @TransactionId = SCOPE_IDENTITY();

UPDATE dbo.tbl_CAT_Complication_d
SET StatusID = 3,
    UpdatedDate = GETDATE(),
    UserId = @UserId,
    TransactionID = @TransactionId
WHERE ComplicationId = @MergeComplicationId;

-- Review before committing
SELECT * FROM dbo.tbl_CAT_WatchToComplication_d WHERE ComplicationId IN (@KeepComplicationId, @MergeComplicationId) ORDER BY CatalogId;
SELECT * FROM dbo.tbl_CAT_Complication_d WHERE ComplicationId IN (@KeepComplicationId, @MergeComplicationId);
SELECT * FROM dbo.tbl_CAT_ComplicationAlternative_d WHERE ComplicationId IN (@KeepComplicationId, @MergeComplicationId);

-- Only commit once the above results look correct:
-- COMMIT TRANSACTION;
-- To undo instead:
-- ROLLBACK TRANSACTION;