/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 02: step 1 (sync map table) and step 2 (match to catalog) in ONE procedure
===================================================================================
Purpose : Creates one stored procedure in EWMaster. Needs script 01 run first.
            dbo.sp_CAT_RawRef_SyncAndMatch @SkipSync BIT = 0, @Rekey BIT = 0
              part 1 (sync)  - loads official raw rows that are not in tbl_CAT_RawRefMap yet
              part 2 (match) - sets CatalogId for map rows where CatalogId IS NULL
            @SkipSync = 1 runs part 2 only (step 6 uses it for its last duplicate check).
            @Rekey = 1 (one time, after the key rules changed) keys the not-yet-mapped rows again.
          (Merged from the former sp_CAT_RawRef_SyncMap and sp_CAT_RawRef_MatchCatalog.)
DB      : EWMaster
Run     : hand-run in SSMS. This file only CREATES the procedures (CREATE OR ALTER);
          it does not fill any table. The EXEC lines at the bottom are commented out.

Confirmed by Vishva (Documents/RawToCatalog_NewRefs_Requirements.md):
  - Official sources only: tbl_sourceManufacturer_mapping, IsActive NULL or 1, CatSourceName contains
    'OFFICIAL' (widened later from 'Official Website%' to match sp_map_rawCatalog_catalogCountry).
  - Raw rows with IsDeleted = 1 are ignored; IsDeleted NULL counts as live; IsSeenInLastRun is not filtered.
  - Match key = normalized reference only (fn_ExtractNumbersAndAlphabets), per manufacturer.
  - tbl_CAT_RawCatalogMapping is read FIRST in step 2 (added later, Vishva): a key there wins over
    the catalog lookup, any brand, only when it points to exactly one active Watch catalog row
    (Janvi's rule). Keys with several catalogs are left to the catalog lookup and flagged in MapNote.
  - "Exists in the catalog" = tbl_CAT_Catalog_d row with EntityType = 'Watch' and StatusID = 1.
  - Cleaning (from Janvi's script): Rolex leading 'M' removed; Audemars Piguet '-' -> '.';
    Tudor leading 'M' ignored on BOTH the raw and the catalog side (in the key only).
  - Several active Watch rows for one key: the LOWEST CatalogId is used and the others are
    written to MapNote ("Multiple active Watch rows: ...") so they can be listed.

Added from the comparison with sp_map_rawCatalog_catalogCountry (Vishva agreed):
  - Blank ReferenceNo: the latest non-empty reference from Mirror.EWMaster.tbl_RAW_Catalog_m is used.
  - Rolex ArtworkId repair of empty / truncated references (see part 1, step 4).
  - Source filter as above. Not copied on purpose: the CatCountryLocationId requirement and the
    refresh of IsDeleted / IsSeenInLastRun on rows already in the map.

Things added that were not asked for (flagged, rule A7):
  - Raw rows with a blank or NULL reference ARE loaded into the map (RefKey NULL, MapStatus 'Unmapped')
    so the coverage count is complete; they are never matched or staged.
  - The scalar function is run once per DISTINCT reference, not once per raw row (performance).

Cost note: step 1 looks for official raw rows missing from the map with an anti-join, so it
reads the official sources' rows of tbl_RAW_Catalog every run (no index on SourceId). It does not
call the function for rows already mapped. Step 2 touches only map rows where CatalogId IS NULL.
===================================================================================
*/

USE [EWMaster]
GO

------------------------------------------------------------
-- ONE PROCEDURE: sync the map table (part 1), then match it to the catalog (part 2)
--   @SkipSync = 1 runs only part 2 (used by step 6 as the last duplicate check)
------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CAT_RawRef_SyncAndMatch
    @SkipSync BIT = 0,
    @Rekey    BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- PART 1: sync - load official raw rows that are not in tbl_CAT_RawRefMap yet
    ------------------------------------------------------------
    IF @SkipSync = 0
    BEGIN
        ------------------------------------------------------------
        -- 1. Official sources (same filter as sp_map_rawCatalog_catalogCountry)
        --    tbl_sourceManufacturer_mapping: IsActive NULL or 1, CatSourceName contains 'OFFICIAL'
        --    (the country is NOT required here: it is not needed to create a catalog row)
        ------------------------------------------------------------
        DROP TABLE IF EXISTS #OfficialSources;
        SELECT
            sm.SourceId,
            sm.CatManufacturerId   AS ManufacturerId,
            sm.CatManufacturerName AS ManufacturerName
        INTO #OfficialSources
        FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
        WHERE ISNULL(sm.IsActive, 1) = 1
          AND UPPER(LTRIM(RTRIM(ISNULL(sm.CatSourceName, N'')))) LIKE N'%OFFICIAL%'
          AND sm.CatManufacturerId IS NOT NULL;

        CREATE UNIQUE CLUSTERED INDEX CX_OfficialSources ON #OfficialSources (SourceId);

        ------------------------------------------------------------
        -- 2. Raw rows to key
        --    a) official raw rows (IsDeleted = 0 or NULL) not in tbl_CAT_RawRefMap yet -> IsExisting = 0
        --    b) only when @Rekey = 1: map rows with no CatalogId and MapStatus Unmapped / New are
        --       keyed again with the current rules -> IsExisting = 1 (one-time, after the rules changed)
        --    ArtworkId is read for the Rolex repair.
        ------------------------------------------------------------
        DROP TABLE IF EXISTS #NewRaw;
        SELECT
            r.Id                                                  AS RawCatalogId,
            r.SourceId,
            o.ManufacturerId,
            o.ManufacturerName,
            LTRIM(RTRIM(LEFT(r.ReferenceNo, 500)))                AS ReferenceRaw,
            LTRIM(RTRIM(LEFT(ISNULL(r.ArtworkId, N''), 500)))     AS ArtworkId,
            CAST(0 AS BIT)                                        AS IsExisting
        INTO #NewRaw
        FROM #OfficialSources AS o
        INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
            ON r.SourceId = o.SourceId
        WHERE (r.IsDeleted = 0 OR r.IsDeleted IS NULL)
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
                WHERE m.RawCatalogId = r.Id
          );

        IF @Rekey = 1
        BEGIN
            INSERT INTO #NewRaw (RawCatalogId, SourceId, ManufacturerId, ManufacturerName, ReferenceRaw, ArtworkId, IsExisting)
            SELECT
                r.Id,
                r.SourceId,
                o.ManufacturerId,
                o.ManufacturerName,
                LTRIM(RTRIM(LEFT(r.ReferenceNo, 500))),
                LTRIM(RTRIM(LEFT(ISNULL(r.ArtworkId, N''), 500))),
                1
            FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
            INNER JOIN dbo.tbl_RAW_Catalog AS r WITH (NOLOCK)
                ON r.Id = m.RawCatalogId
            INNER JOIN #OfficialSources AS o
                ON o.SourceId = r.SourceId
            WHERE m.CatalogId IS NULL
              AND m.MapStatus IN ('Unmapped', 'New')
              AND (r.IsDeleted = 0 OR r.IsDeleted IS NULL);
        END

        CREATE CLUSTERED INDEX CX_NewRaw ON #NewRaw (RawCatalogId);

        ------------------------------------------------------------
        -- 3. Blank references: take the latest non-empty ReferenceNo from the Mirror
        --    (same rule as sp_map_rawCatalog_catalogCountry: newest by COALESCE(UpdatedDate, MirrorDate),
        --     Mirror rows with IsDeleted = 1 ignored)
        --    Mirror.EWMaster.tbl_RAW_Catalog_m
        ------------------------------------------------------------
        DROP TABLE IF EXISTS #MirrorBestRef;
        CREATE TABLE #MirrorBestRef (
            Id                BIGINT        NOT NULL,
            MirrorReferenceNo NVARCHAR(500) NULL
        );
        CREATE UNIQUE CLUSTERED INDEX CX_MirrorBestRef_Id ON #MirrorBestRef (Id);

        IF EXISTS (SELECT 1 FROM #NewRaw WHERE NULLIF(ReferenceRaw, N'') IS NULL)
        BEGIN
            INSERT INTO #MirrorBestRef (Id, MirrorReferenceNo)
            SELECT x.Id, LTRIM(RTRIM(LEFT(x.ReferenceNo, 500)))
            FROM (
                SELECT
                    mm.Id,
                    mm.ReferenceNo,
                    ROW_NUMBER() OVER (
                        PARTITION BY mm.Id
                        ORDER BY COALESCE(mm.UpdatedDate, mm.MirrorDate) DESC
                    ) AS rn
                FROM Mirror.EWMaster.tbl_RAW_Catalog_m AS mm WITH (NOLOCK)
                INNER JOIN #NewRaw AS n
                    ON n.RawCatalogId = mm.Id
                   AND NULLIF(n.ReferenceRaw, N'') IS NULL
                WHERE NULLIF(LTRIM(RTRIM(mm.ReferenceNo)), N'') IS NOT NULL
                  AND ISNULL(mm.IsDeleted, 0) = 0
            ) AS x
            WHERE x.rn = 1;
        END

        -- Reference to use per raw row: its own ReferenceNo, else the Mirror one
        DROP TABLE IF EXISTS #RawRef;
        SELECT
            n.RawCatalogId,
            n.SourceId,
            n.ManufacturerId,
            n.ManufacturerName,
            n.IsExisting,
            COALESCE(NULLIF(n.ReferenceRaw, N''), mr.MirrorReferenceNo, N'')            AS RefForMapping,
            CASE WHEN NULLIF(n.ReferenceRaw, N'') IS NULL AND mr.Id IS NOT NULL
                 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END                            AS FromMirror,
            -- ArtworkId only matters for Rolex; '' for every other brand
            CASE WHEN n.ManufacturerName = N'Rolex' THEN n.ArtworkId ELSE N'' END       AS ArtworkKey
        INTO #RawRef
        FROM #NewRaw AS n
        LEFT JOIN #MirrorBestRef AS mr
            ON mr.Id = n.RawCatalogId;

        CREATE CLUSTERED INDEX CX_RawRef ON #RawRef (RawCatalogId);

        ------------------------------------------------------------
        -- 4. Distinct references to clean (so the function runs once per reference)
        --    Rolex with ArtworkId (same as sp_map_rawCatalog_catalogCountry):
        --      empty reference + ArtworkId starts with 'm'      -> ArtworkId without the 'm'
        --      reference starts with 'm'                        -> reference without the 'm'
        --      reference shorter than ArtworkId, contained in it,
        --        ArtworkId starts with 'm'                      -> ArtworkId without the 'm' (truncated reference)
        --    Rolex without ArtworkId: leading 'M' removed. Audemars Piguet: '-' -> '.'
        ------------------------------------------------------------
        DROP TABLE IF EXISTS #DistinctRefsClean;
        SELECT
            d.ManufacturerName,
            d.RefForMapping,
            d.ArtworkKey,
            CASE
                WHEN d.ManufacturerName = N'Rolex'
                     AND d.RefForMapping = N''
                     AND LEFT(d.ArtworkKey, 1) = N'M'
                     AND LEN(d.ArtworkKey) > 1
                    THEN SUBSTRING(d.ArtworkKey, 2, LEN(d.ArtworkKey) - 1)
                WHEN d.ManufacturerName = N'Rolex'
                     AND LEFT(d.RefForMapping, 1) = N'M'
                     AND LEN(d.RefForMapping) > 1
                    THEN SUBSTRING(d.RefForMapping, 2, LEN(d.RefForMapping) - 1)
                WHEN d.ManufacturerName = N'Rolex'
                     AND d.RefForMapping <> N''
                     AND LEN(d.RefForMapping) < LEN(d.ArtworkKey)
                     AND CHARINDEX(d.RefForMapping, d.ArtworkKey) > 0
                     AND LEFT(d.ArtworkKey, 1) = N'M'
                    THEN SUBSTRING(d.ArtworkKey, 2, LEN(d.ArtworkKey) - 1)
                WHEN d.ManufacturerName = N'Audemars Piguet'
                     AND CHARINDEX(N'-', d.RefForMapping) > 0
                    THEN REPLACE(d.RefForMapping, N'-', N'.')
                ELSE d.RefForMapping
            END AS ReferenceClean
        INTO #DistinctRefsClean
        FROM (
            SELECT DISTINCT ManufacturerName, RefForMapping, ArtworkKey
            FROM #RawRef
            WHERE RefForMapping <> N''
        ) AS d;

        ------------------------------------------------------------
        -- 5. Normalized key per distinct reference
        --    Tudor: one leading 'M' ignored before normalizing
        ------------------------------------------------------------
        DROP TABLE IF EXISTS #DistinctRefsKey;
        SELECT
            c.ManufacturerName,
            c.RefForMapping,
            c.ArtworkKey,
            c.ReferenceClean,
            CAST(dbo.fn_ExtractNumbersAndAlphabets(LEFT(
                CASE
                    WHEN c.ManufacturerName = N'Tudor'
                         AND LEFT(c.ReferenceClean, 1) = N'M'
                         AND LEN(c.ReferenceClean) > 1
                        THEN SUBSTRING(c.ReferenceClean, 2, LEN(c.ReferenceClean) - 1)
                    ELSE c.ReferenceClean
                END, 255)) AS NVARCHAR(500)) AS RefKey
        INTO #DistinctRefsKey
        FROM #DistinctRefsClean AS c;

        ------------------------------------------------------------
        -- 6a. New raw rows into the map (CatalogId NULL, MapStatus 'Unmapped')
        --     ReferenceRaw = the reference used (Mirror one when the raw one was blank)
        ------------------------------------------------------------
        INSERT INTO dbo.tbl_CAT_RawRefMap
            (RawCatalogId, SourceId, ManufacturerId, ReferenceRaw, ReferenceClean, RefKey, MapStatus, MapNote, CreatedDate)
        SELECT
            n.RawCatalogId,
            n.SourceId,
            n.ManufacturerId,
            NULLIF(n.RefForMapping, N''),
            k.ReferenceClean,
            NULLIF(k.RefKey, N''),
            'Unmapped',
            CASE WHEN n.FromMirror = 1 AND NULLIF(k.RefKey, N'') IS NOT NULL
                 THEN N'Reference taken from the Mirror (raw reference was blank)' END,
            GETDATE()
        FROM #RawRef AS n
        LEFT JOIN #DistinctRefsKey AS k
            ON k.ManufacturerName = n.ManufacturerName
           AND k.RefForMapping = n.RefForMapping
           AND k.ArtworkKey = n.ArtworkKey
        WHERE n.IsExisting = 0;

        PRINT 'Sync done - rows added to tbl_CAT_RawRefMap: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        ------------------------------------------------------------
        -- 6b. @Rekey = 1: refresh reference / key of existing rows. If the KEY changed, the row goes
        --     back to 'Unmapped' (step 3 / 02b then re-link or remove the old staged ref).
        ------------------------------------------------------------
        IF @Rekey = 1
        BEGIN
            UPDATE m
            SET m.ReferenceRaw   = NULLIF(n.RefForMapping, N''),
                m.ReferenceClean = k.ReferenceClean,
                m.MapStatus      = CASE WHEN ISNULL(m.RefKey, N'') <> ISNULL(NULLIF(k.RefKey, N''), N'')
                                        THEN 'Unmapped' ELSE m.MapStatus END,
                m.MapNote        = CASE WHEN n.FromMirror = 1 AND NULLIF(k.RefKey, N'') IS NOT NULL
                                        THEN N'Reference taken from the Mirror (raw reference was blank)'
                                        ELSE m.MapNote END,
                m.RefKey         = NULLIF(k.RefKey, N''),
                m.UpdatedDate    = GETDATE()
            FROM dbo.tbl_CAT_RawRefMap AS m
            INNER JOIN #RawRef AS n
                ON n.RawCatalogId = m.RawCatalogId
               AND n.IsExisting = 1
            LEFT JOIN #DistinctRefsKey AS k
                ON k.ManufacturerName = n.ManufacturerName
               AND k.RefForMapping = n.RefForMapping
               AND k.ArtworkKey = n.ArtworkKey
            WHERE m.CatalogId IS NULL
              AND m.MapStatus IN ('Unmapped', 'New')
              AND (   ISNULL(m.RefKey, N'')         <> ISNULL(NULLIF(k.RefKey, N''), N'')
                   OR ISNULL(m.ReferenceClean, N'') <> ISNULL(k.ReferenceClean, N'')
                   OR ISNULL(m.ReferenceRaw, N'')   <> ISNULL(NULLIF(n.RefForMapping, N''), N''));

            PRINT 'Rekey done - existing map rows refreshed: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));
        END
    END

    ------------------------------------------------------------
    -- PART 2: match - set CatalogId for map rows where CatalogId IS NULL
    ------------------------------------------------------------
    ------------------------------------------------------------
    -- 1. Work set: map rows with no CatalogId and a usable key
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #Work;
    SELECT
        m.RawCatalogId,
        m.ManufacturerId,
        m.RefKey
    INTO #Work
    FROM dbo.tbl_CAT_RawRefMap AS m WITH (NOLOCK)
    WHERE m.CatalogId IS NULL
      AND m.RefKey IS NOT NULL;

    CREATE CLUSTERED INDEX CX_Work ON #Work (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 2. Manufacturers that have work (limits the catalog scan)
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #WorkMfr;
    SELECT DISTINCT ManufacturerId
    INTO #WorkMfr
    FROM #Work;

    CREATE UNIQUE CLUSTERED INDEX CX_WorkMfr ON #WorkMfr (ManufacturerId);

    ------------------------------------------------------------
    -- 2b. tbl_CAT_RawCatalogMapping FIRST (manual raw-reference overrides)
    --     A key found there WINS over the catalog lookup below, for ANY brand, but only
    --     when it points to exactly ONE catalog row (same rule as Janvi's map procedure).
    --     The mapped catalog row must be EntityType = 'Watch', StatusID = 1.
    --     The key is cleaned with the same brand rules as the raw side (brand = the brand
    --     of the mapped catalog row). Keys that point to several catalogs are NOT applied;
    --     they fall through to the catalog lookup and, if still unmatched, get a MapNote.
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #MapTblDistinct;
    SELECT DISTINCT
        mf.ManufacturerName,
        LTRIM(RTRIM(LEFT(rcm.RawReferenceNumber, 500))) AS RawReferenceNumber
    INTO #MapTblDistinct
    FROM dbo.tbl_CAT_RawCatalogMapping AS rcm WITH (NOLOCK)
    INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
        ON cd.CatalogId = rcm.CatalogId
    INNER JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
        ON mf.ManufacturerId = cd.ManufacturerId
    WHERE rcm.CatalogId IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(rcm.RawReferenceNumber)), N'') IS NOT NULL
      AND cd.StatusID = 1
      AND cd.EntityType = N'Watch';

    -- Rolex leading 'M' removed, Audemars Piguet '-' -> '.', Tudor leading 'M' ignored (as for the raw side)
    DROP TABLE IF EXISTS #MapTblKey;
    SELECT
        d.ManufacturerName,
        d.RawReferenceNumber,
        CAST(dbo.fn_ExtractNumbersAndAlphabets(LEFT(
            CASE
                WHEN d.ManufacturerName = N'Tudor'
                     AND LEFT(c.RefClean, 1) = N'M' AND LEN(c.RefClean) > 1
                    THEN SUBSTRING(c.RefClean, 2, LEN(c.RefClean) - 1)
                ELSE c.RefClean
            END, 255)) AS NVARCHAR(500)) AS RefKey
    INTO #MapTblKey
    FROM #MapTblDistinct AS d
    CROSS APPLY (
        SELECT CASE
                   WHEN d.ManufacturerName = N'Rolex'
                        AND LEFT(d.RawReferenceNumber, 1) = N'M' AND LEN(d.RawReferenceNumber) > 1
                       THEN SUBSTRING(d.RawReferenceNumber, 2, LEN(d.RawReferenceNumber) - 1)
                   WHEN d.ManufacturerName = N'Audemars Piguet'
                        AND CHARINDEX(N'-', d.RawReferenceNumber) > 0
                       THEN REPLACE(d.RawReferenceNumber, N'-', N'.')
                   ELSE d.RawReferenceNumber
               END AS RefClean
    ) AS c;

    -- Distinct (key, catalog) pairs
    DROP TABLE IF EXISTS #MapTblPairs;
    SELECT DISTINCT k.RefKey, rcm.CatalogId
    INTO #MapTblPairs
    FROM dbo.tbl_CAT_RawCatalogMapping AS rcm WITH (NOLOCK)
    INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
        ON cd.CatalogId = rcm.CatalogId
    INNER JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
        ON mf.ManufacturerId = cd.ManufacturerId
    INNER JOIN #MapTblKey AS k
        ON k.ManufacturerName = mf.ManufacturerName
       AND k.RawReferenceNumber = LTRIM(RTRIM(LEFT(rcm.RawReferenceNumber, 500)))
    WHERE rcm.CatalogId IS NOT NULL
      AND cd.StatusID = 1
      AND cd.EntityType = N'Watch'
      AND NULLIF(k.RefKey, N'') IS NOT NULL;

    -- One row per key: the single catalog, or the list when there are several
    DROP TABLE IF EXISTS #MapTblAgg;
    SELECT
        p.RefKey,
        MIN(p.CatalogId)                                                      AS CatalogId,
        COUNT(*)                                                              AS CatalogCount,
        STRING_AGG(CAST(p.CatalogId AS NVARCHAR(20)), ',') WITHIN GROUP (ORDER BY p.CatalogId) AS CatalogIds
    INTO #MapTblAgg
    FROM #MapTblPairs AS p
    GROUP BY p.RefKey;

    CREATE UNIQUE CLUSTERED INDEX CX_MapTblAgg ON #MapTblAgg (RefKey);

    -- Apply: exactly one catalog for the key, any brand
    UPDATE m
    SET m.CatalogId   = a.CatalogId,
        m.MapStatus   = 'Matched',
        m.MapNote     = N'Matched through tbl_CAT_RawCatalogMapping',
        m.MapDate     = GETDATE(),
        m.UpdatedDate = GETDATE()
    FROM dbo.tbl_CAT_RawRefMap AS m
    INNER JOIN #Work AS w
        ON w.RawCatalogId = m.RawCatalogId
    INNER JOIN #MapTblAgg AS a
        ON a.RefKey = w.RefKey
       AND a.CatalogCount = 1
    WHERE m.CatalogId IS NULL;

    PRINT 'Step 2 (mapping table first) - map rows matched through tbl_CAT_RawCatalogMapping: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    ------------------------------------------------------------
    -- 3. Catalog rows to compare against
    --    tbl_CAT_Catalog_d: EntityType = 'Watch', StatusID = 1; manufacturer StatusID = 1
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #CatRows;
    SELECT
        cd.CatalogId,
        cd.ManufacturerId,
        mf.ManufacturerName,
        cd.ReferenceNumber
    INTO #CatRows
    FROM #WorkMfr AS w
    INNER JOIN dbo.tbl_CAT_Catalog_d AS cd WITH (NOLOCK)
        ON cd.ManufacturerId = w.ManufacturerId
    INNER JOIN dbo.tbl_CAT_Manufacturer_d AS mf WITH (NOLOCK)
        ON mf.ManufacturerId = cd.ManufacturerId
       AND mf.StatusID = 1
    WHERE cd.StatusID = 1
      AND cd.EntityType = N'Watch'
      AND cd.ReferenceNumber IS NOT NULL
      AND LTRIM(RTRIM(cd.ReferenceNumber)) <> N'';

    ------------------------------------------------------------
    -- 4. Normalized key per distinct catalog reference
    --    Tudor: one leading 'M' ignored, same as the raw side
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #CatKeys;
    SELECT
        d.ManufacturerId,
        d.ReferenceNumber,
        CAST(dbo.fn_ExtractNumbersAndAlphabets(LEFT(
            CASE
                WHEN d.ManufacturerName = N'Tudor'
                     AND LEFT(LTRIM(RTRIM(d.ReferenceNumber)), 1) = N'M'
                     AND LEN(LTRIM(RTRIM(d.ReferenceNumber))) > 1
                    THEN SUBSTRING(LTRIM(RTRIM(d.ReferenceNumber)), 2, LEN(LTRIM(RTRIM(d.ReferenceNumber))) - 1)
                ELSE LTRIM(RTRIM(d.ReferenceNumber))
            END, 255)) AS NVARCHAR(500)) AS RefKey
    INTO #CatKeys
    FROM (
        SELECT DISTINCT ManufacturerId, ManufacturerName, ReferenceNumber
        FROM #CatRows
    ) AS d;

    ------------------------------------------------------------
    -- 5. One row per manufacturer + key: lowest CatalogId, and the full list if there are several
    ------------------------------------------------------------
    DROP TABLE IF EXISTS #CatalogRefAgg;
    SELECT
        r.ManufacturerId,
        k.RefKey,
        MIN(r.CatalogId)                                                      AS CatalogId,
        COUNT(*)                                                              AS CatalogCount,
        STRING_AGG(CAST(r.CatalogId AS NVARCHAR(20)), ',') WITHIN GROUP (ORDER BY r.CatalogId) AS CatalogIds
    INTO #CatalogRefAgg
    FROM #CatRows AS r
    INNER JOIN #CatKeys AS k
        ON k.ManufacturerId = r.ManufacturerId
       AND k.ReferenceNumber = r.ReferenceNumber
    WHERE NULLIF(k.RefKey, N'') IS NOT NULL
    GROUP BY r.ManufacturerId, k.RefKey;

    CREATE CLUSTERED INDEX CX_CatalogRefAgg ON #CatalogRefAgg (ManufacturerId, RefKey);

    ------------------------------------------------------------
    -- 6. Set CatalogId on the matched map rows
    --    Several catalog rows for one key: lowest CatalogId, others listed in MapNote
    ------------------------------------------------------------
    UPDATE m
    SET m.CatalogId   = a.CatalogId,
        m.MapStatus   = 'Matched',
        m.MapNote     = CASE WHEN a.CatalogCount > 1
                             THEN LEFT(N'Multiple active Watch rows: ' + a.CatalogIds, 500)
                             ELSE NULL END,
        m.MapDate     = GETDATE(),
        m.UpdatedDate = GETDATE()
    FROM dbo.tbl_CAT_RawRefMap AS m
    INNER JOIN #Work AS w
        ON w.RawCatalogId = m.RawCatalogId
    INNER JOIN #CatalogRefAgg AS a
        ON a.ManufacturerId = w.ManufacturerId
       AND a.RefKey = w.RefKey
    WHERE m.CatalogId IS NULL;

    PRINT 'Step 2 (catalog lookup) - map rows matched to the catalog: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    ------------------------------------------------------------
    -- 7. Flag the rows that stay unmatched because the mapping table key points to
    --    SEVERAL catalogs (a person decides; they remain new refs for now)
    ------------------------------------------------------------
    UPDATE m
    SET m.MapNote     = LEFT(N'tbl_CAT_RawCatalogMapping key points to several catalogs: ' + a.CatalogIds, 500),
        m.UpdatedDate = GETDATE()
    FROM dbo.tbl_CAT_RawRefMap AS m
    INNER JOIN #Work AS w
        ON w.RawCatalogId = m.RawCatalogId
    INNER JOIN #MapTblAgg AS a
        ON a.RefKey = w.RefKey
       AND a.CatalogCount > 1
    WHERE m.CatalogId IS NULL;

    PRINT 'Step 2 - unmatched map rows flagged (mapping table key has several catalogs): ' + CAST(@@ROWCOUNT AS NVARCHAR(20));
END
GO

/*
------------------------------------------------------------
-- Run (select and run on their own, one after the other)
------------------------------------------------------------
EXEC dbo.sp_CAT_RawRef_SyncAndMatch;

------------------------------------------------------------
-- Check: coverage and refs with several catalog rows
------------------------------------------------------------
-- run Check_Coverage_And_ByCatalog.sql (query 1)

SELECT RawCatalogId, ManufacturerId, ReferenceRaw, CatalogId, MapNote
FROM dbo.tbl_CAT_RawRefMap WITH (NOLOCK)
WHERE MapNote LIKE N'Multiple active Watch rows:%';
*/
