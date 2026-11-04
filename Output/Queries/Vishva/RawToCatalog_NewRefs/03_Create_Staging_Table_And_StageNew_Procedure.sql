/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 03: staging table + step 3 procedure (stage new unique refs)
===================================================================================
Purpose : Creates
            dbo.tbl_CAT_RawRefStaging       - one row per UNIQUE new ref, to be reviewed before creation
            dbo.sp_CAT_RawRef_StageNew    - groups unmapped map rows into unique refs and stages them
DB      : EWMaster
Run     : hand-run in SSMS. This file only CREATES the table and the procedure; it fills nothing.
          The EXEC at the bottom is commented out. Needs scripts 01 and 02.
          Each GO batch can be run on its own. Re-runnable.

The staging table already has every column the next steps fill (script 04: values, images,
conflict notes), so no ALTER is needed later. Until step 4 runs, those columns are NULL.

Confirmed by Vishva (Documents/RawToCatalog_NewRefs_Requirements.md):
  - One staging row per manufacturer + normalized ref (RefKey).
  - The reference used for creation is the most frequent cleaned spelling among the raw rows
    (ties: the highest raw Id).
  - Manufacturer name comes from tbl_CAT_Manufacturer_d (the name sp_Create_Catalog looks up).
  - A person reviews every row (IsApproved = 0 until then).

Handling of a ref that is ALREADY in staging (new raw rows of that ref appear later) - flagged, rule A7:
  - staging row pending (ExecutionStatus NULL or 'DryRunOK') -> the raw rows get MapStatus 'New'
  - staging row failed (ExecutionStatus 'Error')              -> the raw rows get MapStatus 'Rejected'
  - staging row created (ExecutionStatus 'Success')           -> the raw rows get that CatalogId, 'Created'
===================================================================================
*/

USE [EWMaster]
GO

