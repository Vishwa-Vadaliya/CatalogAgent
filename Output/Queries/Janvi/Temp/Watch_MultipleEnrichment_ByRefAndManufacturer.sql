/*
    Generalized check: for a given reference number + manufacturer, which
    draft watches (without an assigned enrichment) are sitting in
    tbl_RE_DataToFix "going in multiple enrichment".

    Background (see Knowledge/EW_DB_Knowledge.md §8):
    - A watch "goes in multiple enrichment" when, during enrichment
      assignment, it matches the role of more than one candidate enrichment
      (several ENRs can share the same role, so the watch is checked against
      all of them). Out of those candidates it may end up getting one
      (decided by image similarity) or none.
    - tbl_RE_DataToFix (WatchId = draft id, RefEnrichmentId) holds one row
      per candidate ENR for such a watch. IsFixed on that table is NOT used
      as a filter here (newest confirmed rule) - presence in the table is
      what matters, regardless of IsFixed.
    - A watch without an assigned enrichment = tblWatch_d.ReferenceEnrichmentId
      IS NULL (draft id).

    Steps:
    1) #Params - fill in the reference number + manufacturer to check (text,
       used only to resolve ids - never joined against watch tables directly).
    2) #ResolvedIds - resolve ManufacturerId (tblManufacturer) and
       ReferenceNumberId (tblReferenceNumber) once, up front.
    3) #NoEnrWatches - draft watches filtered by those ids only
       (tblWatch_d.ReferenceNumberId / ManufacturerId - never by the
       ReferenceNumber/ManufacturerName text columns) with no assigned
       enrichment (ReferenceEnrichmentId IS NULL).
    4) #CandidateDetail - those watches joined to tbl_RE_DataToFix, one row
       per candidate RefEnrichmentId.
    5) Final SELECT - one row per watch that has at least one candidate row,
       joined directly to tblMediaAsset_d for the primary image (off the
       already-filtered small watch set, not staged from the full table),
       with comma-separated RefEnrichmentIds, ReferenceNumber, WatchId,
       primary image, and the count of candidate enrichment ids.

    How to use:
    1) Run from EveryWatch (app DB). Edit #Params below with the reference
       number and manufacturer to check, then run the whole script.
    2) Each step is independent and can be re-run on its own once the
       earlier temp tables exist (per B2 - no DECLARE variables).
*/

------------------------------------------------------------
-- 1. Parameters - reference number + manufacturer to check (text input,
--    resolved to ids in the next step; not used to filter watch tables)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;

SELECT
    N'116710BLNR' AS ReferenceNumberInput,   -- <-- edit: reference number to check
    N'Rolex' AS ManufacturerNameInput         -- <-- edit: manufacturer name to check
INTO #Params;

------------------------------------------------------------
-- 2. Resolve ManufacturerId + ReferenceNumberId once, up front
--    tblManufacturer.ManufacturerName -> ManufacturerId
--    tblReferenceNumber.ReferenceNumber + ManufacturerId -> ReferenceNumberId
--    (ReferenceNumberInput kept only for display in the final result)
------------------------------------------------------------
DROP TABLE IF EXISTS #ResolvedIds;

SELECT
    rn.ReferenceNumberId,
    man.ManufacturerId,
    p.ReferenceNumberInput
INTO #ResolvedIds
FROM #Params AS p
INNER JOIN dbo.tblManufacturer AS man WITH (NOLOCK)
    ON man.ManufacturerName = p.ManufacturerNameInput
INNER JOIN dbo.tblReferenceNumber AS rn WITH (NOLOCK)
    ON rn.ManufacturerId = man.ManufacturerId
    AND rn.ReferenceNumber = p.ReferenceNumberInput;

------------------------------------------------------------
-- 3. Draft watches for that ReferenceNumberId/ManufacturerId, no assigned
--    enrichment - ids only, no join or filter on the text columns
--    ReferenceEnrichmentId IS NULL = no ENR assigned yet (draft id)
------------------------------------------------------------
DROP TABLE IF EXISTS #NoEnrWatches;

SELECT
    w.WatchId,
    r.ReferenceNumberInput AS ReferenceNumber
INTO #NoEnrWatches
FROM dbo.tblWatch_d AS w WITH (NOLOCK)
INNER JOIN #ResolvedIds AS r
    ON w.ReferenceNumberId = r.ReferenceNumberId
    AND w.ManufacturerId = r.ManufacturerId
WHERE w.ReferenceEnrichmentId IS NULL
    AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);

CREATE INDEX IX_NoEnrWatches_WatchId ON #NoEnrWatches (WatchId);

------------------------------------------------------------
-- 4. Candidate enrichment rows for those watches
--    tbl_RE_DataToFix.WatchId -> #NoEnrWatches.WatchId (draft id on both sides)
--    No IsFixed filter - every candidate row counts, per confirmed rule
------------------------------------------------------------
DROP TABLE IF EXISTS #CandidateDetail;

SELECT
    nw.WatchId,
    nw.ReferenceNumber,
    dtf.RefEnrichmentId,
    dtf.IsFixed
INTO #CandidateDetail
FROM #NoEnrWatches AS nw
INNER JOIN dbo.tbl_RE_DataToFix AS dtf WITH (NOLOCK)
    ON dtf.WatchId = nw.WatchId
WHERE dtf.RefEnrichmentId IS NOT NULL;

CREATE INDEX IX_CandidateDetail_WatchId ON #CandidateDetail (WatchId);

------------------------------------------------------------
-- 5. Final - one row per watch going in multiple enrichment, with
--    comma-separated candidate enrichment ids, ref number, watch id,
--    primary image, and count of candidate enrichment ids
--    Join tblMediaAsset_d directly off the already-filtered #CandidateDetail
--    watch set (small), not staged from the full (millions-of-rows) table (B5/B8)
------------------------------------------------------------
SELECT
    cd.WatchId,
    cd.ReferenceNumber,
    ma.Url AS PrimaryImageUrl,
    STRING_AGG(CAST(cd.RefEnrichmentId AS NVARCHAR(20)), ',') WITHIN GROUP (ORDER BY cd.RefEnrichmentId) AS EnrichmentIds,
    COUNT(DISTINCT cd.RefEnrichmentId) AS EnrichmentIdCount
FROM #CandidateDetail AS cd
LEFT JOIN dbo.tblMediaAsset_d AS ma WITH (NOLOCK)
    ON ma.WatchId = cd.WatchId
    AND ma.IsPrimary = 1
GROUP BY
    cd.WatchId,
    cd.ReferenceNumber,
    ma.Url
ORDER BY cd.WatchId;
