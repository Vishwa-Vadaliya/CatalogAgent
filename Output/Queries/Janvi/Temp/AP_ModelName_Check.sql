/*
    Checks whether a list of Audemars Piguet model names exist on the catalog
    (EWMaster) side, and returns their StatusID if found.

    tbl_CAT_Model_d has ModelName + StatusID; join to tbl_CAT_Manufacturer_d
    to scope to Audemars Piguet (tbl_CAT_Catalog_d itself has no ModelName
    column, only ModelId/ManufacturerId FKs).

    How to use:
    1) Run from EWMaster.
    2) Fill #InputModels below with the list to check.
    3) Run the script. Last SELECT shows each input model, Yes/No, and StatusID.
*/

DROP TABLE IF EXISTS #InputModels;

CREATE TABLE #InputModels
(
    RowId INT IDENTITY(1,1) PRIMARY KEY,
    ModelNameInput NVARCHAR(300) NOT NULL
);

INSERT INTO #InputModels (ModelNameInput)
VALUES
    ('Royal Oak Jumbo'),
    ('Royal Oak Chronograph'),
    ('Royal Oak Automatique Tourbillon'),
    ('Royal Oak Perpetual'),
    ('Royal Oak Offshore Chronograph Volcano'),
    ('Royal Oak Quantième Perpetuel'),
    ('Royal Oak Quantieme Perpetual'),
    ('Royal Oak Jumbo Extra Thin'),
    ('Royal Oak Double Balance Wheel'),
    ('Royal Oak Offshore Survivor'),
    ('Jules Audemars Grande Sonnerie'),
    ('Royal Oak Flying Tourbillon'),
    ('Jumbo Royal Oak'),
    ('Royal Oak Double Balance'),
    ('Royal Oak Jubilée'),
    ('Royal Oak Mini'),
    ('Royal Oak Offshore Rubens Barrichello'),
    ('Royal Oak Offshore Scuba Boutique Edition'),
    ('Royal Oak A Series'),
    ('Royal Oak Perpetual Calendar Openworked'),
    ('Royal Oak Quantieme Perpetuel Automatique'),
    ('Royal Oak Offshore Chronograph Alinghi Team');

-- Distinct AP model names on the catalog (EWMaster) side
DROP TABLE IF EXISTS #CatalogModels;

SELECT DISTINCT
    mdl.ModelName,
    mdl.StatusID,
    LOWER(LTRIM(RTRIM(mdl.ModelName))) AS CleanModelName
INTO #CatalogModels
FROM tbl_CAT_Model_d AS mdl
INNER JOIN tbl_CAT_Manufacturer_d AS man
    ON man.ManufacturerId = mdl.ManufacturerId
WHERE man.ManufacturerName LIKE 'Audemars Piguet%'
    AND mdl.ModelName IS NOT NULL;

CREATE INDEX IX_CatalogModels_Clean ON #CatalogModels (CleanModelName);

SELECT
    i.ModelNameInput,
    CASE WHEN c.CleanModelName IS NOT NULL THEN 'Yes' ELSE 'No' END AS InCatalog,
    c.StatusID
FROM #InputModels AS i
LEFT JOIN #CatalogModels AS c
    ON c.CleanModelName = LOWER(LTRIM(RTRIM(i.ModelNameInput)))
ORDER BY i.RowId;


/*
    Watch (EveryWatch app DB) side check: a second list of AP model names
    against tblModel.ModelName, ManufacturerId = 142 (AP, app side),
    showing IsDeleted as-is (not filtered out).

    How to use:
    1) Run from EWMaster (EveryWatch tables are prefixed EveryWatch.dbo.).
    2) Fill #InputModelsWatch below with the list to check.
    3) Run the script. Last SELECT shows each input model, Yes/No, and IsDeleted.
*/

DROP TABLE IF EXISTS #InputModelsWatch;

CREATE TABLE #InputModelsWatch
(
    RowId INT IDENTITY(1,1) PRIMARY KEY,
    ModelNameInput NVARCHAR(300) NOT NULL
);

