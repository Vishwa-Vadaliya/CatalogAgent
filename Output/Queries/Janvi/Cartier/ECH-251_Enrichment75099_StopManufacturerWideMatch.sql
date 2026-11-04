------------------------------------------------------------------------------------------
-- ECH-251 — Cartier Reference Enrichment 75099 has an incorrect reference image and is
-- wrongly matched to watches that don't actually look like it (manufacturer-wide image
-- match, EnrichmentTypeId 5, isn't trained on this atypical-looking Cartier piece).
--
-- Fix: set EnrichmentSimilarityScore = 2 on the DRAFT catalog row (tbl_CAT_Catalog_d)
-- behind this enrichment.
--   NULL = normal flow (no override)
--   a decimal (e.g. 0.80) = threshold -- manufacturer-wide match only fires at/above it
--   2 = sentinel outside the 0-1 score range -- always fails the threshold, so
--       manufacturer-wide image match never fires again for this catalog entry
-- Draft only -- the published tbl_CAT_Catalog row is not updated here; publishing
-- propagates draft -> publish automatically, so no separate publish-side update is needed.
-- Already-mismatched watches don't need manual unassignment -- they self-correct on the
-- next enrichment sync once this is in place (confirmed with Janvi).
-- DB: EWMaster (MasterDB). Never run directly -- hand to the user to execute.
-- No sp_PublishAllDataNew call here on purpose -- the user copies these scripts and runs
-- them directly in the DB; publish is a separate, deliberate step they trigger themselves.
------------------------------------------------------------------------------------------

------------------------------------------------------------
-- 1. Find the CatalogId behind ReferenceEnrichmentId 75099
--    sp_Get_CatalogDetails joins EveryWatch.dbo.tbl_RE_ReferenceEnrichment
--    on CatalogId internally when @EnrichmentIds is passed.
--    @TempTableName must be a GLOBAL temp table (## prefix) -- the SP writes
--    its result via dynamic SQL (sp_executesql), whose own batch scope means
--    a local #temp table would not survive back to this session.
------------------------------------------------------------
IF OBJECT_ID('tempdb..##ECH251_CatalogDetails') IS NOT NULL DROP TABLE ##ECH251_CatalogDetails;
EXEC dbo.sp_Get_CatalogDetails
    @EnrichmentIds = '75099',
    @TempTableName = '##ECH251_CatalogDetails';

-- Review: confirm this is the Cartier catalog row from the ticket (check
-- PrimaryImageURL / ManufacturerName / ReferenceNumber against the enrichment).
SELECT * FROM ##ECH251_CatalogDetails;

------------------------------------------------------------
-- 2. Preview -- the catalog row(s) about to be updated, read from the
--    global temp table from step 1 so this step can be re-run on its own
------------------------------------------------------------
SELECT
    c.CatalogId,
    c.ReferenceNumber,
    c.EnrichmentSimilarityScore AS CurrentScore,
    2 AS NewScore
FROM tbl_CAT_Catalog_d AS c WITH (NOLOCK)
WHERE c.CatalogId IN (SELECT DISTINCT CatalogId FROM ##ECH251_CatalogDetails);

------------------------------------------------------------
-- 3. New TransactionID for this update (2 = Update)
------------------------------------------------------------
DECLARE @NewTransactionID BIGINT;
EXEC dbo.sp_Create_Transaction @TransactionTypeID = 2, @OutTransactionID = @NewTransactionID OUTPUT;   -- 2 = Update

-- BEGIN TRAN;

UPDATE dbo.tbl_CAT_Catalog_d
SET EnrichmentSimilarityScore = 2,
    TransactionID = @NewTransactionID
WHERE CatalogId IN (SELECT DISTINCT CatalogId FROM ##ECH251_CatalogDetails);

-- COMMIT;
-- ROLLBACK;
