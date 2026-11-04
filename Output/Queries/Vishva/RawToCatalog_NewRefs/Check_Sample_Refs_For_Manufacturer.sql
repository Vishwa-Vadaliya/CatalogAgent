/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: sample of unmapped raw refs next to the manufacturer's catalog refs
===================================================================================
Purpose : For a manufacturer with low coverage (for example Ball, H. Moser, Doxa, Marvin),
          see whether the unmapped refs are really NEW refs or the same refs written in a
          different format than the catalog (extra suffix, spaces, different separators).
DB      : EWMaster. Read-only (SELECT only). Needs scripts 01 and 02 run, steps 1 and 2 executed.
Run     : change the ManufacturerId in step 1, then select all and run. The last step returns the result.
===================================================================================
*/

------------------------------------------------------------
-- 1. Parameter: the manufacturer to look at (13 = Ball, 65 = H. Moser & Cie, 45 = Doxa, 228 = Marvin)
------------------------------------------------------------
DROP TABLE IF EXISTS #Params;
SELECT 13 AS ManufacturerId
INTO #Params;

------------------------------------------------------------
-- 2. 20 distinct unmapped refs (raw text, cleaned text, normalized key)
--    tbl_CAT_RawRefMap where CatalogId IS NULL
------------------------------------------------------------
DROP TABLE IF EXISTS #UnmappedSample;
SELECT TOP (20)
    m.ReferenceRaw,
    m.ReferenceClean,
    m.RefKey
INTO #UnmappedSample
FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
INNER JOIN #Params AS p
    ON p.ManufacturerId = m.ManufacturerId
WHERE m.CatalogId IS NULL
  AND m.RefKey IS NOT NULL
GROUP BY m.ReferenceRaw, m.ReferenceClean, m.RefKey
ORDER BY m.ReferenceRaw;

------------------------------------------------------------
-- 3. 20 active Watch refs of the same manufacturer in the catalog
--    tbl_CAT_Catalog_d: EntityType = 'Watch', StatusID = 1
------------------------------------------------------------
DROP TABLE IF EXISTS #CatalogSample;
SELECT TOP (20)
    cd.CatalogId,
    cd.ReferenceNumber
INTO #CatalogSample
FROM dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
INNER JOIN #Params AS p
    ON p.ManufacturerId = cd.ManufacturerId
WHERE cd.StatusID = 1
  AND cd.EntityType = N'Watch'
ORDER BY cd.ReferenceNumber;

------------------------------------------------------------
-- 4. Result: both samples one under the other (last step)
------------------------------------------------------------
SELECT
    'Unmapped raw ref' AS Side,
    u.ReferenceRaw     AS ReferenceText,
    u.RefKey           AS NormalizedKey,
    CAST(NULL AS INT)  AS CatalogId
FROM #UnmappedSample AS u
UNION ALL
SELECT
    'Catalog ref',
    c.ReferenceNumber,
    NULL,
    c.CatalogId
FROM #CatalogSample AS c;
