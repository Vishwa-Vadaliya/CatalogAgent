/*
    FP Journe (EWMaster catalog, ManufacturerId = 53): unify model-name casing.
    Of the 85 active (StatusID = 1) models, 19 are ALL CAPS or lowercase-first;
    this fixes those to Title Case to match the other 66 already-correct names.
    French prepositions ("à", "de") stay lowercase, matching the existing
    "Chronomètre à Résonance" convention. Acronyms ("FFC") left untouched.

    Draft table only (tbl_CAT_Model_d) -- publish propagates separately (A9: no
    publish call in this script; run sp_PublishAllDataNew yourself when ready).

    How to run:
    1) Run from EWMaster.
    2) Run step 1, then step 2 (preview) and check it.
    3) Run step 3 (new TransactionID) and the UPDATE together, as one execution
       (no GO between them -- @NewTransactionID is a local variable, B6).
    4) Uncomment COMMIT (or ROLLBACK) at the end after checking the update.
*/

------------------------------------------------------------
-- 1. Target rows: ModelId -> corrected ModelName
------------------------------------------------------------
DROP TABLE IF EXISTS #CasingFix;
CREATE TABLE #CasingFix (ModelId INT PRIMARY KEY, NewModelName NVARCHAR(250));
INSERT INTO #CasingFix (ModelId, NewModelName) VALUES
(1786, N'Astronomic Blue'),
(1831, N'Centigraphe Anniversaire'),
(1787, N'Chronographe'),
(1829, N'Chronographe Monopoussoir Rattrapante Bleu'),
(1821, N'Chronomètre Bleu Byblos'),
(1832, N'Chronomètre Furtif'),
(1820, N'Chronomètre Holland & Holland'),
(1020, N'Linesport Collection'),
(1822, N'Octa Automatique Lune'),
(1827, N'Octa Automatique Lune Havana'),
(1826, N'Octa Automatique Lune Nacre'),
(1823, N'Octa Automatique Réserve'),
(1824, N'Octa Automatique Réserve Havana'),
(1825, N'Octa Automatique Réserve Nacre'),
(1819, N'Octa Chronographe'),
(1817, N'Octa Réserve de Marche'),
(1818, N'Octa Sport'),
(1828, N'Octa Zodiaque'),
(1816, N'Sonnerie Souveraine');

------------------------------------------------------------
-- 2. Preview: current vs new name, with an action flag
------------------------------------------------------------
SELECT
    cf.ModelId,
    mdl.ModelName AS CurrentModelName,
    cf.NewModelName,
    CASE WHEN mdl.ModelName = cf.NewModelName COLLATE Latin1_General_CS_AS THEN 'No change' ELSE 'Update' END AS Action
FROM #CasingFix AS cf
INNER JOIN tbl_CAT_Model_d AS mdl WITH (NOLOCK) ON mdl.ModelId = cf.ModelId
ORDER BY cf.ModelId;

------------------------------------------------------------
-- 3. New TransactionID for this update (2 = Update), then the update itself.
--    Run together as one execution -- @NewTransactionID is a local variable (B6).
------------------------------------------------------------
DECLARE @NewTransactionID BIGINT;
EXEC dbo.sp_Create_Transaction @TransactionTypeID = 2, @OutTransactionID = @NewTransactionID OUTPUT;   -- 2 = Update

BEGIN TRAN;

UPDATE mdl
SET ModelName = cf.NewModelName,
    UpdatedDate = GETDATE(),
    TransactionID = @NewTransactionID
FROM tbl_CAT_Model_d AS mdl
INNER JOIN #CasingFix AS cf ON cf.ModelId = mdl.ModelId
WHERE mdl.ModelName <> cf.NewModelName COLLATE Latin1_General_CS_AS;

-- COMMIT;
-- ROLLBACK;
