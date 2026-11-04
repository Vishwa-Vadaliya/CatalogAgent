/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 04a: sp_CAT_RawRef_MapValue - our own value-mapping procedure
===================================================================================
Purpose : Same inputs and outputs as dbo.sp_Map_RawValueToCatalog_Universal, but covers EVERY field the
          new-ref flow needs. sp_Map_RawValueToCatalog_Universal is in ew-db and is not changed; this is a
          COPY of its logic (DialColor, CaseMaterial, Model, MovementType, StrapMaterial, DialMaterial,
          DialEmbellishment, Caliber - unchanged) plus the additions below. If the shared procedure is
          improved later, copy the change here by hand.
DB      : EWMaster
Run     : hand-run in SSMS. Creates one procedure, changes no data. Re-runnable (CREATE OR ALTER).
          Run BEFORE script 04.

Additions (marked ECH-693 in the code):
  BezelMaterial, CaseBackMaterial -> same steps as CaseMaterial (tbl_CAT_Material_d, alternative names, fuzzy)
  IndicesStyle                    -> tbl_CAT_IndicesStyle_d, exact
  StrapStyle                      -> tbl_CAT_StrapStyle_d exact, then tbl_CAT_StrapStyleAlternative_d
  CrownEmbelishment               -> tbl_CAT_CrownEmbelishment_d exact, then tbl_CAT_CrownEmbelishmentAlternative_d
  Jewels                          -> tbl_CAT_MovementJewels_d, exact
  Edition                         -> tbl_CAT_Edition_d, exact, per @ManufacturerId
  DialStamp                       -> tbl_CAT_DialStamp_d, exact
Matches are trimmed, case-insensitive, active rows only. A value with no match returns
@MappedValue NULL and @MappingMethod 'NotFound'.
===================================================================================
*/

