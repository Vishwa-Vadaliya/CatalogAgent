---
type: Feedback Log
title: Session Corrections Log
description: Append-only chronological log of corrections — cases where Claude did something wrong and was redirected, split into actual mistakes vs. design redirects.
tags: [feedback, corrections, log, retro]
timestamp: 2026-10-31
---

# Session Corrections Log

A review of this session's queries: cases where something I wrote was wrong or
misplaced, and you had to correct it. Split into actual mistakes vs. design
redirects (where you steered the approach, but nothing was actually broken).

## Actual mistakes

1. **Missing `IsDeleted` filter**
   In the "complications -> catalogs -> watches" count query, I pulled
   `WatchId` straight from `tblWatch_d` without excluding deleted watches.
   You caught it: _"But while taking watchids from tblwatch, also don't we
   have to keep isdeleted =0 or null condition."_ This was a real gap --
   should have applied it by default per the project's own tblWatch_d
   staging convention.
   -> Promoted to Knowledge/EW_DB_Knowledge.md (§3, IsDeleted filter rule).

2. **SQL syntax error**
   I wrote `COUNT(DISTINCT WatchId) OVER (PARTITION BY CatalogId)` to get a
   per-catalog rollup alongside the per-enrichment count. SQL Server does
   not allow `DISTINCT` inside `COUNT(...) OVER(...)`. You got
   `Msg 10759, Level 15, State 1` when you actually ran it, and I had to
   restructure it into a separate grouped temp table joined back in.
   -> Promoted to Rules/EW_Rules.md (B11, no DISTINCT inside a windowed aggregate).

3. **Chat-vs-file default was backwards, and the fix was first written to the wrong, older project**
   I defaulted to pasting new queries in chat unless asked to save. You corrected it: save is
   now the default, chat-only only when you explicitly say "give/write it here." I first wrote
   that fix into a different, older project's rule file instead of here, then into that same
   project's instruction file — you redirected both times: all rules belong under CatalogAgent,
   with no other file or project depended on for them any more.
   -> Promoted to Rules/00-core.md (A3). The older project's rule/instruction files were retired.

## Design redirects (not bugs -- you pointed me to a better approach)

4. **Step 2c filtering logic (console.sql)**
   I built a brand-specific `LIKE` pattern recheck against the watch's own
   reference number. You suggested a cleaner approach: directly compare the
   watch's ref vs. the enrichment's ref using `fn_ExtractNumbersAndAlphabets`
   equality instead. Not wrong, just less elegant than what you wanted --
   old version was commented out and kept for reference, not deleted.

5. **Top-10-images query (Query7.sql)**
   I'd layered in an `EntityStatusId` filter on top of the `IsDeleted`
   filter, and ranked all images per watch. You simplified it: drop
   `EntityStatusId` entirely, and only take the `IsPrimary = 1` image per
   watch.
   -> Promoted to Rules/EW_Rules.md (B5, primary-image-only rule) and
   Rules/EW_Rules.md (A7, start simple).

6. **Active-catalog filter: wrong table and wrong filter (`tbl_CAT_Catalog` StatusName)**
   For a Rolex/Patek/AP starting-ref vs. model-consistency check, I queried
   the published `tbl_CAT_Catalog` table and filtered "active" as
   `StatusName <> 'Deleted'` via a join to `tbl_CAT_Status`. You corrected
   it: "active" must be checked in the **draft table** `tbl_CAT_Catalog_d`,
   filtering the numeric `StatusID` column directly -- `StatusID = 1` =
   Active, `2` = Draft, `3` = Deleted. There is no `StatusName <> 'Deleted'`
   check to do here at all; just filter `StatusID = 1` on `tbl_CAT_Catalog_d`.
   -> Promoted to Knowledge/EW_DB_Knowledge.md (§4, catalog active/draft/deleted convention).

