/*
    For a hand-supplied list of draft WatchIds: Title, Description, and
    bezel color(s) (comma-separated, a watch can have more than one).

    Background:
    - tblWatch_d (draft watch, app DB EveryWatch) holds Title and
      Description directly. Description is truncated to 40000 chars in
      both final SELECTs - Google Sheets rejects cell values over ~50000
      chars.
    - Bezel color is many-to-many: TblWatchToBezelColor_d (WatchId,
      BezelColorId) -> tblColor (ColorId -> ColorName). A watch with no
      row in TblWatchToBezelColor_d has no bezel color recorded (LEFT JOIN,
      blank in the result - not an error).

    Steps:
    1) #WatchIds - the input list of WatchIds (edit/paste the values below).
    2) #BezelColors - per WatchId, comma-separated distinct bezel color
       names (empty set collapses to NULL via LEFT JOIN + STRING_AGG).
    3) Final SELECT - one row per input WatchId with Title, Description,
       BezelColors; WatchIds not found in tblWatch_d still appear with
       NULLs (LEFT JOIN from #WatchIds).

    How to use:
    1) Run from EveryWatch (app DB).
    2) Edit #WatchIds below with the WatchId list, then run the whole script.
*/

------------------------------------------------------------
-- 1. Input WatchIds
------------------------------------------------------------
DROP TABLE IF EXISTS #WatchIds;

CREATE TABLE #WatchIds (WatchId BIGINT PRIMARY KEY);

INSERT INTO #WatchIds (WatchId) VALUES
(13481370),(1553131),(1587170),(1598203),(1648677),(2504262),(2504526),(2558536),(2715388),(3585800),
(3609221),(3646664),(3760852),(3778047),(4071108),(4832236),(5091634),(5955685),(6095036),(6118227),
(6123366),(6205410),(6935510),(7044275),(7060185),(7079618),(7941934),(7995385),(8012432),(8076922),
(8109755),(8144044),(8159786),(8184388),(9291732),(9404485),(9458199),(10312801),(11178273),(11186225),
(11213382),(12154325),(12810671),(12886560),(12966638),(13493253),(292218),(293792),(301449),(307936),
(312087),(1724230),(1801456),(1811709),(1861136),(1946813),(1949462),(1951990),(1973744),(2786391),
(2815326),(2854065),(2969445),(3985619),(4343770),(5299771),(5314645),(7252407),(7252410),(8189464),
(8205774),(8229881),(8334676),(8421414),(8477224),(9623014),(9623311),(9653238),(9705051),(9827178),
(10442394),(10442838),(10505715),(10517364),(10575773),(10609785),(11432386),(11434161),(11446014),(11547705),
(634430),(640699),(931543),(931809),(953321),(970700),(2117566),(2151025),(2170670),(2243770),
(3112231),(3112272),(3327027),(4424494),(4497156),(4538313),(5421543),(5639079),(6476366),(6480112),
(6483061),(6631652),(7366111),(7425695),(7448713),(10669040),(10835513),(12333370),(12335384),(12344075),
(12344298),(12504468),(12517445),(13196764),(13222004),(13304064),(13304320),(13306339),(13340253);

------------------------------------------------------------
-- 2. Comma-separated bezel color name(s) per WatchId
--    LEFT JOIN so watches with zero bezel color rows still pass through
------------------------------------------------------------
DROP TABLE IF EXISTS #BezelColors;

SELECT
    wi.WatchId,
    STRING_AGG(c.ColorName, ', ') WITHIN GROUP (ORDER BY c.ColorName) AS BezelColors
INTO #BezelColors
FROM #WatchIds AS wi
LEFT JOIN dbo.TblWatchToBezelColor_d AS wbc WITH (NOLOCK)
    ON wbc.WatchId = wi.WatchId
LEFT JOIN dbo.tblColor AS c WITH (NOLOCK)
    ON c.ColorId = wbc.BezelColorId
GROUP BY wi.WatchId;

