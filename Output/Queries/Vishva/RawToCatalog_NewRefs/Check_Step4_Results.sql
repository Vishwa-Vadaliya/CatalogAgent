/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Check: results of step 4 (sp_CAT_RawRef_FillValues) - read-only
===================================================================================
Purpose : See what step 4 filled in tbl_CAT_RawRefStaging and what it could not match.
          SELECT only, changes nothing.
DB      : EWMaster. Needs scripts 01-04a and step 4 executed.
Run     : run each numbered query on its own (select the block, F5).
          Query 4 and 5 can be limited to one manufacturer: change the name in the WHERE.
===================================================================================
*/

------------------------------------------------------------
-- 1. Overall: how many staged refs have each value filled
--    tbl_CAT_RawRefStaging
------------------------------------------------------------
SELECT
    COUNT(*)                                                                AS StagedRefs,
    SUM(CASE WHEN s.ValuesMappedDate IS NOT NULL THEN 1 ELSE 0 END)         AS Filled,
    SUM(CASE WHEN s.ModelName_Mapped IS NOT NULL THEN 1 ELSE 0 END)         AS WithModel,
    SUM(CASE WHEN s.CaseSize_Parsed IS NOT NULL THEN 1 ELSE 0 END)          AS WithCaseSize,
    SUM(CASE WHEN s.DialColorNames_Mapped IS NOT NULL THEN 1 ELSE 0 END)    AS WithDialColor,
    SUM(CASE WHEN s.CaseMaterialNames_Mapped IS NOT NULL THEN 1 ELSE 0 END) AS WithCaseMaterial,
    SUM(CASE WHEN s.StrapMaterialNames_Mapped IS NOT NULL THEN 1 ELSE 0 END) AS WithStrapMaterial,
    SUM(CASE WHEN s.MovementTypeName_Mapped IS NOT NULL THEN 1 ELSE 0 END)  AS WithMovement,
    SUM(CASE WHEN s.CalibreNumberName_Mapped IS NOT NULL THEN 1 ELSE 0 END) AS WithCaliber,
    SUM(CASE WHEN s.WaterResistanceMeters_Parsed IS NOT NULL THEN 1 ELSE 0 END) AS WithWaterRes,
    SUM(CASE WHEN s.PowerReserveHourName_Parsed IS NOT NULL THEN 1 ELSE 0 END)  AS WithPowerReserve,
    SUM(CASE WHEN s.PrimaryImageURL IS NOT NULL THEN 1 ELSE 0 END)          AS WithImage,
    SUM(CASE WHEN s.SourceLink IS NOT NULL THEN 1 ELSE 0 END)               AS WithSourceLink,
    SUM(CASE WHEN s.ConflictNotes IS NOT NULL THEN 1 ELSE 0 END)            AS WithNotes
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK);

------------------------------------------------------------
-- 2. Per manufacturer: how complete are the refs (what is missing)
------------------------------------------------------------
SELECT
    s.ManufacturerName,
    COUNT(*)                                                              AS Refs,
    SUM(CASE WHEN s.ModelName_Mapped IS NULL THEN 1 ELSE 0 END)           AS NoModel,
    SUM(CASE WHEN s.CaseSize_Parsed IS NULL THEN 1 ELSE 0 END)            AS NoCaseSize,
    SUM(CASE WHEN s.DialColorNames_Mapped IS NULL THEN 1 ELSE 0 END)      AS NoDialColor,
    SUM(CASE WHEN s.CaseMaterialNames_Mapped IS NULL THEN 1 ELSE 0 END)   AS NoCaseMaterial,
    SUM(CASE WHEN s.PrimaryImageURL IS NULL THEN 1 ELSE 0 END)            AS NoImage,
    SUM(CASE WHEN s.ConflictNotes IS NOT NULL THEN 1 ELSE 0 END)          AS WithNotes
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
GROUP BY s.ManufacturerName
ORDER BY COUNT(*) DESC;

------------------------------------------------------------
-- 3. Values with no master value (what the master-table owner may need to add), most frequent first
--    tbl_CAT_RawRefUnmatchedValue
------------------------------------------------------------
SELECT TOP (200)
    u.FieldName,
    u.RawValue,
    u.Reason,
    COUNT(*)                       AS StagedRefs,
    COUNT(DISTINCT u.ManufacturerId) AS Manufacturers
FROM dbo.tbl_CAT_RawRefUnmatchedValue AS u WITH (NOLOCK)
GROUP BY u.FieldName, u.RawValue, u.Reason
ORDER BY COUNT(*) DESC, u.FieldName;

------------------------------------------------------------
-- 4. THE TABLE: one row per new ref, raw text next to the master value that will be used
--    Change the manufacturer name (or remove the WHERE line to see all).
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final     AS NewReference,
    s.RawRowCount,
    s.Model_Raw,                s.ModelName_Mapped,
    s.CaseSize_Parsed,          s.Width_Raw,                s.Dimensions_Raw,
    s.DialColor_Raw,            s.DialColorNames_Mapped,
    s.CaseMaterial_Raw,         s.CaseMaterialNames_Mapped,
    s.BraceletOrStrapMaterial_Raw, s.StrapMaterialNames_Mapped,
    s.Movement_Raw,             s.MovementTypeName_Mapped,
    s.Caliber_Raw,              s.CalibreNumberName_Mapped,
    s.WaterResistance_Raw,      s.WaterResistanceMeters_Parsed,
    s.PowerReserve_Raw,         s.PowerReserveHourName_Parsed,
    s.PrimaryImageURL,
    s.SourceLink,
    s.ConflictNotes,
    s.ValuesMappedDate
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ManufacturerName = N'Ball'
ORDER BY s.ManufacturerName, s.ReferenceNumber_Final;

------------------------------------------------------------
-- 5. The remaining fields for the same manufacturer (second part of the table)
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ReferenceNumber_Final     AS NewReference,
    s.DialMaterial_Raw,         s.DialMaterialName_Mapped,
    s.BezelMaterial_Raw,        s.BezelMaterialNames_Mapped,
    s.CaseBackMaterial_Raw,     s.CasebackMaterialNames_Mapped,
    s.DialEmbellishment_Raw,    s.DialEmbellishmentName_Mapped,
    s.IndicesStyle_Raw,         s.IndicesStyleNames_Mapped,
    s.StrapStyle_Raw,           s.StrapStyleName_Mapped,
    s.CrownEmbelishment_Raw,    s.CrownEmbelishmentName_Mapped,
    s.Jewels_Raw,               s.MovementJewelsName_Mapped,
    s.Edition_Raw,              s.EditionName_Mapped,
    s.DialStamp_Raw,            s.DialStampName_Mapped,
    s.SecondaryImageURLs
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ManufacturerName = N'Ball'
ORDER BY s.ReferenceNumber_Final;

------------------------------------------------------------
-- 6. Refs with notes: conflicts between raw rows, fuzzy matches, skipped image URLs
------------------------------------------------------------
SELECT TOP (200)
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final AS NewReference,
    s.ConflictNotes
FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE s.ConflictNotes IS NOT NULL
ORDER BY s.ManufacturerName, s.ReferenceNumber_Final;
