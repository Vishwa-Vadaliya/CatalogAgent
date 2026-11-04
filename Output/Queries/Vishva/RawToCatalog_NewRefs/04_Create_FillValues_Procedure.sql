/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 04: step 4 procedure - fill the staging rows with values, images, source link
===================================================================================
Purpose : Creates
            dbo.tbl_CAT_RawRefUnmatchedValue   - raw values that have no master value (report for the master-table owner)
            dbo.sp_CAT_RawRef_FillValues     - fills every pending staging row (see below)
DB      : EWMaster
Run     : hand-run in SSMS. This file only CREATES the table and the procedure; it fills nothing.
          The EXEC at the bottom is commented out. Needs scripts 01-03, step 3 executed, and script 04a.
          Each GO batch can be run on its own. Re-runnable.

What the procedure does for every pending staging row (IsApproved = 0, not created):
  1. Takes the raw rows of the ref (tbl_RAW_Catalog rows whose map row is MapStatus 'New').
  2. For each field: the MOST FREQUENT raw value wins, ties -> the value of the highest raw Id.
     Fields where the raw rows disagree are written to ConflictNotes with their counts.
  3. Maps the winning value to a master value with ONE procedure, dbo.sp_CAT_RawRef_MapValue (script 04a,
     our own copy of sp_Map_RawValueToCatalog_Universal plus the fields it lacks). Run script 04a first.
     Fields: Model, DialColor, CaseMaterial, StrapMaterial, DialMaterial, MovementType, Caliber, BezelMaterial,
     CaseBack material, DialEmbellishment, IndicesStyle, StrapStyle, CrownEmbelishment, Jewels,
     Edition (per manufacturer), DialStamp, MovementNumber (raw MovementNo, exact match only).
     See script 04a for which steps each field uses.
     Style (raw Style) is copied as it is when it has 30 characters or less (sp_Create_Catalog @Style is
     VARCHAR(30), no master list); a longer value is not used and is listed as NotParseable.
     NOT filled here (no raw column): case / strap / bezel embellishments, indices materials, series,
     bezel style, bezel type, nickname, pusher shape. The review (step 5) fills them; this procedure never
     clears them, also not with @Reprocess = 1.
     DialColor, CaseMaterial, BezelMaterial, CaseBack material, IndicesStyle and DialEmbellishment are
     comma-separated lists: each item is mapped on its own.
     A value with no master value is NOT created; the *_Mapped column stays empty (or holds only the items
     that matched) and the value is written to tbl_CAT_RawRefUnmatchedValue.
     A FUZZY match is used but written to ConflictNotes so the reviewer sees it.
  4. Parses CaseSize (Width, else the leading number of Dimensions), PowerReserve (hours, must exist in
     tbl_CAT_PowerReserveHour_d) and WaterResistance (whole metres: a number next to m / metres first, then bar or atm x 10,
     then feet, then a lone number; see step 10c) - PowerReserve and CaseSize as in Janvi's script.
  5. Images: the first raw row (lowest raw Id) that has any image is used. Its image with the lowest
     orderIndex is the primary, its other images are secondary. Secondary URLs that contain a comma are
     skipped (sp_Create_Catalog splits the list on commas) and noted in ConflictNotes.
  6. Source link: the raw URL column of the highest raw Id that has one.
  7. Refreshes RawCatalogIds / RawRowCount from the map and sets ValuesMappedDate.

Parameter @Reprocess:
  0 (default) - only staging rows never filled (ValuesMappedDate IS NULL)
  1           - all pending, NOT approved staging rows again (use after a master value was created)
Approved rows and rows already created / failed are never touched.

Rules: temp tables only (B1), NOLOCK on reads (B3). DECLARE is used inside the procedure only (confirmed OK).
===================================================================================
*/

USE [EWMaster]
GO

