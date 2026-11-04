---
type: Plan
title: Build Plan — Brand Reference Agent (`/brand-ref-agent`)
description: Plan for building the brand-ref-agent Claude Code skill — folder/file structure, build order, and how it is tested.
tags: [plans, vishwa, brand-ref-agent, skill-build]
timestamp: 2026-10-24
---

# Build Plan — Brand Reference Agent (`/brand-ref-agent`)

## Context

The brand-by-brand watch-reference work is being turned into a reusable agent. The spec is
`D:\EW\Scripts\Queries\Vishva\requirements.md`. This plan covers **how** the agent is built: the
folder and file structure, what goes in each file, the build order, and how it gets tested.

**Agent form:** a Claude Code **skill** (slash command). It runs in the main conversation, so the
"stop after every step and wait for go-ahead" behaviour works naturally. Usage:

```
/brand-ref-agent <Brand>                         ← start a new brand at Step 1
/brand-ref-agent <Brand> from step 4             ← resume a brand at a given step
```

**Out of scope for this build:**
- Revising `Brand_Reference_Validation_Workflow.md`. That is the next task after this one, and Step 2
  links to the doc so the changes flow in automatically.
- Changing `pick_best_image.py`'s interface. Step 4 edits its constants per run.

---

## 1. Folder & file structure

```
D:\EW\Scripts\.claude\skills\brand-ref-agent\
│
├── SKILL.md
│
├── steps\
│   ├── 01-read-brand-data.md
│   ├── 02-validate-and-build-final-refs.md
│   ├── 03-watch-data-layout.md
│   ├── 04-pick-best-image.md
│   ├── 05-master-value-check.md
│   └── 06-insert-statements.md
│
├── rules\
│   ├── standing-rules.md
│   ├── edge-cases.md
│   └── flag-vocabulary.md
│
├── reference\
│   ├── config.md
│   └── final-refs-layout.md
│
└── scripts\
    ├── requirements.txt
    ├── sheets_client.py
    ├── read_brand_data.py
    ├── partial_checks.py
    ├── layout_watch_data.py
    ├── run_image_picker.py
    ├── master_value_check.py
    └── build_insert_formulas.py
```

**These stay where they are and are referenced by path, not copied:**

| File | Role |
|---|---|
| `Queries\Vishva\requirements.md` | Spec (what the agent must do) |
| `Queries\Vishva\Brand_Reference_Validation_Workflow.md` | Methodology used by Step 2 (one copy only, so revisions apply immediately) |
| `Queries\Vishva\<Brand>_Reference_Validation.md` | Per-brand logs the agent writes or updates |
| `D:\catalog_image_tilt_checker\pick_best_image.py` | Image picker used by Step 4 |