7. **Google Sheet formula: over-built instead of starting simple**
   Asked for a Sheet9 formula to build an `EXEC sp_Update_Catalog` statement
   from CatalogId (col B) and the correct model name (col G), I went
   straight to an `IF($I=TRUE, ..., "")` filter plus `SUBSTITUTE` quote
   escaping, split across batches for 219 rows. You cut in: "simply check
   catalogid model in column B and G just add the formula simple why take
   time," then afterward: "always try things simple if needed then only do
   extra or point me out." Lesson: default to the plain, direct formula/query
   first; only add conditions, escaping, or validation when there's an
   actual need, and flag that need rather than silently building it in.
   -> Promoted to Rules/EW_Rules.md (A7, start simple).

8. **Filtered watches by denormalized text columns instead of ids**
   In `Watch_MultipleEnrichment_ByRefAndManufacturer.sql`, I filtered
   `tblWatch_d` directly on `w.ReferenceNumber = ...` and
   `tblManufacturer.ManufacturerName = ...` (joining on the text columns).
   You corrected it: "wherever we have table ... reference number and
   manufacturer ID in watch table, there we only use the IDs, not directly
   the manufacturer name and reference number" -- resolve
   `ReferenceNumberId`/`ManufacturerId` first (one lookup against
   `tblReferenceNumber`/`tblManufacturer`), then filter the watch table by
   those ids only, never by the raw text copies it carries. Lighter query,
   and the text columns on `tblWatch_d` are denormalized copies, not the
   source of truth for identity.
   -> Promoted to Rules/EW_Rules.md (B9, match on ids not denormalized text columns).

9. **Put a one-time ALTER TABLE / data-fill script inside ew-db**
   For reference production status I wrote
   `ew-db/Scripts/2026/October/RefProductionStatus-01-...sql` (map
   `CountryId` -> NULL, new `IsReconfigured` column + fill from the sheet).
   You corrected it: ew-db is purely the database schema, no other SQL --
   one-time ALTER / fill scripts go under CatalogBrain `Queries/`. Moved to
   `Queries/Janvi/RetailPrice/RefProductionStatus_01_MapCountryNull_IsReconfigured.sql`;
   rule added to `Rules/EW_Rules.md` A6.
   -> Promoted to Rules/EW_Rules.md (A6).

## Session 2026-10-30/31: image-match review (Credor)

### Actual mistakes

10. **Brand names left in the new brand's sheet**
   The Credor copy of the template still had a tab named `Summary for jaeger`
   and no `Enrichment Overview` tab. You caught it: _"There is no enrichment
   overview tab in the sheet you gave me ... the tab name is still jaeger
   summary so such things should not happen."_ Fixed the sheet and template;
   added `PythonScripts/prepare_review_sheet.py` and a read-back check.
   -> Promoted to Knowledge/Image_Match_Review_Workflow.md (section 4)

11. **`IsDeleted` filter on image tables**
   I applied the `IsDeleted = 0 OR NULL` filter to image tables. You
   corrected it: it applies only to `tblWatch` / `tblWatch_d`, never to image
   or other watch-side tables.
   -> Promoted to Rules/EW_Rules.md (B10). Confirmed: `IsDeleted` is used only on
   `tblWatch` / `tblWatch_d`, nowhere else (including `tblReferenceNumber`, `tbl_RAW_Media`).

12. **Edits without showing the changed lines**
   I edited files without showing the diff; you asked to always see it.
   -> Promoted to Rules/EW_Rules.md (A8, show diffs on edit).

13. **CRLF line endings**
   A Python text-mode write converted `NoEnrichment_References.sql` to CRLF,
   so the first diff showed every line as changed. Normalized to LF with sed.
   One-off, left in the log only.

### Design redirects

14. **No-enrichment references query output**
    The first version had a `TOTAL` row and a `(no reference)` row. You asked
    to drop both: _"Don't give the first and the last row."_ Removed the
    `UNION ALL` TOTAL branch and filtered out rows with neither a reference id
    nor a raw reference. One-off, left in the log only.

15. **Same layout for both review tabs**
    You wanted `ManufacturerWide` and `Multiple ENR` to share one layout, and
    the type-1 review query to be the type-5 query with only the enrichment
    type changed. Added blank preview columns to the review queries.
    -> Promoted to Knowledge/Image_Match_Review_Workflow.md (sections 2 and 3)

