------------------------------------------------------------------------------
-- ECH-409: Final defensive check — confirm no watch is still pointing at the
-- now-nonexistent ColorIds 4545 / 4549 (should be impossible given the
-- enforced FK on tblWatchToDialColor(_d).DialColorId -> tblColor.ColorId,
-- but confirming explicitly before treating the app side as resolved).
-- Run from EveryWatch (or prefix with EveryWatch.dbo. if run from EWMaster).
------------------------------------------------------------------------------

DROP TABLE IF EXISTS #OrphanDraft;
SELECT wdc.WatchId, wdc.DialColorId
INTO #OrphanDraft
FROM dbo.tblWatchToDialColor_d AS wdc WITH (NOLOCK)
WHERE wdc.DialColorId IN (4545, 4549);

DROP TABLE IF EXISTS #OrphanPublished;
SELECT wdc.WatchId, wdc.DialColorId
INTO #OrphanPublished
FROM dbo.tblWatchToDialColor AS wdc WITH (NOLOCK)
WHERE wdc.DialColorId IN (4545, 4549);

SELECT 'Draft' AS Side, * FROM #OrphanDraft
UNION ALL
SELECT 'Published' AS Side, * FROM #OrphanPublished;
