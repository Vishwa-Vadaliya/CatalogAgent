/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 02b: remove staged refs that the mapping-table check matched (one-time cleanup)
===================================================================================
Purpose : Step 2 now reads tbl_CAT_RawCatalogMapping first. After you re-run script 02 and
          EXEC dbo.sp_CAT_RawRef_SyncAndMatch, some map rows that were 'New' become
          'Matched'. Their refs are already in tbl_CAT_RawRefStaging (built by steps 3 and 4)
          and must not be created again. This script lists them and then deletes them from
          the staging table and from tbl_CAT_RawRefUnmatchedValue.
DB      : EWMaster. Run AFTER: script 02 (re-created) and EXEC dbo.sp_CAT_RawRef_SyncAndMatch.
Changes : DELETE on tbl_CAT_RawRefStaging and tbl_CAT_RawRefUnmatchedValue (workflow tables
          only; no catalog or raw table is touched). Only refs that are NOT approved and NOT
          executed (ExecutionStatus NULL or DryRunOK) are removed.
Run     : 1) Run part 1 (the list) and look at it. 2) Run part 2 (the delete).
          Nothing is lost for good: a ref that is still new is staged again by step 3.
===================================================================================
*/

------------------------------------------------------------
-- 1. Preview: staged refs that no longer have any 'New' raw row
------------------------------------------------------------
IF OBJECT_ID('tempdb..#ToRemove') IS NOT NULL DROP TABLE #ToRemove;

SELECT
    s.StagingId,
    s.ManufacturerId,
    s.RefKey,
    s.ManufacturerName,
    s.ReferenceNumber_Final,
    s.RawRowCount
INTO #ToRemove
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.IsApproved = 0
  AND (s.ExecutionStatus IS NULL OR s.ExecutionStatus = 'DryRunOK')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
        WHERE m.ManufacturerId = s.ManufacturerId
          AND m.RefKey         = s.RefKey
          AND m.MapStatus      = 'New'
  );

SELECT StagingId, ManufacturerName, ReferenceNumber_Final, RawRowCount FROM #ToRemove ORDER BY ManufacturerName, ReferenceNumber_Final;

SELECT ManufacturerName, COUNT(*) AS RefsToRemove
FROM #ToRemove
GROUP BY ManufacturerName
ORDER BY COUNT(*) DESC;

------------------------------------------------------------
-- 1b. Why each ref is no longer new: what its raw rows are now (read-only, run before the delete)
--     MapStatus Matched + a CatalogId = found in tbl_CAT_RawCatalogMapping or the catalog.
--     MapNote tells which one. Check a few rows by eye: CatalogReference should be the same watch.
--     tbl_CAT_RawRefMap, tbl_CAT_Catalog_d
------------------------------------------------------------
SELECT
    r.StagingId,
    r.ManufacturerName,
    r.ReferenceNumber_Final,
    m.MapStatus,
    m.CatalogId,
    cd.ReferenceNumber AS CatalogReference,
    cd.StatusID        AS CatalogStatusID,
    m.MapNote,
    COUNT(*)           AS RawRows
FROM #ToRemove AS r
INNER JOIN dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
    ON m.ManufacturerId = r.ManufacturerId
   AND m.RefKey         = r.RefKey
LEFT JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
    ON cd.CatalogId = m.CatalogId
GROUP BY r.StagingId, r.ManufacturerName, r.ReferenceNumber_Final, m.MapStatus, m.CatalogId,
         cd.ReferenceNumber, cd.StatusID, m.MapNote
ORDER BY r.ManufacturerName, r.ReferenceNumber_Final;

------------------------------------------------------------
-- 2. Delete (run together with part 1, in the same window - it uses #ToRemove)
------------------------------------------------------------
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DELETE u
FROM dbo.tbl_CAT_RawRefUnmatchedValue AS u
INNER JOIN #ToRemove AS r
    ON r.StagingId = u.StagingId;

PRINT 'Unmatched-value rows removed: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

DELETE s
FROM dbo.tbl_CAT_RawRefStaging AS s
INNER JOIN #ToRemove AS r
    ON r.StagingId = s.StagingId;

PRINT 'Staged refs removed: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

COMMIT TRANSACTION;
