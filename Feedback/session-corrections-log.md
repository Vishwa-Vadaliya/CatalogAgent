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
