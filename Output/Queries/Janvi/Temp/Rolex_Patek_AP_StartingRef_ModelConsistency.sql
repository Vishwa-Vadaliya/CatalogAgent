/*
    Purpose: For Rolex, Patek Philippe and Audemars Piguet, active rows in the
    draft catalog table (tbl_CAT_Catalog_d, StatusID = 1) with EntityType =
    'Watch', extract the "starting ref" (the leading digit run of
    ReferenceNumber, e.g. 116710BLNR -> 116710, 5711/1A-010 -> 5711). Group by
    starting ref and list the distinct ModelId(s) in that group.

    If a starting-ref group has more than one distinct ModelId, check whether
    the matching EntityType = 'PartialReference' row for that same starting
    ref has a ModelId assigned.

    StatusID (tbl_CAT_Catalog_d): 1 = Active, 2 = Draft, 3 = Deleted.

    DB: EWMaster (MasterDB), draft/working table tbl_CAT_Catalog_d.
    Run from EWMaster.

    How to use:
    1) Run steps 1-5 in order (each is independent after the earlier temp
       tables exist).
    2) Step 6 = count of cases (PartialReference has a model assigned despite
       its Watch children disagreeing on model).
    3) Step 7 = detail: every starting-ref group with more than one model,
       its PartialReference row (if any), its ModelId, and case status.
*/

------------------------------------------------------------
-- 1. Target manufacturers (draft side)
--    Rolex, Patek Philippe exact match; Audemars Piguet by LIKE per
--    Knowledge/EW_DB_Knowledge.md convention.
------------------------------------------------------------
DROP TABLE IF EXISTS #TargetManufacturers;

SELECT
    man.ManufacturerId,
    man.ManufacturerName
INTO #TargetManufacturers
FROM dbo.tbl_CAT_Manufacturer_d AS man WITH (NOLOCK)
WHERE man.ManufacturerName IN ('Rolex', 'Patek Philippe')
    OR man.ManufacturerName LIKE 'Audemars Piguet%';

------------------------------------------------------------
-- 2. Active draft catalog rows (StatusID = 1) for these manufacturers,
--    with StartingRef = leading run of digits in ReferenceNumber
--    (PATINDEX finds the first non-digit char; 0 = whole string is digits).
------------------------------------------------------------
DROP TABLE IF EXISTS #ActiveCatalog;

SELECT
    cat.CatalogId,
    tm.ManufacturerId,
    tm.ManufacturerName,
    cat.ReferenceNumber,
    cat.EntityType,
    cat.ModelId,
    CASE
        WHEN PATINDEX('%[^0-9]%', cat.ReferenceNumber) = 0 THEN cat.ReferenceNumber
        WHEN PATINDEX('%[^0-9]%', cat.ReferenceNumber) = 1 THEN NULL -- no leading digit at all
        ELSE LEFT(cat.ReferenceNumber, PATINDEX('%[^0-9]%', cat.ReferenceNumber) - 1)
    END AS StartingRef
INTO #ActiveCatalog
FROM dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
INNER JOIN #TargetManufacturers AS tm
    ON tm.ManufacturerId = cat.ManufacturerId
WHERE cat.StatusID = 1 -- Active
    AND cat.ReferenceNumber IS NOT NULL;

CREATE INDEX IX_ActiveCatalog_Group ON #ActiveCatalog (ManufacturerId, StartingRef, EntityType);

------------------------------------------------------------
-- 3. Distinct ModelId per (Manufacturer, StartingRef) among EntityType = 'Watch'
--    rows only, excluding NULL ModelId.
------------------------------------------------------------
DROP TABLE IF EXISTS #DistinctWatchModels;

SELECT DISTINCT
    ac.ManufacturerId,
    ac.ManufacturerName,
    ac.StartingRef,
    ac.ModelId
INTO #DistinctWatchModels
FROM #ActiveCatalog AS ac
WHERE ac.EntityType = 'Watch'
    AND ac.StartingRef IS NOT NULL
    AND ac.ModelId IS NOT NULL;

CREATE INDEX IX_DistinctWatchModels_Group ON #DistinctWatchModels (ManufacturerId, StartingRef);

------------------------------------------------------------
-- 4. Starting-ref groups where Watch rows have more than one distinct model.
------------------------------------------------------------
DROP TABLE IF EXISTS #InconsistentGroups;

SELECT
    dwm.ManufacturerId,
    dwm.ManufacturerName,
    dwm.StartingRef,
    COUNT(*) AS DistinctWatchModelCount,
    STRING_AGG(CAST(mdl.ModelName AS NVARCHAR(MAX)), ', ') AS WatchModelNames
