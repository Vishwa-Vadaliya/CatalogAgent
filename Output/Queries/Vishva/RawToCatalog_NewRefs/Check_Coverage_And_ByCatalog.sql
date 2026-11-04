/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: coverage and comma list of raw ids per catalog row - read-only, temp tables
===================================================================================
Purpose : Replaces the two views that were first planned. SELECT / temp tables only,
          nothing is created in the database.
DB      : EWMaster. Needs script 01 and the map filled (step 1).
Run     : run each numbered block on its own (select the block, F5).
===================================================================================
*/

------------------------------------------------------------
-- 1. Coverage: official raw rows with / without a CatalogId, per manufacturer + source
--    tbl_CAT_RawRefMap
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

------------------------------------------------------------
-- 2. Overall total (needs query 1 in the same window)
------------------------------------------------------------
SELECT
    SUM(OfficialRawRows) AS OfficialRawRows,
    SUM(MappedRows)      AS MappedRows,
    SUM(UnmappedRows)    AS UnmappedRows,
    CAST(100.0 * SUM(MappedRows) / NULLIF(SUM(OfficialRawRows), 0) AS DECIMAL(5, 2)) AS MappedPct
FROM #Coverage;

------------------------------------------------------------
-- 3. Comma list: raw ids per catalog row (one row per CatalogId with raw rows mapped)
--    tbl_CAT_RawRefMap, tbl_CAT_Catalog_d
--    Add a manufacturer filter below for a big run (copy the line, set the id).
------------------------------------------------------------
DROP TABLE IF EXISTS #ByCatalog;

SELECT
    m.CatalogId,
    c.ReferenceNumber,
    COUNT(*)                                                                                      AS RawRowCount,
    STRING_AGG(CAST(m.RawCatalogId AS NVARCHAR(MAX)), ',') WITHIN GROUP (ORDER BY m.RawCatalogId) AS RawCatalogIds
INTO #ByCatalog
FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
INNER JOIN dbo.tbl_CAT_Catalog_d AS c WITH (NOLOCK)
    ON c.CatalogId = m.CatalogId
WHERE m.CatalogId IS NOT NULL
-- AND m.ManufacturerId = 0   -- <<< optional: one manufacturer
GROUP BY m.CatalogId, c.ReferenceNumber;

SELECT * FROM #ByCatalog ORDER BY RawRowCount DESC, CatalogId;
