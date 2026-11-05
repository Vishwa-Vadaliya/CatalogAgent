/*
    FP Journe model-name casing audit (EWMaster catalog only).
    Pulls every active FP Journe model from the catalog draft table so the
    casing fix can be decided from the real names, not guessed.

    Run from EWMaster.
*/

DROP TABLE IF EXISTS #FPJourneModels;

SELECT
    mdl.ModelId,
    mdl.ModelName,
    mdl.StatusID,
    man.ManufacturerId,
    man.ManufacturerName
INTO #FPJourneModels
FROM tbl_CAT_Model_d AS mdl
INNER JOIN tbl_CAT_Manufacturer_d AS man
    ON man.ManufacturerId = mdl.ManufacturerId
WHERE man.ManufacturerName LIKE '%Journe%'
    AND mdl.ModelName IS NOT NULL;

SELECT * FROM #FPJourneModels ORDER BY ModelName;