INTO #InconsistentGroups
FROM #DistinctWatchModels AS dwm
LEFT JOIN dbo.tbl_CAT_Model_d AS mdl WITH (NOLOCK)
    ON mdl.ModelId = dwm.ModelId
GROUP BY dwm.ManufacturerId, dwm.ManufacturerName, dwm.StartingRef
HAVING COUNT(*) > 1;

------------------------------------------------------------
-- 5. PartialReference row(s) for each inconsistent starting-ref group
--    (a group can have 0, 1, or more PartialReference rows).
------------------------------------------------------------
DROP TABLE IF EXISTS #PartialRefForInconsistent;

SELECT
    ig.ManufacturerId,
    ig.ManufacturerName,
    ig.StartingRef,
    ig.DistinctWatchModelCount,
    ig.WatchModelNames,
    pr.CatalogId AS PartialRefCatalogId,
    pr.ReferenceNumber AS PartialRefReferenceNumber,
    pr.ModelId AS PartialRefModelId,
    mdl.ModelName AS PartialRefModelName,
    CASE
        WHEN pr.CatalogId IS NULL THEN 'No PartialReference row found'
        WHEN pr.ModelId IS NOT NULL THEN 'Model assigned'
        ELSE 'No model assigned'
    END AS CaseStatus
INTO #PartialRefForInconsistent
FROM #InconsistentGroups AS ig
LEFT JOIN #ActiveCatalog AS pr
    ON pr.ManufacturerId = ig.ManufacturerId
    AND pr.StartingRef = ig.StartingRef
    AND pr.EntityType = 'PartialReference'
LEFT JOIN dbo.tbl_CAT_Model_d AS mdl WITH (NOLOCK)
    ON mdl.ModelId = pr.ModelId;

------------------------------------------------------------
-- 6. How many cases: starting-ref groups with more than one Watch model,
--    broken down by whether the PartialReference row has a model assigned.
------------------------------------------------------------
SELECT
    ManufacturerName,
    CaseStatus,
    COUNT(*) AS CaseCount
FROM #PartialRefForInconsistent
GROUP BY ManufacturerName, CaseStatus
ORDER BY ManufacturerName, CaseStatus;

------------------------------------------------------------
-- 7. Detail: every starting-ref group with more than one Watch model,
--    its PartialReference row (if any), and whether it has a model assigned.
------------------------------------------------------------
SELECT
    ManufacturerName,
    StartingRef,
    DistinctWatchModelCount,
    WatchModelNames,
    PartialRefCatalogId,
    PartialRefReferenceNumber,
    PartialRefModelId,
    PartialRefModelName,
    CaseStatus
FROM #PartialRefForInconsistent
ORDER BY ManufacturerName, CaseStatus, StartingRef;


/*
    Appended block: Audemars Piguet (AP) starting-ref -> correct model name
    check. For a hand-supplied list of (StartingRef, Correct Model Name)
    pairs, list every active Watch reference under that starting ref, its
    currently assigned model, the correct model given, and whether they
    match.

    Re-resolves its own manufacturer id and active/StartingRef logic -- does
    not depend on #TargetManufacturers / #ActiveCatalog from earlier blocks
    in this file, so it can be run on its own.

    DB: EWMaster (MasterDB), draft/working table tbl_CAT_Catalog_d.
    StatusID: 1 = Active, 2 = Draft, 3 = Deleted.
*/

------------------------------------------------------------
-- 8. Correct-model input list (StartingRef -> correct model name)
------------------------------------------------------------
DROP TABLE IF EXISTS #CorrectModelInput;

CREATE TABLE #CorrectModelInput
(
    RowId INT IDENTITY(1,1) PRIMARY KEY,
    StartingRef NVARCHAR(150) NOT NULL,
    CorrectModelName NVARCHAR(300) NOT NULL
);

