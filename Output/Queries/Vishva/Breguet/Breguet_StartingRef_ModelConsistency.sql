/*
    Purpose: For Breguet, active rows in the draft catalog table
    (tbl_CAT_Catalog_d, StatusID = 1) with EntityType = 'Watch', extract the
    "starting ref" (the leading digit run of ReferenceNumber, e.g. 5177BR/12/9V6
    -> 5177). Group by starting ref and list the distinct ModelId(s) in that group.

    If a starting-ref group has more than one distinct ModelId, check whether
    the matching EntityType = 'PartialReference' row for that same starting
    ref has a ModelId assigned.

    Same logic as Queries/Janvi/Temp/Rolex_Patek_AP_StartingRef_ModelConsistency.sql,
    for Breguet only.

    StatusID (tbl_CAT_Catalog_d): 1 = Active, 2 = Draft, 3 = Deleted.

    DB: EWMaster (MasterDB), draft/working table tbl_CAT_Catalog_d.
    Run from EWMaster.

    How to use:
    1) Run steps 1-5 in order (each is independent after the earlier temp
       tables exist).
    2) Step 6 = count of cases by PartialReference status.
    3) Step 7 = detail: every starting-ref group with more than one model,
       its PartialReference row (if any), its ModelId, and case status.
*/

------------------------------------------------------------
-- 1. Breguet manufacturer id (draft side)
------------------------------------------------------------
DROP TABLE IF EXISTS #TargetManufacturers;

SELECT
    man.ManufacturerId,
    man.ManufacturerName
INTO #TargetManufacturers
FROM dbo.tbl_CAT_Manufacturer_d AS man WITH (NOLOCK)
WHERE man.ManufacturerName LIKE 'Breguet%';

------------------------------------------------------------
-- 2. Active draft catalog rows (StatusID = 1) for Breguet,
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
