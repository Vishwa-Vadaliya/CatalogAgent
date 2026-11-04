/*
================================================================================
 Reference production status - 01 schema + Reconfigured flag (2026-10-29)
================================================================================
 Database : EWMaster (MasterDB)
 Order    : run this script FIRST, then deploy
              1. dbo.sp_map_rawCatalog_catalogCountry      (maps official sources without a location)
              2. dbo.sp_update_CatalogRetailPrice_FromMapping (+ sp_Insert_...)  (skip map rows without a country)
              3. dbo.sp_Sync_RefProductionStatus_FromMapping (new)

 Step 1  tbl_MAP_RawCatalog_CatalogCountry.CountryId  bigint NOT NULL -> NULL
         (official source with no CatCountryLocationId -> map row with CountryId NULL; used for reference
          production status only, the retail SPs skip it). The FK to tbl_CAT_Country_d and the filtered unique
          index (CatalogId, CountryId) depend on the column, so both are dropped and recreated unchanged.
 Step 2  tbl_sourceManufacturer_mapping.IsReconfigured bit NOT NULL DEFAULT 0 (new column).
 Step 3  IsReconfigured = 1 for the sources marked Reconfigured = TRUE in the "Master Collection" sheet
         (tabs "Manufacturer (Important Ones)" and "Manufacturer (Others)"), read 2026-10-29.
         Keep this column in line with the sheet whenever a source is (re)configured or paused.

 Each step can be re-run safely.
================================================================================
*/

USE [EWMaster];
GO

------------------------------------------------------------
-- Step 1. Map CountryId -> NULL
------------------------------------------------------------
SET XACT_ABORT ON;
GO

IF EXISTS (
    SELECT 1
    FROM sys.columns AS c
    WHERE c.object_id = OBJECT_ID(N'dbo.tbl_MAP_RawCatalog_CatalogCountry')
      AND c.name = N'CountryId'
      AND c.is_nullable = 0
)
BEGIN
    BEGIN TRAN;

    DROP INDEX [UQ_MAP_RCC_CatalogId_CountryId_Active] ON [dbo].[tbl_MAP_RawCatalog_CatalogCountry];

    ALTER TABLE [dbo].[tbl_MAP_RawCatalog_CatalogCountry] DROP CONSTRAINT [FK_MAP_RCC_tbl_CAT_Country_d];

    ALTER TABLE [dbo].[tbl_MAP_RawCatalog_CatalogCountry] ALTER COLUMN [CountryId] bigint NULL;

    ALTER TABLE [dbo].[tbl_MAP_RawCatalog_CatalogCountry] WITH CHECK
        ADD CONSTRAINT [FK_MAP_RCC_tbl_CAT_Country_d] FOREIGN KEY ([CountryId])
        REFERENCES [dbo].[tbl_CAT_Country_d] ([CountryId]);

    CREATE UNIQUE NONCLUSTERED INDEX [UQ_MAP_RCC_CatalogId_CountryId_Active]
        ON [dbo].[tbl_MAP_RawCatalog_CatalogCountry] ([CatalogId] ASC, [CountryId] ASC)
        WHERE ([IsDeleted] = (0));

    COMMIT TRAN;
END;
GO

SELECT c.name, c.is_nullable
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.tbl_MAP_RawCatalog_CatalogCountry')
  AND c.name = N'CountryId';
GO

------------------------------------------------------------
-- Step 2. IsReconfigured column on source mapping
------------------------------------------------------------
IF COL_LENGTH(N'dbo.tbl_sourceManufacturer_mapping', N'IsReconfigured') IS NULL
BEGIN
    ALTER TABLE [dbo].[tbl_sourceManufacturer_mapping]
        ADD [IsReconfigured] bit NOT NULL
            CONSTRAINT [DF_sourceManufacturer_mapping_IsReconfigured] DEFAULT ((0));
END;
GO