------------------------------------------------------------
-- 1. Table: raw values with no master value (one row per staging row + field + value)
------------------------------------------------------------
IF OBJECT_ID(N'dbo.tbl_CAT_RawRefUnmatchedValue', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_CAT_RawRefUnmatchedValue
    (
        UnmatchedId    INT IDENTITY(1, 1) NOT NULL,
        StagingId      INT            NOT NULL,
        ManufacturerId INT            NOT NULL,
        FieldName      VARCHAR(50)    NOT NULL,
        RawValue       NVARCHAR(1000) NULL,
        Reason         VARCHAR(30)    NOT NULL,   -- NoMasterValue / NotParseable
        CreatedDate    DATETIME       NOT NULL CONSTRAINT DF_tbl_CAT_RawRefUnmatchedValue_CreatedDate DEFAULT (GETDATE()),
        CONSTRAINT PK_tbl_CAT_RawRefUnmatchedValue PRIMARY KEY CLUSTERED (UnmatchedId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefUnmatchedValue_Staging' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefUnmatchedValue'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefUnmatchedValue_Staging
        ON dbo.tbl_CAT_RawRefUnmatchedValue (StagingId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefUnmatchedValue_Field' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefUnmatchedValue'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefUnmatchedValue_Field
        ON dbo.tbl_CAT_RawRefUnmatchedValue (FieldName, ManufacturerId) INCLUDE (StagingId);
GO

------------------------------------------------------------
-- 2. STEP 4 PROCEDURE: fill the staging rows
------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CAT_RawRef_FillValues
    @Reprocess BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ------------------------------------------------------------
    -- 1. Staging rows to fill
    --    tbl_CAT_RawRefStaging: not approved, not created / failed
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Work;
    SELECT
        s.StagingId,
        s.ManufacturerId,
        s.RefKey
    INTO #Work
    FROM dbo.tbl_CAT_RawRefStaging AS s WITH (NOLOCK)
    WHERE s.IsApproved = 0
      AND (s.ExecutionStatus IS NULL OR s.ExecutionStatus = N'DryRunOK')
      AND (@Reprocess = 1 OR s.ValuesMappedDate IS NULL);

    CREATE UNIQUE CLUSTERED INDEX CX_Work ON #Work (StagingId);

    DECLARE @WorkCount INT = (SELECT COUNT(*) FROM #Work);
    PRINT 'Step 4 - staging rows to fill: ' + CAST(@WorkCount AS NVARCHAR(20));

    IF @WorkCount = 0
        RETURN;

    ------------------------------------------------------------
    -- 2. Raw rows of each ref (map rows still 'New'), values trimmed, blank = NULL
    --    tbl_CAT_RawRefMap + tbl_RAW_Catalog
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #RawRows;
    SELECT
        w.StagingId,
        w.ManufacturerId,
        r.Id                                                         AS RawCatalogId,
        NULLIF(LTRIM(RTRIM(r.Model)), N'')                           AS Model,
        NULLIF(LTRIM(RTRIM(r.DialColor)), N'')                       AS DialColor,
        NULLIF(LTRIM(RTRIM(r.CaseMaterial)), N'')                    AS CaseMaterial,
        NULLIF(LTRIM(RTRIM(r.BraceletOrStrapMaterial)), N'')         AS BraceletOrStrapMaterial,
        NULLIF(LTRIM(RTRIM(r.DialMaterial)), N'')                    AS DialMaterial,
        NULLIF(LTRIM(RTRIM(r.BezelMaterial)), N'')                   AS BezelMaterial,
        NULLIF(LTRIM(RTRIM(r.CaseBackMaterial)), N'')                AS CaseBackMaterial,
        NULLIF(LTRIM(RTRIM(r.DialEmbellishment)), N'')               AS DialEmbellishment,
        NULLIF(LTRIM(RTRIM(r.IndicesStyle)), N'')                    AS IndicesStyle,
        NULLIF(LTRIM(RTRIM(r.StrapStyle)), N'')                      AS StrapStyle,
        NULLIF(LTRIM(RTRIM(r.CrownEmbelishment)), N'')               AS CrownEmbelishment,
        NULLIF(LTRIM(RTRIM(r.Jewels)), N'')                          AS Jewels,
        NULLIF(LTRIM(RTRIM(r.Edition)), N'')                         AS Edition,
        NULLIF(LTRIM(RTRIM(r.DialStamp)), N'')                       AS DialStamp,
        NULLIF(LTRIM(RTRIM(r.PowerReserve)), N'')                    AS PowerReserve,
        NULLIF(LTRIM(RTRIM(r.WaterResistance)), N'')                 AS WaterResistance,
        NULLIF(LTRIM(RTRIM(r.Caliber)), N'')                         AS Caliber,
        NULLIF(LTRIM(RTRIM(r.Movement)), N'')                        AS Movement,
        NULLIF(LTRIM(RTRIM(r.MovementNo)), N'')                      AS MovementNo,
        NULLIF(LTRIM(RTRIM(r.Style)), N'')                           AS Style,
        CASE WHEN r.Width > 0 AND r.Width < 1000
             THEN CONVERT(NVARCHAR(100), CAST(r.Width AS DECIMAL(10, 2))) END AS Width,
        NULLIF(LTRIM(RTRIM(r.Dimensions)), N'')                      AS Dimensions,
        NULLIF(LTRIM(RTRIM(r.URL)), N'')                             AS SourceUrl
    INTO #RawRows
    FROM #Work AS w
    INNER JOIN dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
        ON m.ManufacturerId = w.ManufacturerId
       AND m.RefKey = w.RefKey
       AND m.CatalogId IS NULL
       AND m.MapStatus = N'New'
    INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
        ON r.Id = m.RawCatalogId;

    CREATE CLUSTERED INDEX CX_RawRows ON #RawRows (StagingId, RawCatalogId);

    ------------------------------------------------------------
    -- 3. One row per raw row + field (unpivot), only non-empty values
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Vals;
    SELECT
        r.StagingId,
        r.ManufacturerId,
        r.RawCatalogId,
        v.FieldName,
        v.Val
    INTO #Vals
    FROM #RawRows AS r
    CROSS APPLY (VALUES
        (N'Model',                   r.Model),
        (N'DialColor',               r.DialColor),
        (N'CaseMaterial',            r.CaseMaterial),
        (N'BraceletOrStrapMaterial', r.BraceletOrStrapMaterial),
        (N'DialMaterial',            r.DialMaterial),
        (N'BezelMaterial',           r.BezelMaterial),
        (N'CaseBackMaterial',        r.CaseBackMaterial),
        (N'DialEmbellishment',       r.DialEmbellishment),
        (N'IndicesStyle',            r.IndicesStyle),
        (N'StrapStyle',              r.StrapStyle),
        (N'CrownEmbelishment',       r.CrownEmbelishment),
        (N'Jewels',                  r.Jewels),
        (N'Edition',                 r.Edition),
        (N'DialStamp',               r.DialStamp),
        (N'PowerReserve',            r.PowerReserve),
        (N'WaterResistance',         r.WaterResistance),
        (N'Caliber',                 r.Caliber),
        (N'Movement',                r.Movement),
        (N'MovementNumber',          r.MovementNo),
        (N'Style',                   r.Style),
        (N'Width',                   r.Width),
        (N'Dimensions',              r.Dimensions)
    ) AS v (FieldName, Val)
    WHERE v.Val IS NOT NULL;

    CREATE CLUSTERED INDEX CX_Vals ON #Vals (StagingId, FieldName);

    ------------------------------------------------------------
    -- 4. How often each value occurs per staging row + field
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #ValCount;
    SELECT
        v.StagingId,
        v.ManufacturerId,
        v.FieldName,
        v.Val,
        COUNT(*)            AS Cnt,
        MAX(v.RawCatalogId) AS MaxRawId
    INTO #ValCount
    FROM #Vals AS v
    GROUP BY v.StagingId, v.ManufacturerId, v.FieldName, v.Val;

    CREATE CLUSTERED INDEX CX_ValCount ON #ValCount (StagingId, FieldName);

    ------------------------------------------------------------
    -- 5. The winning value: most frequent, ties the highest raw Id
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Winner;
    SELECT
        x.StagingId,
        x.ManufacturerId,
        x.FieldName,
        x.Val,
        x.Cnt
    INTO #Winner
    FROM (
        SELECT
            vc.*,
            ROW_NUMBER() OVER (PARTITION BY vc.StagingId, vc.FieldName
                               ORDER BY vc.Cnt DESC, vc.MaxRawId DESC) AS rn
        FROM #ValCount AS vc
    ) AS x
    WHERE x.rn = 1;

    CREATE CLUSTERED INDEX CX_Winner ON #Winner (StagingId, FieldName);

    ------------------------------------------------------------
    -- 6. Notes for the reviewer (conflicts, fuzzy matches, skipped URLs)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Notes;
    CREATE TABLE #Notes
    (
        StagingId INT NOT NULL,
        Note      NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NOT NULL
    );

    -- 6a. Fields where the raw rows disagree: every value with its count
    INSERT INTO #Notes (StagingId, Note)
    SELECT
        x.StagingId,
        N'Conflict ' + x.FieldName + N': '
            + STRING_AGG(CAST(LEFT(x.Val, 80) + N' (' + CAST(x.Cnt AS NVARCHAR(10)) + N')' AS NVARCHAR(MAX)), N'; ')
              WITHIN GROUP (ORDER BY x.Cnt DESC, x.MaxRawId DESC)
    FROM #ValCount AS x
    INNER JOIN (
        SELECT vc.StagingId, vc.FieldName
        FROM #ValCount AS vc
        GROUP BY vc.StagingId, vc.FieldName
        HAVING COUNT(*) > 1
    ) AS m
        ON m.StagingId = x.StagingId
       AND m.FieldName = x.FieldName
    GROUP BY x.StagingId, x.FieldName;

    ------------------------------------------------------------
    -- 7. Items to map: lists are split on commas, single values are used whole
    --    MapMfr = manufacturer only for fields that depend on it (Model, Edition), else 0
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Tokens;
    SELECT
        t.StagingId,
        t.ManufacturerId,
        CASE WHEN t.FieldName IN (N'Model', N'Edition') THEN t.ManufacturerId ELSE 0 END AS MapMfr,
        t.FieldName,
        t.Token
    INTO #Tokens
    FROM (
        SELECT DISTINCT
            w.StagingId,
            w.ManufacturerId,
            w.FieldName,
            LTRIM(RTRIM(s.value)) AS Token
        FROM #Winner AS w
        CROSS APPLY STRING_SPLIT(w.Val, N',') AS s
        WHERE w.FieldName IN (N'DialColor', N'CaseMaterial', N'BezelMaterial', N'CaseBackMaterial', N'IndicesStyle', N'DialEmbellishment')
          AND LTRIM(RTRIM(s.value)) <> N''
        UNION ALL
        SELECT
            w.StagingId,
            w.ManufacturerId,
            w.FieldName,
            w.Val
        FROM #Winner AS w
        WHERE w.FieldName IN (N'Model', N'BraceletOrStrapMaterial', N'DialMaterial', N'Movement', N'Caliber',
                              N'StrapStyle', N'CrownEmbelishment', N'Jewels', N'Edition', N'DialStamp', N'MovementNumber')
    ) AS t;

    CREATE CLUSTERED INDEX CX_Tokens ON #Tokens (StagingId, FieldName);

    DROP TABLE IF EXISTS #DistinctTokens;
    SELECT DISTINCT
        t.MapMfr,
        t.FieldName,
        t.Token
    INTO #DistinctTokens
    FROM #Tokens AS t;

    ------------------------------------------------------------
    -- 8. Master value for each distinct item
    --    #Mapped: MapMfr + field + item -> master name + method (Exact / Alternative / Fuzzy / ...)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Mapped;
    CREATE TABLE #Mapped
    (
        MapMfr      INT NOT NULL,
        FieldName   VARCHAR(50)    COLLATE DATABASE_DEFAULT NOT NULL,
        Token       NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NOT NULL,
        MappedValue NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,
        Method      NVARCHAR(50)   COLLATE DATABASE_DEFAULT NULL
    );

    -- 8a. One call to our own procedure per DISTINCT item (cursor, confirmed OK).
    --     sp_CAT_RawRef_MapValue (script 04a) covers every field: exact, alternative names and fuzzy where they exist.
    DECLARE @CurMfr INT,
            @CurMfrParam INT,
            @CurField VARCHAR(50),
            @CurSpField NVARCHAR(100),
            @CurToken NVARCHAR(MAX),
            @OutValue NVARCHAR(MAX),
            @OutIds NVARCHAR(500),
            @OutMethod NVARCHAR(50),
            @OutScore DECIMAL(5, 2);

    DECLARE map_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            d.MapMfr,
            d.FieldName,
            CASE d.FieldName
                WHEN N'BraceletOrStrapMaterial' THEN N'StrapMaterial'
                WHEN N'Movement'                THEN N'MovementType'
                ELSE d.FieldName
            END,
            d.Token
        FROM #DistinctTokens AS d;

    OPEN map_cursor;
    FETCH NEXT FROM map_cursor INTO @CurMfr, @CurField, @CurSpField, @CurToken;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @OutValue = NULL;
        SET @OutIds = NULL;
        SET @OutMethod = NULL;
        SET @OutScore = NULL;
        SET @CurMfrParam = CASE WHEN @CurMfr = 0 THEN NULL ELSE @CurMfr END;   -- EXEC parameters cannot be expressions

        EXEC dbo.sp_CAT_RawRef_MapValue
            @FieldName = @CurSpField,
            @RawValue = @CurToken,
            @ManufacturerId = @CurMfrParam,
            @MappedValue = @OutValue OUTPUT,
            @MappedIds = @OutIds OUTPUT,
            @MappingMethod = @OutMethod OUTPUT,
            @ConfidenceScore = @OutScore OUTPUT;

        IF @OutValue IS NOT NULL
            INSERT INTO #Mapped (MapMfr, FieldName, Token, MappedValue, Method)
            VALUES (@CurMfr, @CurField, @CurToken, @OutValue, @OutMethod);

        FETCH NEXT FROM map_cursor INTO @CurMfr, @CurField, @CurSpField, @CurToken;
    END

    CLOSE map_cursor;
    DEALLOCATE map_cursor;

    ------------------------------------------------------------
    -- 9. Result per staging row + item (NULL MappedValue = no master value)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #TokenResult;
    SELECT
        t.StagingId,
        t.ManufacturerId,
        t.FieldName,
        t.Token,
        mp.MappedValue,
        mp.Method
    INTO #TokenResult
    FROM #Tokens AS t
    LEFT JOIN #Mapped AS mp
        ON mp.MapMfr = t.MapMfr
       AND mp.FieldName = t.FieldName
       AND mp.Token = t.Token COLLATE DATABASE_DEFAULT;

    -- fuzzy matches are used but shown to the reviewer
    INSERT INTO #Notes (StagingId, Note)
    SELECT DISTINCT
        r.StagingId,
        N'Fuzzy match ' + r.FieldName + N': ' + LEFT(r.Token, 80) + N' -> ' + LEFT(r.MappedValue, 80)
    FROM #TokenResult AS r
    WHERE r.Method = N'Fuzzy'
      AND r.MappedValue IS NOT NULL;

    -- master values per staging row: lists comma-joined, one value per item
    DROP TABLE IF EXISTS #Agg;
    SELECT
        a.StagingId,
        a.FieldName,
        STRING_AGG(a.MappedValue, N',') WITHIN GROUP (ORDER BY a.MappedValue) AS Mapped
    INTO #Agg
    FROM (
        SELECT DISTINCT x.StagingId, x.FieldName, x.MappedValue
        FROM (
            SELECT r.StagingId, r.FieldName, r.Token, MIN(r.MappedValue) AS MappedValue
            FROM #TokenResult AS r
            WHERE r.MappedValue IS NOT NULL
            GROUP BY r.StagingId, r.FieldName, r.Token
        ) AS x
    ) AS a
    GROUP BY a.StagingId, a.FieldName;

    CREATE CLUSTERED INDEX CX_Agg ON #Agg (StagingId, FieldName);

    ------------------------------------------------------------
    -- 10. Parsed values (same rules as Janvi's script)
    ------------------------------------------------------------
    -- 10a. Case size: Width if numeric, else the leading number of Dimensions; 1 .. 999 mm
    DROP TABLE IF EXISTS #CaseSize;
    SELECT
        w.StagingId,
        COALESCE(
            CASE WHEN TRY_CAST(wi.Val AS NUMERIC(10, 2)) > 0 THEN TRY_CAST(wi.Val AS NUMERIC(10, 2)) END,
            CASE WHEN PATINDEX(N'[0-9]%', di.Val) = 1
                      AND TRY_CAST(LEFT(di.Val, PATINDEX(N'%[^0-9.]%', di.Val + N' ') - 1) AS NUMERIC(10, 2)) BETWEEN 1 AND 999
                 THEN TRY_CAST(LEFT(di.Val, PATINDEX(N'%[^0-9.]%', di.Val + N' ') - 1) AS NUMERIC(10, 2)) END
        ) AS CaseSize,
        COALESCE(wi.Val, di.Val) AS RawText
    INTO #CaseSize
    FROM #Work AS w
    LEFT JOIN #Winner AS wi ON wi.StagingId = w.StagingId AND wi.FieldName = N'Width'
    LEFT JOIN #Winner AS di ON di.StagingId = w.StagingId AND di.FieldName = N'Dimensions';

    -- 10b. Power reserve: one unambiguous number; '3 days' = 72; must exist in tbl_CAT_PowerReserveHour_d
    DROP TABLE IF EXISTS #PRHours;
    SELECT
        w.StagingId,
        w.Val AS RawText,
        TRY_CAST(LEFT(a.t, b.p - 1) AS FLOAT) * CASE WHEN w.Val LIKE N'%day%' THEN 24 ELSE 1 END AS Hours
    INTO #PRHours
    FROM #Winner AS w
    CROSS APPLY (SELECT SUBSTRING(w.Val, PATINDEX(N'%[0-9]%', w.Val), 50) AS t) AS a
    CROSS APPLY (SELECT PATINDEX(N'%[^0-9.]%', a.t + N' ') AS p) AS b
    WHERE w.FieldName = N'PowerReserve'
      AND PATINDEX(N'%[0-9]%', w.Val) > 0
      AND PATINDEX(N'%[0-9]%', SUBSTRING(a.t, b.p, 50)) = 0;

    DROP TABLE IF EXISTS #PRResult;
    SELECT
        p.StagingId,
        MIN(LTRIM(RTRIM(m.PowerReserveHourName))) AS PowerReserveName
    INTO #PRResult
    FROM #PRHours AS p
    INNER JOIN dbo.tbl_CAT_PowerReserveHour_d AS m WITH (NOLOCK)
        ON LTRIM(RTRIM(m.PowerReserveHourName)) = CONVERT(NVARCHAR(50), p.Hours) COLLATE SQL_Latin1_General_CP1_CI_AS
       AND m.StatusID = 1
    WHERE p.Hours > 0
    GROUP BY p.StagingId;

    -- 10c. Water resistance in whole metres (the catalog column is an INT). First rule that finds a number wins:
    --        1) a number written next to m / metre / metres / meter / meters   '100m/330ft' = 100, '3 bar (~30 meters)' = 30
    --        2) a number next to bar / bars / atm, times 10                    '10 bar' = 100
    --        3) a number next to ft / feet, times 0.3048                       '330 ft' = 101
    --        4) the only number in the text, taken as metres                   '100' = 100
    --      Text with no number ('Splash Resistant') stays empty and is listed as NotParseable.
    --      The text is lower-cased and the unit words are shortened first, so one pattern finds the number.
    DROP TABLE IF EXISTS #WRParts;
    SELECT
        w.StagingId,
        w.Val,
        t.T,
        PATINDEX(N'%[0-9]m[^a-z]%', t.T) AS PosM,
        PATINDEX(N'%[0-9]bar%',     t.T) AS PosBar,
        PATINDEX(N'%[0-9]atm%',     t.T) AS PosAtm,
        PATINDEX(N'%[0-9]ft%',      t.T) AS PosFt
    INTO #WRParts
    FROM #Winner AS w
    CROSS APPLY (SELECT N' ' + REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        LOWER(w.Val),
                        N'metres', N'm'), N'meters', N'm'), N'metre', N'm'), N'meter', N'm'),
                        N'bars', N'bar'), N'feet', N'ft'),
                        N' m', N'm'), N' bar', N'bar'), N' atm', N'atm'), N' ft', N'ft'), N'~', N'') + N' ' AS T) AS t
    WHERE w.FieldName = N'WaterResistance'
      AND PATINDEX(N'%[0-9]%', w.Val) > 0;

    DROP TABLE IF EXISTS #WaterRes;
    SELECT
        q.StagingId,
        TRY_CAST(ROUND(q.RawMeters, 0) AS INT) AS Meters
    INTO #WaterRes
    FROM (
        SELECT
            p.StagingId,
            COALESCE(nm.Num, nb.Num * 10, na.Num * 10, nf.Num * 0.3048, bn.Num) AS RawMeters
        FROM #WRParts AS p
        CROSS APPLY (SELECT CASE WHEN p.PosM > 0
                                 THEN REVERSE(LEFT(REVERSE(LEFT(p.T, p.PosM)),
                                                   PATINDEX(N'%[^0-9.]%', REVERSE(LEFT(p.T, p.PosM)) + N' ') - 1)) END AS S) AS sm
        CROSS APPLY (SELECT CASE WHEN p.PosBar > 0
                                 THEN REVERSE(LEFT(REVERSE(LEFT(p.T, p.PosBar)),
                                                   PATINDEX(N'%[^0-9.]%', REVERSE(LEFT(p.T, p.PosBar)) + N' ') - 1)) END AS S) AS sb
        CROSS APPLY (SELECT CASE WHEN p.PosAtm > 0
                                 THEN REVERSE(LEFT(REVERSE(LEFT(p.T, p.PosAtm)),
                                                   PATINDEX(N'%[^0-9.]%', REVERSE(LEFT(p.T, p.PosAtm)) + N' ') - 1)) END AS S) AS sa
        CROSS APPLY (SELECT CASE WHEN p.PosFt > 0
                                 THEN REVERSE(LEFT(REVERSE(LEFT(p.T, p.PosFt)),
                                                   PATINDEX(N'%[^0-9.]%', REVERSE(LEFT(p.T, p.PosFt)) + N' ') - 1)) END AS S) AS sf
        CROSS APPLY (SELECT TRY_CAST(CASE WHEN LEFT(sm.S, 1) = N'.' THEN SUBSTRING(sm.S, 2, 50) ELSE sm.S END AS FLOAT) AS Num) AS nm
        CROSS APPLY (SELECT TRY_CAST(CASE WHEN LEFT(sb.S, 1) = N'.' THEN SUBSTRING(sb.S, 2, 50) ELSE sb.S END AS FLOAT) AS Num) AS nb
        CROSS APPLY (SELECT TRY_CAST(CASE WHEN LEFT(sa.S, 1) = N'.' THEN SUBSTRING(sa.S, 2, 50) ELSE sa.S END AS FLOAT) AS Num) AS na
        CROSS APPLY (SELECT TRY_CAST(CASE WHEN LEFT(sf.S, 1) = N'.' THEN SUBSTRING(sf.S, 2, 50) ELSE sf.S END AS FLOAT) AS Num) AS nf
        -- rule 4: the text holds one number only
        CROSS APPLY (SELECT SUBSTRING(p.Val, PATINDEX(N'%[0-9]%', p.Val), 50) AS S1) AS b1
        CROSS APPLY (SELECT PATINDEX(N'%[^0-9.]%', b1.S1 + N' ') AS E1) AS b2
        CROSS APPLY (SELECT CASE WHEN PATINDEX(N'%[0-9]%', SUBSTRING(b1.S1, b2.E1, 50)) = 0
                                 THEN TRY_CAST(LEFT(b1.S1, b2.E1 - 1) AS FLOAT) END AS Num) AS bn
    ) AS q
    WHERE q.RawMeters >= 0.5
      AND q.RawMeters <= 20000;

    ------------------------------------------------------------
    -- 11. Images: first raw row (lowest raw Id) with an image; lowest orderIndex = primary, rest = secondary
    --     tbl_RAW_Media: IsDeleted = 0, Photo not blank
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #MediaRows;
    SELECT
        r.StagingId,
        r.RawCatalogId,
        md.Id                          AS MediaId,
        ISNULL(md.orderIndex, 2147483647) AS OrderIdx,
        LTRIM(RTRIM(md.Photo))         AS Photo
    INTO #MediaRows
    FROM #RawRows AS r
    INNER JOIN dbo.tbl_RAW_Media AS md WITH (NOLOCK)
        ON md.RawCatalogId = r.RawCatalogId
    WHERE md.IsDeleted = 0
      AND NULLIF(LTRIM(RTRIM(md.Photo)), N'') IS NOT NULL;

    CREATE CLUSTERED INDEX CX_MediaRows ON #MediaRows (StagingId, RawCatalogId);

    DROP TABLE IF EXISTS #ImageRow;
    SELECT
        mr.StagingId,
        MIN(mr.RawCatalogId) AS ImageRawCatalogId
    INTO #ImageRow
    FROM #MediaRows AS mr
    GROUP BY mr.StagingId;

    DROP TABLE IF EXISTS #ImageOrdered;
    SELECT
        mr.StagingId,
        mr.RawCatalogId,
        mr.Photo,
        ROW_NUMBER() OVER (PARTITION BY mr.StagingId ORDER BY mr.OrderIdx, mr.MediaId) AS rn
    INTO #ImageOrdered
    FROM #MediaRows AS mr
    INNER JOIN #ImageRow AS ir
        ON ir.StagingId = mr.StagingId
       AND ir.ImageRawCatalogId = mr.RawCatalogId;

    DROP TABLE IF EXISTS #Primary;
    SELECT
        o.StagingId,
        o.RawCatalogId,
        o.Photo
    INTO #Primary
    FROM #ImageOrdered AS o
    WHERE o.rn = 1;

    -- secondary: the other photos of the same raw row, no duplicates, no commas (the list is split on commas)
    DROP TABLE IF EXISTS #SecondaryAll;
    SELECT
        o.StagingId,
        o.Photo,
        MIN(o.rn) AS rn
    INTO #SecondaryAll
    FROM #ImageOrdered AS o
    INNER JOIN #Primary AS p
        ON p.StagingId = o.StagingId
    WHERE o.rn > 1
      AND o.Photo <> p.Photo
    GROUP BY o.StagingId, o.Photo;

    DROP TABLE IF EXISTS #Secondary;
    SELECT
        s.StagingId,
        STRING_AGG(s.Photo, N',') WITHIN GROUP (ORDER BY s.rn) AS SecondaryUrls
    INTO #Secondary
    FROM #SecondaryAll AS s
    WHERE s.Photo NOT LIKE N'%,%'
    GROUP BY s.StagingId;

    INSERT INTO #Notes (StagingId, Note)
    SELECT
        s.StagingId,
        N'Secondary image URL(s) containing a comma skipped: ' + CAST(COUNT(*) AS NVARCHAR(10))
    FROM #SecondaryAll AS s
    WHERE s.Photo LIKE N'%,%'
    GROUP BY s.StagingId;

    ------------------------------------------------------------
    -- 12. Source link: raw URL of the highest raw Id that has one
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Link;
    SELECT
        l.StagingId,
        l.SourceUrl
    INTO #Link
    FROM (
        SELECT
            r.StagingId,
            r.SourceUrl,
            ROW_NUMBER() OVER (PARTITION BY r.StagingId ORDER BY r.RawCatalogId DESC) AS rn
        FROM #RawRows AS r
        WHERE r.SourceUrl IS NOT NULL
    ) AS l
    WHERE l.rn = 1;

    ------------------------------------------------------------
    -- 13. Write everything to the staging rows (one transaction)
    ------------------------------------------------------------
    BEGIN TRANSACTION;

    -- 13a. clear what an earlier run wrote (re-run safe)
    UPDATE s
    SET s.Model_Raw = NULL, s.DialColor_Raw = NULL, s.CaseMaterial_Raw = NULL, s.BraceletOrStrapMaterial_Raw = NULL,
        s.DialMaterial_Raw = NULL, s.BezelMaterial_Raw = NULL, s.CaseBackMaterial_Raw = NULL, s.DialEmbellishment_Raw = NULL,
        s.IndicesStyle_Raw = NULL, s.StrapStyle_Raw = NULL, s.CrownEmbelishment_Raw = NULL, s.Jewels_Raw = NULL,
        s.Edition_Raw = NULL, s.DialStamp_Raw = NULL, s.PowerReserve_Raw = NULL, s.WaterResistance_Raw = NULL,
        s.Caliber_Raw = NULL, s.Movement_Raw = NULL, s.Width_Raw = NULL, s.Dimensions_Raw = NULL,
        s.ModelName_Mapped = NULL, s.DialColorNames_Mapped = NULL, s.CaseMaterialNames_Mapped = NULL,
        s.StrapMaterialNames_Mapped = NULL, s.DialMaterialName_Mapped = NULL, s.BezelMaterialNames_Mapped = NULL,
        s.CasebackMaterialNames_Mapped = NULL, s.DialEmbellishmentName_Mapped = NULL, s.IndicesStyleNames_Mapped = NULL,
        s.StrapStyleName_Mapped = NULL, s.CrownEmbelishmentName_Mapped = NULL, s.MovementJewelsName_Mapped = NULL,
        s.EditionName_Mapped = NULL, s.DialStampName_Mapped = NULL, s.PowerReserveHourName_Parsed = NULL,
        s.WaterResistanceMeters_Parsed = NULL, s.CalibreNumberName_Mapped = NULL, s.MovementTypeName_Mapped = NULL,
        s.CaseSize_Parsed = NULL, s.SourceLink = NULL, s.ImageRawCatalogId = NULL, s.PrimaryImageURL = NULL,
        s.SecondaryImageURLs = NULL, s.ConflictNotes = NULL,
        s.MovementNumber_Raw = NULL, s.MovementNumberName_Mapped = NULL, s.Style_Raw = NULL, s.Style_Value = NULL
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Work AS w
        ON w.StagingId = s.StagingId;

    DELETE u
    FROM dbo.tbl_CAT_RawRefUnmatchedValue AS u
    INNER JOIN #Work AS w
        ON w.StagingId = u.StagingId;

    -- 13b. raw ids and counts from the map (new raw rows of a staged ref are picked up here)
    UPDATE s
    SET s.RawCatalogIds = g.RawCatalogIds,
        s.RawRowCount   = g.RawRowCount
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN (
        SELECT
            r.StagingId,
            COUNT(*) AS RawRowCount,
            STRING_AGG(CAST(r.RawCatalogId AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY r.RawCatalogId) AS RawCatalogIds
        FROM #RawRows AS r
        GROUP BY r.StagingId
    ) AS g
        ON g.StagingId = s.StagingId;

    -- 13c. winning raw text per field
    UPDATE s
    SET s.Model_Raw                   = p.Model,
        s.DialColor_Raw               = p.DialColor,
        s.CaseMaterial_Raw            = p.CaseMaterial,
        s.BraceletOrStrapMaterial_Raw = p.BraceletOrStrapMaterial,
        s.DialMaterial_Raw            = p.DialMaterial,
        s.BezelMaterial_Raw           = p.BezelMaterial,
        s.CaseBackMaterial_Raw        = p.CaseBackMaterial,
        s.DialEmbellishment_Raw       = p.DialEmbellishment,
        s.IndicesStyle_Raw            = p.IndicesStyle,
        s.StrapStyle_Raw              = p.StrapStyle,
        s.CrownEmbelishment_Raw       = p.CrownEmbelishment,
        s.Jewels_Raw                  = p.Jewels,
        s.Edition_Raw                 = p.Edition,
        s.DialStamp_Raw               = p.DialStamp,
        s.PowerReserve_Raw            = p.PowerReserve,
        s.WaterResistance_Raw         = p.WaterResistance,
        s.Caliber_Raw                 = p.Caliber,
        s.Movement_Raw                = p.Movement,
        s.Width_Raw                   = LEFT(p.Width, 100),
        s.Dimensions_Raw              = p.Dimensions,
        s.MovementNumber_Raw          = p.MovementNumber,
        s.Style_Raw                   = p.Style
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN (
        SELECT
            w.StagingId,
            MAX(CASE WHEN w.FieldName = N'Model'                   THEN w.Val END) AS Model,
            MAX(CASE WHEN w.FieldName = N'DialColor'               THEN w.Val END) AS DialColor,
            MAX(CASE WHEN w.FieldName = N'CaseMaterial'            THEN w.Val END) AS CaseMaterial,
            MAX(CASE WHEN w.FieldName = N'BraceletOrStrapMaterial' THEN w.Val END) AS BraceletOrStrapMaterial,
            MAX(CASE WHEN w.FieldName = N'DialMaterial'            THEN w.Val END) AS DialMaterial,
            MAX(CASE WHEN w.FieldName = N'BezelMaterial'           THEN w.Val END) AS BezelMaterial,
            MAX(CASE WHEN w.FieldName = N'CaseBackMaterial'        THEN w.Val END) AS CaseBackMaterial,
            MAX(CASE WHEN w.FieldName = N'DialEmbellishment'       THEN w.Val END) AS DialEmbellishment,
            MAX(CASE WHEN w.FieldName = N'IndicesStyle'            THEN w.Val END) AS IndicesStyle,
            MAX(CASE WHEN w.FieldName = N'StrapStyle'              THEN w.Val END) AS StrapStyle,
            MAX(CASE WHEN w.FieldName = N'CrownEmbelishment'       THEN w.Val END) AS CrownEmbelishment,
            MAX(CASE WHEN w.FieldName = N'Jewels'                  THEN w.Val END) AS Jewels,
            MAX(CASE WHEN w.FieldName = N'Edition'                 THEN w.Val END) AS Edition,
            MAX(CASE WHEN w.FieldName = N'DialStamp'               THEN w.Val END) AS DialStamp,
            MAX(CASE WHEN w.FieldName = N'PowerReserve'            THEN w.Val END) AS PowerReserve,
            MAX(CASE WHEN w.FieldName = N'WaterResistance'         THEN w.Val END) AS WaterResistance,
            MAX(CASE WHEN w.FieldName = N'Caliber'                 THEN w.Val END) AS Caliber,
            MAX(CASE WHEN w.FieldName = N'Movement'                THEN w.Val END) AS Movement,
            MAX(CASE WHEN w.FieldName = N'Width'                   THEN w.Val END) AS Width,
            MAX(CASE WHEN w.FieldName = N'Dimensions'              THEN w.Val END) AS Dimensions,
            MAX(CASE WHEN w.FieldName = N'MovementNumber'          THEN w.Val END) AS MovementNumber,
            MAX(CASE WHEN w.FieldName = N'Style'                   THEN w.Val END) AS Style
        FROM #Winner AS w
        GROUP BY w.StagingId
    ) AS p
        ON p.StagingId = s.StagingId;

    -- 13d. master values per field
    UPDATE s
    SET s.ModelName_Mapped             = LEFT(a.Model, 500),
        s.DialColorNames_Mapped        = a.DialColor,
        s.CaseMaterialNames_Mapped     = a.CaseMaterial,
        s.StrapMaterialNames_Mapped    = a.Strap,
        s.DialMaterialName_Mapped      = a.DialMaterial,
        s.BezelMaterialNames_Mapped    = a.BezelMaterial,
        s.CasebackMaterialNames_Mapped = a.CaseBackMaterial,
        s.DialEmbellishmentName_Mapped = a.DialEmbellishment,
        s.IndicesStyleNames_Mapped     = a.IndicesStyle,
        s.StrapStyleName_Mapped        = LEFT(a.StrapStyle, 500),
        s.CrownEmbelishmentName_Mapped = LEFT(a.CrownEmbelishment, 500),
        s.MovementJewelsName_Mapped    = LEFT(a.Jewels, 500),
        s.EditionName_Mapped           = LEFT(a.Edition, 500),
        s.DialStampName_Mapped         = LEFT(a.DialStamp, 500),
        s.CalibreNumberName_Mapped     = LEFT(a.Caliber, 500),
        s.MovementTypeName_Mapped      = LEFT(a.Movement, 500),
        s.MovementNumberName_Mapped    = LEFT(a.MovementNumber, 500)
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN (
        SELECT
            g.StagingId,
            MAX(CASE WHEN g.FieldName = N'Model'                   THEN g.Mapped END) AS Model,
            MAX(CASE WHEN g.FieldName = N'DialColor'               THEN g.Mapped END) AS DialColor,
            MAX(CASE WHEN g.FieldName = N'CaseMaterial'            THEN g.Mapped END) AS CaseMaterial,
            MAX(CASE WHEN g.FieldName = N'BraceletOrStrapMaterial' THEN g.Mapped END) AS Strap,
            MAX(CASE WHEN g.FieldName = N'DialMaterial'            THEN g.Mapped END) AS DialMaterial,
            MAX(CASE WHEN g.FieldName = N'BezelMaterial'           THEN g.Mapped END) AS BezelMaterial,
            MAX(CASE WHEN g.FieldName = N'CaseBackMaterial'        THEN g.Mapped END) AS CaseBackMaterial,
            MAX(CASE WHEN g.FieldName = N'DialEmbellishment'       THEN g.Mapped END) AS DialEmbellishment,
            MAX(CASE WHEN g.FieldName = N'IndicesStyle'            THEN g.Mapped END) AS IndicesStyle,
            MAX(CASE WHEN g.FieldName = N'StrapStyle'              THEN g.Mapped END) AS StrapStyle,
            MAX(CASE WHEN g.FieldName = N'CrownEmbelishment'       THEN g.Mapped END) AS CrownEmbelishment,
            MAX(CASE WHEN g.FieldName = N'Jewels'                  THEN g.Mapped END) AS Jewels,
            MAX(CASE WHEN g.FieldName = N'Edition'                 THEN g.Mapped END) AS Edition,
            MAX(CASE WHEN g.FieldName = N'DialStamp'               THEN g.Mapped END) AS DialStamp,
            MAX(CASE WHEN g.FieldName = N'Caliber'                 THEN g.Mapped END) AS Caliber,
            MAX(CASE WHEN g.FieldName = N'Movement'                THEN g.Mapped END) AS Movement,
            MAX(CASE WHEN g.FieldName = N'MovementNumber'          THEN g.Mapped END) AS MovementNumber
        FROM #Agg AS g
        GROUP BY g.StagingId
    ) AS a
        ON a.StagingId = s.StagingId;

    -- 13e. parsed values
    UPDATE s
    SET s.CaseSize_Parsed = c.CaseSize
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #CaseSize AS c
        ON c.StagingId = s.StagingId
    WHERE c.CaseSize IS NOT NULL;

    UPDATE s
    SET s.PowerReserveHourName_Parsed = p.PowerReserveName
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #PRResult AS p
        ON p.StagingId = s.StagingId;

    UPDATE s
    SET s.WaterResistanceMeters_Parsed = wr.Meters
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #WaterRes AS wr
        ON wr.StagingId = s.StagingId
    WHERE wr.Meters IS NOT NULL;

    -- style: free text in the catalog (VARCHAR(30)); used only when it fits
    UPDATE s
    SET s.Style_Value = CAST(w.Val AS VARCHAR(30))
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Winner AS w
        ON w.StagingId = s.StagingId
       AND w.FieldName = N'Style'
    WHERE LEN(w.Val) <= 30;

    -- 13f. images and source link
    UPDATE s
    SET s.ImageRawCatalogId = p.RawCatalogId,
        s.PrimaryImageURL   = p.Photo
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Primary AS p
        ON p.StagingId = s.StagingId;

    UPDATE s
    SET s.SecondaryImageURLs = sec.SecondaryUrls
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Secondary AS sec
        ON sec.StagingId = s.StagingId;

    UPDATE s
    SET s.SourceLink = l.SourceUrl
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Link AS l
        ON l.StagingId = s.StagingId;

    -- 13g. unmatched values for the report
    INSERT INTO dbo.tbl_CAT_RawRefUnmatchedValue (StagingId, ManufacturerId, FieldName, RawValue, Reason)
    SELECT DISTINCT
        r.StagingId,
        r.ManufacturerId,
        r.FieldName,
        LEFT(r.Token, 1000),
        'NoMasterValue'
    FROM #TokenResult AS r
    WHERE r.MappedValue IS NULL;

    INSERT INTO dbo.tbl_CAT_RawRefUnmatchedValue (StagingId, ManufacturerId, FieldName, RawValue, Reason)
    SELECT
        w.StagingId,
        w.ManufacturerId,
        'PowerReserve',
        LEFT(w.Val, 1000),
        CASE WHEN EXISTS (SELECT 1 FROM #PRHours AS ph WHERE ph.StagingId = w.StagingId AND ph.Hours > 0)
             THEN 'NoMasterValue' ELSE 'NotParseable' END
    FROM #Winner AS w
    LEFT JOIN #PRResult AS pr
        ON pr.StagingId = w.StagingId
    WHERE w.FieldName = N'PowerReserve'
      AND pr.StagingId IS NULL;

    INSERT INTO dbo.tbl_CAT_RawRefUnmatchedValue (StagingId, ManufacturerId, FieldName, RawValue, Reason)
    SELECT
        w.StagingId,
        w.ManufacturerId,
        'WaterResistance',
        LEFT(w.Val, 1000),
        'NotParseable'
    FROM #Winner AS w
    LEFT JOIN #WaterRes AS wr
        ON wr.StagingId = w.StagingId
       AND wr.Meters IS NOT NULL
    WHERE w.FieldName = N'WaterResistance'
      AND wr.StagingId IS NULL;

    INSERT INTO dbo.tbl_CAT_RawRefUnmatchedValue (StagingId, ManufacturerId, FieldName, RawValue, Reason)
    SELECT
        c.StagingId,
        w.ManufacturerId,
        'CaseSize',
        LEFT(c.RawText, 1000),
        'NotParseable'
    FROM #CaseSize AS c
    INNER JOIN #Work AS w
        ON w.StagingId = c.StagingId
    WHERE c.CaseSize IS NULL
      AND c.RawText IS NOT NULL;

    INSERT INTO dbo.tbl_CAT_RawRefUnmatchedValue (StagingId, ManufacturerId, FieldName, RawValue, Reason)
    SELECT
        w.StagingId,
        w.ManufacturerId,
        'Style',
        LEFT(w.Val, 1000),
        'NotParseable'
    FROM #Winner AS w
    WHERE w.FieldName = N'Style'
      AND LEN(w.Val) > 30;

    -- 13h. notes for the reviewer
    UPDATE s
    SET s.ConflictNotes = n.Txt
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN (
        SELECT
            x.StagingId,
            STRING_AGG(x.Note, N' | ') WITHIN GROUP (ORDER BY x.Note) AS Txt
        FROM #Notes AS x
        GROUP BY x.StagingId
    ) AS n
        ON n.StagingId = s.StagingId;

    -- 13i. done
    UPDATE s
    SET s.ValuesMappedDate = GETDATE()
    FROM dbo.tbl_CAT_RawRefStaging AS s
    INNER JOIN #Work AS w
        ON w.StagingId = s.StagingId;

    COMMIT TRANSACTION;

    ------------------------------------------------------------
    -- 14. Summary
    ------------------------------------------------------------
    DECLARE @ImageCount INT = (SELECT COUNT(*) FROM #Primary);
    DECLARE @NoteCount INT = (SELECT COUNT(DISTINCT n.StagingId) FROM #Notes AS n);
    DECLARE @UnmatchedCount INT = (SELECT COUNT(*)
                                   FROM dbo.tbl_CAT_RawRefUnmatchedValue AS u WITH (NOLOCK)
                                   INNER JOIN #Work AS w ON w.StagingId = u.StagingId);

    PRINT 'Step 4 - staging rows filled: ' + CAST(@WorkCount AS NVARCHAR(20));
    PRINT 'Step 4 - with a primary image: ' + CAST(@ImageCount AS NVARCHAR(20));
    PRINT 'Step 4 - with conflict / fuzzy notes: ' + CAST(@NoteCount AS NVARCHAR(20));
    PRINT 'Step 4 - unmatched values listed: ' + CAST(@UnmatchedCount AS NVARCHAR(20));
END
GO

/*
------------------------------------------------------------
-- Run (select and run on their own)
------------------------------------------------------------
EXEC dbo.sp_CAT_RawRef_FillValues;            -- only rows never filled
-- EXEC dbo.sp_CAT_RawRef_FillValues @Reprocess = 1;   -- all pending, not approved rows again

-- Check 1: how many staged refs have each value filled
SELECT
    COUNT(*)                                                        AS StagedRefs,
    SUM(CASE WHEN ValuesMappedDate IS NOT NULL THEN 1 ELSE 0 END)   AS Filled,
    SUM(CASE WHEN ModelName_Mapped IS NOT NULL THEN 1 ELSE 0 END)   AS WithModel,
    SUM(CASE WHEN DialColorNames_Mapped IS NOT NULL THEN 1 ELSE 0 END)     AS WithDialColor,
    SUM(CASE WHEN CaseMaterialNames_Mapped IS NOT NULL THEN 1 ELSE 0 END)  AS WithCaseMaterial,
    SUM(CASE WHEN CaseSize_Parsed IS NOT NULL THEN 1 ELSE 0 END)    AS WithCaseSize,
    SUM(CASE WHEN PrimaryImageURL IS NOT NULL THEN 1 ELSE 0 END)    AS WithImage,
    SUM(CASE WHEN SourceLink IS NOT NULL THEN 1 ELSE 0 END)         AS WithSourceLink,
    SUM(CASE WHEN ConflictNotes IS NOT NULL THEN 1 ELSE 0 END)      AS WithNotes
FROM dbo.tbl_CAT_RawRefStaging WITH (NOLOCK);

-- Check 2: values with no master value, most frequent first
SELECT TOP (100) FieldName, RawValue, Reason, COUNT(*) AS StagedRefs
FROM dbo.tbl_CAT_RawRefUnmatchedValue WITH (NOLOCK)
GROUP BY FieldName, RawValue, Reason
ORDER BY COUNT(*) DESC;
*/
