/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 05b: export one manufacturer batch for the Claude review (read-only)
===================================================================================
Purpose : One row per staged ref with IsApproved = 0 for ONE manufacturer: the values
          step 4 chose, the conflict notes, the image links, and the raw Title /
          Description text of the raw rows behind the ref. Claude reads this and
          decides per ref (text first, then image, then web).
          SELECT only, changes nothing.
DB      : EWMaster. Needs scripts 01-04 run and step 4 executed.
Run     : 1) Change the manufacturer name in the two places marked  <<< CHANGE.
          2) Select all, F5.
          3) Right-click the result grid > Save Results As > CSV, and give the file to
             Claude. Newlines inside the text are already replaced by spaces, so the
             CSV stays one line per ref.
Batch   : one manufacturer at a time. Refs with ConflictNotes come first.
Text    : up to the 3 newest raw rows per ref that have a Title or Description;
          each Description is cut to 1500 characters.
===================================================================================
*/

------------------------------------------------------------
-- 1. Staged refs of the batch (IsApproved = 0, not yet created)
------------------------------------------------------------
IF OBJECT_ID('tempdb..#Batch') IS NOT NULL DROP TABLE #Batch;

SELECT s.StagingId, s.ManufacturerId, s.RefKey
INTO   #Batch
FROM   dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
WHERE  s.ManufacturerName = N'Ball'                      -- <<< CHANGE
  AND  s.IsApproved = 0
  AND  (s.ExecutionStatus IS NULL OR s.ExecutionStatus = 'DryRunOK');

CREATE CLUSTERED INDEX IX_Batch ON #Batch (StagingId);

------------------------------------------------------------
-- 2. Raw rows behind each ref that have text, newest first, 3 per ref
--    tbl_CAT_RawRefMap (MapStatus = 'New') + tbl_RAW_Catalog
------------------------------------------------------------
IF OBJECT_ID('tempdb..#RawText') IS NOT NULL DROP TABLE #RawText;

SELECT
    b.StagingId,
    r.Id AS RawCatalogId,
    ROW_NUMBER() OVER (PARTITION BY b.StagingId ORDER BY r.Id DESC) AS rn,
    LTRIM(RTRIM(CAST(r.Title AS NVARCHAR(500))))                    AS Title,
    LEFT(LTRIM(RTRIM(CAST(r.[Description] AS NVARCHAR(MAX)))), 1500) AS [Description],
    LEFT(CAST(r.DialDescription AS NVARCHAR(MAX)), 300)             AS DialDescription,
    LEFT(CAST(r.CaseDescription AS NVARCHAR(MAX)), 300)             AS CaseDescription
INTO   #RawText
FROM   #Batch AS b
JOIN   dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
       ON  m.ManufacturerId = b.ManufacturerId
       AND m.RefKey         = b.RefKey
       AND m.MapStatus      = 'New'
JOIN   dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
       ON  r.Id = m.RawCatalogId
WHERE  NULLIF(LTRIM(RTRIM(CAST(r.Title AS NVARCHAR(500)))), N'') IS NOT NULL
   OR  NULLIF(LTRIM(RTRIM(CAST(r.[Description] AS NVARCHAR(MAX)))), N'') IS NOT NULL;

DELETE FROM #RawText WHERE rn > 3;

-- Replace line breaks so a CSV export stays one line per ref
UPDATE #RawText
SET Title           = REPLACE(REPLACE(Title,           CHAR(13), N' '), CHAR(10), N' '),
    [Description]   = REPLACE(REPLACE([Description],   CHAR(13), N' '), CHAR(10), N' '),
    DialDescription = REPLACE(REPLACE(DialDescription, CHAR(13), N' '), CHAR(10), N' '),
    CaseDescription = REPLACE(REPLACE(CaseDescription, CHAR(13), N' '), CHAR(10), N' ');

------------------------------------------------------------
-- 3. One text blob per ref
------------------------------------------------------------
IF OBJECT_ID('tempdb..#TextPerRef') IS NOT NULL DROP TABLE #TextPerRef;

