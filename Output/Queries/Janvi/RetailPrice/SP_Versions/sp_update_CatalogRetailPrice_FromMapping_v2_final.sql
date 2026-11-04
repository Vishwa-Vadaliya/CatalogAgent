USE [EWMaster]
GO
/****** Object:  StoredProcedure [dbo].[sp_update_CatalogRetailPrice_FromMapping]    Script Date: 9/28/2026 5:50:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    Incremental retail price insert (daily): same rules as sp_Insert_CatalogRetailPrice_FromMapping except
    - Watermark: dbo.tbl_cat_RetailPrice_SyncLog ? MAX(MaxRawCatalogTransactionId) (ignore dates).
    - Mirror: (CatalogId, CountryId) with no public draft retail yet ? all mirror history + EffectiveDate CASE
      (same as sp_Insert_CatalogRetailPrice_FromMapping). Otherwise mirror rows with TransactionId > @LastMax only when
      current dbo.tbl_RAW_Catalog.TransactionId > @LastMax for that RawCatalogId (stale raw ? skip mirror for that id).
    - Current raw row: TransactionId > @LastMax (EffectiveDate = UpdatedDate); also include when NeedFullMirrorHistory = 1
      (new retail key). No map.RawCatalogUpdatedDate date gate.
    - End of run: log row + MAX(TransactionId) over whole dbo.tbl_RAW_Catalog (even when RowsInserted = 0).

    Full backfill remains sp_Insert_CatalogRetailPrice_FromMapping (unchanged).

    - Source currency gate: dbo.tbl_sourceManufacturer_mapping (per SourceId). When Currency is set,
      raw/mirror row Currency must match (trim, case-insensitive); NULL/blank = no extra check.

    - CatalogId / CountryId from mapping, plus ref guard (same RawCatalogId can point at wrong data):
      normalized raw/mirror ReferenceNo must match either (a) tbl_CAT_Catalog_d.ReferenceNumber or
      (b) a row in tbl_CAT_RawCatalogMapping for the same CatalogId with the same
      normalized RawReferenceNumber (catalog ref is cleaned; raw listing may be unclean; RawCatalogId
      is often NULL on that table so it is not part of the check).
    - Soft-deleted listings excluded: dbo.tbl_RAW_Catalog rows with IsDeleted = 1 are ignored for retail
      insert (RAW path and current-row gate on MIRROR path). Mirror history rows with IsDeleted = 1 on
      tbl_RAW_Catalog_m are also excluded. Active map only (map.IsDeleted = 0).
    - No USD conversion: % difference baseline per (CatalogID, CountryId, CurrencyId): latest public
      verified draft row in tbl_CAT_CatalogRetailPrice_d (StatusID = 1, IsPrivate = 0, IsVerified = 1)
      when present; if that key has no verified retail yet, baseline = latest upcoming candidate in this
      run (max EffectiveDate among #PriceChangesAfterPLS for that key). IsPrivate = 1 and IsVerified = 0
      are excluded from catalog-latest reads (private / non-manufacturer streams).
    - Same-day collapse + consecutive duplicate removal: status-1 rows are dropped only when price equals
      the previous status-1 candidate in this run (outliers StatusID = 2 are invisible in that chain).
      Matching published catalog latest price on a later date is allowed (e.g. 5000 after 7000 on 6-12).
      Upcoming-run baseline is used for % diff / outliers only — not to drop the latest candidate when
      no catalog retail exists yet (avoids skipping the true latest price e.g. 1.35 CAD).
    - StatusID: 1 normal; 2 when ABS(% diff vs baseline — catalog latest or upcoming latest) > 50, or when
      WouldBeStatus = 1 but price equals published catalog latest and an earlier outlier (WouldBeStatus = 2)
      exists in this run with no status-1 change in between (PrevStatus1PriceInRun IS NULL) — pending review
      as duplicate-of-catalog while outlier is unresolved (e.g. catalog 5000 on 02-12, outlier 50000 on 03-12,
      5000 on 04-12 inserts as StatusID 2; 5000 on 06-12 after 7000 stays StatusID 1). Manual review may
      promote related StatusID 2 rows to 1 after the outlier is confirmed.
    - Idempotent re-run: remove candidates early when (CatalogID, CountryId, CurrencyId, Price) matches an existing row
      on the same calendar day (CreatedAt vs EffectiveDate) with StatusID IN (1, 2, 3) and IsPrivate = 0 — before
      same-day, consecutive dedup, and merged timeline (avoids ghost rows affecting in-run patterns).
    - tbl_RAW_Catalog.Price is float: TRY_CAST to money / decimal(10,2) avoids overflow on bad crawl values
      (dot/comma magnitudes); PercDiff NULL when % cannot fit decimal(10,2); WouldBeStatus still uses float compare.
    - Merge with latest verified catalog row (IsVerified = 1) per (CatalogID, CountryId, CurrencyId)
      for timeline insert rules. Rows inserted by this SP are IsVerified = 1 (manufacturer official).

    - Rolex ref guard (2026-10-28): for map rows whose RAW source is Rolex (tbl_sourceManufacturer_mapping.CatManufacturerName
      = 'ROLEX') the guard key is built like sp_map_rawCatalog_catalogCountry does: blank ReferenceNo + ArtworkId starting
      m -> ArtworkId without m; ReferenceNo starting m -> strip m; ReferenceNo shorter than and contained in an ArtworkId
      starting m -> ArtworkId without m; else ReferenceNo. Then the same compare (catalog ref or tbl_CAT_RawCatalogMapping).
      Other brands: unchanged (ReferenceNo as is).

    - Map rows without a country (map.CountryId NULL, official source with no location; 2026-10-29) are skipped:
      they exist for reference production status only and never get retail prices.

    Parameters: @DryRun = 1 preview only (no log, no watermark advance). @SeedMaxTransactionId when log empty.
    Pipeline when @DryRun = 0: INSERT + tbl_cat_RetailPrice_SyncLog in one transaction; then UpdateMap + Sync
    + sp_Sync_RefProductionStatus_FromMapping (reference production status from the same map).

    EveryWatchDDL: no matching routine — new MasterDB procedure.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_update_CatalogRetailPrice_FromMapping]
      @DryRun                 bit     = 1
    , @SeedMaxTransactionId   bigint  = NULL
    , @InsertedRowCount       int     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @InsertedRowCount = 0;

   EXEC sp_map_rawCatalog_catalogCountry;

    DECLARE
        @LastMaxRawCatalogTransactionId bigint
      , @NewMaxRawCatalogTransactionId  bigint
      , @RunCompletedAt                   datetime2(3)
      , @LogStatus                        varchar(20)
      , @LogErrorMessage                  nvarchar(max);

    /* Watermark: always take MAX(TransactionId) ever logged (ignore dates). */
    SELECT
        @LastMaxRawCatalogTransactionId = MAX(l.MaxRawCatalogTransactionId)
    FROM dbo.tbl_cat_RetailPrice_SyncLog AS l WITH (NOLOCK);

    IF @LastMaxRawCatalogTransactionId IS NULL
        SET @LastMaxRawCatalogTransactionId = ISNULL(@SeedMaxTransactionId, 0);

    /* -------------------------------------------------------------------------
       MIRROR PATH: new (CatalogId, CountryId) ? full mirror + EffectiveDate CASE; else incremental by TransactionId.
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #ActiveMapPairs;
    DROP TABLE IF EXISTS #CatalogCountryHasRetail;
    DROP TABLE IF EXISTS #RcmRefExtract;
    DROP TABLE IF EXISTS #MirrorBaseInc;
    DROP TABLE IF EXISTS #MirrorBaseFull;
    DROP TABLE IF EXISTS #MirrorRanked;
    DROP TABLE IF EXISTS #TempMirror;

    SELECT DISTINCT
          rp.CatalogID AS CatalogId
        , rp.CountryId
    INTO #CatalogCountryHasRetail
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
    INNER JOIN (
        SELECT DISTINCT
              map.CatalogId
            , map.CountryId
        FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
        INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
            ON cat.CatalogId = map.CatalogId
           AND cat.StatusID = 1
        INNER JOIN dbo.tbl_RAW_Catalog AS rawCur WITH (NOLOCK)
            ON rawCur.Id = map.RawCatalogId
           AND ISNULL(rawCur.IsDeleted, 0) = 0
        WHERE map.IsDeleted = 0
    ) AS mk
        ON mk.CatalogId = rp.CatalogID
       AND mk.CountryId = rp.CountryId
    WHERE rp.StatusID = 1
      AND ISNULL(rp.IsPrivate, 0) = 0;

    CREATE UNIQUE CLUSTERED INDEX CX_CatalogCountryHasRetail
        ON #CatalogCountryHasRetail (CatalogId, CountryId);

    /* Active map keys + catalog ref extract once per map row (same predicates as before). */
    SELECT
          map.RawCatalogId
        , map.CatalogId
        , map.CountryId
        , rawCur.TransactionId AS RawCurrentTransactionId
        , dbo.fn_ExtractNumbersAndAlphabets(
              CAST(LEFT(LTRIM(RTRIM(ISNULL(cat.ReferenceNumber, N''))), 255) AS varchar(255))
          ) AS CatRefExt
        , CAST(
              CASE
                  WHEN hr.CatalogId IS NULL
                      THEN 1
                  ELSE 0
              END AS bit
          ) AS NeedFullMirrorHistory
        , CAST(
              CASE
                  WHEN UPPER(LTRIM(RTRIM(ISNULL(sm.CatManufacturerName, N'')))) = N'ROLEX'
                      THEN 1
                  ELSE 0
              END AS bit
          ) AS IsRolex
    INTO #ActiveMapPairs
    FROM dbo.tbl_MAP_RawCatalog_CatalogCountry AS map WITH (NOLOCK)
    INNER JOIN dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
        ON cat.CatalogId = map.CatalogId
       AND cat.StatusID = 1
    INNER JOIN dbo.tbl_RAW_Catalog AS rawCur WITH (NOLOCK)
        ON rawCur.Id = map.RawCatalogId
       AND ISNULL(rawCur.IsDeleted, 0) = 0
    LEFT JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
        ON sm.SourceId = rawCur.SourceId
    LEFT JOIN #CatalogCountryHasRetail AS hr WITH (NOLOCK)
        ON hr.CatalogId = map.CatalogId
       AND hr.CountryId = map.CountryId
    WHERE map.IsDeleted = 0
      AND map.CountryId IS NOT NULL;

    CREATE CLUSTERED INDEX CX_ActiveMapPairs_Raw
        ON #ActiveMapPairs (RawCatalogId);

    CREATE NONCLUSTERED INDEX IX_ActiveMapPairs_Cat
        ON #ActiveMapPairs (CatalogId, CountryId);

    /* Curated ref keys for active catalogs only (replaces per-row correlated EXISTS). */
    SELECT DISTINCT
          rcm.CatalogId
        , dbo.fn_ExtractNumbersAndAlphabets(
              CAST(LEFT(LTRIM(RTRIM(ISNULL(rcm.RawReferenceNumber, N''))), 255) AS varchar(255))
          ) AS RcmRefExt
    INTO #RcmRefExtract
    FROM dbo.tbl_CAT_RawCatalogMapping AS rcm WITH (NOLOCK)
    INNER JOIN (
        SELECT DISTINCT
              amp.CatalogId
        FROM #ActiveMapPairs AS amp WITH (NOLOCK)
    ) AS ck
        ON ck.CatalogId = rcm.CatalogId
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(rcm.RawReferenceNumber, N''))), N'') IS NOT NULL;

    CREATE NONCLUSTERED INDEX IX_RcmRefExtract
        ON #RcmRefExtract (CatalogId, RcmRefExt);

    /* Incremental mirror: retail exists; mirror TransactionId > watermark only if current raw TransactionId > watermark. */
    ;WITH MirrorJoinedInc AS (
        SELECT
              trc.IdMirror
            , trc.Id
            , trc.ReferenceNo
            , trc.Manufacturer
            , trc.ArtworkId
            , trc.Price
            , trc.Currency
            , trc.SourceId
            , trc.CreatedDate
            , trc.UpdatedDate
            , trc.MirrorDate
            , trc.URL               AS Url
            , trc.Location
            , trc.IsSeenInLastRun
            , amp.CatalogId
            , amp.CountryId
            , amp.CatRefExt
            , dbo.fn_ExtractNumbersAndAlphabets(
                  CAST(LEFT(rk.GuardRef, 255) AS varchar(255))
              ) AS MirrorRefExt
        FROM #ActiveMapPairs AS amp WITH (NOLOCK)
        INNER JOIN MIRROR.EWMaster.tbl_raw_catalog_m AS trc WITH (NOLOCK)
            ON trc.Id = amp.RawCatalogId
        CROSS APPLY (
            SELECT
                  LTRIM(RTRIM(ISNULL(trc.ReferenceNo, N''))) AS RefTrim
                , LTRIM(RTRIM(ISNULL(CAST(trc.ArtworkId AS nvarchar(255)), N''))) AS ArtTrim
        ) AS rt
        /* Ref guard key: Rolex rule as in sp_map_rawCatalog_catalogCountry (leading m / ArtworkId); others as is. */
        CROSS APPLY (
            SELECT
                CASE
                    WHEN amp.IsRolex = 0
                        THEN rt.RefTrim
                    WHEN rt.RefTrim = N''
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    WHEN LEFT(rt.RefTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.RefTrim, 2, 255)
                    WHEN LEN(rt.RefTrim) < LEN(rt.ArtTrim)
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                         AND CHARINDEX(rt.RefTrim, rt.ArtTrim) > 0
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    ELSE rt.RefTrim
                END AS GuardRef
        ) AS rk
        WHERE amp.NeedFullMirrorHistory = 0
          AND amp.RawCurrentTransactionId IS NOT NULL
          AND amp.RawCurrentTransactionId > @LastMaxRawCatalogTransactionId
          AND ISNULL(trc.IsDeleted, 0) = 0
          AND trc.TransactionId IS NOT NULL
          AND trc.TransactionId > @LastMaxRawCatalogTransactionId
    )
    SELECT
          mj.IdMirror
        , mj.Id
        , mj.ReferenceNo
        , mj.Manufacturer
        , mj.ArtworkId
        , mj.Price
        , mj.Currency
        , mj.SourceId
        , trs.Name              AS SourceName
        , mj.CreatedDate
        , mj.UpdatedDate
        , mj.MirrorDate
        , mj.CatalogId
        , mj.CountryId
        , mj.Url
        , mj.Location
        , mj.IsSeenInLastRun
    INTO #MirrorBaseInc
    FROM MirrorJoinedInc AS mj WITH (NOLOCK)
    INNER JOIN dbo.tbl_RAW_Source AS trs WITH (NOLOCK)
        ON mj.SourceId = trs.SourceId
    LEFT JOIN #RcmRefExtract AS rcmHit WITH (NOLOCK)
        ON rcmHit.CatalogId = mj.CatalogId
       AND rcmHit.RcmRefExt = mj.MirrorRefExt
    WHERE NULLIF(mj.MirrorRefExt, '') IS NOT NULL
      AND (
          mj.MirrorRefExt = mj.CatRefExt
          OR rcmHit.CatalogId IS NOT NULL
      );

    /* New retail (CatalogId, CountryId): all mirror rows; ref guard per mirror ReferenceNo. */
    ;WITH MirrorJoinedFull AS (
        SELECT
              trc.IdMirror
            , trc.Id
            , trc.ReferenceNo
            , trc.Manufacturer
            , trc.ArtworkId
            , trc.Price
            , trc.Currency
            , trc.SourceId
            , trc.CreatedDate
            , trc.UpdatedDate
            , trc.MirrorDate
            , trc.URL               AS Url
            , trc.Location
            , trc.IsSeenInLastRun
            , amp.CatalogId
            , amp.CountryId
            , amp.CatRefExt
            , dbo.fn_ExtractNumbersAndAlphabets(
                  CAST(LEFT(rk.GuardRef, 255) AS varchar(255))
              ) AS MirrorRefExt
        FROM #ActiveMapPairs AS amp WITH (NOLOCK)
        INNER JOIN MIRROR.EWMaster.tbl_raw_catalog_m AS trc WITH (NOLOCK)
            ON trc.Id = amp.RawCatalogId
        CROSS APPLY (
            SELECT
                  LTRIM(RTRIM(ISNULL(trc.ReferenceNo, N''))) AS RefTrim
                , LTRIM(RTRIM(ISNULL(CAST(trc.ArtworkId AS nvarchar(255)), N''))) AS ArtTrim
        ) AS rt
        /* Ref guard key: Rolex rule as in sp_map_rawCatalog_catalogCountry (leading m / ArtworkId); others as is. */
        CROSS APPLY (
            SELECT
                CASE
                    WHEN amp.IsRolex = 0
                        THEN rt.RefTrim
                    WHEN rt.RefTrim = N''
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    WHEN LEFT(rt.RefTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.RefTrim, 2, 255)
                    WHEN LEN(rt.RefTrim) < LEN(rt.ArtTrim)
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                         AND CHARINDEX(rt.RefTrim, rt.ArtTrim) > 0
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    ELSE rt.RefTrim
                END AS GuardRef
        ) AS rk
        WHERE amp.NeedFullMirrorHistory = 1
          AND ISNULL(trc.IsDeleted, 0) = 0
          AND trc.TransactionId IS NOT NULL
    )
    SELECT
          mj.IdMirror
        , mj.Id
        , mj.ReferenceNo
        , mj.Manufacturer
        , mj.ArtworkId
        , mj.Price
        , mj.Currency
        , mj.SourceId
        , trs.Name              AS SourceName
        , mj.CreatedDate
        , mj.UpdatedDate
        , mj.MirrorDate
        , mj.CatalogId
        , mj.CountryId
        , mj.Url
        , mj.Location
        , mj.IsSeenInLastRun
    INTO #MirrorBaseFull
    FROM MirrorJoinedFull AS mj WITH (NOLOCK)
    INNER JOIN dbo.tbl_RAW_Source AS trs WITH (NOLOCK)
        ON mj.SourceId = trs.SourceId
    LEFT JOIN #RcmRefExtract AS rcmHit WITH (NOLOCK)
        ON rcmHit.CatalogId = mj.CatalogId
       AND rcmHit.RcmRefExt = mj.MirrorRefExt
    WHERE NULLIF(mj.MirrorRefExt, '') IS NOT NULL
      AND (
          mj.MirrorRefExt = mj.CatRefExt
          OR rcmHit.CatalogId IS NOT NULL
      );

    SELECT
          m.*
        , ROW_NUMBER() OVER (
              PARTITION BY m.Id, m.Location, m.Currency
              ORDER BY m.MirrorDate ASC
          ) AS RowNum
        , SUM(CASE WHEN m.UpdatedDate IS NOT NULL THEN 1 ELSE 0 END)
              OVER (
                  PARTITION BY m.Id, m.Location, m.Currency
                  ORDER BY m.MirrorDate ASC
                  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
              ) AS PriorNotNullUpdatedDateCount
        , LAG(m.MirrorDate) OVER (
              PARTITION BY m.Id, m.Location, m.Currency
              ORDER BY m.MirrorDate ASC
          ) AS PrevMirrorDate
    INTO #MirrorRanked
    FROM #MirrorBaseFull AS m WITH (NOLOCK);

    SELECT
          m.Id
        , m.ReferenceNo
        , m.Manufacturer
        , m.ArtworkId
        , m.Price
        , m.Currency
        , m.SourceId
        , m.SourceName
        , m.CreatedDate
        , m.UpdatedDate
        , m.MirrorDate
        , m.CatalogId
        , m.CountryId
        , m.Url
        , m.Location
        , m.IsSeenInLastRun
        , CAST(NULL AS varchar(20)) AS MirrorScenario
        , m.UpdatedDate              AS EffectiveDate
        , 'MIRROR'                   AS DataOrigin
    INTO #TempMirror
    FROM #MirrorBaseInc AS m WITH (NOLOCK)
    WHERE m.UpdatedDate IS NOT NULL

    UNION ALL

    SELECT
          m.Id
        , m.ReferenceNo
        , m.Manufacturer
        , m.ArtworkId
        , m.Price
        , m.Currency
        , m.SourceId
        , m.SourceName
        , m.CreatedDate
        , m.UpdatedDate
        , m.MirrorDate
        , m.CatalogId
        , m.CountryId
        , m.Url
        , m.Location
        , m.IsSeenInLastRun
        , CASE
              WHEN m.UpdatedDate IS NULL
                  THEN 'S1-PreFix'
              WHEN ISNULL(m.PriorNotNullUpdatedDateCount, 0) = 0
                  THEN 'S2-Transition'
              ELSE 'S3-Reliable'
          END AS MirrorScenario
        , CASE
              WHEN m.UpdatedDate IS NOT NULL
                   AND ISNULL(m.PriorNotNullUpdatedDateCount, 0) >= 1
                  THEN m.UpdatedDate
              WHEN m.PrevMirrorDate IS NULL
                  THEN m.CreatedDate
              ELSE m.PrevMirrorDate
          END AS EffectiveDate
        , 'MIRROR' AS DataOrigin
    FROM #MirrorRanked AS m WITH (NOLOCK);

    /* -------------------------------------------------------------------------
       RAW PATH: current dbo.tbl_RAW_Catalog (not deleted). Incremental: TransactionId > watermark;
       full current row when NeedFullMirrorHistory = 1 (same split as mirror). Ref guard as mirror.
       EffectiveDate = raw UpdatedDate (no mirror timeline).
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #TempRawMapped;

    ;WITH RawJoined AS (
        SELECT
              trc.Id
            , trc.ReferenceNo
            , trc.Manufacturer
            , trc.ArtworkId
            , trc.Price
            , trc.Currency
            , trc.SourceId
            , trc.CreatedDate
            , trc.UpdatedDate
            , trc.URL               AS Url
            , trc.IsSeenInLastRun
            , amp.CatalogId
            , amp.CountryId
            , amp.CatRefExt
            , dbo.fn_ExtractNumbersAndAlphabets(
                  CAST(LEFT(rk.GuardRef, 255) AS varchar(255))
              ) AS RawRefExt
        FROM #ActiveMapPairs AS amp WITH (NOLOCK)
        INNER JOIN dbo.tbl_RAW_Catalog AS trc WITH (NOLOCK)
            ON trc.Id = amp.RawCatalogId
        CROSS APPLY (
            SELECT
                  LTRIM(RTRIM(ISNULL(trc.ReferenceNo, N''))) AS RefTrim
                , LTRIM(RTRIM(ISNULL(CAST(trc.ArtworkId AS nvarchar(255)), N''))) AS ArtTrim
        ) AS rt
        /* Ref guard key: Rolex rule as in sp_map_rawCatalog_catalogCountry (leading m / ArtworkId); others as is. */
        CROSS APPLY (
            SELECT
                CASE
                    WHEN amp.IsRolex = 0
                        THEN rt.RefTrim
                    WHEN rt.RefTrim = N''
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    WHEN LEFT(rt.RefTrim, 1) IN (N'm', N'M')
                        THEN SUBSTRING(rt.RefTrim, 2, 255)
                    WHEN LEN(rt.RefTrim) < LEN(rt.ArtTrim)
                         AND LEFT(rt.ArtTrim, 1) IN (N'm', N'M')
                         AND CHARINDEX(rt.RefTrim, rt.ArtTrim) > 0
                        THEN SUBSTRING(rt.ArtTrim, 2, 255)
                    ELSE rt.RefTrim
                END AS GuardRef
        ) AS rk
        WHERE ISNULL(trc.IsDeleted, 0) = 0
          AND trc.TransactionId IS NOT NULL
          AND (
              amp.NeedFullMirrorHistory = 1
              OR trc.TransactionId > @LastMaxRawCatalogTransactionId
          )
    )
    SELECT
          rj.Id
        , rj.ReferenceNo
        , rj.Manufacturer
        , rj.ArtworkId
        , rj.Price
        , rj.Currency
        , rj.SourceId
        , trs.Name              AS SourceName
        , rj.CreatedDate
        , rj.UpdatedDate
        , CAST(NULL AS datetime) AS MirrorDate
        , rj.CatalogId
        , rj.CountryId
        , rj.Url
        , rj.IsSeenInLastRun
        , CAST(NULL AS varchar(20)) AS MirrorScenario
        /* Single “as of” timestamp for raw side (no mirror EffectiveDate CASE). */
        , rj.UpdatedDate       AS EffectiveDate
        , 'RAW'                 AS DataOrigin
    INTO #TempRawMapped
    FROM RawJoined AS rj WITH (NOLOCK)
    INNER JOIN dbo.tbl_RAW_Source AS trs WITH (NOLOCK)
        ON rj.SourceId = trs.SourceId
    LEFT JOIN #RcmRefExtract AS rcmHit WITH (NOLOCK)
        ON rcmHit.CatalogId = rj.CatalogId
       AND rcmHit.RcmRefExt = rj.RawRefExt
    WHERE NULLIF(rj.RawRefExt, '') IS NOT NULL
      AND (
          rj.RawRefExt = rj.CatRefExt
          OR rcmHit.CatalogId IS NOT NULL
      );

    /* Single stream: raw current row + all mirror history rows per mapping. */

    DROP TABLE IF EXISTS #AllRaw;

    SELECT
          Id
        , ReferenceNo
        , Manufacturer
        , ArtworkId
        , Price
        , Currency
        , SourceId
        , SourceName
        , CreatedDate
        , UpdatedDate
        , MirrorDate
        , MirrorScenario
        , EffectiveDate
        , DataOrigin
        , CatalogId
        , CountryId
        , Url
        , IsSeenInLastRun
    INTO #AllRaw
    FROM #TempRawMapped AS r WITH (NOLOCK)
    UNION ALL
    SELECT
          Id
        , ReferenceNo
        , Manufacturer
        , ArtworkId
        , Price
        , Currency
        , SourceId
        , SourceName
        , CreatedDate
        , UpdatedDate
        , MirrorDate
        , MirrorScenario
        , EffectiveDate
        , DataOrigin
        , CatalogId
        , CountryId
        , Url
        , IsSeenInLastRun
    FROM #TempMirror AS m WITH (NOLOCK);

    /* Require resolvable CurrencyId (active currency dimension) and basic price validity.
       Optional expected currency per SourceId (tbl_sourceManufacturer_mapping.Currency). */
    DROP TABLE IF EXISTS #Filtered;

    SELECT
          ar.*
        , cur.CurrencyId
    INTO #Filtered
    FROM #AllRaw AS ar WITH (NOLOCK)
    INNER JOIN dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
        ON sm.SourceId = ar.SourceId
       AND ISNULL(sm.IsActive, 1) = 1
    LEFT JOIN dbo.tbl_CAT_Currency_d AS cur WITH (NOLOCK)
        ON cur.StatusID = 1
       AND cur.CurrencyName = ar.Currency
    WHERE ar.CountryId IS NOT NULL
      AND ar.Price IS NOT NULL
      AND TRY_CAST(ar.Price AS money) IS NOT NULL
      AND TRY_CAST(ar.Price AS money) > 0
      AND ar.Currency IS NOT NULL
      AND ar.Currency <> ''
      AND ar.EffectiveDate IS NOT NULL
      AND cur.CurrencyId IS NOT NULL
      AND (
          NULLIF(LTRIM(RTRIM(ISNULL(sm.Currency, N''))), N'') IS NULL
          OR UPPER(LTRIM(RTRIM(ISNULL(sm.Currency, N'')))) = UPPER(LTRIM(RTRIM(ISNULL(ar.Currency, N''))))
      );

    /* Chronological row index within (CatalogId, CountryId, CurrencyId). */
    DROP TABLE IF EXISTS #Ranked;

    SELECT
          ROW_NUMBER() OVER (
              PARTITION BY f.CatalogId, f.CountryId, f.CurrencyId
              ORDER BY f.EffectiveDate ASC
          ) AS RowNum
        , f.*
    INTO #Ranked
    FROM #Filtered AS f WITH (NOLOCK);

    /* Attach immediately previous price in the same key partition (for change detection). */
    DROP TABLE IF EXISTS #WithPrevPrice;

    SELECT
          r.*
        , prev.Price AS PrevPrice
    INTO #WithPrevPrice
    FROM #Ranked AS r WITH (NOLOCK)
    LEFT JOIN #Ranked AS prev WITH (NOLOCK)
        ON prev.CatalogId = r.CatalogId
       AND prev.CountryId = r.CountryId
       AND prev.CurrencyId = r.CurrencyId
       AND prev.RowNum = r.RowNum - 1;

    /* Keep first row and any row where price changed vs previous (price-change timeline). */
    DROP TABLE IF EXISTS #PriceChanges;

    SELECT
          w.*
        /* Marks last row in partition (legacy; not used after USD logic removal). */
        , CAST(
              CASE
                  WHEN w.RowNum = MAX(w.RowNum) OVER (
                      PARTITION BY w.CatalogId, w.CountryId, w.CurrencyId
                  )
                  THEN 1
                  ELSE 0
              END
              AS bit
          ) AS IsLatestPrice
    INTO #PriceChanges
    FROM #WithPrevPrice AS w WITH (NOLOCK)
    WHERE w.PrevPrice IS NULL
       OR w.Price <> w.PrevPrice;

    /* -------------------------------------------------------------------------
       CATALOG BASELINE (draft retail, StatusID = 1, IsPrivate = 0, IsVerified = 1):
       latest manufacturer-official row per key. Private (IsPrivate = 1) and non-verified
       (IsVerified = 0) rows are excluded — different streams; not used for % diff or
       duplicate-vs-catalog checks.
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #CatalogLatest;

    SELECT
          x.CatalogID
        , x.CountryId
        , x.CurrencyId
        , x.CreatedAt
        , x.Price
    INTO #CatalogLatest
    FROM (
        SELECT
              rp.CatalogID
            , rp.CountryId
            , rp.CurrencyId
            , rp.CreatedAt
            , rp.Price
            , ROW_NUMBER() OVER (
                  PARTITION BY rp.CatalogID, rp.CountryId, rp.CurrencyId
                  ORDER BY rp.CreatedAt DESC, rp.CatalogRetailPriceID DESC
              ) AS rn
        FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
        WHERE rp.StatusID = 1
          AND ISNULL(rp.IsPrivate, 0) = 0
          AND rp.IsVerified = 1
    ) AS x
    WHERE x.rn = 1;

    CREATE CLUSTERED INDEX CX_CatalogLatest_Key
        ON #CatalogLatest (CatalogID, CountryId, CurrencyId);

    /* -------------------------------------------------------------------------
       EXISTING RETAIL: same CatalogID, CountryId, CurrencyId, Price, calendar day (CreatedAt vs EffectiveDate)
       already persisted (StatusID 1/2/3, IsPrivate = 0) — drop from #PriceChanges before dedup chain.
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #ExistingRetail;

    SELECT DISTINCT
          rp.CatalogID
        , rp.CountryId
        , rp.CurrencyId
        , TRY_CAST(rp.Price AS money) AS Price
        , rp.CreatedAt
    INTO #ExistingRetail
    FROM dbo.tbl_CAT_CatalogRetailPrice_d AS rp WITH (NOLOCK)
    INNER JOIN (
        SELECT DISTINCT
              pc.CatalogId
            , pc.CountryId
            , pc.CurrencyId
        FROM #PriceChanges AS pc WITH (NOLOCK)
    ) AS k
        ON k.CatalogId = rp.CatalogID
       AND k.CountryId = rp.CountryId
       AND k.CurrencyId = rp.CurrencyId
    WHERE ISNULL(rp.IsPrivate, 0) = 0
      AND rp.StatusID IN (CAST(1 AS tinyint), CAST(2 AS tinyint), CAST(3 AS tinyint));

    CREATE CLUSTERED INDEX CX_ExistingRetail
        ON #ExistingRetail (CatalogID, CountryId, CurrencyId, CreatedAt, Price);

    DELETE pc
    FROM #PriceChanges AS pc
    WHERE EXISTS (
            SELECT 1
            FROM #ExistingRetail AS er WITH (NOLOCK)
            WHERE er.CatalogID = pc.CatalogId
              AND er.CountryId = pc.CountryId
              AND er.CurrencyId = pc.CurrencyId
              AND er.Price = TRY_CAST(pc.Price AS money)
              AND CAST(er.CreatedAt AS date) = CAST(pc.EffectiveDate AS date)
        );

    DROP TABLE IF EXISTS #PriceChangesAfterPLS;

    SELECT
          pc.*
    INTO #PriceChangesAfterPLS
    FROM #PriceChanges AS pc WITH (NOLOCK);

    /* -------------------------------------------------------------------------
       UPCOMING BASELINE: keys with no catalog retail yet — latest candidate price
       per (CatalogId, CountryId, CurrencyId) for % diff / outlier (treated as trusted “latest”).
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #UpcomingLatestBaseline;

    SELECT
          z.CatalogId
        , z.CountryId
        , z.CurrencyId
        , TRY_CAST(z.Price AS money) AS BaselinePrice
    INTO #UpcomingLatestBaseline
    FROM (
        SELECT
              pc.CatalogId
            , pc.CountryId
            , pc.CurrencyId
            , pc.Price
            , ROW_NUMBER() OVER (
                  PARTITION BY pc.CatalogId, pc.CountryId, pc.CurrencyId
                  ORDER BY CAST(pc.EffectiveDate AS date) DESC, pc.EffectiveDate DESC, pc.RowNum DESC
              ) AS rn
        FROM #PriceChangesAfterPLS AS pc WITH (NOLOCK)
        LEFT JOIN #CatalogLatest AS cl WITH (NOLOCK)
            ON cl.CatalogID = pc.CatalogId
           AND cl.CountryId = pc.CountryId
           AND cl.CurrencyId = pc.CurrencyId
        WHERE cl.CatalogID IS NULL
    ) AS z
    WHERE z.rn = 1
      AND TRY_CAST(z.Price AS money) IS NOT NULL;

    CREATE CLUSTERED INDEX CX_UpcomingLatestBaseline
        ON #UpcomingLatestBaseline (CatalogId, CountryId, CurrencyId);

    /* -------------------------------------------------------------------------
       THRESHOLD: same currency vs baseline — catalog latest when retail exists, else upcoming latest
       in this run. WouldBeStatus 2 = outlier (|pct| > 50); 1 = normal band.
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #temp_staging;

    SELECT
          pc.CatalogId      AS catalogid
        , TRY_CAST(pc.Price AS money) AS price
        , pc.CurrencyId   AS currencyid
        , pc.CountryId    AS countryid
        , pc.EffectiveDate AS CreatedAT
        , CAST(0 AS bit)  AS isprivate
        /* Baseline for % diff: catalog latest when present, else latest upcoming candidate (same run). */
        , CAST(
              COALESCE(cl.Price, ulb.BaselinePrice) AS money
          ) AS LatestCatalogPrice
        /* Published catalog only — used for dedup; upcoming baseline must not suppress latest insert. */
        , CAST(cl.Price AS money) AS CatalogLatestPrice
        /* NULL when no baseline, zero baseline, or % outside decimal(10,2) (extreme float/raw prices). */
        , CASE
              WHEN COALESCE(cl.Price, ulb.BaselinePrice) IS NULL
                   OR COALESCE(cl.Price, ulb.BaselinePrice) = 0
                  THEN NULL
              ELSE TRY_CAST(
                      ROUND(
                          (
                              (
                                  CAST(pc.Price AS float)
                                  - CAST(COALESCE(cl.Price, ulb.BaselinePrice) AS float)
                              )
                              / NULLIF(CAST(COALESCE(cl.Price, ulb.BaselinePrice) AS float), 0)
                          ) * 100.0,
                          2
                      ) AS decimal(10, 2)
                  )
          END AS PercDiffFromLatestCatalog
        /* 2 = |% diff vs baseline| > 50 (review); 1 = within band or no baseline. */
        , CAST(
              CASE
                  WHEN COALESCE(cl.Price, ulb.BaselinePrice) IS NOT NULL
                       AND COALESCE(cl.Price, ulb.BaselinePrice) <> 0
                       AND ABS(
                           (
                               (
                                   CAST(pc.Price AS float)
                                   - CAST(COALESCE(cl.Price, ulb.BaselinePrice) AS float)
                               )
                               / NULLIF(CAST(COALESCE(cl.Price, ulb.BaselinePrice) AS float), 0)
                           ) * 100.0
                       ) > 50.0
                      THEN 2
                  ELSE 1
              END AS tinyint
          ) AS WouldBeStatus
    INTO #temp_staging
    FROM #PriceChangesAfterPLS AS pc WITH (NOLOCK)
    LEFT JOIN #CatalogLatest AS cl WITH (NOLOCK)
        ON cl.CatalogID = pc.CatalogId
       AND cl.CountryId = pc.CountryId
       AND cl.CurrencyId = pc.CurrencyId
    LEFT JOIN #UpcomingLatestBaseline AS ulb WITH (NOLOCK)
        ON ulb.CatalogId = pc.CatalogId
       AND ulb.CountryId = pc.CountryId
       AND ulb.CurrencyId = pc.CurrencyId;

    /* Same calendar day: keep latest timestamp first (rank 1 = winner for that day). */
    DROP TABLE IF EXISTS #temp_staging_ranked;

    SELECT
          t.catalogid
        , t.price
        , t.currencyid
        , t.countryid
        , t.CreatedAT
        , t.isprivate
        , t.LatestCatalogPrice
        , t.CatalogLatestPrice
        , t.PercDiffFromLatestCatalog
        , t.WouldBeStatus
        , ROW_NUMBER() OVER (
              PARTITION BY
                  t.catalogid
                , t.countryid
                , t.currencyid
                , CAST(t.CreatedAT AS date)
              ORDER BY t.CreatedAT DESC
          ) AS SameDayRank
    INTO #temp_staging_ranked
    FROM #temp_staging AS t WITH (NOLOCK);

    /* -------------------------------------------------------------------------
       DEDUP CHAIN (status-1 only): prior “normal” candidate price in this run.
       Rows that would be Status 2 are skipped when walking backward (invisible).
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #SameDayOne;

    /* SameDayRank = 1 rows only; PrevStatus1PriceInRun = last earlier row with WouldBeStatus = 1. */
    SELECT
          r.catalogid
        , r.price
        , r.currencyid
        , r.countryid
        , r.CreatedAT
        , r.isprivate
        , r.LatestCatalogPrice
        , r.CatalogLatestPrice
        , r.PercDiffFromLatestCatalog
        , r.WouldBeStatus
        , r.SameDayRank
        , prev_s1.price AS PrevStatus1PriceInRun
    INTO #SameDayOne
    FROM #temp_staging_ranked AS r WITH (NOLOCK)
    OUTER APPLY (
        /* Newest prior same-day-primary row whose WouldBeStatus recomputes to 1 (same % rule as s). */
        SELECT TOP (1)
              s.price
        FROM #temp_staging_ranked AS s WITH (NOLOCK)
        WHERE s.catalogid = r.catalogid
          AND s.countryid = r.countryid
          AND s.currencyid = r.currencyid
          AND s.SameDayRank = 1
          AND s.CreatedAT < r.CreatedAT
          AND CAST(
                  CASE
                      WHEN s.LatestCatalogPrice IS NOT NULL
                           AND s.LatestCatalogPrice <> 0
                           AND ABS(
                               (
                                   (CAST(s.price AS float) - CAST(s.LatestCatalogPrice AS float))
                                   / NULLIF(CAST(s.LatestCatalogPrice AS float), 0)
                               ) * 100.0
                           ) > 50.0
                          THEN 2
                      ELSE 1
                  END AS tinyint
              ) = 1
        ORDER BY s.CreatedAT DESC
    ) AS prev_s1
    WHERE r.SameDayRank = 1;

    /* KeepAfterPass1: only rank-1 per day. KeepInFinal: drop status-1 only on consecutive dup vs prev status-1; keep all status-2. */
    DROP TABLE IF EXISTS #temp;

    SELECT
          r.catalogid
        , r.price
        , r.currencyid
        , r.countryid
        , r.CreatedAT
        , r.isprivate
        , r.SameDayRank
        , r.LatestCatalogPrice
        , r.CatalogLatestPrice
        , r.PercDiffFromLatestCatalog
        , r.WouldBeStatus
        , CAST(CASE WHEN r.SameDayRank = 1 THEN 1 ELSE 0 END AS bit) AS KeepAfterPass1
        , sd.PrevStatus1PriceInRun
        , CAST(
              CASE
                  WHEN r.SameDayRank <> 1 THEN 0
                  WHEN r.WouldBeStatus = 2 THEN 1
                  WHEN r.WouldBeStatus = 1
                       AND r.price = sd.PrevStatus1PriceInRun
                      THEN 0
                  ELSE 1
              END
              AS bit
          ) AS KeepInFinal
        /* Insert status: catalog-price repeat after an unreviewed outlier ? 2 until outlier is promoted. */
        , CAST(
              CASE
                  WHEN r.WouldBeStatus = 2 THEN 2
                  WHEN r.WouldBeStatus = 1
                       AND r.CatalogLatestPrice IS NOT NULL
                       AND r.price = r.CatalogLatestPrice
                       AND sd.PrevStatus1PriceInRun IS NULL
                       AND EXISTS (
                             SELECT 1
                             FROM #temp_staging_ranked AS o WITH (NOLOCK)
                             WHERE o.catalogid = r.catalogid
                               AND o.countryid = r.countryid
                               AND o.currencyid = r.currencyid
                               AND o.SameDayRank = 1
                               AND o.WouldBeStatus = 2
                               AND o.CreatedAT < r.CreatedAT
                           )
                      THEN 2
                  ELSE r.WouldBeStatus
              END
              AS tinyint
          ) AS FinalStatusID
    INTO #temp
    FROM #temp_staging_ranked AS r WITH (NOLOCK)
    LEFT JOIN #SameDayOne AS sd WITH (NOLOCK)
        ON sd.catalogid = r.catalogid
       AND sd.countryid = r.countryid
       AND sd.currencyid = r.currencyid
       AND sd.CreatedAT = r.CreatedAT
       AND sd.SameDayRank = r.SameDayRank;

    /* -------------------------------------------------------------------------
       MERGED TIMELINE: anchor with latest verified public catalog row (Src=CAT, IsVerified = 1),
       then candidates (Src=CAND).
       SrcSort orders CAT before CAND on same CreatedAt for stable LAG.
       ------------------------------------------------------------------------- */

    DROP TABLE IF EXISTS #MergedTimeline;

    SELECT
          cl.CatalogID      AS catalogid
        , cl.Price        AS price
        , cl.CurrencyId   AS currencyid
        , cl.CountryId    AS countryid
        , cl.CreatedAt    AS CreatedAT
        , CAST('CAT' AS varchar(3)) AS Src
        /* CAT sorts before CAND when CreatedAt ties (stable LAG). */
        , CAST(0 AS tinyint) AS SrcSort
        , CAST(NULL AS tinyint) AS InsStatusID
        , CAST(NULL AS decimal(10, 2)) AS PercDiffFromLatestCatalog
    INTO #MergedTimeline
    FROM #CatalogLatest AS cl WITH (NOLOCK)

    UNION ALL

    SELECT
          t.catalogid
        , t.price
        , t.currencyid
        , t.countryid
        , t.CreatedAT
        , 'CAND'
        , 1
        , t.FinalStatusID
        , t.PercDiffFromLatestCatalog
    FROM #temp AS t WITH (NOLOCK)
    /* Only rows that survived same-day + consecutive-dup rules. */
    WHERE t.KeepInFinal = 1;

    /* LAG across CAT+CAND: enforce “new point in time” and “price changed vs merged predecessor”. */
    DROP TABLE IF EXISTS #FinalInserts;

    SELECT
          m.catalogid
        , m.price
        , m.currencyid
        , m.countryid
        , m.CreatedAT
        , m.Src
        , m.InsStatusID
        , m.PercDiffFromLatestCatalog
        , LAG(m.CreatedAT) OVER (
              PARTITION BY m.catalogid, m.countryid, m.currencyid
              ORDER BY m.CreatedAT ASC, m.SrcSort ASC
          ) AS PrevCreatedAt
        , LAG(m.price) OVER (
              PARTITION BY m.catalogid, m.countryid, m.currencyid
              ORDER BY m.CreatedAt ASC, m.SrcSort ASC
          ) AS PrevPriceLag
    INTO #FinalInserts
    FROM #MergedTimeline AS m WITH (NOLOCK);

    /* Single row set for preview and INSERT (identical filters). */
    DROP TABLE IF EXISTS #RowsToInsert;

    SELECT
          f.catalogid
        , f.price
        , f.currencyid
        , f.countryid
        , f.CreatedAT
        , ISNULL(f.InsStatusID, CAST(1 AS tinyint)) AS StatusID
        , f.PercDiffFromLatestCatalog
    INTO #RowsToInsert
    FROM #FinalInserts AS f WITH (NOLOCK)
    WHERE f.Src = 'CAND'
      /* Must advance calendar day vs previous point on merged timeline (CAT or CAND). */
      AND (
              f.PrevCreatedAt IS NULL
              OR CAST(f.CreatedAt AS date) > CAST(f.PrevCreatedAt AS date)
          )
      /* Must differ from immediate predecessor price on merged timeline. */
      AND (
              f.PrevPriceLag IS NULL
              OR f.price <> f.PrevPriceLag
          );

    IF @DryRun = 1
    BEGIN
        SELECT
              @LastMaxRawCatalogTransactionId AS LastMaxRawCatalogTransactionIdUsed;

        SELECT
              r.catalogid     AS CatalogID
            , r.price         AS Price
            , r.currencyid    AS CurrencyId
            , r.countryid     AS CountryId
            , r.CreatedAT     AS CreatedAt
            , r.StatusID
            , r.PercDiffFromLatestCatalog
        FROM #RowsToInsert AS r WITH (NOLOCK)
        ORDER BY
              r.catalogid
            , r.countryid
            , r.currencyid
            , r.CreatedAT;

        SET @InsertedRowCount = (SELECT COUNT(*) FROM #RowsToInsert AS x WITH (NOLOCK));

        RETURN;
    END;

    DECLARE @InsertBatchTransactionId bigint;

    SET @RunCompletedAt = SYSUTCDATETIME();

    SELECT
        @NewMaxRawCatalogTransactionId = MAX(trc.TransactionId)
    FROM dbo.tbl_RAW_Catalog AS trc WITH (NOLOCK)
    WHERE trc.TransactionId IS NOT NULL;

    IF @NewMaxRawCatalogTransactionId IS NULL
        SET @NewMaxRawCatalogTransactionId = @LastMaxRawCatalogTransactionId;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.tblTransaction (TransactionTypeID, UserID, CreatedDate)
        VALUES (1, 1, GETDATE());

        SET @InsertBatchTransactionId = SCOPE_IDENTITY();

        INSERT INTO dbo.tbl_CAT_CatalogRetailPrice_d (
              CatalogID
            , Price
            , CurrencyId
            , CountryId
            , CreatedAt
            , StatusID
            , TransactionId
            , IsPrivate
            , IsSeenInLastRun
            , PriceLastSeenDate
            , IsVerified
        )
        SELECT
              r.catalogid
            , r.price
            , r.currencyid
            , r.countryid
            , r.CreatedAT
            , r.StatusID
            , @InsertBatchTransactionId
            , CAST(0 AS bit)
            , CAST(0 AS tinyint)
            , CAST(NULL AS datetime2(3))
            , CAST(1 AS bit) /* IsVerified = 1: manufacturer official website */
        FROM #RowsToInsert AS r WITH (NOLOCK);

        SET @InsertedRowCount = @@ROWCOUNT;

        INSERT INTO dbo.tbl_cat_RetailPrice_SyncLog (
              RunCompletedAt
            , MaxRawCatalogTransactionId
            , RowsInserted
            , Status
            , ErrorMessage
        )
        VALUES (
              @RunCompletedAt
            , @NewMaxRawCatalogTransactionId
            , @InsertedRowCount
            , N'Success'
            , NULL
        );

        COMMIT TRANSACTION;

        EXEC dbo.sp_UpdateMap_PriceLastSeen;
        EXEC dbo.sp_Sync_PriceLastSeenDate_isSeenInLastRun @UserId = 1;
        EXEC dbo.sp_Sync_RefProductionStatus_FromMapping @UserId = 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @InsertedRowCount = 0;
        END;

        SET @RunCompletedAt = SYSUTCDATETIME();
        SET @LogStatus = N'Failed';
        SET @LogErrorMessage = ERROR_MESSAGE();

        /* Failed run: do not advance watermark (retail inserts rolled back). */
        SET @NewMaxRawCatalogTransactionId = @LastMaxRawCatalogTransactionId;

        INSERT INTO dbo.tbl_cat_RetailPrice_SyncLog (
              RunCompletedAt
            , MaxRawCatalogTransactionId
            , RowsInserted
            , Status
            , ErrorMessage
        )
        VALUES (
              @RunCompletedAt
            , @NewMaxRawCatalogTransactionId
            , 0
            , @LogStatus
            , @LogErrorMessage
        );

        THROW;
    END CATCH;

END;
GO
