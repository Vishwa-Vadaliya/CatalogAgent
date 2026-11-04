/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 06: step 6 - create the approved refs in the catalog (cursor over sp_Create_Catalog)
===================================================================================
Purpose : Creates dbo.sp_CAT_RawRef_CreateCatalog. For every staged ref with IsApproved = 1
          that has not been executed yet, it calls dbo.sp_Create_Catalog once (the only way a
          catalog row is created) and writes the result back to tbl_CAT_RawRefStaging and to the
          raw rows' map rows (tbl_CAT_RawRefMap).
DB      : EWMaster. Needs scripts 01-04a, step 4 executed, and review done (IsApproved = 1).
Run     : this file only CREATES the procedure. Nothing is created in the catalog by running it.
          The EXEC lines at the bottom are commented out.

Parameters
  @IsDryRun         1 (DEFAULT) = sp_Create_Catalog validates every ref and creates nothing;
                    staging gets ExecutionStatus 'DryRunOK' or 'Error'.
                    0 = really create the catalog rows.
  @ManufacturerName NULL = all approved refs; or one manufacturer name (batch by manufacturer).
  @MaxRows          NULL = all; or the maximum number of refs for this run (use 5 for a first test).
  @RetryErrors      0 = skip refs whose last run ended in 'Error'; 1 = try them again.
  @UserID           6 (as agreed).

What it does, in order
  1. Runs sp_CAT_RawRef_SyncAndMatch @SkipSync = 1 again (match part only), so the "already in the catalog" check (catalog table AND
     tbl_CAT_RawCatalogMapping, the mapping table first) is current at the moment of creating.
     Note: this also updates map rows (Matched) in a dry run - it is bookkeeping, not creation.
  2. Work set = staging rows with IsApproved = 1, ValuesMappedDate set, ExecutionStatus NULL or
     'DryRunOK' (or 'Error' with @RetryErrors = 1), for the manufacturer / @MaxRows asked.
  3. Refs that now match an existing catalog row (step 2 result) are NOT created: staging gets
     ExecutionStatus 'Skipped', the existing CatalogId and a note.
  4. Cursor: one sp_Create_Catalog call per remaining ref, @EntityType = 'Watch'. Each call is its own
     transaction inside sp_Create_Catalog (it rolls back by itself on error), so there is NO outer
     transaction here; a failed ref never stops the others.
  5. Result per ref: real run Success (CatalogId written to staging; raw rows' map rows set to
     'Created' with that CatalogId) or Error (message in ExecutionError; map rows 'Rejected' with a note,
     same as step 3). Dry run: DryRunOK or Error (map rows untouched).

Things to know
  - sp_Create_Catalog has no duplicate check of its own; the check in step 1/3 above is the protection.
  - In a dry run sp_Create_Catalog returns one small result set per ref. In SSMS use
    Query > Query Options > Results > Grid > "Discard results after execution" for big runs; the
    printed counts and the final result list still show.
  - @SourceName is passed from staging.CatSourceName. If sp_Create_Catalog says the source name does
    not exist in tbl_CAT_Source_d, the dry run will show it per ref (not verified against the deployed data).
  - Also passed (script 03b columns): CaseEmbelishments, StrapEmbelishments, BezelEmbelishments, IndicesMaterials,
    Series, Style, BezelStyleName, BezelTypeName, MovementNumberName, NicknameName, PusherShapeName.
    Step 4 fills only MovementNumber and Style from raw; the others come from the review (step 5).
  - Not passed: CatalogNotes, and the parameters this flow never uses (TransactionID, RuleId, IndicesMaterialName, ...).
===================================================================================
*/

USE [EWMaster]
GO

