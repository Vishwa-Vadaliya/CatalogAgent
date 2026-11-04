/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: how many UNIQUE new refs sit behind the unmapped official raw rows
===================================================================================
Purpose : The coverage view counts raw ROWS. The same ref appears in many sources
          (country sites) and listings, so unmapped rows are far more than unique new refs.
          This splits the unmapped rows per manufacturer into:
            - rows with no usable reference (blank / NULL / punctuation only; never staged)
            - rows with a reference, and how many DISTINCT normalized refs they make
DB      : EWMaster. Read-only (SELECT only). Needs scripts 01 and 02 run, with step 1 and 2 executed.
Run     : select all and run; the last step returns the result.
===================================================================================
*/

------------------------------------------------------------
-- 1. Unmapped official raw rows (CatalogId IS NULL) with the manufacturer name
--    tbl_CAT_RawRefMap + tbl_CAT_Manufacturer_d
------------------------------------------------------------
DROP TABLE IF EXISTS #Unmapped;
SELECT
    m.RawCatalogId,
    m.ManufacturerId,
    mf.ManufacturerName,
    m.RefKey
INTO #Unmapped
FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
    ON mf.ManufacturerId = m.ManufacturerId
WHERE m.CatalogId IS NULL;

------------------------------------------------------------
-- 2. Per manufacturer: rows, rows without a usable ref, distinct unique new refs
--    (last step - returns the result)
------------------------------------------------------------
SELECT
    u.ManufacturerId,
    u.ManufacturerName,
    COUNT(*)                                               AS UnmappedRawRows,
    SUM(CASE WHEN u.RefKey IS NULL THEN 1 ELSE 0 END)      AS RowsWithoutUsableRef,
    COUNT(DISTINCT u.RefKey)                               AS UniqueNewRefs
FROM #Unmapped AS u
GROUP BY u.ManufacturerId, u.ManufacturerName
ORDER BY UniqueNewRefs DESC;