16. **Template copy not cleared of the previous brand's data**
    The first Credor copy of the template still held Jaeger-LeCoultre's data.
    You asked me to remove it, then: _"remember to remove the data whenever you
    create the sheet, you may keep the template formulas ... but change the
    brand name."_ Fixed with `PythonScripts/prepare_review_sheet.py`, which
    clears the pasted data and typed numbers and sets the brand title.
    -> Promoted to Knowledge/Image_Match_Review_Workflow.md (section 3)

17. **Typed inputs and the reason list**
    You told me the "Earlier" enrichment % is hardcoded, so ask before adding
    it, and that the difference-reason list changes every time, so it must not
    be fixed. The "Earlier" % is now a typed input that is never invented, and
    the reason list is built from the review itself.
    -> Promoted to Knowledge/Image_Match_Review_Workflow.md (sections 1 and 3)

18. **Rule change: when a query gets a file**
    You first said not to create a new file for every query. Updated: a query
    of about 3–4 lines goes in the chat only; a longer one is saved as a new
    file under `Queries/<Person>/`.
    -> Promoted to Rules/EW_Rules.md (A3)

## Session 2026-10-31: ECH-251 Cartier enrichment fix

### Actual mistakes

19. **Baked `sp_PublishAllDataNew` into a handed-off script**
    I added `EXEC sp_PublishAllDataNew` at the end of the ECH-251 update
    script. You corrected it: _"Never write `SP publish all data` in your
    query, because sometimes what we did was just copy the query and run it
    in the database, but we don't want to publish that now."_ Removed the
    call; publishing is a separate step the user triggers themselves.
    -> Promoted to Rules/EW_Rules.md (A9, no publish calls in handed-off scripts).

20. **Updated the published table when only the draft needed it**
    I wrote matching `UPDATE`s against both `tbl_CAT_Catalog_d` and
    `tbl_CAT_Catalog` to set `EnrichmentSimilarityScore = 2`. You corrected
    it: only the draft table needs the update -- publishing propagates
    draft -> publish automatically, so the publish-side `UPDATE` was
    unnecessary.
    -> Promoted to Knowledge/EW_DB_Knowledge.md (§3, draft-only data-fix rule).

## Session 2026-10-31: raw catalog -> catalog new refs automation (ECH-693)

### Design redirects

21. **Edited another person's existing scripts instead of building new ones in the user's own folder**
    While exploring ECH-693 I found Janvi's pipeline in `D:\EW\Scripts\Queries\Janvi\Raw To Catalog`
    (outside this repo) and kept patching it: power reserve and dial embellishment, nine more
    watch fields, new staging columns, a swapped mapping-proc table pair. All uncommitted, none
    run. You redirected: _"let us forget this approach, leave this everything just take context
    from this let us build one separate folder for this under my Vishva folder ... firstly we
    will build the requirements.md file and based on that we will create the scripts. And for
    requirements.md also we will build the plan for it."_ Root cause: I never read
    `CLAUDE.md` / `Rules/EW_Rules.md` at the start of the session, and went straight to patching
    instead of capturing requirements first (A0). Right way: restate the requirements, agree a
    plan, write the requirements doc, then build new scripts under `Queries/Vishva/<folder>/`;
    treat existing scripts in other folders or repos as read-only context.

22. **Linked the task to `brand-ref-agent` and left the main goal out of the plan**
    In the requirements plan I asked whether "agentic" meant a Claude skill like `brand-ref-agent`,
    and listed the goal only as the ticket text. You corrected: _"brand-ref-agent is a totally
    different thing, it has nothing to do with it"_, and asked the plan to state the main goal:
    add to `tbl_CAT_Catalog_d` only the **unique** new references from `tbl_RAW_Catalog` (official
    sources) that don't exist there yet, one per reference, even though the same reference sits in
    many raw rows from different sources with the same model, dial colour and case material. You
    also confirmed new stored procedures and a staging table are allowed in EWMaster, and that
    Janvi's scripts are context only. Right way: state the goal in the user's terms first, don't
    reuse an unrelated skill as the model for a different task, and list the duplicate and
    exception cases up front.

