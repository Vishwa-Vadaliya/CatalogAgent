---
type: Skill Step
title: Step 4 — Pick the best primary image
description: Fills FinalImageUrl with the best candidate image per row using the skill's tilt-checking pick_best_image.py script.
tags: [skills, brand-ref-agent, steps, images]
timestamp: 2026-10-31
---
# Step 4 — Pick the best primary image

**Runs on the `<brand> final refs Variation` tab (Step 3), one pick per variation row.** The picker finds rows
by `VariationId`, so always pass `--key-header VariationId` (the same flag goes to
`web_image_fallback.py`; the `ref` column in its candidates CSV then holds `VariationId`s). This step
comes **before** filling dial colour / case material and before finding unique variations: the best
image is what Step 4b looks at.

## First: ask the scope

Before doing anything in this step, ask the user: run it for **(a) the rows currently visible under
their filter, (b) all rows, or (c) something else** (a list of refs / `VariationId`s, a range)? Wait for
the answer, then state the exact row count that scope gives and get it confirmed. Use that scope for
every dry run and write in the step. Never assume the filter, and never assume "all". Filter scope: the picker only reads visible rows (default). All rows: add `--all-rows` to
`run_image_picker.py` (it then ignores the filter). A list: the user filters the tab to those rows first.

**Purpose:** fill `FinalImageUrl` with the most upright, clearest image out of each row's first 5
candidates, using this skill's `scripts/pick_best_image.py`. A best pick that is **still completely
tilted** is not accepted: it is counted, reported, and, as the very last resort, replaced by an image
found on the web (see "Tilt gate and web fallback" below).

That script is the old `D:\catalog_image_tilt_checker\pick_best_image.py` with the **same picking
logic** (scoring, CLIP not-watch check, choice of the lowest score), but taking the tab and columns
as arguments instead of hardcoded values. The old script is left untouched and is no longer used.
It still imports `check_tilt.py` from `D:\catalog_image_tilt_checker\`.

## Do

1. Run the wrapper as a **dry run** (the picker writes only a CSV). Use `--limit 20` first for a
   quick sanity check on a new tab:

   ```
   python <skill>\scripts\run_image_picker.py --tab "<brand> final refs Variation" --key-header VariationId [--first-url-col X] [--limit 20]
   ```

   `--first-url-col` is auto-detected when omitted (the first column right of `FinalImageUrl` holding
   single image URLs); the detected column is printed, so check it.

   The wrapper reads the tab's headers to find the key column and `FinalImageUrl`, checks that the
   candidate columns hold URLs, then runs `pick_best_image.py` with those columns. Outputs go to
   `D:\catalog_image_tilt_checker\runs\<tab-slug>\`.
2. Read the summary together with the user:
   - rows picked, and the picked-flag counts (`OK`, `BORDERLINE`, `UNDETERMINED`, `TILTED`,
     `HORIZONTAL`, `NOT_WATCH`, `DOWNLOAD_ERROR`)
   - **not usable** rows: anything other than `OK` / `BORDERLINE` needs a manual look
   - a warning if the CLIP box/non-watch check failed for some images (they were treated as
     watches)
3. Know how the picker behaves:
   - It only processes rows visible under the sheet's current filter, across the whole sheet (no
     row cap).
   - It leaves cells that already hold a URL alone.
   - A digit 1–5 in the cell is treated as a hand pick and replaced with that slot's URL. Any other
     text (e.g. `NULL`) is replaced with the best pick.
   - **Tilt gate (default):** a best pick that is FULLY TILTED (`TILTED`) or SIDEWAYS (`HORIZONTAL`) is
     **not written**; the cell stays empty, the count is printed, and the reference goes into
     `needs_web.csv`. Add `--write-tilted` to write those picks anyway.
   - `NOT_WATCH`, `UNDETERMINED` and `DOWNLOAD_ERROR` picks are still written and listed for manual
     review, unless `--skip-unusable` is given.
   - It needs several minutes per few thousand images (CPU only).
4. After the user's OK, run again with `--write` (plus `--skip-unusable` if the user wants it).
   Before writing, the picker re-reads the live sheet and re-locates every target row by its ref
   text. Rows that moved are written where the ref now is, and rows whose cell changed since the
   analysis are skipped and listed. It saves a timestamped backup of the old cell values next to
   the CSV.

## Tilt gate and web fallback (last resort)

Slightly tilted is fine. What is not fine is a **best pick that is still completely tilted**: tilted
beyond `--tilt-ok-deg` (default 30 degrees) with the symmetry check agreeing, or lying sideways. The
picker classifies every best pick: `UPRIGHT` (within 5 degrees), `SLIGHT` (accepted), `FULLY TILTED`,
`SIDEWAYS`, `NOT A WATCH`, `UNDETERMINED`, `DOWNLOAD ERROR`, and writes the class into
`pick_results.csv` (`tilt_status`, `needs_web`).

Order of work, never reversed:

1. **Own images first.** Pick the best of the reference's own candidates (the normal run).
2. **Report the tilted ones.** Tell the user how many best picks are fully tilted or sideways, and
   list them (`needs_web.csv`). This is part of the report even if the user does not ask for it.
3. **Ask the user before any web search.** Say it plainly: "N watches have an improper (completely
   tilted) best image and would need a web search. Should I go ahead?" Then **stop and wait**. Do not
   search, do not prepare candidate URLs, until the user says yes. If they say no, the references stay
   empty for a manual pick. (`web_image_fallback.py --candidates` refuses to run without
   `--user-approved`, which is passed only after the user's yes.)
4. **Web search is the last step**, and only for those references, after the user's yes:
   - `python <skill>\scripts\web_image_fallback.py --tab "<brand> final refs Variation" --key-header VariationId --list` shows each one
     with its model, dial and case for the search.
   - The agent searches the web (brand + exact ref; dealer, auction and official pages) for a
     straight front view of the dial and saves the image URLs it found as `ref,url,source_page`.
   - `python <skill>\scripts\web_image_fallback.py --tab "<brand> final refs Variation" --key-header VariationId --candidates <file> --user-approved`
     is a dry run: it downloads each candidate, rejects small images (`--min-side`, default 400),
     tilted or sideways ones and box/non-watch ones, and picks the best acceptable image per
     reference. It ignores any reference that is not in `needs_web.csv`.
   - After the user's OK on the result, re-run with `--write`. It re-reads the sheet, writes only into an empty
     `FinalImageUrl`, and saves a backup of the old values.
5. **Say what is left.** Report how many references got a web image, how many have candidates but
   none acceptable, and how many have none; those stay empty for a manual pick.

Web images come from other sites. The source page of each is saved in `web_fallback_results.csv`;
tell the user that those images are external.

## Report

Rows written; **how many best picks are fully tilted / sideways (and held back)**; the other
not-usable picks with ref, row and flag; web-fallback results if that step ran; where the CSVs and
backups are.

## Checkpoint

**Stop.** The user reviews the not-usable picks (and fixes them by hand if they like). Then read
`steps/04b-fill-dial-and-case.md`.
