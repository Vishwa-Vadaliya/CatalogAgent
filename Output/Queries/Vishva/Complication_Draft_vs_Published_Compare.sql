------------------------------------------------------------
-- Compare complication draft vs published tables (EWMaster)
--   tbl_CAT_Complication_d          vs tbl_CAT_Complication
--   tbl_CAT_WatchToComplication_d   vs tbl_CAT_WatchToComplication
-- Published tables have no StatusID, so they are compared with the ACTIVE
-- draft rows (StatusID = 1). ONLY draft StatusID = 1 should be published:
-- draft rows with StatusID = 2 (or 3) are expected to be absent from published;
-- if they are still published it is flagged.
-- Read the details at any step with SELECT * FROM #Step.
------------------------------------------------------------

------------------------------------------------------------
-- 1. Complication: draft (all statuses) and published
------------------------------------------------------------
DROP TABLE IF EXISTS #CompDraft;
SELECT ComplicationId, ComplicationName, CreatedDate, UpdatedDate, UserId, TransactionID, StatusID
INTO #CompDraft
FROM dbo.tbl_CAT_Complication_d WITH (NOLOCK);
CREATE CLUSTERED INDEX IX_CompDraft ON #CompDraft (ComplicationId);

DROP TABLE IF EXISTS #CompPub;
SELECT ComplicationId, ComplicationName, CreatedDate, UpdatedDate, UserId, TransactionID, DraftID
INTO #CompPub
FROM dbo.tbl_CAT_Complication WITH (NOLOCK);
CREATE CLUSTERED INDEX IX_CompPub ON #CompPub (ComplicationId);

------------------------------------------------------------
-- 2. WatchToComplication: draft (all statuses) and published
------------------------------------------------------------
DROP TABLE IF EXISTS #WtcDraft;
SELECT CatalogId, ComplicationId, CreatedDate, UpdatedDate, UserId, TransactionID, StatusID
INTO #WtcDraft
FROM dbo.tbl_CAT_WatchToComplication_d WITH (NOLOCK);
CREATE CLUSTERED INDEX IX_WtcDraft ON #WtcDraft (CatalogId, ComplicationId);

DROP TABLE IF EXISTS #WtcPub;
SELECT CatalogId, ComplicationId, CreatedDate, UpdatedDate, UserId, TransactionID
INTO #WtcPub
FROM dbo.tbl_CAT_WatchToComplication WITH (NOLOCK);
CREATE CLUSTERED INDEX IX_WtcPub ON #WtcPub (CatalogId, ComplicationId);

------------------------------------------------------------
-- 3. Complication differences (row level)
--    Join on ComplicationId. Only rows that differ are kept.
------------------------------------------------------------
DROP TABLE IF EXISTS #ComplicationDiff;
SELECT
    COALESCE(d.ComplicationId, p.ComplicationId) AS ComplicationId,
    CASE
        WHEN p.ComplicationId IS NULL                       THEN 'Draft active, NOT in published'
        WHEN d.ComplicationId IS NULL                       THEN 'In published, NOT in draft'
        WHEN d.StatusID <> 1                                THEN 'In published, but draft StatusID = ' + CAST(d.StatusID AS VARCHAR(3)) + ' (only StatusID 1 should be published)'
        ELSE 'Value difference'
    END AS DiffType,
    d.StatusID                AS DraftStatusID,
    d.ComplicationName        AS DraftName,
    p.ComplicationName        AS PublishedName,
    d.TransactionID           AS DraftTransactionID,
    p.TransactionID           AS PublishedTransactionID,
    d.UserId                  AS DraftUserId,
    p.UserId                  AS PublishedUserId,
    d.CreatedDate             AS DraftCreatedDate,
    p.CreatedDate             AS PublishedCreatedDate,
    d.UpdatedDate             AS DraftUpdatedDate,
    p.UpdatedDate             AS PublishedUpdatedDate,
    p.DraftID                 AS PublishedDraftID,
    CASE WHEN ISNULL(d.ComplicationName, '') <> ISNULL(p.ComplicationName, '') THEN 1 ELSE 0 END AS NameDiffers,
    CASE WHEN d.TransactionID <> p.TransactionID                               THEN 1 ELSE 0 END AS TransactionDiffers,
    CASE WHEN ISNULL(d.UserId, -1) <> ISNULL(p.UserId, -1)                     THEN 1 ELSE 0 END AS UserIdDiffers,
    CASE WHEN d.CreatedDate <> p.CreatedDate                                   THEN 1 ELSE 0 END AS CreatedDateDiffers,
    CASE WHEN d.UpdatedDate <> p.UpdatedDate                                   THEN 1 ELSE 0 END AS UpdatedDateDiffers
INTO #ComplicationDiff
FROM #CompDraft AS d WITH (NOLOCK)
FULL OUTER JOIN #CompPub AS p WITH (NOLOCK)
    ON p.ComplicationId = d.ComplicationId
WHERE (d.StatusID = 1 AND p.ComplicationId IS NULL)         -- active in draft, missing in published
   OR (d.ComplicationId IS NULL)                            -- only in published
   OR (p.ComplicationId IS NOT NULL AND d.StatusID <> 1)    -- published but draft not active
   OR (d.StatusID = 1 AND p.ComplicationId IS NOT NULL AND (
          ISNULL(d.ComplicationName, '') <> ISNULL(p.ComplicationName, '')
       OR d.TransactionID <> p.TransactionID
       OR ISNULL(d.UserId, -1) <> ISNULL(p.UserId, -1)
       OR d.CreatedDate <> p.CreatedDate
       OR d.UpdatedDate <> p.UpdatedDate));

