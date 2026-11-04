USE [EWMaster]
GO
/****** Object:  StoredProcedure [dbo].[sp_Assign_Complications_To_Catalog]    Script Date: 21-Sep-26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_Assign_Complications_To_Catalog]
    @CatalogId INT,
    @Complications NVARCHAR(MAX),      -- Comma-separated like 'Chronograph, Moonphase'
    @TransactionID INT = NULL,         -- Optional: if provided, use it
    @IsDryRun BIT = 0                  -- 1 = Show what will happen, 0 = Do it
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Step 1: Parse Complications
        DECLARE @ComplicationList TABLE (ComplicationName NVARCHAR(250));
        INSERT INTO @ComplicationList
        SELECT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@Complications, ',');

        -- Step 2: Validate Complications
        IF EXISTS (
            SELECT 1
            FROM @ComplicationList cl
            LEFT JOIN tbl_CAT_Complication_d cd ON cl.ComplicationName = cd.ComplicationName AND cd.StatusID = 1
            WHERE cd.ComplicationId IS NULL
        )
        BEGIN
            DECLARE @InvalidComplications NVARCHAR(MAX);
            SELECT @InvalidComplications = STRING_AGG(cl.ComplicationName, ', ')
            FROM @ComplicationList cl
            LEFT JOIN tbl_CAT_Complication_d cd ON cl.ComplicationName = cd.ComplicationName AND cd.StatusID = 1
            WHERE cd.ComplicationId IS NULL;

            RAISERROR('❌ Invalid complications: %s', 16, 1, @InvalidComplications);
            RETURN;
        END

        -- Step 3: Determine Changes
        DECLARE @TargetMappings TABLE (
            ComplicationId INT,
            ComplicationName NVARCHAR(250),
            Action NVARCHAR(50)
        );

        -- Reactivate deleted
        INSERT INTO @TargetMappings (ComplicationId, ComplicationName, Action)
        SELECT cd.ComplicationId, cd.ComplicationName, 'Reactivate'
        FROM @ComplicationList cl
        JOIN tbl_CAT_Complication_d cd ON cl.ComplicationName = cd.ComplicationName
        JOIN tbl_CAT_WatchToComplication_d wtc
            ON wtc.ComplicationId = cd.ComplicationId AND wtc.CatalogId = @CatalogId
        WHERE wtc.StatusID = 3;

        -- Insert new
        INSERT INTO @TargetMappings (ComplicationId, ComplicationName, Action)
        SELECT cd.ComplicationId, cd.ComplicationName, 'Insert'
        FROM @ComplicationList cl
        JOIN tbl_CAT_Complication_d cd ON cl.ComplicationName = cd.ComplicationName
        WHERE NOT EXISTS (
            SELECT 1
            FROM tbl_CAT_WatchToComplication_d wtc
            WHERE wtc.CatalogId = @CatalogId
              AND wtc.ComplicationId = cd.ComplicationId
        );

        -- Delete: those currently active but NOT in new list
        INSERT INTO @TargetMappings (ComplicationId, ComplicationName, Action)
        SELECT cd.ComplicationId, cd.ComplicationName, 'Delete'
        FROM tbl_CAT_WatchToComplication_d wtc
        JOIN tbl_CAT_Complication_d cd ON cd.ComplicationId = wtc.ComplicationId
        WHERE wtc.CatalogId = @CatalogId
          AND wtc.StatusID = 1
          AND NOT EXISTS (
              SELECT 1
              FROM @ComplicationList cl
              WHERE cl.ComplicationName = cd.ComplicationName
          );

        -- No Changes Needed
        IF NOT EXISTS (SELECT 1 FROM @TargetMappings)
        BEGIN
            PRINT '✅ No changes needed. All provided complications are already correctly assigned.';
            RETURN;
        END

        -- Step 4: Dry Run
        IF @IsDryRun = 1
        BEGIN
            PRINT 'ℹ️ Dry run mode - no changes will be made.';
            SELECT
                @CatalogId AS CatalogId,
                ComplicationId,
                ComplicationName,
                Action
            FROM @TargetMappings
            ORDER BY Action, ComplicationName;
            RETURN;
        END

        -- Step 5: Apply Changes
        BEGIN TRANSACTION;

        -- Create Transaction if not provided
        IF @TransactionID IS NULL
        BEGIN
            INSERT INTO tblTransaction (TransactionTypeID, UserID, CreatedDate)
            VALUES (1, 4, GETDATE());

            SET @TransactionID = SCOPE_IDENTITY();

            IF @TransactionID IS NULL
            BEGIN
                RAISERROR('❌ Could not generate a new TransactionID.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END

        -- Reactivate
        UPDATE wtc
        SET wtc.StatusID = 1,
            wtc.TransactionID = @TransactionID,
            wtc.UpdatedDate = GETDATE(),
            UserId = 4
        FROM tbl_CAT_WatchToComplication_d wtc
        JOIN @TargetMappings tm ON wtc.ComplicationId = tm.ComplicationId
        WHERE wtc.CatalogId = @CatalogId AND tm.Action = 'Reactivate';

        -- Insert
        INSERT INTO tbl_CAT_WatchToComplication_d (CatalogId, ComplicationId, CreatedDate, UpdatedDate, UserId, StatusID, TransactionID)
        SELECT @CatalogId, ComplicationId, GETDATE(), GETDATE(), 4, 1, @TransactionID
        FROM @TargetMappings
        WHERE Action = 'Insert';

        -- Delete (mark as deleted)
        UPDATE wtc
        SET wtc.StatusID = 3,
            wtc.TransactionID = @TransactionID,
            wtc.UpdatedDate = GETDATE(),
            UserId = 4
        FROM tbl_CAT_WatchToComplication_d wtc
        JOIN @TargetMappings tm ON wtc.ComplicationId = tm.ComplicationId
        WHERE wtc.CatalogId = @CatalogId AND tm.Action = 'Delete';

         UPDATE dbo.tbl_CAT_Catalog_d
 SET TransactionID = @TransactionID
 WHERE CatalogId = @CatalogId;

        COMMIT TRANSACTION;

        PRINT '✅ Complications have been successfully updated for CatalogId = ' + CAST(@CatalogId AS NVARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000),
                @ErrorSeverity INT,
                @ErrorState INT;

        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR('❌ Failed to update complications for CatalogId = %d. Error: %s',
                  @ErrorSeverity, @ErrorState, @CatalogId, @ErrorMessage);
    END CATCH
END;


-- ============================================================
-- Cursor driver: runs sp_Assign_Complications_To_Catalog once per row
-- below, instead of ~50,000 separate EXEC statements. Each row here is
-- the same as one of your EXEC calls -- e.g.
--   EXEC sp_Assign_Complications_To_Catalog @catalogid = 154422, @complications = 'Date, GMT', @transactionid=345137;
-- becomes the row (154422, 'Date, GMT', 345137) below.
--
-- Per-row TRY/CATCH so one bad CatalogId/complication doesn't abort the
-- whole run -- failures are logged to #Errors instead of stopping the
-- cursor, and you get a success/error count + the error list at the end.
-- ============================================================

-- Step 1: one row per EXEC call -- replace/extend the VALUES list with
-- your ~50,000 rows (CatalogId, Complications, TransactionID).
IF OBJECT_ID('tempdb..#ComplicationAssignments') IS NOT NULL DROP TABLE #ComplicationAssignments;
CREATE TABLE #ComplicationAssignments (
    CatalogId INT,
    Complications NVARCHAR(MAX),
    TransactionID INT
);

INSERT INTO #ComplicationAssignments (CatalogId, Complications, TransactionID) VALUES
    (154422, 'Date, GMT', 345137);
    -- add the rest of your ~50,000 rows here, comma-separated

-- Step 2: cursor loop
IF OBJECT_ID('tempdb..#Errors') IS NOT NULL DROP TABLE #Errors;
CREATE TABLE #Errors (CatalogId INT, ErrorMessage NVARCHAR(4000));

DECLARE @CatalogId INT, @Complications NVARCHAR(MAX), @TransactionID INT;
DECLARE @SuccessCount INT = 0, @ErrorCount INT = 0;

DECLARE ComplicationCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CatalogId, Complications, TransactionID
    FROM #ComplicationAssignments;

OPEN ComplicationCursor;
FETCH NEXT FROM ComplicationCursor INTO @CatalogId, @Complications, @TransactionID;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC dbo.sp_Assign_Complications_To_Catalog
            @CatalogId = @CatalogId,
            @Complications = @Complications,
            @TransactionID = @TransactionID;

        SET @SuccessCount = @SuccessCount + 1;
    END TRY
    BEGIN CATCH
        SET @ErrorCount = @ErrorCount + 1;
        INSERT INTO #Errors (CatalogId, ErrorMessage)
        VALUES (@CatalogId, ERROR_MESSAGE());
    END CATCH

    FETCH NEXT FROM ComplicationCursor INTO @CatalogId, @Complications, @TransactionID;
END

CLOSE ComplicationCursor;
DEALLOCATE ComplicationCursor;

PRINT 'Done. Success: ' + CAST(@SuccessCount AS VARCHAR(20)) + ', Errors: ' + CAST(@ErrorCount AS VARCHAR(20));

SELECT * FROM #Errors;



exec sp_Get_EnrRule_UpdateFormat

EXEC sp_Get_EnrRule_CreateFormat

EXEC sp_create_enrichment_rule
@DryRun=1,
@TransactionId = 346219,
@ManufacturerName = 'rolex',
@GlobalRuleId = 35,
@ModelName = NULL,
@ChildRefStructure = 'XXXXX', @CaseMaterial = 1,    @DialColor = 1,    @DialMaterial = 0,    @CaseSize = 0,    @StrapMaterials = 0,    @Editions = 0,    @DialStamp = 1,    @Calibre = 0,    @DialFinish = 0,    @BezelColor = 0,    @BraceletMaterial = 0,    @BraceletStyle = 0,    @IndicesEmbellishment = 0,    @IndicesStyle = 0,    @CaseEmblishment = 0,    @DialEmblishment = 0,    @Nickname = 0
;
use everywatch
Select *
From EveryWatch-prod.(NOLOCK)