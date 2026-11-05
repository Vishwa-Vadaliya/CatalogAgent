------------------------------------------------------------
-- Purpose: Count how many active Rolex rows in tbl_CAT_Catalog_d (EWMaster) match a
--          researched reference-number -> nickname mapping, as a sizing check before
--          any INSERT into tbl_CAT_Nickname(_d) or UPDATE of NicknameId.
-- DB: EWMaster
-- Scope confirmed with user: Rolex only, catalog side (tbl_CAT_Catalog_d.NicknameId),
--   "High confidence" rows only from
--   Output/Documents/Rolex/Rolex_Nickname_Reference_Mapping.md — the "Check" and
--   "Not resolved yet" rows are excluded until confirmed.
-- Read-only — SELECT only, no INSERT/UPDATE here.
------------------------------------------------------------

------------------------------------------------------------
-- 1. Candidate nickname -> reference number map (high-confidence only)
------------------------------------------------------------
DROP TABLE IF EXISTS #NicknameMap;
SELECT *
INTO #NicknameMap
FROM (VALUES
    ('Pepsi',                       '126710BLRO'),
    ('Pepsi (vintage)',             '1675'),
    ('Pepsi (vintage)',             '6542'),
    ('Batman',                      '116710BLNR'),
    ('Sprite',                      '126720VTNR'),
    ('Hulk',                        '116610LV'),
    ('Kermit',                      '16610LV'),
    ('Starbucks',                   '126610LV'),
    ('Smurf',                       '116619LB'),
    ('Panda',                       '116500LN'),
    ('Paul Newman',                 '6239'),
    ('Paul Newman',                 '6241'),
    ('Steve McQueen',               '1655'),
    ('Polar',                       '226570'),
    ('James Cameron / D-Blue',      '116660'),
    ('James Cameron / D-Blue',      '126660'),
    ('Great White / Single Red',    '1665'),
    ('Triple Six',                  '16660')
) AS v(Nickname, ReferenceNumber);

------------------------------------------------------------
-- 2. Active Rolex catalog rows (ManufacturerId = 129, StatusID = 1)
------------------------------------------------------------
DROP TABLE IF EXISTS #RolexCatalog;
SELECT
    c.CatalogId,
    c.ReferenceNumber,
    c.NicknameId,
    c.EntityType,
    c.StatusID
INTO #RolexCatalog
FROM dbo.tbl_CAT_Catalog_d AS c WITH (NOLOCK)
WHERE c.ManufacturerId = 129
  AND c.StatusID = 1;

------------------------------------------------------------
-- 3. Match -> one row per nickname, with match count and how many already have a NicknameId
------------------------------------------------------------
DROP TABLE IF EXISTS #MatchSummary;
SELECT
    m.Nickname,
    m.ReferenceNumber,
    COUNT(rc.CatalogId)                                  AS MatchedCatalogRows,
    SUM(CASE WHEN rc.NicknameId IS NOT NULL THEN 1 ELSE 0 END) AS AlreadyHasNicknameId
INTO #MatchSummary
FROM #NicknameMap AS m
LEFT JOIN #RolexCatalog AS rc
    ON rc.ReferenceNumber = m.ReferenceNumber
GROUP BY m.Nickname, m.ReferenceNumber;

SELECT * FROM #MatchSummary ORDER BY MatchedCatalogRows DESC, Nickname;