------------------------------------------------------------
-- 4. WatchToComplication differences (row level)
--    Join on (CatalogId, ComplicationId). Only rows that differ are kept.
------------------------------------------------------------
DROP TABLE IF EXISTS #MappingDiff;
SELECT
    COALESCE(d.CatalogId, p.CatalogId)           AS CatalogId,
    COALESCE(d.ComplicationId, p.ComplicationId) AS ComplicationId,
    CASE
        WHEN p.CatalogId IS NULL   THEN 'Draft active, NOT in published'
        WHEN d.CatalogId IS NULL   THEN 'In published, NOT in draft'
        WHEN d.StatusID <> 1       THEN 'In published, but draft StatusID = ' + CAST(d.StatusID AS VARCHAR(3)) + ' (only StatusID 1 should be published)'
        ELSE 'Value difference'
    END AS DiffType,
    d.StatusID                AS DraftStatusID,
    d.TransactionID           AS DraftTransactionID,
    p.TransactionID           AS PublishedTransactionID,
    d.UserId                  AS DraftUserId,
    p.UserId                  AS PublishedUserId,
    d.CreatedDate             AS DraftCreatedDate,
    p.CreatedDate             AS PublishedCreatedDate,
    d.UpdatedDate             AS DraftUpdatedDate,
    p.UpdatedDate             AS PublishedUpdatedDate,
    CASE WHEN d.TransactionID <> p.TransactionID           THEN 1 ELSE 0 END AS TransactionDiffers,
    CASE WHEN ISNULL(d.UserId, -1) <> ISNULL(p.UserId, -1) THEN 1 ELSE 0 END AS UserIdDiffers,
    CASE WHEN d.CreatedDate <> p.CreatedDate               THEN 1 ELSE 0 END AS CreatedDateDiffers,
    CASE WHEN d.UpdatedDate <> p.UpdatedDate               THEN 1 ELSE 0 END AS UpdatedDateDiffers
INTO #MappingDiff
FROM #WtcDraft AS d WITH (NOLOCK)
FULL OUTER JOIN #WtcPub AS p WITH (NOLOCK)
    ON p.CatalogId = d.CatalogId
   AND p.ComplicationId = d.ComplicationId
WHERE (d.StatusID = 1 AND p.CatalogId IS NULL)
   OR (d.CatalogId IS NULL)
   OR (p.CatalogId IS NOT NULL AND d.StatusID <> 1)
   OR (d.StatusID = 1 AND p.CatalogId IS NOT NULL AND (
          d.TransactionID <> p.TransactionID
       OR ISNULL(d.UserId, -1) <> ISNULL(p.UserId, -1)
       OR d.CreatedDate <> p.CreatedDate
       OR d.UpdatedDate <> p.UpdatedDate));

------------------------------------------------------------
-- 5. Count comparison + number of differing rows (final result)
--    Details: SELECT * FROM #ComplicationDiff;  SELECT * FROM #MappingDiff;
------------------------------------------------------------
SELECT
    'tbl_CAT_Complication'                          AS TablePair,
    (SELECT COUNT(*) FROM #CompDraft WITH (NOLOCK) WHERE StatusID = 1)  AS DraftActive,
    (SELECT COUNT(*) FROM #CompDraft WITH (NOLOCK) WHERE StatusID = 2)  AS DraftStatus2,
    (SELECT COUNT(*) FROM #CompDraft WITH (NOLOCK) WHERE StatusID = 3)  AS DraftDeleted,
    (SELECT COUNT(*) FROM #CompDraft WITH (NOLOCK) WHERE StatusID NOT IN (1, 2, 3)) AS DraftOtherStatus,
    (SELECT COUNT(*) FROM #CompPub WITH (NOLOCK))   AS Published,
    (SELECT COUNT(*) FROM #CompDraft WITH (NOLOCK) WHERE StatusID = 1)
      - (SELECT COUNT(*) FROM #CompPub WITH (NOLOCK)) AS ActiveMinusPublished,
    (SELECT COUNT(*) FROM #ComplicationDiff WITH (NOLOCK)) AS DifferingRows
UNION ALL
SELECT
    'tbl_CAT_WatchToComplication',
    (SELECT COUNT(*) FROM #WtcDraft WITH (NOLOCK) WHERE StatusID = 1),
    (SELECT COUNT(*) FROM #WtcDraft WITH (NOLOCK) WHERE StatusID = 2),
    (SELECT COUNT(*) FROM #WtcDraft WITH (NOLOCK) WHERE StatusID = 3),
    (SELECT COUNT(*) FROM #WtcDraft WITH (NOLOCK) WHERE StatusID NOT IN (1, 2, 3)),
    (SELECT COUNT(*) FROM #WtcPub WITH (NOLOCK)),
    (SELECT COUNT(*) FROM #WtcDraft WITH (NOLOCK) WHERE StatusID = 1)
      - (SELECT COUNT(*) FROM #WtcPub WITH (NOLOCK)),
    (SELECT COUNT(*) FROM #MappingDiff WITH (NOLOCK));
