/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: results of step 6 (sp_CAT_RawRef_CreateCatalog) - read-only
===================================================================================
Purpose : See what step 6 did: statuses, errors and the catalog rows it created.
          SELECT only, changes nothing.
DB      : EWMaster. Needs script 06 and step 6 executed (dry run or real).
Run     : run each numbered query on its own (select the block, F5).
===================================================================================
*/

------------------------------------------------------------
-- 1. Statuses of the approved refs (NULL = approved, not executed yet)
--    tbl_CAT_RawRefStaging
------------------------------------------------------------
SELECT
    s.ExecutionStatus,
    COUNT(*)           AS Refs,
    SUM(s.RawRowCount) AS RawRows
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.IsApproved = 1
GROUP BY s.ExecutionStatus
ORDER BY COUNT(*) DESC;

------------------------------------------------------------
-- 2. Errors grouped by message (what to fix first)
------------------------------------------------------------
SELECT TOP (100)
    LEFT(s.ExecutionError, 300) AS ErrorStart,
    COUNT(*)                    AS Refs,
    MIN(s.ManufacturerName)     AS ExampleManufacturer,
    MIN(s.ReferenceNumber_Final) AS ExampleReference
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ExecutionStatus = N'Error'
GROUP BY LEFT(s.ExecutionError, 300)
ORDER BY COUNT(*) DESC;

------------------------------------------------------------
-- 3. Every ref with an error (one row each)
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final AS NewReference,
    s.ExecutionDate,
    s.ExecutionError
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ExecutionStatus = N'Error'
ORDER BY s.ManufacturerName, s.ReferenceNumber_Final;

------------------------------------------------------------
-- 4. Refs skipped because they already exist in the catalog
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final AS NewReference,
    s.CatalogId             AS ExistingCatalogId,
    s.ExecutionError        AS Note
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ExecutionStatus = N'Skipped'
ORDER BY s.ManufacturerName, s.ReferenceNumber_Final;

------------------------------------------------------------
-- 5. Catalog rows created (real run): staged value next to what the catalog now holds
--    tbl_CAT_Catalog_d
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final AS StagedReference,
    cd.CatalogId,
    cd.ReferenceNumber      AS CatalogReference,
    cd.EntityType,
    cd.StatusID,
    cd.CreatedDate,
    s.RawRowCount
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
    ON cd.CatalogId = s.CatalogId
WHERE s.ExecutionStatus = N'Success'
ORDER BY s.ExecutionDate DESC, s.ManufacturerName;

------------------------------------------------------------
-- 6. Map table after step 6: coverage per manufacturer and source
--    (same as query 1 of Check_Coverage_And_ByCatalog.sql)
------------------------------------------------------------
DROP TABLE IF EXISTS #Coverage;

SELECT
    sm.CatManufacturerName AS ManufacturerName,
    m.ManufacturerId,
    sm.CatSourceName,
    m.SourceId,
    COUNT(*)                                                 AS OfficialRawRows,
    SUM(CASE WHEN m.CatalogId IS NOT NULL THEN 1 ELSE 0 END) AS MappedRows,
    SUM(CASE WHEN m.CatalogId IS NULL THEN 1 ELSE 0 END)     AS UnmappedRows,
    CAST(100.0 * SUM(CASE WHEN m.CatalogId IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 2)) AS MappedPct
INTO #Coverage
FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    ON sm.SourceId = m.SourceId
GROUP BY sm.CatManufacturerName, m.ManufacturerId, sm.CatSourceName, m.SourceId;

SELECT * FROM #Coverage ORDER BY UnmappedRows DESC;