INSERT INTO #CorrectModelInput (StartingRef, CorrectModelName)
VALUES
    ('25831', 'Royal Oak Tourbillon "25th Anniversary"'),
    ('25902', 'Royal Oak Tourbillon Openworked'),
    ('25977', 'Royal Oak Tourbillon Chronograph'),
    ('26116', 'Royal Oak Tourbillon Chronograph'),
    ('26257', 'Royal Oak Tourbillon Chronograph'),
    ('26343', 'Royal Oak Tourbillon Chronograph Openworked'),
    ('26347', 'Royal Oak Tourbillon Chronograph Openworked'),
    ('26348', 'Royal Oak Offshire Tourbillon Chronograph Openworked'),
    ('26377', 'Royal Oak Tourbillon Chronograph'),
    ('26510', 'Royal Oak Tourbillon Extra-Thin'),
    ('26511', 'Royal Oak Tourbillon Extra-Thin Openworked "40th Anniversary"'),
    ('26512', 'Royal Oak Tourbillon Extra-Thin'),
    ('26513', 'Royal Oak Tourbillon Extra-Thin Openworked'),
    ('26515', 'Royal Oak Tourbillon Extra-Thin'),
    ('26516', 'Royal Oak Tourbillon Extra-Thin'),
    ('26517', 'Royal Oak Tourbillon Extra-Thin'),
    ('26518', 'Royal Oak Tourbillon Extra-Thin Openworked'),
    ('26520', 'Royal Oak Tourbillon Extra-Thin'),
    ('26521', 'Royal Oak Tourbillon Extra-Thin'),
    ('26522', 'Royal Oak Tourbillon Extra-Thin'),
    ('26530', 'Royal Oak Selfwinding Flying Tourbillon'),
    ('26531', 'Royal Oak Tourbillon Extra-Thin'),
    ('26533', 'Royal Oak Selfwinding Flying Tourbillon'),
    ('26534', 'Royal Oak Tourbillon Extra-Thin'),
    ('26535', 'Royal Oak Tourbillon Extra-Thin'),
    ('26670', 'Royal Oak Selfwinding Flying Tourbillon Extra-Thin (RD#3)'),
    ('26660', 'Royal Oak Selfwinding Flying Tourbillon Extra-Thin (RD#3)'),
    ('26730', 'Royal Oak Selfwinding Flying Tourbillon'),
    ('26735', 'Royal Oak Selfwinding Flying Tourbillon Openworked');

------------------------------------------------------------
-- 9. AP manufacturer id (draft side), re-resolved for this block
------------------------------------------------------------
DROP TABLE IF EXISTS #AP_Manufacturer;

SELECT
    man.ManufacturerId
INTO #AP_Manufacturer
FROM dbo.tbl_CAT_Manufacturer_d AS man WITH (NOLOCK)
WHERE man.ManufacturerName LIKE 'Audemars Piguet%';

------------------------------------------------------------
-- 10. Active AP catalog rows (StatusID = 1), all EntityTypes, with
--     StartingRef and currently assigned model name.
------------------------------------------------------------
DROP TABLE IF EXISTS #AP_ActiveCatalog;

SELECT
    cat.CatalogId,
    cat.ReferenceNumber,
    cat.EntityType,
    cat.ModelId,
    mdl.ModelName AS CurrentModelName,
    CASE
        WHEN PATINDEX('%[^0-9]%', cat.ReferenceNumber) = 0 THEN cat.ReferenceNumber
        WHEN PATINDEX('%[^0-9]%', cat.ReferenceNumber) = 1 THEN NULL -- no leading digit at all
        ELSE LEFT(cat.ReferenceNumber, PATINDEX('%[^0-9]%', cat.ReferenceNumber) - 1)
    END AS StartingRef
INTO #AP_ActiveCatalog
FROM dbo.tbl_CAT_Catalog_d AS cat WITH (NOLOCK)
INNER JOIN #AP_Manufacturer AS apm
    ON apm.ManufacturerId = cat.ManufacturerId
LEFT JOIN dbo.tbl_CAT_Model_d AS mdl WITH (NOLOCK)
    ON mdl.ModelId = cat.ModelId
WHERE cat.StatusID = 1 -- Active
    AND cat.ReferenceNumber IS NOT NULL;

CREATE INDEX IX_AP_ActiveCatalog_StartingRef ON #AP_ActiveCatalog (StartingRef);

------------------------------------------------------------
-- 11. Final: every reference under each input StartingRef, current model
--     vs. correct model, and whether they match.
--     LEFT JOIN from the input list so a StartingRef with no catalog rows
--     still shows up (with NULLs) instead of silently disappearing.
------------------------------------------------------------
SELECT
    i.StartingRef,
    ac.CatalogId,
    ac.ReferenceNumber,
    ac.EntityType,
    ac.ModelId AS CurrentModelId,
    ac.CurrentModelName,
    i.CorrectModelName,
    CASE
        WHEN ac.CatalogId IS NULL THEN 'No catalog row found for this StartingRef'
        WHEN ac.CurrentModelName IS NULL THEN 'No model currently assigned'
        WHEN LOWER(LTRIM(RTRIM(ac.CurrentModelName))) = LOWER(LTRIM(RTRIM(i.CorrectModelName))) THEN 'Match'
        ELSE 'No match'
    END AS MatchStatus
FROM #CorrectModelInput AS i
LEFT JOIN #AP_ActiveCatalog AS ac
    ON ac.StartingRef = i.StartingRef
ORDER BY i.RowId, ac.EntityType, ac.ReferenceNumber;
