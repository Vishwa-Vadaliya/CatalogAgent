---
name: image-match-review
description: Review the manufacturer-wide image match (type 5) and the multiple-ENR image similarity (type 1) for one brand — ask the setup questions, write the five SQL queries for the user to run, create and prepare the brand's Google Sheet from the template, and fill the FINAL SUMMARY once the user has pasted the results. Usage — "/image-match-review <Brand>".
tags: [skills, image-match-review, enrichment, multiple-enr, google-sheets]
timestamp: 2026-10-30
---

# Image match review

**Goal:** for the given brand, hand the user the queries, give them a ready Google Sheet in the standard
layout, and fill its `FINAL SUMMARY` after they paste the results and (optionally) review them.

**Repo root:** the folder where `CatalogBrain` is cloned (the one containing `Knowledge/` and `Rules/`) — every `Knowledge/`, `Rules/`, `Queries/` and `PythonScripts/` path below is relative to it.

**Single source of truth:** `Knowledge/Image_Match_Review_Workflow.md` (in the repo root)
holds the questions, query table, template id, tab map and every formula. Read it first and follow it.
This skill only sequences the work; don't copy its content here.

## Hard rules

- **Never run any SQL**, even if the user says go ahead. Write the `.sql` and hand it over (`Rules/00-core.md` A1).
- Follow `Rules/10-sql-style.md` for query style (temp tables, NOLOCK, headers, no `DECLARE`) and verify tables/columns
  against `D:\EW\ew-db` before writing SQL. Never modify `ew-db`.
- Same sheet layout for every brand. Never invent the "Earlier" %, the threshold or the sample size — ask.
- Creating a Drive file and sharing it are outward actions: confirm with the user first.

## Steps

1. **Take the brand** from the message; ask if missing.
2. **Ask the setup questions** (workflow section 1): scope (both reviews or one), exact manufacturer name,
   current threshold, sample size per band, person folder (Ravi / Vishva / Janvi). The "Earlier" % can wait until
   the summary step.
3. **Write the queries** into `Queries/<Person>/<Brand>/` (rule A2). Adapt the reference queries listed in the
   workflow table by changing only `#Params` (brand, threshold, sample size, enrichment type) and the tab named in
   each header comment. Use the neutral tab names from the workflow. Tell the user the run order and which tab and
   cell each result is pasted into.
4. **Create the sheet:** after the user confirms, copy the template (`copy_file`) as
   `ManufacturerWideImageMatch <Brand>`. Ask the user to share it with the service account as Editor, then run
   `PythonScripts/prepare_review_sheet.py <key.json> <new sheet id> <Brand>`. The service-account key is a file on the
   user's machine; ask for its path, never store it in the repo. Read the sheet back and check what the workflow's
   rules of thumb say (neutral tab names, no other brand's name, every needed tab exists).
5. **Wait for the user to paste the results.** When told they are pasted, read the sheet (Drive connector for values,
   Sheets API read-only for formulas) and report which tabs have data and which are still empty before filling anything.
6. **Fill `FINAL SUMMARY`** with the workflow's formulas (sections 1, 2, 3, 4, 5). Leave section 6 examples and the notes
   to the user. Ask for the "Earlier" % and put it in `F8` only if the user gives one.
7. **Report:** the key numbers, anything inconsistent (e.g. a figure the user quoted that differs from the sheet) and
   what is still missing. Don't commit or push unless asked.

## Resuming

If the brand already has a folder in `Queries/<Person>/<Brand>/` or a sheet named `ManufacturerWideImageMatch <Brand>`,
say so and ask which step to resume at instead of starting over.