------------------------------------------------------------
-- 3. Final - Title, Description, BezelColors per input WatchId
------------------------------------------------------------
SELECT
    wi.WatchId,
    w.Title,
    LEFT(w.Description, 40000) AS Description,
    bc.BezelColors
FROM #WatchIds AS wi
LEFT JOIN dbo.tblWatch_d AS w WITH (NOLOCK)
    ON w.WatchId = wi.WatchId
LEFT JOIN #BezelColors AS bc
    ON bc.WatchId = wi.WatchId
where w.watchid in (1102895,1105776,1498157,2323601,2441281,3365181,3365216,3382845,3383202,3394030,3445386,3494169,3513850,5940128,6688763,6695750,6708582,7710416,8965938,8977782,10026956,10095576,10974359,11848943,11882721,11926076,12634926,13383489,13399686,13467216,13481370,1553131,1587170,1598203,1648677,3585800,3646664,3760852,3778047,4071108,4832236,6095036,6118227,6123366,6205410,6935510,7044275,7941934,7995385,8012432,8076922,8109755,9404485,9458199,10312801,11186225,12810671,12886560,12966638,13493253,292218,293792,307936,312087,1724230,1811709,1861136,1946813,1949462,2786391,2815326,2854065,4343770,5299771,7252407,7252410,8189464,8334676,9623311,9653238,9705051,9827178,10505715,10517364,10575773,10609785,11432386,11547705,634430,640699,931543,953321,970700,2117566,2151025,2170670,2243770,3112231,3112272,3327027,4538313,5421543,5639079,6476366,6480112,6483061,7366111,7425695,7448713,10669040,10835513,12517445,13196764,13222004,13304064,13304320,13340253)
ORDER BY wi.WatchId;

------------------------------------------------------------
-- 4. Watches without enrichment, reference number 16710
--    No assigned enrichment = tblWatch_d.ReferenceEnrichmentId IS NULL
--    (draft id). tblWatch_d has ReferenceNumberId - resolve the text
--    "16710" to its ReferenceNumberId(s) via tblReferenceNumber first,
--    then filter tblWatch_d by the id, never by the ReferenceNumber text
--    column (no manufacturer given, so this can resolve to more than one
--    ReferenceNumberId across manufacturers - all are included).
------------------------------------------------------------
DROP TABLE IF EXISTS #ResolvedRefIds;

SELECT rn.ReferenceNumberId
INTO #ResolvedRefIds
FROM dbo.tblReferenceNumber AS rn WITH (NOLOCK)
WHERE rn.ReferenceNumber = N'16710';

DROP TABLE IF EXISTS #Ref16710_NoEnr;

SELECT
    w.WatchId,
    w.ManufacturerId,
    w.ManufactureName,
    w.ReferenceNumber,
    w.Title,
    w.Description
INTO #Ref16710_NoEnr
FROM dbo.tblWatch_d AS w WITH (NOLOCK)
INNER JOIN #ResolvedRefIds AS r
    ON r.ReferenceNumberId = w.ReferenceNumberId
WHERE w.ReferenceEnrichmentId IS NULL
    AND (w.IsDeleted = 0 OR w.IsDeleted IS NULL);

SELECT
    r.WatchId,
    r.ManufacturerId,
    r.ManufactureName,
    r.ReferenceNumber,
    r.Title,
    LEFT(r.Description, 40000) AS Description,
    STRING_AGG(c.ColorName, ', ') WITHIN GROUP (ORDER BY c.ColorName) AS BezelColors
FROM #Ref16710_NoEnr AS r
LEFT JOIN dbo.TblWatchToBezelColor_d AS wbc WITH (NOLOCK)
    ON wbc.WatchId = r.WatchId
LEFT JOIN dbo.tblColor AS c WITH (NOLOCK)
    ON c.ColorId = wbc.BezelColorId
GROUP BY
    r.WatchId,
    r.ManufacturerId,
    r.ManufactureName,
    r.ReferenceNumber,
    r.Title,
    r.Description
ORDER BY r.WatchId;
