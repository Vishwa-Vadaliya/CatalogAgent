/*
===================================================================================
ECH-693 - Raw to Catalog new refs
Script 05c: master values the review may use for the step 5 fields - read-only
===================================================================================
Purpose : In the review, Claude (or a person) writes names for fields that have no raw column.
          sp_Create_Catalog accepts only names that exist in the master table, so this lists
          every active master value per field. With read-only MCP access this export is not needed.
DB      : EWMaster. SELECT only, changes nothing.
Run     : run once and send me the result (or save it as CSV). Run it again when a master value was added.
          Query 1 = counts per field, query 2 = all values.
===================================================================================
*/

------------------------------------------------------------
-- 1. How many active values each field has
------------------------------------------------------------
SELECT x.FieldName, COUNT(*) AS ActiveValues
FROM (
    SELECT N'Case / Strap / Bezel embellishment (tbl_CAT_Embelishment_d)' AS FieldName
    FROM dbo.tbl_CAT_Embelishment_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Indices material (tbl_CAT_Material_d)'
    FROM dbo.tbl_CAT_Material_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Bezel style (tbl_CAT_BezelStyle_d)'
    FROM dbo.tbl_CAT_BezelStyle_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Bezel type (tbl_CAT_BezelType_d)'
    FROM dbo.tbl_CAT_BezelType_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Movement number (tbl_CAT_MovementNumber_d)'
    FROM dbo.tbl_CAT_MovementNumber_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Nickname (tbl_CAT_Nickname_d)'
    FROM dbo.tbl_CAT_Nickname_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
    UNION ALL
    SELECT N'Pusher shape (tbl_CAT_PusherShape_d)'
    FROM dbo.tbl_CAT_PusherShape_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
) AS x
GROUP BY x.FieldName
ORDER BY x.FieldName;

------------------------------------------------------------
-- 2. All active values (FieldName, Value)
------------------------------------------------------------
SELECT N'Embelishment' AS FieldName, LTRIM(RTRIM(t.EmbelishmentName)) AS [Value]
FROM dbo.tbl_CAT_Embelishment_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'IndicesMaterial', LTRIM(RTRIM(t.MaterialName))
FROM dbo.tbl_CAT_Material_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'BezelStyle', LTRIM(RTRIM(t.BezelStyleName))
FROM dbo.tbl_CAT_BezelStyle_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'BezelType', LTRIM(RTRIM(t.BezelTypeName))
FROM dbo.tbl_CAT_BezelType_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'MovementNumber', LTRIM(RTRIM(t.MovementNumberName))
FROM dbo.tbl_CAT_MovementNumber_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'Nickname', LTRIM(RTRIM(t.NicknameName))
FROM dbo.tbl_CAT_Nickname_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
UNION ALL
SELECT N'PusherShape', LTRIM(RTRIM(t.PusherShapeName))
FROM dbo.tbl_CAT_PusherShape_d AS t WITH (NOLOCK) WHERE t.StatusID = 1
ORDER BY FieldName, [Value];