23. **Scoped the Claude review to conflict rows only**
    For the new Claude-review step I proposed exporting only staged refs with `ConflictNotes` not
    null. You redirected: _"take all the data with isapproved = 0 ... not just the one with
    conflictnotes not null. As claude will review all of them but conflict notes will be reviewed
    very properly."_ Right way: the Claude review covers every staged ref with `IsApproved = 0`;
    refs with conflict notes get the closest look. Order of evidence: title/description first,
    then the image, then web search; if still unsure, leave as is. Do not narrow the scope the
    user described before asking.

24. **Added staging columns for Claude-review tracking that were not needed**
    For the Claude-review step I wrote script 05a adding four `ClaudeReview*` columns to
    `tbl_CAT_RawRefStaging`. You asked: _"Are the Claude review columns really necessary to the
    staging table? ... cannot it just directly write the things in the conflict notes ... Or we
    can just keep one column in the artifact only, not the staging."_ Right way: keep the staging
    table as it is; Claude's decision is written into `ConflictNotes` (and corrected values, and
    `IsApproved = 1` when sure), and the "reviewed by Claude" tracking lives in the artifact only.
    Start with the smallest change to an existing table.

25. **Matched raw refs only against the catalog, not against the manual mapping table**
    Steps 1-3 compared the cleaned raw reference only with `tbl_CAT_Catalog_d`, so a raw ref that was
    manually mapped in `tbl_CAT_RawCatalogMapping` to an existing catalog row (different-looking
    reference) would have been staged as new and later created as a duplicate. I found the gap when
    you asked whether the mapping table is checked. You confirmed Janvi's rule (a mapping match wins,
    any brand, only when it points to exactly one catalog) and said: _"always look in
    tbl_CAT_RawCatalogMapping before start mapping from raw to catalog table. so do that change."_
    Right way: when building a raw-to-catalog match, read the existing mapping/override tables the
    current process uses (check `Knowledge/` and the existing map procedures) before designing the
    match, instead of comparing against the catalog table alone.

26. **Used placeholder scenario thresholds in the FINAL SUMMARY instead of deriving them from the data**
    For the Cartier `FINAL SUMMARY` section 4 I typed thresholds 0.96 down to 0.83 as a guess (flagged
    as an assumption) while the pasted `Overview Data` baseline was 0.89. Rows 0.96-0.89 showed 0
    additional watches and the section 3 threshold (0.77) was not in the list, so the cards showed
    `#N/A`. You said: _"fix this my formula and all is not working"_. Right way: section 4 rows are
    the current threshold minus 0.01 downward, 14 rows (here 0.88 down to 0.75), taken from the
    baseline in `Overview Data` / the workflow doc; the section 3 input must be a number that exists
    in that list. Don't invent placeholder thresholds.

27. **Listed only the `_d` (draft) table for some watch-attribute tables, omitting the published counterpart**
    When listing the EveryWatch tables the scripts use, I gave `tblWatchToBezelColor_d` and
    `TblWatchToBraceletMaterial_D` with no published table next to them, although
    `Knowledge/EW_DB_Knowledge.md` section 3 says the draft/publish pattern holds for every table.
    You said: _"for tblWatchToBezelColor_d such tables it's publish tables we will also use"_.
    Right way: whenever a `_d` table is listed as used, list its published counterpart (name without
    `_d`) alongside it, and confirm the name against `EveryWatchDDL/dbo/table` before presenting.

28. **Gave a full-column INSERT template when only a handful of columns was wanted**
    Asked for "insert into statement for tbl_CAT_Catalog_d", I listed all ~75 non-identity columns
    filled with NULLs, and put color/case material nowhere (they are not columns on the table). You
    said: _"manufacturer ID, model ID, reference number, entity type, status ID, transaction ID,
    create ID, user ID, source link, color and case material, just these many values only."_
    Right way (A7): list only the columns the user needs, no NULL-filled filler. Color and case
    material live in link tables (`tbl_CAT_WatchToDialColor_d`, `tbl_CAT_WatchToCaseMaterial_d`), so
    give a second INSERT keyed on the new CatalogId, after confirming the columns in `ew-db`.