SELECT
    t.StagingId,
    STRING_AGG(CAST(
        N'[raw ' + CAST(t.RawCatalogId AS NVARCHAR(20)) + N'] TITLE: ' + ISNULL(t.Title, N'')
        + N' | DESCRIPTION: ' + ISNULL(t.[Description], N'')
        AS NVARCHAR(MAX)), N'  ||  ') WITHIN GROUP (ORDER BY t.rn) AS RawTitleAndDescription,
    MAX(CASE WHEN t.rn = 1 THEN t.DialDescription END)             AS Latest_DialDescription,
    MAX(CASE WHEN t.rn = 1 THEN t.CaseDescription END)             AS Latest_CaseDescription
INTO   #TextPerRef
FROM   #RawText AS t
GROUP BY t.StagingId;

------------------------------------------------------------
-- 3b. Map notes of the raw rows behind each ref
--     (e.g. "tbl_CAT_RawCatalogMapping key points to several catalogs: ...")
------------------------------------------------------------
IF OBJECT_ID('tempdb..#MapNotes') IS NOT NULL DROP TABLE #MapNotes;

SELECT b.StagingId, MAX(m.MapNote) AS MapNote
INTO   #MapNotes
FROM   #Batch AS b
JOIN   dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
       ON  m.ManufacturerId = b.ManufacturerId
       AND m.RefKey         = b.RefKey
       AND m.MapStatus      = 'New'
WHERE  m.MapNote IS NOT NULL
GROUP BY b.StagingId;

------------------------------------------------------------
-- 4. The export: refs with conflict notes first
------------------------------------------------------------
SELECT
    s.StagingId,
    s.ManufacturerName,
    s.ReferenceNumber_Final      AS NewReference,
    s.RawRowCount,
    s.ConflictNotes,
    mn.MapNote                   AS MapNote,
    s.ModelName_Mapped,
    s.CaseSize_Parsed,
    s.DialColorNames_Mapped,
    s.CaseMaterialNames_Mapped,
    s.StrapMaterialNames_Mapped,
    s.MovementTypeName_Mapped,
    s.CalibreNumberName_Mapped,
    s.WaterResistanceMeters_Parsed,
    s.PowerReserveHourName_Parsed,
    s.DialMaterialName_Mapped,
    s.BezelMaterialNames_Mapped,
    s.CasebackMaterialNames_Mapped,
    s.DialEmbellishmentName_Mapped,
    s.IndicesStyleNames_Mapped,
    s.StrapStyleName_Mapped,
    s.CrownEmbelishmentName_Mapped,
    s.MovementJewelsName_Mapped,
    s.EditionName_Mapped,
    s.DialStampName_Mapped,
    s.MovementNumber_Raw,
    s.MovementNumberName_Mapped,
    s.Style_Raw,
    s.Style_Value,
    s.CaseEmbelishmentNames_Mapped,
    s.StrapEmbelishmentNames_Mapped,
    s.BezelEmbelishmentNames_Mapped,
    s.IndicesMaterialNames_Mapped,
    s.Series_Value,
    s.BezelStyleName_Mapped,
    s.BezelTypeName_Mapped,
    s.NicknameName_Mapped,
    s.PusherShapeName_Mapped,
    s.WaterResistance_Raw,
    s.PowerReserve_Raw,
    s.Model_Raw,
    s.DialColor_Raw,
    s.CaseMaterial_Raw,
    s.PrimaryImageURL,
    s.SourceLink,
    x.Latest_DialDescription,
    x.Latest_CaseDescription,
    x.RawTitleAndDescription,
    s.ValuesMappedDate
FROM   #Batch AS b
JOIN   dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK) ON s.StagingId = b.StagingId
LEFT JOIN #TextPerRef AS x ON x.StagingId = b.StagingId
LEFT JOIN #MapNotes   AS mn ON mn.StagingId = b.StagingId
ORDER BY CASE WHEN s.ConflictNotes IS NULL THEN 1 ELSE 0 END, s.ReferenceNumber_Final;

------------------------------------------------------------
-- 5. How many refs are in the batch (second result tab)
------------------------------------------------------------
SELECT
    N'Ball'                                                   AS Manufacturer,   -- <<< CHANGE (same name)
    COUNT(*)                                                  AS RefsInBatch,
    SUM(CASE WHEN s.ConflictNotes IS NOT NULL THEN 1 ELSE 0 END) AS WithConflictNotes,
    SUM(CASE WHEN x.StagingId IS NULL THEN 1 ELSE 0 END)      AS WithNoRawText
FROM   #Batch AS b
JOIN   dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK) ON s.StagingId = b.StagingId
LEFT JOIN #TextPerRef AS x ON x.StagingId = b.StagingId;
