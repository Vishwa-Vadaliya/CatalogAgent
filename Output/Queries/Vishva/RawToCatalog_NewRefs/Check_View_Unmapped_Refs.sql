/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: look at the unmapped / new refs (read-only)
===================================================================================
Purpose : See the unique new references staged by step 3, and the raw rows that could
          not be staged (no reference number). SELECT only, changes nothing.
DB      : EWMaster. Needs scripts 01-03 run and steps 1, 2 and 3 executed.
Run     : run each numbered query on its own (select the block, F5).
          Optional filter: put a manufacturer name in the WHERE of query 2 / 3.
===================================================================================
*/

------------------------------------------------------------
-- 1. Summary: new refs waiting per manufacturer
--    tbl_CAT_RawRefStaging (one row per unique new ref)
------------------------------------------------------------
SELECT
    s.ManufacturerName,
    COUNT(*)            AS NewRefs,
    SUM(s.RawRowCount)  AS RawRowsBehindThem
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ExecutionStatus IS NULL
   OR s.ExecutionStatus = 'Pending'
GROUP BY s.ManufacturerName
ORDER BY NewRefs DESC;

------------------------------------------------------------
-- 2. The list: every unique new ref (one row each)
--    Add  AND s.ManufacturerName = N'Ball'  to look at one manufacturer.
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final AS NewReference,
    s.ReferenceRaw          AS LatestRawText,
    s.RawRowCount,
    s.RawCatalogIds,
    s.CatSourceName,
    s.IsApproved,
    s.ExecutionStatus
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE (s.ExecutionStatus IS NULL OR s.ExecutionStatus = 'Pending')
ORDER BY s.ManufacturerName, s.ReferenceNumber_Final;

------------------------------------------------------------
-- 3. Raw rows still unmapped that have NO usable reference
--    (cannot become catalog refs - crawler data gap)
--    tbl_CAT_RawRefMap where CatalogId IS NULL and RefKey IS NULL
------------------------------------------------------------
SELECT TOP (500)
    m.RawCatalogId,
    sm.CatManufacturerName AS ManufacturerName,
    m.SourceId,
    m.ReferenceRaw
FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = m.SourceId
WHERE m.CatalogId IS NULL
  AND m.RefKey IS NULL
ORDER BY sm.CatManufacturerName, m.RawCatalogId;
