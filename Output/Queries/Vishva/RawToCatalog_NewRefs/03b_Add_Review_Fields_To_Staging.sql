/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 03b: add the extra sp_Create_Catalog fields to tbl_CAT_RawRefStaging
===================================================================================
Purpose : sp_Create_Catalog has 11 more optional fields that scripts 03 / 04 did not carry.
          This adds one staging column for each (CatalogNotes is NOT added, on purpose).
DB      : EWMaster
Run     : hand-run in SSMS, once, AFTER script 03. Re-runnable (a column is only added if missing).
          Changes the structure only, no data. Run it BEFORE re-creating scripts 04 / 06.

Who fills what
  Step 4 (script 04) from the raw table:
    MovementNumber_Raw / MovementNumberName_Mapped   raw MovementNo -> tbl_CAT_MovementNumber_d (exact match)
    Style_Raw / Style_Value                          raw Style (kept when 30 characters or less)
  Step 5 (the review: Claude from Title / Description / image, or a person) - no raw column exists:
    CaseEmbelishmentNames_Mapped, StrapEmbelishmentNames_Mapped, BezelEmbelishmentNames_Mapped
        -> tbl_CAT_Embelishment_d, comma-separated
    IndicesMaterialNames_Mapped -> tbl_CAT_Material_d, comma-separated
    Series_Value                -> free text (NVARCHAR(4000), no master list)
    BezelStyleName_Mapped       -> tbl_CAT_BezelStyle_d
    BezelTypeName_Mapped        -> tbl_CAT_BezelType_d
    NicknameName_Mapped         -> tbl_CAT_Nickname_d
    PusherShapeName_Mapped      -> tbl_CAT_PusherShape_d
  A value must match the master name exactly: sp_Create_Catalog rejects an unknown name.
  Step 4 never clears the step 5 columns, also not with @Reprocess = 1.
===================================================================================
*/

USE [EWMaster]
GO

IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'MovementNumber_Raw') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD MovementNumber_Raw NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'MovementNumberName_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD MovementNumberName_Mapped NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'Style_Raw') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD Style_Raw NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'Style_Value') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD Style_Value VARCHAR(30) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'CaseEmbelishmentNames_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD CaseEmbelishmentNames_Mapped NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'StrapEmbelishmentNames_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD StrapEmbelishmentNames_Mapped NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'BezelEmbelishmentNames_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD BezelEmbelishmentNames_Mapped NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'IndicesMaterialNames_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD IndicesMaterialNames_Mapped NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'Series_Value') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD Series_Value NVARCHAR(4000) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'BezelStyleName_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD BezelStyleName_Mapped NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'BezelTypeName_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD BezelTypeName_Mapped NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'NicknameName_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD NicknameName_Mapped NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.tbl_CAT_RawRefStaging', N'PusherShapeName_Mapped') IS NULL
    ALTER TABLE dbo.tbl_CAT_RawRefStaging ADD PusherShapeName_Mapped NVARCHAR(500) NULL;
GO

-- Check: the 13 new columns exist (expect 13 rows)
SELECT c.name AS ColumnName, TYPE_NAME(c.user_type_id) AS DataType, c.max_length
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefStaging')
  AND c.name IN (N'MovementNumber_Raw', N'MovementNumberName_Mapped', N'Style_Raw', N'Style_Value',
                 N'CaseEmbelishmentNames_Mapped', N'StrapEmbelishmentNames_Mapped', N'BezelEmbelishmentNames_Mapped',
                 N'IndicesMaterialNames_Mapped', N'Series_Value', N'BezelStyleName_Mapped', N'BezelTypeName_Mapped',
                 N'NicknameName_Mapped', N'PusherShapeName_Mapped')
ORDER BY c.column_id;