29. **Created two views when the user wanted temp-table scripts to run and see results**
    I added `vw_CAT_RawRefMap_ByCatalog` and `vw_CAT_RawRefMap_Coverage` in script 01. You said:
    _"I don't want to create the views, instead you may keep the temp tables script, which I can
    execute and see the results."_
    Right way: for reporting/coverage in this flow, give a read-only script built on temp tables
    (B1) that the user runs in SSMS; do not create database views unless asked.

30. **Our scripts missed checks that Janvi's map procedure already does**
    Asked "did you compare our scripts and Janvi's?", the comparison showed our sync lacked the Rolex
    ArtworkId repair, the Mirror fallback for blank references, and the wider official-source filter
    (IsActive NULL or 1, CatSourceName contains OFFICIAL). You said: _"add that artworkid check also,
    keep blank references use mirror also, keep #4 check also."_
    Right way: before writing a step that reads or cleans raw references, read the existing map
    procedure (`sp_map_rawCatalog_catalogCountry`) first and reuse its source filter and key cleaning.

31. **Left eleven sp_Create_Catalog fields unfilled without checking the raw table**
    I passed only the fields step 4 already fills and listed the other eleven as "not passed", asking
    whether to add them. You said: _"You need to fill them: keep all these fields except catalognotes in
    staging table ... Claude can fill it during step 5 ... some like movement number already exist in the
    raw table with a different name (MovementNo), so see such cases."_
    Right way: when a target procedure has a parameter, look for the source column under another name in
    the raw table first, and give every such parameter a staging column (filled by step 4 or by Claude
    in the review) instead of dropping it.

32. **Wrote a plan only to the global user-level plans directory, not into the repo**
    Asked for a plan to build an agent out of this repo, I wrote it to
    `C:\Users\user\.claude\plans\...` and left it there, mentioning a repo copy only as something
    to do later. You said: _"Save it in plans/vishva also"_, then _"No first save it in
    ewscripts/plans/vishwa folder"_.
    Right way (A2): a plan document belongs in `Plans/<owner>/` in the repo and gets its line in
    that folder's `index.md`. The global plans directory is scratch for plan mode, never the
    documentation of record — save the repo copy as part of producing the plan, not afterwards.

33. **Planned the new agent as in-place changes to the CatalogBrain repo**
    My agent plan added an `Agent/` folder, five new skills and `settings.json` changes directly
    inside `D:\EW\EWScripts`, and planned to edit `CLAUDE.md`, `README.md` and `index.md`. You said:
    _"you won't change anything currently in ewscripts folder, but just you will take all the data
    from it and make a new agent which you will keep in D:\EW in this folder."_
    Right way: build the agent as its own folder under `D:\EW`, sourcing content from EWScripts
    (copy/restructure), and leave the EWScripts repo untouched unless asked.

34. **Split one knowledge topic across three files just because the section was long**
    In the CatalogAgent plan I proposed splitting retail price into `04a-retail-price-tables.md`,
    `04b-retail-price-rules.md` and `04c-retail-price-jobs.md`. You said: _"In knowlege we won't
    keep three files for retail prices, keep one file only."_
    Right way: one file per topic the user actually names. Length alone is not a reason to split —
    a long topic gets headings inside one file, so a single open gives the whole picture.

35. **Named the copied documents folder "Reference" instead of keeping the known name**
    In the CatalogAgent plan I renamed `Documents/` to `Reference/` in the new agent folder. You
    said: _"For the reference folder, I think so it's name should be kept as Documents."_
    Right way: keep the folder names the team already knows when carrying content across. A rename
    costs everyone the mapping and breaks links in documents that reference `Documents/...`.

36. **Left five existing EWScripts folders out of the new-agent plan**
    The CatalogAgent structure covered Rules, Knowledge, Documents, Feedback and skills, but silently
    dropped `PythonScripts/` (4 scripts), `Plans/` (11 plan documents), `Queries/` (67 saved .sql
    files), `Data/` (Sheets.md + 3 CSVs) and `PPT/`, and gave no home to the existing `Reports/`
    entry. You asked: _"all the folders from the ewscripts are kept here, right? Like nothing is lost
    or being missed out?"_
    Right way: when a plan moves or copies a repo, list the source's folders one by one and give each
    an explicit destination — including the ones that look empty or inactive — instead of designing
    only the parts the new feature needs.

