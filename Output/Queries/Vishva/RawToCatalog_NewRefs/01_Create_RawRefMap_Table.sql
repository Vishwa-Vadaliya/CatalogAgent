/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 01: mapping table + indexes
===================================================================================
Purpose : tbl_CAT_RawRefMap holds ONE ROW PER OFFICIAL tbl_RAW_Catalog ROW with the
          CatalogId it maps to (NULL = not mapped yet). Later steps scan only the rows
          where CatalogId IS NULL.
DB      : EWMaster
Run     : hand-run in SSMS. Each GO batch can be run alone. Re-runnable (table is only
          created if missing, indexes only if missing). Nothing here reads or changes
          existing data. The comma list and the coverage counts are NOT views: run
          Check_Coverage_And_ByCatalog.sql (temp tables) to see them.

Confirmed by Vishva (see Documents/RawToCatalog_NewRefs_Requirements.md):
  - Official sources only: tbl_sourceManufacturer_mapping, IsActive NULL or 1,
    CatSourceName contains 'OFFICIAL' (widened later, see script 02).
  - Match on the normalized reference number only (RefKey, filled by the later match step).
  - MapStatus: Unmapped, Matched, New, Created, Rejected.
===================================================================================
*/

USE [EWMaster]
GO

------------------------------------------------------------
-- 1. Mapping table: one row per official raw row
--    RawCatalogId -> tbl_RAW_Catalog.Id
--    RefKey       -> normalized reference (fn_ExtractNumbersAndAlphabets after cleaning); filled by the match step
--    CatalogId    -> tbl_CAT_Catalog_d.CatalogId, NULL until mapped
------------------------------------------------------------
IF OBJECT_ID(N'dbo.tbl_CAT_RawRefMap', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tbl_CAT_RawRefMap
    (
        RawCatalogId   BIGINT        NOT NULL,
        SourceId       INT           NOT NULL,
        ManufacturerId INT           NOT NULL,
        ReferenceRaw   NVARCHAR(500) NULL,
        ReferenceClean NVARCHAR(500) NULL,
        RefKey         NVARCHAR(500) NULL,
        CatalogId      INT           NULL,
        MapStatus      VARCHAR(20)   NOT NULL CONSTRAINT DF_tbl_CAT_RawRefMap_MapStatus DEFAULT ('Unmapped'),
        MapNote        NVARCHAR(500) NULL,
        MapDate        DATETIME      NULL,
        CreatedDate    DATETIME      NOT NULL CONSTRAINT DF_tbl_CAT_RawRefMap_CreatedDate DEFAULT (GETDATE()),
        UpdatedDate    DATETIME      NULL,
        CONSTRAINT PK_tbl_CAT_RawRefMap PRIMARY KEY CLUSTERED (RawCatalogId),
        CONSTRAINT CK_tbl_CAT_RawRefMap_MapStatus CHECK (MapStatus IN ('Unmapped', 'Matched', 'New', 'Created', 'Rejected'))
    );
END
GO

------------------------------------------------------------
-- 2. Indexes on the mapping table
--    IX_..._Catalog  : the comma list and coverage counts (rows that have a CatalogId)
--    IX_..._RefKey   : step 2 / step 3 grouping by manufacturer + normalized ref
--    IX_..._Status   : finding the work set (CatalogId IS NULL / MapStatus)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefMap_Catalog' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefMap'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefMap_Catalog
        ON dbo.tbl_CAT_RawRefMap (CatalogId) INCLUDE (RawCatalogId, ManufacturerId, SourceId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefMap_RefKey' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefMap'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefMap_RefKey
        ON dbo.tbl_CAT_RawRefMap (ManufacturerId, RefKey) INCLUDE (RawCatalogId, CatalogId, MapStatus);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_tbl_CAT_RawRefMap_Status' AND object_id = OBJECT_ID(N'dbo.tbl_CAT_RawRefMap'))
    CREATE NONCLUSTERED INDEX IX_tbl_CAT_RawRefMap_Status
        ON dbo.tbl_CAT_RawRefMap (MapStatus, CatalogId) INCLUDE (RawCatalogId, ManufacturerId);
GO