CREATE OR ALTER PROCEDURE dbo.sp_CAT_RawRef_CreateCatalog
    @IsDryRun         BIT           = 1,
    @ManufacturerName NVARCHAR(200) = NULL,
    @MaxRows          INT           = NULL,
    @RetryErrors      BIT           = 0,
    @UserID           INT           = 6
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- 1. Fresh "already in the catalog" check (catalog + tbl_CAT_RawCatalogMapping first)
    ------------------------------------------------------------
    EXEC dbo.sp_CAT_RawRef_SyncAndMatch @SkipSync = 1;

    ------------------------------------------------------------
    -- 2. Work set: approved, filled, not executed yet
    --    tbl_CAT_RawRefStaging
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Work;
    SELECT TOP (ISNULL(@MaxRows, 2147483647))
        s.StagingId,
        s.ManufacturerId,
        s.RefKey,
        s.ManufacturerName,
        s.ModelName_Mapped,
        s.ReferenceNumber_Final,
        s.CaseSize_Parsed,
        s.CatSourceName,
        s.SourceLink,
        s.PrimaryImageURL,
        s.SecondaryImageURLs,
        s.MovementTypeName_Mapped,
        s.CalibreNumberName_Mapped,
        s.CaseMaterialNames_Mapped,
        s.DialColorNames_Mapped,
        s.StrapMaterialNames_Mapped,
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
        s.PowerReserveHourName_Parsed,
        s.WaterResistanceMeters_Parsed,
        s.CaseEmbelishmentNames_Mapped,
        s.StrapEmbelishmentNames_Mapped,
        s.BezelEmbelishmentNames_Mapped,
        s.IndicesMaterialNames_Mapped,
        s.Series_Value,
        s.Style_Value,
        s.BezelStyleName_Mapped,
        s.BezelTypeName_Mapped,
        s.MovementNumberName_Mapped,
        s.NicknameName_Mapped,
        s.PusherShapeName_Mapped
    INTO #Work
    FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
    WHERE s.IsApproved = 1
      AND s.ValuesMappedDate IS NOT NULL
      AND (   s.ExecutionStatus IS NULL
           OR s.ExecutionStatus = N'DryRunOK'
           OR (@RetryErrors = 1 AND s.ExecutionStatus = N'Error'))
      AND (@ManufacturerName IS NULL OR s.ManufacturerName = @ManufacturerName)
    ORDER BY s.StagingId;

    CREATE UNIQUE CLUSTERED INDEX CX_Work6 ON #Work (StagingId);

    -- Keep the full list for the final result
    DROP TABLE IF EXISTS #AllWork;
    SELECT StagingId INTO #AllWork FROM #Work;

    PRINT 'Step 6 - approved refs in this run: ' + CAST(@@ROWCOUNT AS NVARCHAR(20))
        + CASE WHEN @IsDryRun = 1 THEN N'  (DRY RUN - nothing is created)' ELSE N'  (REAL RUN)' END;

    ------------------------------------------------------------
    -- 3. Refs that already exist in the catalog now: skip, do not create
    --    (map rows Matched by step 2: tbl_CAT_RawCatalogMapping first, then the catalog)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #AlreadyThere;
    SELECT
        w.StagingId,
        MIN(m.CatalogId) AS CatalogId
    INTO #AlreadyThere
    FROM #Work AS w
    INNER JOIN dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
        ON m.ManufacturerId = w.ManufacturerId
       AND m.RefKey         = w.RefKey
       AND m.MapStatus      = 'Matched'
       AND m.CatalogId IS NOT NULL
    GROUP BY w.StagingId;

    UPDATE s
    SET s.ExecutionStatus = N'Skipped',
        s.CatalogId       = a.CatalogId,
        s.ExecutionDate   = GETDATE(),
        s.ExecutionError  = N'Not created: already in the catalog (found just before creating). CatalogId '
                            + CAST(a.CatalogId AS NVARCHAR(20))
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #AlreadyThere AS a
        ON a.StagingId = s.StagingId;

    PRINT 'Step 6 - skipped, already in the catalog: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE w
    FROM #Work AS w
    INNER JOIN #AlreadyThere AS a
        ON a.StagingId = w.StagingId;

    ------------------------------------------------------------
    -- 4. Cursor: one sp_Create_Catalog call per ref
    ------------------------------------------------------------
    DECLARE @StagingId        INT,
            @ManufacturerId   INT,
            @RefKey           NVARCHAR(500),
            @MfrName          NVARCHAR(200),
            @ModelName        NVARCHAR(MAX),
            @Reference        NVARCHAR(500),
            @CaseSize         NUMERIC(10, 2),
            @SourceName       NVARCHAR(200),
            @SourceLink       NVARCHAR(MAX),
            @PrimaryImage     NVARCHAR(MAX),
            @SecondaryImages  NVARCHAR(MAX),
            @MovementType     NVARCHAR(MAX),
            @Calibre          NVARCHAR(250),
            @CaseMaterials    NVARCHAR(MAX),
            @DialColors       NVARCHAR(MAX),
            @StrapMaterials   NVARCHAR(MAX),
            @DialMaterials    NVARCHAR(MAX),
            @BezelMaterials   NVARCHAR(MAX),
            @CasebackMaterials NVARCHAR(MAX),
            @DialEmbellishments NVARCHAR(MAX),
            @IndicesStyles    NVARCHAR(MAX),
            @StrapStyle       NVARCHAR(MAX),
            @CrownEmbelishment NVARCHAR(MAX),
            @MovementJewels   NVARCHAR(MAX),
            @EditionName      NVARCHAR(MAX),
            @DialStampName    NVARCHAR(MAX),
            @PowerReserve     NVARCHAR(MAX),
            @WaterResistance  INT,
            @CaseEmbelishments NVARCHAR(MAX),
            @StrapEmbelishments NVARCHAR(MAX),
            @BezelEmbelishments NVARCHAR(MAX),
            @IndicesMaterials NVARCHAR(MAX),
            @Series           NVARCHAR(4000),
            @Style            VARCHAR(30),
            @BezelStyleName   NVARCHAR(MAX),
            @BezelTypeName    NVARCHAR(MAX),
            @MovementNumberName NVARCHAR(MAX),
            @NicknameName     NVARCHAR(250),
            @PusherShapeName  NVARCHAR(MAX),
            @NewCatalogId     INT,
            @ErrorText        NVARCHAR(MAX),
            @CountOk          INT = 0,
            @CountError       INT = 0;

    DECLARE ref_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            StagingId, ManufacturerId, RefKey, ManufacturerName, ModelName_Mapped, ReferenceNumber_Final,
            CaseSize_Parsed, CatSourceName, SourceLink, PrimaryImageURL, SecondaryImageURLs,
            MovementTypeName_Mapped, CalibreNumberName_Mapped, CaseMaterialNames_Mapped, DialColorNames_Mapped,
            StrapMaterialNames_Mapped, DialMaterialName_Mapped, BezelMaterialNames_Mapped,
            CasebackMaterialNames_Mapped, DialEmbellishmentName_Mapped, IndicesStyleNames_Mapped,
            StrapStyleName_Mapped, CrownEmbelishmentName_Mapped, MovementJewelsName_Mapped,
            EditionName_Mapped, DialStampName_Mapped, PowerReserveHourName_Parsed, WaterResistanceMeters_Parsed,
            CaseEmbelishmentNames_Mapped, StrapEmbelishmentNames_Mapped, BezelEmbelishmentNames_Mapped,
            IndicesMaterialNames_Mapped, Series_Value, Style_Value, BezelStyleName_Mapped, BezelTypeName_Mapped,
            MovementNumberName_Mapped, NicknameName_Mapped, PusherShapeName_Mapped
        FROM #Work
        ORDER BY StagingId;

    OPEN ref_cursor;

    FETCH NEXT FROM ref_cursor INTO
        @StagingId, @ManufacturerId, @RefKey, @MfrName, @ModelName, @Reference,
        @CaseSize, @SourceName, @SourceLink, @PrimaryImage, @SecondaryImages,
        @MovementType, @Calibre, @CaseMaterials, @DialColors,
        @StrapMaterials, @DialMaterials, @BezelMaterials,
        @CasebackMaterials, @DialEmbellishments, @IndicesStyles,
        @StrapStyle, @CrownEmbelishment, @MovementJewels,
        @EditionName, @DialStampName, @PowerReserve, @WaterResistance,
        @CaseEmbelishments, @StrapEmbelishments, @BezelEmbelishments,
        @IndicesMaterials, @Series, @Style, @BezelStyleName, @BezelTypeName,
        @MovementNumberName, @NicknameName, @PusherShapeName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @NewCatalogId = NULL;
        SET @ErrorText    = NULL;

        BEGIN TRY
            EXEC dbo.sp_Create_Catalog
                @ManufacturerName      = @MfrName,
                @ModelName             = @ModelName,
                @ReferenceNumber       = @Reference,
                @CaseSize              = @CaseSize,
                @EntityType            = N'Watch',
                @SourceName            = @SourceName,
                @UserID                = @UserID,
                @SourceLink            = @SourceLink,
                @PrimaryImageURL       = @PrimaryImage,
                @SecondaryImageURL     = @SecondaryImages,
                @MovementTypeName      = @MovementType,
                @CalibreNumberName     = @Calibre,
                @CaseMaterials         = @CaseMaterials,
                @DialColors            = @DialColors,
                @StrapMaterials        = @StrapMaterials,
                @DialMaterials         = @DialMaterials,
                @BezelMaterials        = @BezelMaterials,
                @CasebackMaterials     = @CasebackMaterials,
                @DialEmbelishments     = @DialEmbellishments,
                @IndicesStyles         = @IndicesStyles,
                @StrapStyleName        = @StrapStyle,
                @CrownEmbelishmentName = @CrownEmbelishment,
                @MovementJewelsName    = @MovementJewels,
                @EditionName           = @EditionName,
                @DialStampName         = @DialStampName,
                @PowerReserveHourName  = @PowerReserve,
                @WaterResistancesMeters = @WaterResistance,
                @CaseEmbelishments     = @CaseEmbelishments,
                @StrapEmbelishments    = @StrapEmbelishments,
                @BezelEmbelishments    = @BezelEmbelishments,
                @IndicesMaterials      = @IndicesMaterials,
                @Series                = @Series,
                @Style                 = @Style,
                @BezelStyleName        = @BezelStyleName,
                @BezelTypeName         = @BezelTypeName,
                @MovementNumberName    = @MovementNumberName,
                @NicknameName          = @NicknameName,
                @PusherShapeName       = @PusherShapeName,
                @IsDryRun              = @IsDryRun,
                @OutCatalogId          = @NewCatalogId OUTPUT;
        END TRY
        BEGIN CATCH
            SET @ErrorText = LEFT(ERROR_MESSAGE(), 4000);
        END CATCH

        -- A real run that returned no error but no CatalogId is also a failure
        IF @ErrorText IS NULL AND @IsDryRun = 0 AND @NewCatalogId IS NULL
            SET @ErrorText = N'sp_Create_Catalog finished without error but returned no CatalogId.';

        IF @ErrorText IS NOT NULL
        BEGIN
            SET @CountError += 1;

            UPDATE dbo.tbl_CAT_RawRefStaging
            SET ExecutionStatus = N'Error',
                ExecutionDate   = GETDATE(),
                ExecutionError  = @ErrorText
            WHERE StagingId = @StagingId;

            -- Real run only: the raw rows are marked Rejected (same as step 3 does for a failed ref)
            IF @IsDryRun = 0
                UPDATE dbo.tbl_CAT_RawRefMap
                SET MapStatus   = 'Rejected',
                    MapNote     = N'See tbl_CAT_RawRefStaging StagingId ' + CAST(@StagingId AS NVARCHAR(20)),
                    MapDate     = GETDATE(),
                    UpdatedDate = GETDATE()
                WHERE ManufacturerId = @ManufacturerId
                  AND RefKey         = @RefKey
                  AND CatalogId IS NULL;
        END
        ELSE IF @IsDryRun = 1
        BEGIN
            SET @CountOk += 1;

            UPDATE dbo.tbl_CAT_RawRefStaging
            SET ExecutionStatus = N'DryRunOK',
                ExecutionDate   = GETDATE(),
                ExecutionError  = NULL
            WHERE StagingId = @StagingId;
        END
        ELSE
        BEGIN
            SET @CountOk += 1;

            UPDATE dbo.tbl_CAT_RawRefStaging
            SET ExecutionStatus = N'Success',
                ExecutionDate   = GETDATE(),
                ExecutionError  = NULL,
                CatalogId       = @NewCatalogId
            WHERE StagingId = @StagingId;

            -- All raw rows behind this ref now point to the new catalog row
            UPDATE dbo.tbl_CAT_RawRefMap
            SET CatalogId   = @NewCatalogId,
                MapStatus   = 'Created',
                MapDate     = GETDATE(),
                UpdatedDate = GETDATE()
            WHERE ManufacturerId = @ManufacturerId
              AND RefKey         = @RefKey
              AND CatalogId IS NULL;
        END

        FETCH NEXT FROM ref_cursor INTO
            @StagingId, @ManufacturerId, @RefKey, @MfrName, @ModelName, @Reference,
            @CaseSize, @SourceName, @SourceLink, @PrimaryImage, @SecondaryImages,
            @MovementType, @Calibre, @CaseMaterials, @DialColors,
            @StrapMaterials, @DialMaterials, @BezelMaterials,
            @CasebackMaterials, @DialEmbellishments, @IndicesStyles,
            @StrapStyle, @CrownEmbelishment, @MovementJewels,
            @EditionName, @DialStampName, @PowerReserve, @WaterResistance,
        @CaseEmbelishments, @StrapEmbelishments, @BezelEmbelishments,
        @IndicesMaterials, @Series, @Style, @BezelStyleName, @BezelTypeName,
        @MovementNumberName, @NicknameName, @PusherShapeName;
    END

    CLOSE ref_cursor;
    DEALLOCATE ref_cursor;

    PRINT 'Step 6 - ' + CASE WHEN @IsDryRun = 1 THEN N'dry run OK: ' ELSE N'catalog rows created: ' END
        + CAST(@CountOk AS NVARCHAR(20)) + N'   errors: ' + CAST(@CountError AS NVARCHAR(20));

    ------------------------------------------------------------
    -- 5. Result list of this run
    ------------------------------------------------------------
    SELECT
        s.StagingId,
        s.ManufacturerName,
        s.ReferenceNumber_Final AS NewReference,
        s.ExecutionStatus,
        s.CatalogId,
        s.ExecutionError
    FROM #AllWork AS a
    INNER JOIN dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
        ON s.StagingId = a.StagingId
    ORDER BY CASE s.ExecutionStatus WHEN N'Error' THEN 0 WHEN N'Skipped' THEN 1 ELSE 2 END,
             s.ManufacturerName, s.ReferenceNumber_Final;
END
GO

/*
------------------------------------------------------------
-- Run (select and run on their own, one after the other)
------------------------------------------------------------
-- 1. First test: DRY RUN (the default), 5 refs of one manufacturer - creates nothing
EXEC dbo.sp_CAT_RawRef_CreateCatalog @ManufacturerName = N'Ball', @MaxRows = 5;

-- 2. Whole manufacturer, still a dry run
EXEC dbo.sp_CAT_RawRef_CreateCatalog @ManufacturerName = N'Ball';

-- 3. REAL run (only after the dry run shows no unexpected errors)
EXEC dbo.sp_CAT_RawRef_CreateCatalog @IsDryRun = 0, @ManufacturerName = N'Ball';

-- 4. Try the refs that ended in Error again (after fixing the values)
EXEC dbo.sp_CAT_RawRef_CreateCatalog @IsDryRun = 0, @ManufacturerName = N'Ball', @RetryErrors = 1;
*/