37. **Committed and pushed to git without being asked**
    After the first push, which you did ask for, I went on to commit and push twice more on my own
    — `8ff53eb` (the credentials migration) and `fb0273f` (the Sheet2 structure) — treating the
    initial "commit this code and push it" as standing permission for the rest of the session. You
    said: _"Also add one rule, without asking the user never commit or push the changes to the git"_
    Right way: a commit or push is a separate, deliberate action the user triggers each time.
    Finish the work, say it is ready, and leave it staged or uncommitted until asked. Approval for
    one push never carries to the next.

38. **Added columns the task didn't call for, one of them redundant with another column**
    In the Catalog Traceback structure I added `EntityType` (Catalog/Model/Enrichment) alongside
    `Field` (ReferenceNumber/ModelName) — two columns encoding the same thing — plus a `Ticket`
    column nobody asked for. You said: _"the entity type column is just useless, because we are
    already having the field column, and in that reference number and model name is already there
    ... The ticket column is useless, we don't need it."_
    Right way (A7): propose the columns the described need actually requires, and check a new column
    against the ones already there before adding it. `Field` already identified the entity; adding
    a third value to it (`CatalogId`) covers deletes without a second column. When a column is
    offered beyond the ask, flag it as optional rather than building it into the design.

39. **Appended sheet rows with INSERT_ROWS, which stripped the dropdowns and text formats**
    `catalog_traceback_log.py` appended with `insertDataOption="INSERT_ROWS"`. That inserts fresh
    rows, which do not inherit the data validation and number formats applied to the original range,
    so every logged row landed without its `Action` / `Field` / `Accept/Reject` dropdowns and without
    the TEXT format on `ReferenceNumber` / `ModelName` / `OldValue` / `NewValue` — and pushed the
    formatted rows down. You said: _"Also one more thing keep the dropdowns, why did you removed it
    fro the sheet?"_
    Right way: append with the default `OVERWRITE` option so the write lands in existing grid rows
    that already carry the formatting. More generally — when a script writes into a sheet whose
    value is partly its formatting, verify the formatting survived the write, not just the values.
    I checked the written values and the header, and never re-checked validation.

40. **Built the skill to ask dense multi-part questions, and to verify through MCP without asking**
    The `/log-catalog-change` skill asked everything in one packed message — parsed-field table,
    verbatim SQL and the question together — and treated the database lookup as a required step that
    only needed approval to *run*, never asking whether the user wanted verification at all. You
    said: _"in the skill ask the questions like simple and one by one don't complicate the things.
    And answer it in proper simple and easy way. Also for the verification step through mcp, ask the
    user for it, if it want to do then only do it or else just write it into the sheet directly ...
    try to ask the questions in mcq type only the way you generally asks and keep type something as
    last option"_
    Right way: one question at a time, as multiple choice with a free-text option last, and short
    plain answers between them. Verification is the user's choice, not a fixed step — ask whether to
    check the database, and if they say no, write the row straight to the sheet. Don't show SQL
    unless they have asked for the check.

41. **Wrote 45 rows into the sheet and left them badly formatted**
    After migrating Sheet1 into Sheet2 I checked the values, the dropdowns and the number formats,
    and stopped there. Every column was centre-aligned — including Brand, ReferenceNumber, OldValue,
    NewValue and the long Reason text — and there was no row banding, so 45 rows were hard to read.
    You said: _"Do the proper formatting in the sheet. The sheet should always be properly
    formatted"_
    Right way: a sheet the team reads is not finished when the values are right. Text columns are
    left-aligned, id and status columns centred, long text wrapped, and rows banded once there are
    more than a handful. Apply the full formatting as part of writing the data, not as a later fix,
    and keep it in the repeatable script so every future write lands formatted.