**Why it's split this way:**
- **`steps\`:** the agent reads only the file for the current step. This keeps context small, and
  opening the next file only happens after your go-ahead.
- **`rules\`:** read once at the start. These apply to every step and aren't repeated in each step
  file.
- **`reference\`:** facts that change rarely (IDs, paths, layout). Keeping them in one place means
  one edit when something moves.
- **`scripts\`:** the risky, repeated logic (safe writes, partial checks, layout reshaping) is
  written once and tested, instead of being rewritten in every session.

---

## 2. Contents of each file

### `SKILL.md` (entry point)
- Frontmatter: `name: brand-ref-agent`, plus a description with usage examples.
- Goal in two lines, with a link to `requirements.md`.
- Startup routine:
  1. Read `rules\*` and `reference\config.md`.
  2. Check whether the brand already has a final-refs tab or log, to decide between a new brand and
     a resume.
  3. Confirm the starting step with the user.
- The step index table: step, file, one-line purpose.
- The hard rule: **stop after each step, report numbers, wait for the go-ahead.** Never run SQL.
- At the end of each step: append to the brand's log file.

### `steps\01-read-brand-data.md` → `scripts\read_brand_data.py`
- Find the brand tab and read its headers by name.
- Apply any live filter.
- Compute and report:
  - total rows
  - rows where `ReferenceNumberId` is set, and rows where it's NULL
  - unique `ReferenceNumber` count
  - unique `RawReferenceNumber` count
  - `TotalWatchCount` sum
- **Checkpoint:** scope confirmed by the user.

### `steps\02-validate-and-build-final-refs.md`
- Points to `Brand_Reference_Validation_Workflow.md` and lists its sub-phases in order:
  1. landscape research
  2. Phase A
  3. Phase B
  4. partial/duplicate/invalid detection
  5. build the final-refs tab
  6. structural alignment and dedup
  7. Sheet4 catalog cross-check
- The internal checkpoints between sub-phases stay in place.
- Partial-ref, duplicate and invalid checks use `scripts\partial_checks.py`.
- Every issue is flagged in `PartialRefFlag`, never deleted.
- **Checkpoint:** you review the flags and counts.

### `steps\03-watch-data-layout.md` → `scripts\layout_watch_data.py`
- Ask the user to paste their query output into the final-refs tab, and to say where it was pasted.
- Reshape it into the standard layout:
  - map rows by `ReferenceNumberId`
  - split `Images` into one URL per column
  - add the `SourceLink` and `FinalImage` formulas
  - set the TEXT format
- Report matched refs, unmatched refs and blank fields.
- **Checkpoint:** layout confirmed.

### `steps\04-pick-best-image.md` → `scripts\run_image_picker.py`
- `run_image_picker.py`:
  - Reads the final-refs headers and works out `TAB`, `FIRST_URL_COL`, `R` and the read range.
  - Edits those constants in `pick_best_image.py` after making a backup copy of the script.
  - Runs the **dry run** (CSV only) and summarizes the flags.
  - After your approval, runs with `--write`.
  - Restores the script's original constants afterwards.
- Report the rows whose pick isn't usable (TILTED, HORIZONTAL, NOT_WATCH, UNDETERMINED,
  DOWNLOAD_ERROR) for manual review.
- **Checkpoint:** you review the flagged picks.

### `steps\05-master-value-check.md` → `scripts\master_value_check.py`
- Take the unique `DialColor`, `CaseMaterial` and `ModelName` values (full refs only) and compare
  them with the master list, ignoring case and extra spaces.
- Output, per field: each value not in the master list, its row count, and a near-match suggestion
  where there is one.
- No values are changed without your instruction.
- **Checkpoint:** you fix the values or tell the agent which replacements to make.

### `steps\06-insert-statements.md` → `scripts\build_insert_formulas.py`
- Write one formula per clean full-ref row in the last column, using the template in
  `final-refs-layout.md`.
  - Single quotes inside values are escaped.
  - Flagged rows are skipped.
- Report how many statements were written and how many rows were skipped, with the reasons.
- **Checkpoint:** you run the statements yourself.

### `rules\standing-rules.md`
The 9 standing rules from requirements.md §5:
- re-fetch before writing
- respect the live filter and sort, and find rows by ref text
- no deduplicating by WatchId
- verify a ref from several angles before calling it invalid
- no overclaiming
- TEXT format
- match the tab's existing flag wording
- never delete rows
- when one error turns up, re-check everything for the same failure mode

Also the "never run SQL" rule.

### `rules\edge-cases.md`
requirements.md §6, written as a checklist, one line per check:
- partial detection
- invalid/junk shapes
- typo-detection reliability
- formats
- catalog cross-check
- enrichment
- sheet mechanics

### `rules\flag-vocabulary.md`
- The shared `PartialRefFlag` wording table.
- The rule that a tab's existing wording wins: read a sample of its flags first.

### `reference\config.md`
- Workbook ID
- Service-account key path
- Sheet4 column map (one column per brand, filled in as brands are done)
- Image-script path
- Brand logs folder
- **Master-values link: TBD**
- Manufacturer-name spelling per brand, used in the INSERT statements

### `reference\final-refs-layout.md`
- The standard column blocks.
- The exact formulas:
  - `SourceLink` = `="https://everywatch.com/watch/"&K<row>`
  - `FinalImage` = `=IMAGE(<FinalImageUrl cell>)`
  - the INSERT template, with `StatusId` 1 and `UserID` 6
- The note: if a tab already uses a different order, keep it and read the headers by name.

### `scripts\` (Python helpers)

| Script | What it does |
|---|---|
| `requirements.txt` | `google-api-python-client`, `google-auth` (the image script's own dependencies are already installed) |
| `sheets_client.py` | Shared library: auth from config; `get_headers()` by name; `visible_rows()` replicating `basicFilter`; `find_row_by_ref()`; `safe_batch_write()` that re-fetches, checks each target cell still holds the expected ref, then writes in chunks of 500; `set_text_format()` |
| `read_brand_data.py` | Step 1 scope summary |
| `partial_checks.py` | Prefix check, same-base-up-to-last-separator, embedded fragment, front truncation, short/full-form (optional prefix), Hamming-1 candidate list (marked "needs verification", never auto-flagged) |
| `layout_watch_data.py` | Step 3 reshape |
| `run_image_picker.py` | Step 4 wrapper around `pick_best_image.py` |
| `master_value_check.py` | Step 5 comparison |
| `build_insert_formulas.py` | Step 6 formulas |

Rules for every script:
- Each script prints its counts.
- Each script supports `--dry-run` (the default) and needs `--write` to change the sheet.
- No script ever deletes rows.

---

## 3. Build order

1. `reference\config.md`, `reference\final-refs-layout.md`
2. `rules\standing-rules.md`, `rules\edge-cases.md`, `rules\flag-vocabulary.md`
3. `scripts\sheets_client.py`, then test it read-only against an existing final-refs tab
4. The other scripts, each tested in `--dry-run` mode against an existing, finished brand tab
5. `steps\01` … `steps\06`
6. `SKILL.md`, last, once everything it points to exists

---

## 4. Verification

- **Read-only test on a finished brand.** Run Steps 1, 3, 5 and 6 in dry-run against a brand that's
  already complete (e.g. Jacob & Co. or Credor). The scripts' output should match what's already on
  the sheet: same counts, same INSERT text, same layout.
- **Partial-check regression.** `partial_checks.py` must re-find the known cases from past brands:
  the last-separator partials, the short/full-form duplicates and the catalog matches already
  flagged.
- **Image wrapper.** Dry run only on a small `--limit`. Confirm the constants are set correctly and
  restored afterwards.
- **Skill invocation.** Run `/brand-ref-agent <finished brand> from step 5` and confirm it:
  - reads the rules
  - reads only the step 5 file
  - stops at the checkpoint
- **No writes during testing** unless you approve one.

---

## 5. Open items carried over from requirements.md

- Master-values link, which Step 5 needs before it can run for real.
- TotalWatchCount source rule (brand tab vs `WatchIds` count).
- Revising the workflow doc (next task).
- The image script still writes picks it marks as not usable. These are handled by manual review
  for now.
