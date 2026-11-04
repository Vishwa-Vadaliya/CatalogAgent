------------------------------------------------------------
-- Cartier: catalog details (one row per catalog)
-- DB: EWMaster (Catalog DB).
-- Uses dbo.sp_Get_CatalogDetails, which returns all catalog fields from the draft
-- tables (tbl_CAT_Catalog_d + lookups): CatalogId, EnrichmentId, ReferenceNumber,
-- EnrichmentRefName, Model, Edition, Manufacturer, EntityType, ParentCatalogId,
-- dial color / case material / strap / bezel / etc. (comma-separated),
-- primary + secondary image URLs, ProductionStatus, StatusID, CreatedDate, UpdatedDate...
-- Scope: catalog StatusID IN (1, 2) = Active + Draft (the SP's built-in filter).
-- Manufacturer match: ManufacturerName LIKE '%Cartier%' (the SP's built-in match).
------------------------------------------------------------

------------------------------------------------------------
-- 1. Load Cartier catalog details into a global temp table
--    (global ## so it survives the SP's dynamic SQL and can be re-read on its own)
------------------------------------------------------------
EXEC dbo.sp_Get_CatalogDetails
    @ManufacturerName = 'Cartier',
    @TempTableName    = '##CartierCatalogDetails';

------------------------------------------------------------
-- 2. Result: Cartier catalog details
------------------------------------------------------------
SELECT *
FROM ##CartierCatalogDetails
ORDER BY EntityType DESC, ReferenceNumber;