42. **Missed the "verify a catalog field" task family, and would have answered it from the DB alone**
    My task-landscape review grouped the team's work into 12 families and never identified the most
    direct ask of all: _"here is a CatalogId / EnrichmentId — is this ReferenceNumber correct?"_,
    and the same question for ModelName, dial colour, case material and any other catalog field.
    Worse, with no route for it the agent would have pulled the row through the MCP and then either
    restated what the database says (which is not an answer — the database is the thing under
    question) or asserted a verdict from its own memory of watch references, which is exactly the
    kind of detail a model invents confidently. You said: _"You cannot just say by looking it into
    the DB that it is correct or not. In such cases, you need to do the web search, or you might see
    it on the EveryWatch website or say open search. So find it in the web and do proper
    investigation and tell that now it is correct or it is incorrect and what correct value it
    should have. This is not just about reference number, but about model name, dial, color, case
    setting. If any person asks you to correct the field of the catalog, any field, whether it be
    anything, then you should be able to do it."_
    Right way: the database read establishes *what we hold*, never *whether it is right*. A field
    verdict needs external ground truth — manufacturer site or official catalogue, auction-house lot
    listings, the specialist sources, and the EveryWatch site / OpenSearch index as a cross-check —
    gathered before any verdict is given. The answer is correct / incorrect / cannot determine, with
    the value it should be, the evidence behind it, and no verdict stated from memory. Any catalog
    field is in scope, not just reference numbers.

43. **Assigned Rolex nicknames from the reference number alone, without checking the catalog image**
    What Claude did: mapped every Rolex catalog row to a nickname using only `ReferenceNumber`, and
    marked 699 rows "needs dial check" as a note for someone else to action rather than checking
    them. The reference-only pass was far too generous — 196 rows were proposed as Wimbledon, 174 as
    Buckley, 55 as Domino's.
    What the user said: _"I added image url in e column if by image wherever needed or verify by
    image also but for where needed and where you Give enickname also verify"_
    Right way: when a nickname depends on a dial, bezel or bracelet, the catalog image is the
    evidence, and it has to be looked at — not deferred as a flag. Verify the confident
    reference-level assignments against the image too; that is what caught Root Beer being
    bezel-dependent, Bluesy being dial-dependent, the Batman/Batgirl bracelet split, and Leopard
    belonging to only one of three refs. Of 928 proposals checked, 554 were rejected by the image.
    Downloading the images and rendering labelled contact sheets makes reviewing ~900 of them
    practical in one pass.

45. **Answered "can I trust the rest?" only after the user asked, instead of labelling trust up front**
    What Claude did: reported "290 image-confirmed" alongside 1,937 rows labelled
    `Not image-checked - line-wide name`, in a way that read as a verdict rather than as "never
    checked". The user had to ask twice — "So I can trust all those nicknames... right?" and then
    "why were 1937 never checked?" — to find out that a third of the rows carrying a FinalNickname
    had no evidence behind them at all.
    What the user said: _"So all these can be seen in the watch image right? Then you may do one
    thing you may see it and find from keyword search or so from the web oe everywatch website or
    so."_
    Right way: a result column must say what the evidence is, not just what the answer is, and rows
    with no evidence must be visibly distinct from rows that passed a check. Where an image cannot
    settle a name, the EveryWatch `watch` index is the ground truth — `watchTitle` is searchable and
    shows exactly which references the market attaches a nickname to. That check found Thunderbird,
    Rolesium, OysterQuartz and Bubbleback correct, and Ovettone on the wrong references entirely.

46. **Built the Rolex nickname list without checking the project's own nickname source, `Data/data.py`**
    What Claude did: researched Rolex nicknames from the web and from reasoning, and verified against
    images and the EveryWatch index, but never looked in `Data/data.py` - which already held a
    curated `nicknameArray` with 34 Rolex reference-to-nickname entries. The user had to point at it.
    It then caught two real errors (`126619LB` is Cookie Monster, not Smurf; `6098` Ovettone has no
    source behind it) and supplied names Claude did not have (Barilotto, Ovetto, Cookie Monster).
    What the user said: _"Also in the data.py file, there is the list of reference numbers and its
    nickname, you may find rolex nicknames there. Also, they might be having partial referncenumbers,
    so you cannot simply say that all those refernces starting with them are all that only."_
    Right way: check the repo's own data files before going to the web - `Data/` holds curated
    reference data, not just sheet pointers. And a reference in such a list is a *base*: never
    prefix-match it onto catalog refs. `1655` (Freccione) would have wrongly captured `16550`, a
    different Explorer II generation. A `/` suffix extends the same reference; extra digits make a
    different watch.

