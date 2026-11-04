/*
    Cursor-based runner for sp_Create_Catalog
    Reference used: lagacy/Cursors-for-run-SP/create-catalog.sql

    Added fields vs. original: CaseSize (CaseWidth), StrapEmbelishments,
    CaseEmbelishments, BezelEmbelishments.

    How to use:
    1) Add all input rows in #CreateCatalogQueue (sample rows included below).
    2) Run the script.
    3) Check the final SELECT for success/error per row.
*/

SET NOCOUNT ON;


DROP TABLE if exists #CreateCatalogQueue;

CREATE TABLE #CreateCatalogQueue
(
    RowId INT IDENTITY(1,1) PRIMARY KEY,
    ReferenceNumber NVARCHAR(100) NOT NULL,
    ManufacturerName NVARCHAR(200) NOT NULL,
    ModelName NVARCHAR(300) NOT NULL,
    CaseMaterials NVARCHAR(500) NULL,
    DialColors NVARCHAR(500) NULL,
    DialMaterial NVARCHAR(500) NULL,
    PrimaryImageURL NVARCHAR(MAX) NULL,
    SourceLink NVARCHAR(500) NULL,
    CaseSize NUMERIC(10, 2) NULL,
    StrapEmbelishments NVARCHAR(MAX) NULL,
    CaseEmbelishments NVARCHAR(MAX) NULL,
    BezelEmbelishments NVARCHAR(MAX) NULL,
    EntityType NVARCHAR(500) NULL,
    TransactionId INT NULL,
    StatusId INT NOT NULL,
    UserID INT NOT NULL,
    OutCatalogId INT NULL,
    IsProcessed BIT NOT NULL DEFAULT (0),
    ErrorMessage NVARCHAR(4000) NULL
);


INSERT INTO #CreateCatalogQueue
    (ReferenceNumber, ManufacturerName, ModelName, CaseMaterials, DialColors, DialMaterial,
     PrimaryImageURL, SourceLink, CaseSize, StrapEmbelishments, CaseEmbelishments, BezelEmbelishments,
     EntityType, TransactionId, StatusId, UserID)
VALUES
    ('116610LN', 'Rolex', 'Submariner Date', 'Steel', 'Black', NULL,
     NULL, NULL, 40.00, NULL, NULL, NULL,
     'Watch', NULL, 1, 4);

EXEC sp_Create_Transaction 1, 6;

DECLARE
    @RowId INT,
    @ReferenceNumber NVARCHAR(100),
    @ManufacturerName NVARCHAR(200),
    @ModelName NVARCHAR(300),
    @CaseMaterials NVARCHAR(500),
    @DialColors NVARCHAR(500),
    @DialMaterial NVARCHAR(500),
    @PrimaryImageURL NVARCHAR(MAX),
    @SourceLink NVARCHAR(500),
    @CaseSize NUMERIC(10, 2),
    @StrapEmbelishments NVARCHAR(MAX),
    @CaseEmbelishments NVARCHAR(MAX),
    @BezelEmbelishments NVARCHAR(MAX),
    @EntityType NVARCHAR(500),
    @StatusId INT,
    @UserID INT,
    @OutCatalogId INT,
    @ErrorMessage NVARCHAR(4000);

DECLARE cur_CreateCatalog CURSOR LOCAL FAST_FORWARD FOR
SELECT
    RowId,
    ReferenceNumber,
    ManufacturerName,
    ModelName,
    CaseMaterials,
    DialColors,
    DialMaterial,
    PrimaryImageURL,
    SourceLink,
    CaseSize,
    StrapEmbelishments,
    CaseEmbelishments,
    BezelEmbelishments,
    EntityType,
    StatusId,
    UserID
FROM #CreateCatalogQueue
WHERE IsProcessed = 0
ORDER BY RowId;

OPEN cur_CreateCatalog;

FETCH NEXT FROM cur_CreateCatalog INTO
    @RowId,
    @ReferenceNumber,
    @ManufacturerName,
    @ModelName,
    @CaseMaterials,
    @DialColors,
    @DialMaterial,
    @PrimaryImageURL,
    @SourceLink,
    @CaseSize,
    @StrapEmbelishments,
    @CaseEmbelishments,
    @BezelEmbelishments,
    @EntityType,
    @StatusId,
    @UserID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @OutCatalogId = NULL;
    SET @ErrorMessage = NULL;

    BEGIN TRY
        EXEC dbo.sp_Create_Catalog
             @ReferenceNumber = @ReferenceNumber,
             @ManufacturerName = @ManufacturerName,
             @ModelName = @ModelName,
             @CaseMaterials = @CaseMaterials,
             @DialColors = @DialColors,
             @DialMaterials = @DialMaterial,
             @PrimaryImageURL = @PrimaryImageURL,
             @SourceLink = @SourceLink,
             @CaseSize = @CaseSize,
             @StrapEmbelishments = @StrapEmbelishments,
             @CaseEmbelishments = @CaseEmbelishments,
             @BezelEmbelishments = @BezelEmbelishments,
            @EntityType = 'Watch',
            @TransactionID = 339213,
             @StatusId = @StatusId,
             @UserID = @UserID,
             @OutCatalogId = @OutCatalogId OUTPUT;

        UPDATE #CreateCatalogQueue
        SET
            OutCatalogId = @OutCatalogId,
            IsProcessed = 1,
            ErrorMessage = NULL
        WHERE RowId = @RowId;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE #CreateCatalogQueue
        SET
            IsProcessed = 0,
            ErrorMessage = @ErrorMessage
        WHERE RowId = @RowId;

        PRINT 'Error for ReferenceNumber ' + ISNULL(@ReferenceNumber, N'') + N': ' + @ErrorMessage;
    END CATCH;

    FETCH NEXT FROM cur_CreateCatalog INTO
        @RowId,
        @ReferenceNumber,
        @ManufacturerName,
        @ModelName,
        @CaseMaterials,
        @DialColors,
        @DialMaterial,
        @PrimaryImageURL,
        @SourceLink,
        @CaseSize,
        @StrapEmbelishments,
        @CaseEmbelishments,
        @BezelEmbelishments,
        @EntityType,
        @StatusId,
        @UserID;
END;

CLOSE cur_CreateCatalog;
DEALLOCATE cur_CreateCatalog;

SELECT
    RowId,
    ReferenceNumber,
    ManufacturerName,
    ModelName,
    DialMaterial,
    SourceLink,
    CaseSize,
    StrapEmbelishments,
    CaseEmbelishments,
    BezelEmbelishments,
    EntityType,
    StatusId,
    UserID,
    OutCatalogId,
    IsProcessed,
    ErrorMessage
FROM #CreateCatalogQueue
ORDER BY RowId;
