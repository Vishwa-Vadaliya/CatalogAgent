------------------------------------------------------------------------------
-- ECH-409: Follow-up check — the full diagnostic only returned ColorId 4524;
-- 4545 and 4549 (named in the ticket) returned no row at all. This checks,
-- with the absolute minimum logic, whether those rows still exist at all
-- (regardless of IsDeleted/IsActive/CleanName), and does a broad name sweep
-- in case they were renamed.
-- Run from EWMaster (cross-DB to EveryWatch).
------------------------------------------------------------------------------

------------------------------------------------------------
-- 1. Do ColorId 4524 / 4545 / 4549 exist at all in tblColor,
--    with no filtering whatsoever?
------------------------------------------------------------
DROP TABLE IF EXISTS #RawCheck;
SELECT c.ColorId,
       c.ColorName,
       c.CleanName,
       c.IsActive,
       c.IsDeleted,
       c.IsPending,
       c.ParentId,
       c.CatalogId,
       c.CreatedDate,
       c.UpdatedDate
INTO #RawCheck
FROM EveryWatch.dbo.tblColor AS c WITH (NOLOCK)
WHERE c.ColorId IN (4524, 4545, 4549);

SELECT * FROM #RawCheck ORDER BY ColorId;

------------------------------------------------------------
-- 2. Broad name sweep — any row whose name contains "ombr"
--    (catches "ombre"/"ombrè"/renamed variants), regardless of id.
------------------------------------------------------------
DROP TABLE IF EXISTS #NameSweep;
SELECT c.ColorId,
       c.ColorName,
       c.CleanName,
       c.IsActive,
       c.IsDeleted,
       c.ParentId,
       c.CatalogId,
       c.CreatedDate,
       c.UpdatedDate
INTO #NameSweep
FROM EveryWatch.dbo.tblColor AS c WITH (NOLOCK)
WHERE c.ColorName LIKE N'%ombr%'
   OR c.CleanName LIKE N'%ombr%';

SELECT * FROM #NameSweep ORDER BY ColorId;

------------------------------------------------------------
-- 3. Were 4545 / 4549 merged away already? Check the merge queue
--    and merge history for these ids as OldAttributeId (AttributeTypeId
--    5 = Dial Color per sp_UT_MergeColor) — this would explain rows
--    disappearing from tblColor if sp_UT_MergeColor already ran.
------------------------------------------------------------
DROP TABLE IF EXISTS #MergeQueueCheck;
SELECT m.Id,
       m.AttributeTypeId,
       m.OldAttributeId,
       m.OldAttributeName,
       m.NewAttributeId,
       m.NewAttributeName,
       m.ActionTypeId,
       m.ActionStatus,
       m.CreatedDate,
       m.UpdatedDate,
       m.ApprovedDate,
       m.MoveToSynonym
INTO #MergeQueueCheck
FROM EveryWatch.dbo.tblAttributeMergeQueue AS m WITH (NOLOCK)
WHERE m.AttributeTypeId = 5
  AND (m.OldAttributeId IN (4524, 4545, 4549)
       OR m.NewAttributeId IN (4524, 4545, 4549)
       OR m.OldAttributeName LIKE N'%ombr%'
       OR m.NewAttributeName LIKE N'%ombr%');

SELECT * FROM #MergeQueueCheck ORDER BY CreatedDate DESC;

------------------------------------------------------------
-- 4. Were 4545 / 4549 moved to a color synonym instead of deleted
--    outright? (sp_UT_MergeColor's MoveToSynonym path.)
------------------------------------------------------------
DROP TABLE IF EXISTS #SynonymCheck;
SELECT s.ColorSynonymID,
       s.ColorId,
       s.ColorName,
       s.IsAlternativeName,
       s.IsVerified
INTO #SynonymCheck
FROM EveryWatch.dbo.tblColorSynonym AS s WITH (NOLOCK)
WHERE s.ColorId IN (4524, 4545, 4549)
   OR s.ColorName LIKE N'%ombr%';

SELECT * FROM #SynonymCheck ORDER BY ColorId;