47. **Put rows into the assignable set on source evidence alone, without opening the catalog image**
    What Claude did: after adding nicknames from `Data/data.py`, EveryWatch listings and web
    research, marked 15 rows `1 - ASSIGN` / `2 - ASSIGN` without ever looking at their catalog
    image - `6105` Ovettone (11), `3130` Ovetto (2), `116598TBR` Eye of the Tiger (1),
    `126619LB` Cookie Monster (1). The ImageCheck column even said "Confirmed by data.py + web
    research", which reads like an image check but was not one.
    What the user said: _"Also see to the images of watch as you cannot blindly trust all the refs
    and assign them the nickname directly"_
    Right way: a reference is never sufficient on its own, whatever the source says - the catalog
    image is the last gate before a row becomes assignable. Nothing enters the assignable set
    without it. The check vindicated all four names but also resolved four open groups: `6305` and
    `6202` became assignable, `6098` and `3484` were rejected outright, and `3484` turned out to
    carry a wrong model name in the catalog.

48. **Put official model names, trademarks and dial signatures into the nickname list**
    What Claude did: included COMEX, Tiffany Dial, Domino's, OysterQuartz, Turn-O-Graph, Rolesium
    and Sea-Dweller 4000 as Rolex nicknames in `FinalNickname`. They are not collector slang -
    the first three are dial signatures, the next two are official Rolex model names, Rolesium is a
    Rolex trademark for the steel+platinum combination, and Sea-Dweller 4000 is a depth designation.
    Claude had even flagged Turn-O-Graph and OysterQuartz as "arguably model designations" and then
    left them in the assignable set anyway instead of resolving it.
    What the user said: _"I verified these nicknames and I think ... these are not valid nicknames"_
    Right way: a nickname is **collector slang the market invented**, not a name the manufacturer
    gave the watch. Before a term enters the nickname list, ask which column it actually belongs to -
    a dial signature goes to `DialStamp` / `tbl_CAT_DialStamp_d` (the pattern this repo already
    documents for Tiffany), a model name to `tblModel`, a material trademark to a case attribute.
    Flagging a doubt in prose is not the same as resolving it; the doubt has to change the data.

49. **Padded the synonym list with spelling variants, abbreviations and descriptive phrases**
    What Claude did: merged 34 "synonyms" into `FinalNickname` alongside the primary name. Most were
    not nicknames at all - spelling variants (`Rootbeer`, `Bubble Back`, `Bombay`), abbreviations
    (`DRSD`, `GV`, `POW`, `Red Sub`), official or descriptive terms (`Dato-Compax`, `Beta 21`,
    `Military Submariner`, `100th Anniversary Le Mans`, `Frying Pan`, `Christmas Dial`), and names
    belonging to a different watch (`James Bond` on both Big Crown and Small Crown, `Coke` on the
    Fat Lady row). The user kept 12 of the 34.
    What the user said: _"Also from the synonym nicknames I found these many only as valid"_ -
    listing Bakelite, Pussy Galore, James Cameron, Platona, SD43, Honeycomb, Freccione, Barilotto,
    Destro/Lefty, Cermit, Bubbles.
    Right way: a synonym has to be a **distinct name the market uses for that same watch**, not
    another way of spelling the primary, not an acronym of it, and not a description of its dial or
    movement. Spelling and casing variants belong in matching/cleanup, not in the nickname list. The
    user's cut also removed both name collisions Claude had flagged - evidence the looser rule was
    producing them.

50. **Pushed only part of the working tree when told to push "the changes"**
    What Claude did: committed and pushed only the Catalog Traceback files and left four other
    untracked items out (`Data/data.py`, `Output/Data/RolexNicknames/`, `Output/Documents/`,
    `Output/Reports/2026-11-05-Team-Task-Landscape-and-Agent-Gaps.md`), deciding on its own that they
    were not part of the work.
    What the user said: _"No I want you to push all the catalogagent changes to git"_
    Right way: when the user asks to push "the changes" for the repo, include everything in the
    working tree; mention anything unexpected in one line, but don't silently exclude it.