USE [EWMaster]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_CAT_RawRef_MapValue]
    @FieldName NVARCHAR(100),
    @RawValue NVARCHAR(MAX),
    @ManufacturerId INT = NULL,
    @SourceId INT = NULL,
    @MappedValue NVARCHAR(MAX) OUTPUT,
    @MappedIds NVARCHAR(500) OUTPUT,
    @MappingMethod NVARCHAR(50) OUTPUT,
    @ConfidenceScore DECIMAL(5,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @MappedValue = NULL;
    SET @MappedIds = NULL;
    SET @MappingMethod = 'NotFound';
    SET @ConfidenceScore = 0;

    DECLARE @TrimmedValue NVARCHAR(MAX) = LTRIM(RTRIM(@RawValue));
    -- Normalize trademark/registered/copyright marks and special dash characters so
    -- 'Moonshine(TM)-Gold' style raw text can still hit Exact/Alternative/Fuzzy matches.
    SET @TrimmedValue = REPLACE(REPLACE(REPLACE(@TrimmedValue, NCHAR(8482), N''), NCHAR(174), N''), NCHAR(169), N'');
    SET @TrimmedValue = REPLACE(REPLACE(@TrimmedValue, NCHAR(8209), N'-'), NCHAR(8211), N'-');
    SET @TrimmedValue = LTRIM(RTRIM(REPLACE(REPLACE(@TrimmedValue, N'  ', N' '), N'  ', N' ')));
    -- Segment helpers (DialColor / CaseMaterial): avoid short catalog names stealing compound raw values
    DECLARE @DialPrimary NVARCHAR(MAX);
    DECLARE @DialLastComma NVARCHAR(MAX);
    DECLARE @SegWith INT;
    DECLARE @SegAnd INT;
    DECLARE @SegAndWord INT;
    DECLARE @SegDash INT;
    DECLARE @SegSlash INT;
    DECLARE @SegMin INT;
    DECLARE @SegRev NVARCHAR(MAX);
    DECLARE @SegCommaRev INT;
    DECLARE @CasePrimary NVARCHAR(MAX);
    DECLARE @CaseSegWith INT;
    DECLARE @CaseSegAnd INT;
    DECLARE @CaseSegAndWord INT;
    DECLARE @CaseSegDash INT;
    DECLARE @CaseSegSlash INT;
    DECLARE @CaseSegMin INT;

    IF @TrimmedValue IS NULL OR @TrimmedValue = ''
    BEGIN
        RETURN;
    END

    -- ECH-693 addition: bezel and case-back material use the same master table (tbl_CAT_Material_d)
    -- and the same exact / alternative / fuzzy steps as the case material.
    IF @FieldName IN ('BezelMaterial', 'CaseBackMaterial')
        SET @FieldName = 'CaseMaterial';
    IF @FieldName = 'DialColor'
    BEGIN
        -- Known synonym / spelling normalizations handled directly here (no Alternative-table row needed)
        IF @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS = N'Grey'
            SET @TrimmedValue = N'Gray';
        ELSE IF @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS = N'Rose'
            SET @TrimmedValue = N'Pink';
        ELSE IF @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS = N'Argent' + NCHAR(233)
            SET @TrimmedValue = N'Silver';
        ELSE IF @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS = N'Bleu clair'
            SET @TrimmedValue = N'Light Blue';

        SET @DialPrimary = @TrimmedValue;
        SET @SegWith = CHARINDEX(N' with ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @SegAnd = CHARINDEX(N' & ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @SegAndWord = CHARINDEX(N' and ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @SegDash = CHARINDEX(N' - ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @SegSlash = CHARINDEX(N'/', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @SegMin = NULL;
        IF @SegWith > 0 SET @SegMin = @SegWith;
        IF @SegAnd > 0 AND (@SegMin IS NULL OR @SegAnd < @SegMin) SET @SegMin = @SegAnd;
        IF @SegAndWord > 0 AND (@SegMin IS NULL OR @SegAndWord < @SegMin) SET @SegMin = @SegAndWord;
        IF @SegDash > 0 AND (@SegMin IS NULL OR @SegDash < @SegMin) SET @SegMin = @SegDash;
        IF @SegSlash > 0 AND (@SegMin IS NULL OR @SegSlash < @SegMin) SET @SegMin = @SegSlash;
        IF @SegMin IS NOT NULL
            SET @DialPrimary = LTRIM(RTRIM(LEFT(@TrimmedValue, @SegMin - 1)));

        SET @DialLastComma = NULL;
        IF CHARINDEX(N',', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS) > 0
        BEGIN
            SET @SegRev = REVERSE(@TrimmedValue);
            SET @SegCommaRev = CHARINDEX(N',', @SegRev COLLATE SQL_Latin1_General_CP1_CI_AS);
            IF @SegCommaRev > 0
                SET @DialLastComma = LTRIM(RTRIM(REVERSE(LEFT(@SegRev, @SegCommaRev - 1))));
        END

        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(ColorName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = ColorName,
                @MappedIds = CAST(ColorId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(ColorName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.DialColorId = m.ColorId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.ColorName,
                @MappedIds = CAST(m.ColorId AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.DialColorId = m.ColorId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1;
            RETURN;
        END

        -- Bilingual / dual labels: prefer last comma segment (e.g. 'Blau, Blue' -> 'Blue')
        IF @DialLastComma IS NOT NULL AND @DialLastComma <> N'' AND @DialLastComma <> @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
        BEGIN
            IF EXISTS (
                SELECT 1 FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(ColorName)) = @DialLastComma COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = ColorName,
                    @MappedIds = CAST(ColorId AS NVARCHAR(20)),
                    @MappingMethod = 'Exact',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(ColorName)) = @DialLastComma COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1;
                RETURN;
            END
            IF EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.dialcolorid = m.ColorId
                WHERE LTRIM(RTRIM(a.Name)) = @DialLastComma COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = m.ColorName,
                    @MappedIds = CAST(m.ColorId AS NVARCHAR(20)),
                    @MappingMethod = 'Alternative',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.dialcolorid = m.ColorId
                WHERE LTRIM(RTRIM(a.Name)) = @DialLastComma COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1;
                RETURN;
            END
        END

        -- Compound dials: first tone only (e.g. 'Black & Red' / 'Black with orange' -> catalog 'Black')
        IF @DialPrimary <> @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS AND LEN(@DialPrimary) > 0
        BEGIN
            IF EXISTS (
                SELECT 1 FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(ColorName)) = @DialPrimary COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = ColorName,
                    @MappedIds = CAST(ColorId AS NVARCHAR(20)),
                    @MappingMethod = 'Exact',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_Color_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(ColorName)) = @DialPrimary COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1;
                RETURN;
            END
            IF EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.dialcolorid = m.ColorId
                WHERE LTRIM(RTRIM(a.Name)) = @DialPrimary COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = m.ColorName,
                    @MappedIds = CAST(m.ColorId AS NVARCHAR(20)),
                    @MappingMethod = 'Alternative',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_DialColorAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Color_d AS m WITH (NOLOCK) ON a.DialColorId = m.ColorId
                WHERE LTRIM(RTRIM(a.Name)) = @DialPrimary COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1;
                RETURN;
            END
        END

        -- Fuzzy: no SOUNDEX; no reverse-LIKE unless catalog name is at least as long as raw (stops 'Black' eating 'Black with orange')
        SELECT TOP 1
            @MappedValue = d.ColorName,
            @MappedIds = CAST(d.ColorId AS NVARCHAR(20)),
            @MappingMethod = 'Fuzzy',
            @ConfidenceScore =
                100.0 - (100.0 * ABS(LEN(d.ColorName) - LEN(@TrimmedValue)) /
                         NULLIF(CAST(LEN(@TrimmedValue) AS FLOAT), 0))
        FROM dbo.tbl_CAT_Color_d AS d WITH (NOLOCK)
        WHERE d.StatusID = 1
          AND (
                d.ColorName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @TrimmedValue + N'%'
                OR (LEN(@TrimmedValue) >= 4 AND d.ColorName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + @TrimmedValue + N'%')
                OR (
                    N' ' + @TrimmedValue + N' ' COLLATE SQL_Latin1_General_CP1_CI_AS
                        LIKE N'% ' + d.ColorName + N' %'
                )
                -- Suffix forms: 'silvered'/'silvery'/'silverish' etc. -> root color name 'Silver'
                OR (
                    N' ' + @TrimmedValue + N' ' COLLATE SQL_Latin1_General_CP1_CI_AS
                        LIKE N'% ' + d.ColorName + N'ed %'
                )
                OR (
                    N' ' + @TrimmedValue + N' ' COLLATE SQL_Latin1_General_CP1_CI_AS
                        LIKE N'% ' + d.ColorName + N'y %'
                )
                OR (
                    N' ' + @TrimmedValue + N' ' COLLATE SQL_Latin1_General_CP1_CI_AS
                        LIKE N'% ' + d.ColorName + N'ish %'
                )
          )
        ORDER BY
            CASE
                WHEN d.ColorName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @TrimmedValue + N'%' THEN 0
                WHEN LEN(@TrimmedValue) >= 4 AND d.ColorName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + @TrimmedValue + N'%' THEN 1
                ELSE 2
            END,
            ABS(LEN(d.ColorName) - LEN(@TrimmedValue)),
            d.ColorName;

        RETURN;
    END

    IF @FieldName = 'CaseMaterial'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(MaterialName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = MaterialName,
                @MappedIds = CAST(MaterialId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(MaterialName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_CaseMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.casematerialid = m.MaterialId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.MaterialName,
                @MappedIds = CAST(m.MaterialId AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_CaseMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.casematerialid = m.MaterialId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1;
            RETURN;
        END

        -- Steel / Oyster steel: always canonical stainless row before '/' or '&' splits (e.g. 'pvd/steel' must not map to 'pvd' only)
        IF (
                @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
                OR @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%oyster%steel%'
                OR @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%oystersteel%'
            )
            AND @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE N'%gold%'
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
                WHERE m.StatusID = 1
                  AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%stainless%'
                  AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = m.MaterialName,
                    @MappedIds = CAST(m.MaterialId AS NVARCHAR(20)),
                    @MappingMethod = N'SteelDefault',
                    @ConfidenceScore = 90
                FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
                WHERE m.StatusID = 1
                  AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%stainless%'
                  AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
                ORDER BY LEN(m.MaterialName) ASC, m.MaterialName;
                RETURN;
            END
        END

        SET @CasePrimary = @TrimmedValue;
        SET @CaseSegWith = CHARINDEX(N' with ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @CaseSegAnd = CHARINDEX(N' & ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @CaseSegAndWord = CHARINDEX(N' and ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @CaseSegDash = CHARINDEX(N' - ', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @CaseSegSlash = CHARINDEX(N'/', @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS);
        SET @CaseSegMin = NULL;
        IF @CaseSegWith > 0 SET @CaseSegMin = @CaseSegWith;
        IF @CaseSegAnd > 0 AND (@CaseSegMin IS NULL OR @CaseSegAnd < @CaseSegMin) SET @CaseSegMin = @CaseSegAnd;
        IF @CaseSegAndWord > 0 AND (@CaseSegMin IS NULL OR @CaseSegAndWord < @CaseSegMin) SET @CaseSegMin = @CaseSegAndWord;
        IF @CaseSegDash > 0 AND (@CaseSegMin IS NULL OR @CaseSegDash < @CaseSegMin) SET @CaseSegMin = @CaseSegDash;
        IF @CaseSegSlash > 0 AND (@CaseSegMin IS NULL OR @CaseSegSlash < @CaseSegMin) SET @CaseSegMin = @CaseSegSlash;

        IF @CaseSegMin IS NOT NULL
            SET @CasePrimary = LTRIM(RTRIM(LEFT(@TrimmedValue, @CaseSegMin - 1)));

        IF @CasePrimary <> @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS AND LEN(@CasePrimary) > 0
        BEGIN
            IF EXISTS (
                SELECT 1 FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(MaterialName)) = @CasePrimary COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = MaterialName,
                    @MappedIds = CAST(MaterialId AS NVARCHAR(20)),
                    @MappingMethod = 'Exact',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
                WHERE LTRIM(RTRIM(MaterialName)) = @CasePrimary COLLATE SQL_Latin1_General_CP1_CI_AS AND StatusID = 1;
                RETURN;
            END
            IF EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_CaseMaterialAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.casematerialid = m.MaterialId
                WHERE LTRIM(RTRIM(a.Name)) = @CasePrimary COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = m.MaterialName,
                    @MappedIds = CAST(m.MaterialId AS NVARCHAR(20)),
                    @MappingMethod = 'Alternative',
                    @ConfidenceScore = 100
                FROM dbo.tbl_CAT_CaseMaterialAlternative_d AS a WITH (NOLOCK)
                INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.casematerialid = m.MaterialId
                WHERE LTRIM(RTRIM(a.Name)) = @CasePrimary COLLATE SQL_Latin1_General_CP1_CI_AS
                  AND a.StatusID = 1 AND m.StatusID = 1;
                RETURN;
            END
        END

        SELECT TOP 1
            @MappedValue = m.MaterialName,
            @MappedIds = CAST(m.MaterialId AS NVARCHAR(20)),
            @MappingMethod = 'Fuzzy',
            @ConfidenceScore =
                100.0 - (100.0 * ABS(LEN(m.MaterialName) - LEN(@TrimmedValue)) /
                         NULLIF(CAST(LEN(@TrimmedValue) AS FLOAT), 0))
        FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
        WHERE m.StatusID = 1
          AND (
                m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @TrimmedValue + N'%'
                OR (LEN(@TrimmedValue) >= 4 AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + @TrimmedValue + N'%')
                OR (
                    N' ' + @TrimmedValue + N' ' COLLATE SQL_Latin1_General_CP1_CI_AS
                        LIKE N'% ' + m.MaterialName + N' %'
                )
          )
          AND (
                @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE N'%pvd%'
                OR m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%pvd%'
          )
          AND NOT (
                @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
                AND @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE N'%gold%'
                AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%gold%'
                AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE N'%steel%'
          )
        ORDER BY
            CASE
                WHEN m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE @TrimmedValue + N'%' THEN 0
                WHEN LEN(@TrimmedValue) >= 4 AND m.MaterialName COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + @TrimmedValue + N'%' THEN 1
                ELSE 2
            END,
            ABS(LEN(m.MaterialName) - LEN(@TrimmedValue)),
            m.MaterialName;

        RETURN;
    END

    IF @FieldName = 'Model'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Model_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(ModelName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
              AND (@ManufacturerId IS NULL OR ManufacturerId = @ManufacturerId)
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = ModelName,
                @MappedIds = CAST(ModelId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Model_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(ModelName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
              AND (@ManufacturerId IS NULL OR ManufacturerId = @ManufacturerId);
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_ModelAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Model_d AS m WITH (NOLOCK) ON a.ModelId = m.ModelId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
              AND (@ManufacturerId IS NULL OR m.ManufacturerId = @ManufacturerId)
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.ModelName,
                @MappedIds = CAST(m.ModelId AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_ModelAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Model_d AS m WITH (NOLOCK) ON a.ModelId = m.ModelId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
              AND (@ManufacturerId IS NULL OR m.ManufacturerId = @ManufacturerId);
            RETURN;
        END

        SELECT TOP 1
            @MappedValue = ModelName,
            @MappedIds = CAST(ModelId AS NVARCHAR(20)),
            @MappingMethod = 'Fuzzy',
            @ConfidenceScore =
                100.0 - (100.0 * ABS(LEN(ModelName) - LEN(@TrimmedValue)) /
                         NULLIF(CAST(LEN(@TrimmedValue) AS FLOAT), 0))
        FROM dbo.tbl_CAT_Model_d WITH (NOLOCK)
        WHERE StatusID = 1
          AND (@ManufacturerId IS NULL OR ManufacturerId = @ManufacturerId)
          AND (ModelName LIKE '%' + @TrimmedValue + '%'
               OR @TrimmedValue LIKE '%' + ModelName + '%')
        ORDER BY
            CASE WHEN ModelName LIKE @TrimmedValue + '%' THEN 0 ELSE 1 END,
            ABS(LEN(ModelName) - LEN(@TrimmedValue));

        RETURN;
    END

    IF @FieldName = 'MovementType'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_MovementType_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(MovementTypeName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = MovementTypeName,
                @MappedIds = CAST(MovementTypeId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_MovementType_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(MovementTypeName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_MovementTypeAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_MovementType_d AS m WITH (NOLOCK) ON a.MovementTypeId = m.MovementTypeId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.MovementTypeName,
                @MappedIds = CAST(m.MovementTypeId AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_MovementTypeAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_MovementType_d AS m WITH (NOLOCK) ON a.MovementTypeId = m.MovementTypeId
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1;
            RETURN;
        END

        SELECT TOP 1
            @MappedValue = MovementTypeName,
            @MappedIds = CAST(MovementTypeId AS NVARCHAR(20)),
            @MappingMethod = 'Fuzzy',
            @ConfidenceScore = 80
        FROM dbo.tbl_CAT_MovementType_d WITH (NOLOCK)
        WHERE StatusID = 1
          AND (MovementTypeName LIKE '%' + @TrimmedValue + '%'
               OR @TrimmedValue LIKE '%' + MovementTypeName + '%')
        ORDER BY ABS(LEN(MovementTypeName) - LEN(@TrimmedValue));

        RETURN;
    END

    IF @FieldName = 'StrapMaterial'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(materialname)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = materialname,
                @MappedIds = CAST(materialid AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(materialname)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_StrapMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.strapmaterialid = m.materialid
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.materialname,
                @MappedIds = CAST(m.materialid AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_StrapMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.strapmaterialid = m.materialid
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1;
            RETURN;
        END

        IF (
                @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
                OR @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%oyster%steel%'
                OR @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%oystersteel%'
            )
            AND @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE N'%gold%'
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
                WHERE m.StatusID = 1
                  AND m.materialname COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%stainless%'
                  AND m.materialname COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
            )
            BEGIN
                SELECT TOP 1
                    @MappedValue = m.materialname,
                    @MappedIds = CAST(m.materialid AS NVARCHAR(20)),
                    @MappingMethod = N'SteelDefault',
                    @ConfidenceScore = 90
                FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
                WHERE m.StatusID = 1
                  AND m.materialname COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%stainless%'
                  AND m.materialname COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%steel%'
                ORDER BY LEN(m.materialname) ASC, m.materialname;
                RETURN;
            END
        END

        SELECT TOP 1
            @MappedValue = m.materialname,
            @MappedIds = CAST(m.materialid AS NVARCHAR(20)),
            @MappingMethod = 'Fuzzy',
            @ConfidenceScore = 80
        FROM dbo.tbl_CAT_Material_d AS m WITH (NOLOCK)
        WHERE m.StatusID = 1
          AND (m.materialname COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + @TrimmedValue + N'%'
               OR @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%' + m.materialname + N'%')
        ORDER BY ABS(LEN(m.materialname) - LEN(@TrimmedValue)), m.materialname;

        RETURN;
    END

    IF @FieldName = 'DialMaterial'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(materialname)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = materialname,
                @MappedIds = CAST(materialid AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Material_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(materialname)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_DialMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.dialmaterialid = m.materialid
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = m.materialname,
                @MappedIds = CAST(m.materialid AS NVARCHAR(20)),
                @MappingMethod = 'Alternative',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_DialMaterialAlternative_d AS a WITH (NOLOCK)
            INNER JOIN dbo.tbl_CAT_Material_d AS m WITH (NOLOCK) ON a.dialmaterialid = m.materialid
            WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND a.StatusID = 1 AND m.StatusID = 1;
            RETURN;
        END
        RETURN;
    END

    IF @FieldName = 'DialEmbellishment'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_Embelishment_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(embelishmentName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = embelishmentName,
                @MappedIds = CAST(EmbelishmentId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_Embelishment_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(embelishmentName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END
        RETURN;
    END

    IF @FieldName = 'Caliber'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.tbl_CAT_CalibreNumber_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(CalibreNumberName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1
        )
        BEGIN
            SELECT TOP 1
                @MappedValue = CalibreNumberName,
                @MappedIds = CAST(CalibreNumberId AS NVARCHAR(20)),
                @MappingMethod = 'Exact',
                @ConfidenceScore = 100
            FROM dbo.tbl_CAT_CalibreNumber_d WITH (NOLOCK)
            WHERE LTRIM(RTRIM(CalibreNumberName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
              AND StatusID = 1;
            RETURN;
        END
        RETURN;
    END
    ------------------------------------------------------------
    -- ECH-693 additions: fields the shared procedure does not map
    ------------------------------------------------------------
    IF @FieldName = 'IndicesStyle'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(IndicesStyleName)),
            @MappedIds = CAST(IndicesStyleId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_IndicesStyle_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(IndicesStyleName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusID = 1;
        RETURN;
    END

    IF @FieldName = 'StrapStyle'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(StrapStyleName)),
            @MappedIds = CAST(StrapStyleId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_StrapStyle_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(StrapStyleName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusID = 1;
        IF @MappedValue IS NOT NULL
            RETURN;

        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(m.StrapStyleName)),
            @MappedIds = CAST(m.StrapStyleId AS NVARCHAR(20)),
            @MappingMethod = 'Alternative',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_StrapStyleAlternative_d AS a WITH (NOLOCK)
        INNER JOIN dbo.tbl_CAT_StrapStyle_d AS m WITH (NOLOCK) ON a.StrapStyleId = m.StrapStyleId
        WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND a.StatusID = 1 AND m.StatusID = 1;
        RETURN;
    END

    IF @FieldName = 'CrownEmbelishment'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(CrownEmbelishmentName)),
            @MappedIds = CAST(CrownEmbelishmentId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_CrownEmbelishment_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(CrownEmbelishmentName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusID = 1;
        IF @MappedValue IS NOT NULL
            RETURN;

        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(m.CrownEmbelishmentName)),
            @MappedIds = CAST(m.CrownEmbelishmentId AS NVARCHAR(20)),
            @MappingMethod = 'Alternative',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_CrownEmbelishmentAlternative_d AS a WITH (NOLOCK)
        INNER JOIN dbo.tbl_CAT_CrownEmbelishment_d AS m WITH (NOLOCK) ON a.CrownEmbelishmentId = m.CrownEmbelishmentId
        WHERE LTRIM(RTRIM(a.Name)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND a.StatusID = 1 AND m.StatusID = 1;
        RETURN;
    END

    IF @FieldName = 'Jewels'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(MovementJewelsName)),
            @MappedIds = CAST(MovementJewelsId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_MovementJewels_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(MovementJewelsName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusID = 1;
        RETURN;
    END

    IF @FieldName = 'Edition'
    BEGIN
        -- editions belong to a manufacturer
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(EditionName)),
            @MappedIds = CAST(EditionId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_Edition_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(EditionName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND ManufacturerId = @ManufacturerId
          AND StatusId = 1;
        RETURN;
    END

    IF @FieldName = 'DialStamp'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(DialStampName)),
            @MappedIds = CAST(DialStampId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_DialStamp_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(DialStampName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusId = 1;
        RETURN;
    END

    IF @FieldName = 'MovementNumber'
    BEGIN
        SELECT TOP 1
            @MappedValue = LTRIM(RTRIM(MovementNumberName)),
            @MappedIds = CAST(MovementNumberId AS NVARCHAR(20)),
            @MappingMethod = 'Exact',
            @ConfidenceScore = 100
        FROM dbo.tbl_CAT_MovementNumber_d WITH (NOLOCK)
        WHERE LTRIM(RTRIM(MovementNumberName)) = @TrimmedValue COLLATE SQL_Latin1_General_CP1_CI_AS
          AND StatusID = 1;
        RETURN;
    END
END
GO