INSERT INTO #InputModelsWatch (ModelNameInput)
VALUES
    ('Royal Oak "Jumbo" Extra-Thin'),
    ('Royal Oak Selfwinding Chronograph'),
    ('Royal Oak Selfwinding Tourbillon'),
    ('Royal Oak Perpetual Calendar'),
    ('Royal Oak Offshore Chronograph'),
    ('Royal Oak Pereptual Calendar'),
    ('Royal Oak Pereptual Calendar'),
    ('Royal Oak "Jumbo" Extra Thin'),
    ('Royal Oak Double Balance Wheel Openworked'),
    ('Royal Oak Offshore'),
    ('Jules Audemars Grand Sonnerie'),
    ('Royal Oak Selfwinding Flying Tourbillon'),
    ('Royal Oak "Jumbo" Extra-Thin'),
    ('Royal Oak Doulble Balance Wheel Openworked'),
    ('Royal Oak "Jumbo" Extra-Thin'),
    ('Royal Oak Mini Frosted Gold Quartz'),
    ('Royal Oak Offshore'),
    ('Royal Oak Offshore'),
    ('Royal Oak "Jumbo" Extra-Thin'),
    ('Royal Oak Perpetual Calendar'),
    ('Royal Oak Perpetual Calendar'),
    ('Royal Oak Offshore Chronograph');

-- Distinct AP model names on the watch (EveryWatch) side
DROP TABLE IF EXISTS #WatchModels;

SELECT
    m.ModelName,
    m.IsDeleted,
    LOWER(LTRIM(RTRIM(m.ModelName))) AS CleanModelName
INTO #WatchModels
FROM EveryWatch.dbo.tblModel AS m
WHERE m.ManufacturerId = 142 -- Audemars Piguet, app DB
    AND m.ModelName IS NOT NULL;

CREATE INDEX IX_WatchModels_Clean ON #WatchModels (CleanModelName);

SELECT
    i.ModelNameInput,
    CASE WHEN w.CleanModelName IS NOT NULL THEN 'Yes' ELSE 'No' END AS InWatchSide,
    w.IsDeleted
FROM #InputModelsWatch AS i
LEFT JOIN #WatchModels AS w
    ON w.CleanModelName = LOWER(LTRIM(RTRIM(i.ModelNameInput)))
ORDER BY i.RowId;


/*
    Duplicate-name check on the watch (EveryWatch app DB) side: among all
    non-deleted AP models (ManufacturerId = 142), find pairs whose ModelName
    reduces to the same "Complete Clean Name" via dbo.fn_ExtractNumbersAndAlphabets
    (letters + digits only, lowercased) but are different ModelId/ModelName rows.

    Precompute the cleaned key into a temp table first (the UDF has a WHILE
    loop and is slow used directly in a join predicate), then self-join.

    How to use: run from EWMaster (EveryWatch tables are prefixed EveryWatch.dbo.).
*/

DROP TABLE IF EXISTS #AllAPModels;

SELECT
    m.ModelId,
    m.ModelName,
    dbo.fn_ExtractNumbersAndAlphabets(CAST(m.ModelName AS VARCHAR(255))) AS CleanName
INTO #AllAPModels
FROM EveryWatch.dbo.tblModel AS m
WHERE m.ManufacturerId = 142 -- Audemars Piguet, app DB
    AND (m.IsDeleted = 0 OR m.IsDeleted IS NULL)
    AND m.ModelName IS NOT NULL;

CREATE INDEX IX_AllAPModels_Clean ON #AllAPModels (CleanName);

SELECT
    a.ModelId AS ModelId_1,
    a.ModelName AS ModelName_1,
    b.ModelId AS ModelId_2,
    b.ModelName AS ModelName_2,
    a.CleanName
FROM #AllAPModels AS a
INNER JOIN #AllAPModels AS b
    ON b.CleanName = a.CleanName
    AND b.ModelId > a.ModelId
ORDER BY a.CleanName;