------------------------------------------------------------
-- 1. Staging table: one row per unique new ref
--    Columns *_Raw hold the chosen raw text, *_Mapped / *_Parsed the value passed to sp_Create_Catalog
------------------------------------------------------------
IF OBJECT_ID(N'dbo.tbl_CAT_RawRefStaging', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_CAT_RawRefStaging
    (
        StagingId                      INT IDENTITY(1, 1) NOT NULL,
        ManufacturerId                 INT            NOT NULL,
        ManufacturerName               NVARCHAR(200)  NULL,
        CatSourceName                  NVARCHAR(200)  NULL,
        RefKey                         NVARCHAR(500)  NOT NULL,
        ReferenceRaw                   NVARCHAR(500)  NULL,
        ReferenceNumber_Final          NVARCHAR(500)  NOT NULL,
        RawCatalogIds                  NVARCHAR(MAX)  NULL,
        RawRowCount                    INT            NULL,

        -- values taken from the raw rows (step 4)
        Model_Raw                      NVARCHAR(MAX)  NULL,
        DialColor_Raw                  NVARCHAR(MAX)  NULL,
        CaseMaterial_Raw               NVARCHAR(MAX)  NULL,
        BraceletOrStrapMaterial_Raw    NVARCHAR(MAX)  NULL,
        DialMaterial_Raw               NVARCHAR(MAX)  NULL,
        BezelMaterial_Raw              NVARCHAR(MAX)  NULL,
        CaseBackMaterial_Raw           NVARCHAR(MAX)  NULL,
        DialEmbellishment_Raw          NVARCHAR(MAX)  NULL,
        IndicesStyle_Raw               NVARCHAR(MAX)  NULL,
        StrapStyle_Raw                 NVARCHAR(MAX)  NULL,
        CrownEmbelishment_Raw          NVARCHAR(MAX)  NULL,
        Jewels_Raw                     NVARCHAR(MAX)  NULL,
        Edition_Raw                    NVARCHAR(MAX)  NULL,
        DialStamp_Raw                  NVARCHAR(MAX)  NULL,
        PowerReserve_Raw               NVARCHAR(MAX)  NULL,
        WaterResistance_Raw            NVARCHAR(MAX)  NULL,
        Caliber_Raw                    NVARCHAR(MAX)  NULL,
        Movement_Raw                   NVARCHAR(MAX)  NULL,
        Width_Raw                      NVARCHAR(100)  NULL,
        Dimensions_Raw                 NVARCHAR(MAX)  NULL,

        -- values passed to sp_Create_Catalog (step 4); NULL = no master match / not parseable
        ModelName_Mapped               NVARCHAR(500)  NULL,
        DialColorNames_Mapped          NVARCHAR(MAX)  NULL,
        CaseMaterialNames_Mapped       NVARCHAR(MAX)  NULL,
        StrapMaterialNames_Mapped      NVARCHAR(MAX)  NULL,
        DialMaterialName_Mapped        NVARCHAR(MAX)  NULL,
        BezelMaterialNames_Mapped      NVARCHAR(MAX)  NULL,
        CasebackMaterialNames_Mapped   NVARCHAR(MAX)  NULL,
        DialEmbellishmentName_Mapped   NVARCHAR(MAX)  NULL,
        IndicesStyleNames_Mapped       NVARCHAR(MAX)  NULL,
        StrapStyleName_Mapped          NVARCHAR(500)  NULL,
        CrownEmbelishmentName_Mapped   NVARCHAR(500)  NULL,
        MovementJewelsName_Mapped      NVARCHAR(500)  NULL,
        EditionName_Mapped             NVARCHAR(500)  NULL,
        DialStampName_Mapped           NVARCHAR(500)  NULL,
        PowerReserveHourName_Parsed    NVARCHAR(50)   NULL,
        WaterResistanceMeters_Parsed   INT            NULL,
        CalibreNumberName_Mapped       NVARCHAR(500)  NULL,
        MovementTypeName_Mapped        NVARCHAR(500)  NULL,
        CaseSize_Parsed                NUMERIC(10, 2) NULL,

        -- source link and images (step 4)
        SourceLink                     NVARCHAR(MAX)  NULL,
        ImageRawCatalogId              BIGINT         NULL,
        PrimaryImageURL                NVARCHAR(MAX)  NULL,
        SecondaryImageURLs             NVARCHAR(MAX)  NULL,

        -- for the reviewer (step 4): fields where the raw rows disagree, with counts
        ConflictNotes                  NVARCHAR(MAX)  NULL,
        ValuesMappedDate               DATETIME       NULL,

        -- review and creation (step 5 / 6)
        IsApproved                     BIT            NOT NULL CONSTRAINT DF_tbl_CAT_RawRefStaging_IsApproved DEFAULT (0),
        ReviewNote                     NVARCHAR(1000) NULL,
        ExecutionStatus                NVARCHAR(50)   NULL,
        ExecutionDate                  DATETIME       NULL,
        ExecutionError                 NVARCHAR(MAX)  NULL,
        CatalogId                      INT            NULL,
        CreatedDate                    DATETIME       NOT NULL CONSTRAINT DF_tbl_CAT_RawRefStaging_CreatedDate DEFAULT (GETDATE()),
        CONSTRAINT PK_tbl_CAT_RawRefStaging PRIMARY KEY CLUSTERED (StagingId)
    );
END
GO

------------------------------------------------------------
-- 2. Indexes on the staging table
--    UX_..._MfrRef : one staging row per manufacturer + normalized ref
--    IX_..._Review : the review and creation queries (approved / not executed)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_tbl_CAT_RawRefStaging_MfrRef' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefStaging'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_tbl_CAT_RawRefStaging_MfrRef
        ON dbo.tbl_CAT_RawRefStaging (ManufacturerId, RefKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefStaging_Review' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefStaging'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefStaging_Review
        ON dbo.tbl_CAT_RawRefStaging (IsApproved, ExecutionStatus) INCLUDE (ManufacturerId);
GO

------------------------------------------------------------
-- 3. STEP 3 PROCEDURE: stage new unique refs
------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CAT_RawRef_StageNew
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- 1. Candidate map rows: Unmapped, no CatalogId, usable key
    --    tbl_CAT_RawRefMap
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Cand;
    SELECT
        m.RawCatalogId,
        m.ManufacturerId,
        m.SourceId,
        m.ReferenceRaw,
        m.ReferenceClean,
        m.RefKey
    INTO #Cand
    FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
    WHERE m.CatalogId IS NULL
      AND m.MapStatus = 'Unmapped'
      AND m.RefKey IS NOT NULL;

    CREATE CLUSTERED INDEX CX_Cand ON #Cand (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 2. Cleaned spellings per ref with how often each occurs
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #SpellCounts;
    SELECT
        c.ManufacturerId,
        c.RefKey,
        c.ReferenceClean,
        COUNT(*)              AS SpellCount,
        MAX(c.RawCatalogId)   AS MaxRawId
    INTO #SpellCounts
    FROM #Cand AS c
    GROUP BY c.ManufacturerId, c.RefKey, c.ReferenceClean;

    ------------------------------------------------------------
    -- 3. The spelling used for creation: most frequent, ties the highest raw Id
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #SpellPick;
    SELECT
        s.ManufacturerId,
        s.RefKey,
        s.ReferenceClean AS ReferenceFinal
    INTO #SpellPick
    FROM (
        SELECT
            sc.*,
            ROW_NUMBER() OVER (PARTITION BY sc.ManufacturerId, sc.RefKey
                               ORDER BY sc.SpellCount DESC, sc.MaxRawId DESC) AS rn
        FROM #SpellCounts AS sc
    ) AS s
    WHERE s.rn = 1;

    CREATE CLUSTERED INDEX CX_SpellPick ON #SpellPick (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 4. The most recent raw row of each ref (gives the raw spelling and the source name)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #LatestRow;
    SELECT
        l.ManufacturerId,
        l.RefKey,
        l.ReferenceRaw,
        l.SourceId
    INTO #LatestRow
    FROM (
        SELECT
            c.*,
            ROW_NUMBER() OVER (PARTITION BY c.ManufacturerId, c.RefKey
                               ORDER BY c.RawCatalogId DESC) AS rn
        FROM #Cand AS c
    ) AS l
    WHERE l.rn = 1;

    CREATE CLUSTERED INDEX CX_LatestRow ON #LatestRow (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 5. One row per unique ref: raw Ids, count
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Groups;
    SELECT
        c.ManufacturerId,
        c.RefKey,
        COUNT(*)                                                                    AS RawRowCount,
        STRING_AGG(CAST(c.RawCatalogId AS NVARCHAR(MAX)), ',') WITHIN GROUP (ORDER BY c.RawCatalogId) AS RawCatalogIds
    INTO #Groups
    FROM #Cand AS c
    GROUP BY c.ManufacturerId, c.RefKey;

    CREATE CLUSTERED INDEX CX_Groups ON #Groups (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 6. Insert the refs that are not in staging yet
    --    manufacturer name from tbl_CAT_Manufacturer_d (StatusID = 1); source name from tbl_sourceManufacturer_mapping
    ------------------------------------------------------------
    INSERT INTO dbo.tbl_CAT_RawRefStaging
        (ManufacturerId, ManufacturerName, CatSourceName, RefKey, ReferenceRaw, ReferenceNumber_Final, RawCatalogIds, RawRowCount)
    SELECT
        g.ManufacturerId,
        mf.ManufacturerName,
        sm.CatSourceName,
        g.RefKey,
        lr.ReferenceRaw,
        sp.ReferenceFinal,
        g.RawCatalogIds,
        g.RawRowCount
    FROM #Groups AS g
    INNER JOIN #SpellPick AS sp
        ON sp.ManufacturerId = g.ManufacturerId AND sp.RefKey = g.RefKey
    INNER JOIN #LatestRow AS lr
        ON lr.ManufacturerId = g.ManufacturerId AND lr.RefKey = g.RefKey
    LEFT JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
        ON mf.ManufacturerId = g.ManufacturerId AND mf.StatusID = 1
    LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
        ON sm.SourceId = lr.SourceId
    WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
            WHERE s.ManufacturerId = g.ManufacturerId
              AND s.RefKey = g.RefKey
    );

    PRINT 'Step 3 - new refs staged: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    ------------------------------------------------------------
    -- 7. Update the map rows of every candidate ref from its staging row
    --    pending -> New, failed -> Rejected, created -> Created with that CatalogId
    ------------------------------------------------------------
    UPDATE m
    SET m.MapStatus   = CASE
                            WHEN s.ExecutionStatus = N'Success' THEN 'Created'
                            WHEN s.ExecutionStatus = N'Error'   THEN 'Rejected'
                            ELSE 'New'
                        END,
        m.CatalogId   = CASE WHEN s.ExecutionStatus = N'Success' THEN s.CatalogId ELSE m.CatalogId END,
        m.MapNote     = CASE WHEN s.ExecutionStatus = N'Error' THEN N'See tbl_CAT_RawRefStaging StagingId ' + CAST(s.StagingId AS NVARCHAR(20)) ELSE m.MapNote END,
        m.MapDate     = GETDATE(),
        m.UpdatedDate = GETDATE()
    FROM dbo.tbl_CAT_RawRefMap AS m
    INNER JOIN #Cand AS c
        ON c.RawCatalogId = m.RawCatalogId
    INNER JOIN dbo.tbl_CAT_RawRefStaging AS s
        ON s.ManufacturerId = c.ManufacturerId
       AND s.RefKey = c.RefKey
    WHERE m.MapStatus = 'Unmapped';

    PRINT 'Step 3 - map rows updated: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));
END
GO

/*
------------------------------------------------------------
-- Run (select and run on their own)
------------------------------------------------------------
EXEC dbo.sp_CAT_RawRef_StageNew;

-- Check: staged refs per manufacturer, and map status counts
SELECT ManufacturerId, ManufacturerName, COUNT(*) AS StagedRefs
FROM dbo.tbl_CAT_RawRefStaging WITH (NOLOCK)
GROUP BY ManufacturerId, ManufacturerName
ORDER BY StagedRefs DESC;

SELECT MapStatus, COUNT(*) AS MapRows
FROM dbo.tbl_CAT_RawRefMap WITH (NOLOCK)
GROUP BY MapStatus;
*/
