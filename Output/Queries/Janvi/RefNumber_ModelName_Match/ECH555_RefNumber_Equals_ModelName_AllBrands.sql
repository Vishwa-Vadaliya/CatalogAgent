------------------------------------------------------------
-- ECH-555: Reference Number same as Model Name - validation across brands
-- DB: EveryWatch (app) for tblReferenceNumber/tblModel/tblManufacturer,
--     EWMaster (catalog) for the primary catalog image via CatalogId.
-- Finds every ReferenceNumberId whose ReferenceNumber text equals its
-- linked Model's ModelName text (same ManufacturerId), across all brands,
-- so each brand can be reviewed: is ref==model a valid pattern for that
-- brand (no real reference numbers, Model used as the de facto reference),
-- or is it a data error to fix.
-- Per B9: already matching on ids (ModelId/ManufacturerId), ReferenceNumber/
-- ModelName text is compared only because that IS the condition being checked.
-- Per B10: no IsDeleted filter here - not asked for, and tblReferenceNumber/
-- tblModel aren't the tables IsDeleted is maintained on.
------------------------------------------------------------

------------------------------------------------------------
-- 1. References whose ReferenceNumber text equals their Model's ModelName
--    (trimmed, case-insensitive), same ManufacturerId on both sides
------------------------------------------------------------
DROP TABLE IF EXISTS #RefModelSame;
SELECT
    rn.ReferenceNumberId,
    rn.ReferenceNumber,
    rn.ModelId,
    m.ModelName,
    rn.ManufacturerId,
    rn.CatalogId,
    rn.IsActive,
    rn.IsPending,
    rn.IsAutoCreated,
    rn.CreatedDate
INTO #RefModelSame
FROM EveryWatch.dbo.tblReferenceNumber AS rn WITH (NOLOCK)
INNER JOIN EveryWatch.dbo.tblModel AS m WITH (NOLOCK)
    ON m.ModelId = rn.ModelId
    AND m.ManufacturerId = rn.ManufacturerId
WHERE LTRIM(RTRIM(rn.ReferenceNumber)) = LTRIM(RTRIM(m.ModelName));

CREATE NONCLUSTERED INDEX IX_RefModelSame_CatalogId ON #RefModelSame (CatalogId);
CREATE NONCLUSTERED INDEX IX_RefModelSame_ManufacturerId ON #RefModelSame (ManufacturerId);

------------------------------------------------------------
-- 2. Primary catalog image per CatalogId (IsPrimary = 1, per B5)
------------------------------------------------------------
DROP TABLE IF EXISTS #PrimaryImage;
SELECT
    cm.CatalogId,
    cm.S3Url,
    cm.URL
INTO #PrimaryImage
FROM EWMaster.dbo.tbl_CAT_Media AS cm WITH (NOLOCK)
WHERE cm.IsPrimary = 1
    AND cm.CatalogId IN (SELECT CatalogId FROM #RefModelSame WHERE CatalogId IS NOT NULL);

CREATE NONCLUSTERED INDEX IX_PrimaryImage_CatalogId ON #PrimaryImage (CatalogId);

------------------------------------------------------------
-- 3. Final: brand name + ref/model match + primary image, one row per reference
------------------------------------------------------------
DROP TABLE IF EXISTS #Final;
SELECT
    mfr.ManufacturerName,
    r.ReferenceNumberId,
    r.ReferenceNumber,
    r.ModelId,
    r.ModelName,
    r.CatalogId,
    r.IsActive,
    r.IsPending,
    r.IsAutoCreated,
    r.CreatedDate,
    pi.S3Url AS PrimaryImageS3Url,
    pi.URL AS PrimaryImageURL
INTO #Final
FROM #RefModelSame AS r
INNER JOIN EveryWatch.dbo.tblManufacturer AS mfr WITH (NOLOCK)
    ON mfr.ManufacturerId = r.ManufacturerId
LEFT JOIN #PrimaryImage AS pi
    ON pi.CatalogId = r.CatalogId;

SELECT *
FROM #Final
ORDER BY ManufacturerName, ReferenceNumber;