------------------------------------------------------------
-- Step 3. Fill IsReconfigured from the Master Collection sheet
------------------------------------------------------------
DROP TABLE IF EXISTS #Reconfigured;
SELECT v.SourceId
INTO #Reconfigured
FROM (VALUES
    /* Rolex */ (13987), (15032), (15033), (15034), (15035), (15036), (15037), (15038), (15039), (15040), (15041), (15042), (15043),
    /* Omega */ (14040), (14799), (14800), (14801),
    /* Cartier */ (13996), (14161), (14162), (14163), (14164), (14878), (14879), (14880), (14881), (14882), (14883),
    /* Patek Philippe */ (14042), (15049), (15050), (15051), (15052), (15053), (15054), (15055), (15056), (15057), (15984), (15985),
    /* Tag Heuer */ (13981), (14859), (14860), (14861), (14862), (14863), (14864), (14865), (14866), (14867), (14868), (14869),
    /* Breitling (CN 14814 paused) */ (13982), (14804), (14805), (14806), (14807), (14808), (14809), (14810), (14811), (14812), (14813), (14815),
    /* Jaeger-LeCoultre */ (13983), (14818), (14819), (14820), (14821), (14822), (14823), (14824), (14825), (14826),
    /* IWC */ (13986), (14847), (14848), (14849), (14850), (14851), (14852), (14853), (14854),
    /* Hublot */ (14050), (14893), (14894), (14895), (14896), (14897), (14898), (14899), (14900), (14901), (14902),
    /* Audemars Piguet */ (13989), (15096), (15097), (15098), (15099), (15100), (15101), (15102), (15103), (15104), (15105),
    /* AP Chronicles (not official; ignored by the map SP) */ (15297),
    /* Vacheron Constantin (CA 14911 paused) */ (13994), (14905), (14906), (14907), (14908), (14909), (14910), (14912), (14913), (14914), (14915), (14916),
    /* A. Lange & Sohne */ (13995), (14920), (14921), (14922), (14923), (14924), (14925), (14926), (14927),
    /* Baume & Mercier */ (14062), (14941), (14942), (14943), (14944), (14945),
    /* Panerai */ (13997), (14960), (14961), (14962), (14963), (14964),
    /* Longines */ (13998), (14969), (14970), (14971), (14972),
    /* Tudor (CN 15378 removed) */ (14052), (15370), (15371), (15372), (15373), (15374), (15375), (15376), (15377), (15379),
    /* Piaget */ (13999), (14949), (14950), (14951), (14952), (14953), (14954), (14955), (14956),
    /* Zenith */ (14065), (15158), (15159), (15160), (15161), (15162), (15163),
    /* Blancpain */ (14046), (15113), (15114), (15115), (15116), (15117), (15118), (15119), (15120), (15121), (15122), (15123), (15124),
    /* Grand Seiko */ (14048), (14986), (14987), (14988),
    /* Chopard */ (14056), (14992), (14993), (14994), (14995),
    /* Oris */ (14167), (15071), (15072), (15073), (15074), (15075), (15076), (15077), (15078), (15079), (15080), (15081), (15082),
    /* Hamilton */ (14069), (14996), (14997), (14998), (14999), (15000),
    /* Tissot */ (14071), (14976), (14977), (14978), (14979),
    /* Mido */ (14054), (15061), (15062), (15063),
    /* Montblanc */ (14061), (15001), (15002), (15003), (15004), (15005),
    /* Ebel */ (14058), (15185), (15186), (15187), (15188), (15189),
    /* Maurice Lacroix */ (14063), (15009), (15010), (15011), (15012), (15013), (15014), (15015), (15016),
    /* Norqain */ (14174), (15325), (15326), (15327), (15328), (15329), (15330), (15331), (15332), (15333), (15334),
    /* Bell & Ross */ (16717), (16718), (16719), (16720), (16721), (16722), (16723), (16724), (16725), (16726), (16727), (16728), (16729),
    /* Seiko */ (14047), (14982), (14983), (14984),
    /* Revue Thommen */ (14082), (15403), (15404), (15405), (15406),
    /* F.P. Journe */ (14224),
    /* Richard Mille */ (14178),
    /* Laurent Ferrier */ (14076),
    /* Parmigiani Fleurier (status never touched) */ (15983),
    /* Glycine */ (14068),
    /* Doxa */ (14070),
    /* Ball */ (14075),
    /* Speake-Marin */ (14081),
    /* Urwerk */ (14166),
    /* Eberhard & Co */ (14171),
    /* Romain Jerome */ (14180),
    /* Junghans */ (14187),
    /* Nomos Glashutte */ (14189),
    /* Eterna */ (14191),
    /* Marvin */ (14192),
    /* Reconvilier */ (14196),
    /* Roger Dubuis */ (14199),
    /* H. Moser & Cie. */ (17168)
) AS v (SourceId);

-- 3a. Preview: sheet sources missing from tbl_sourceManufacturer_mapping (expected: none)
SELECT r.SourceId AS SheetSourceIdNotInSourceMapping
FROM #Reconfigured AS r
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
    WHERE sm.SourceId = r.SourceId
);

-- 3b. Set the flag (1 for sheet TRUE, 0 for every other source)
UPDATE sm
SET sm.IsReconfigured = CASE WHEN r.SourceId IS NOT NULL THEN 1 ELSE 0 END,
    sm.UpdatedDate = GETDATE()
FROM dbo.tbl_sourceManufacturer_mapping AS sm
LEFT JOIN #Reconfigured AS r
    ON r.SourceId = sm.SourceId
WHERE sm.IsReconfigured <> CASE WHEN r.SourceId IS NOT NULL THEN 1 ELSE 0 END;

-- 3c. Check: Reconfigured sources per brand
SELECT
      sm.CatManufacturerId
    , sm.CatManufacturerName
    , COUNT(*) AS Sources
    , SUM(CASE WHEN sm.IsReconfigured = 1 THEN 1 ELSE 0 END) AS ReconfiguredSources
    , SUM(CASE WHEN sm.IsReconfigured = 1
                AND UPPER(ISNULL(sm.CatSourceName, N'')) LIKE N'%OFFICIAL%' THEN 1 ELSE 0 END) AS ReconfiguredOfficialSources
FROM dbo.tbl_sourceManufacturer_mapping AS sm WITH (NOLOCK)
WHERE sm.CatManufacturerId IS NOT NULL
GROUP BY sm.CatManufacturerId, sm.CatManufacturerName
HAVING SUM(CASE WHEN sm.IsReconfigured = 1 THEN 1 ELSE 0 END) > 0
ORDER BY sm.CatManufacturerName;

DROP TABLE IF EXISTS #Reconfigured;
GO
