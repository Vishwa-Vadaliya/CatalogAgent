---
name: brand-ref-agent
description: Build the maximum set of unique, correct, full watch reference numbers for a brand from the RawRefsToAssign Google Sheet — first research the brand's reference numbering in depth (valid structures vs caseback/case/serial numbers), then read the brand data and decide which structures to keep, validate refs, flag partial/duplicate/invalid ones, add watch variations and best images, fill dial/case, find unique variations, check against master values, and generate catalog INSERT statements. Usage — "/brand-ref-agent <Brand>" to start a brand at Step 1b, or "/brand-ref-agent <Brand> from step 4" to resume.
tags: [skills, brand-ref-agent, reference-validation, google-sheets]
timestamp: 2026-10-31
---

# Brand Reference Agent

**Goal:** for the given brand, produce the largest possible set of **unique, correct, full
reference numbers** (no duplicates, no partial or invalid refs), each enriched with dial color, case
material, model name and a primary image, and ending as a catalog-ready `INSERT` statement.

The spec is `D:\EW\Scripts\Queries\Vishva\requirements.md`. The methodology for Step 2 is
`D:\EW\Scripts\Queries\Vishva\Brand_Reference_Validation_Workflow.md`. If this skill and the spec
ever disagree, tell the user instead of picking one.

## Start-up (every invocation)

1. **Read `rules/standing-rules.md` now.** It applies to every step. Read `reference/config.md`
   too. Read `rules/edge-cases.md` and `rules/flag-vocabulary.md` when a step says to.
2. Take the brand name from the user's message. If it's missing, ask.
3. Work out where to start:
   - Look for the brand's existing `<Brand>_Reference_Validation.md` log and
     `<Brand>_Reference_Profile.md` profile in `D:\EW\Scripts\Queries\Vishva\`, and for an existing
     `<brand> final refs` tab.
   - If the user said "from step N", start there. If the brand already has work done and they
     didn't say, **ask which step to resume at**. Don't assume Step 1.
   - **Starting at Step 2 or later with no profile:** say so and run Step 1b first, unless the user
     explicitly says to skip it. Skipping it is the user's call, and the report must say the brand
     rules were not researched.
   - **A new brand starts at Step 1b, not Step 1.** Don't open the brand's data tab until the brand
     research is done.
4. Read **only** the file for the step you're about to run, from `steps/`.

## The steps

| # | File | What | Scripts |
|---|---|---|---|
| 1b | `steps/01b-deep-brand-research.md` | **Runs first.** Deep brand research from the internet only (mandatory): every reference structure the brand uses, which are valid, which numbers are *not* refs (caseback / case / serial / caliber numbers …). Structures that stay `likely` / `unconfirmed` get a **cross-model verification**. Writes the draft brand reference profile. | (none, no data read) |
| 1 | `steps/01-read-brand-data.md` | **Runs after 1b.** Read the brand's refs, raw refs, counts, model names; inventory the structures in the data; test each against the profile (cross-model check for the unsettled ones); **decide which structures to keep**. | `read_brand_data.py`, `ref_structures.py` |
| 2 | `steps/02-validate-and-build-final-refs.md` | Run the validation workflow **using the profile**; flag partial / duplicate / invalid refs in `PartialRefFlag`; build the `<brand> final refs` tab; **note every changed ref (original, what changed, why)**. | `partial_checks.py`, `ref_change_note.py`, `sheets_client.py` |
| 3 | `steps/03-watch-data-layout.md` | The user pastes the watch-variations query output (max possible variations per ref) into the new `<brand> final refs Variation` tab; the agent prepares it (`VariationId`, image columns). Nothing is written into the final-refs tab. | `prepare_variations_tab.py` |
| 4 | `steps/04-pick-best-image.md` | Pick the best primary image **per variation row** (`--key-header VariationId`) with the tilt-checker script. Best picks that are still completely tilted are counted, held back and, as the last resort, replaced by a web image. | `run_image_picker.py`, `web_image_fallback.py` |
| 4b | `steps/04b-fill-dial-and-case.md` | Fill blank DialColor / CaseMaterial from the **image** first, web only if needed (ask first); master values only; ask when a value is not in master. | `sheets_client.py` |
| 4c | `steps/04c-unique-variations.md` | Find the unique variations per ref (dial + case are only a hint; use images, watch counts, and web checks for low-variation refs, asking first). Status in `VariationStatus`. | `sheets_client.py` |
| 5 | `steps/05-master-value-check.md` | List the DialColor / CaseMaterial / ModelName values not in the master list. **Runs three times:** before 4b, right after 4b, and finally on the `Keep` rows before Step 6. | `master_value_check.py` |
| 6 | `steps/06-insert-statements.md` | One `INSERT INTO #CreateCatalogQueue` formula per **kept variation**. | `build_insert_formulas.py` |

Order of the whole run: **1b → 1 → 2 → 3 → 4 (images) → 5 (master check, run 1) → 4b (fill dial/case) → 5 (run 2) → 4c (unique variations) → 5 (final run on `Keep` rows) → 6.**
Before Steps 4, 4b, 4c, 5 and 6 the agent **asks the user for the scope**: the currently filtered rows, all rows, or something else.
The old `layout_watch_data.py` (writes watch data into the final-refs tab) is no longer used in this flow.

Scripts live in `scripts/` (run them with `python <skill folder>\scripts\<name>.py`). Reference
facts are in `reference/` (`config.md`, `final-refs-layout.md`, `brand-profile-template.md`).

## Hard rules (summary; the full list is in `rules/standing-rules.md`)

- **Stop at the end of every step.** Report exact numbers and wait for the user's go-ahead. Never
  open the next step's file before that. The user decides when to move on.
- **Know the brand before judging its refs.** Step 1b (deep research) comes before reading the data and before any validation; the data does not decide what is valid.
  Never flag a ref as partial, duplicate or invalid, and never call a number a case number or
  serial, without the brand reference profile (`<Brand>_Reference_Profile.md`) to back it.
- **Model switching.** Research on reference numbers (Step 1b, the web verification in Step 2, the
  variation web checks in Step 4c) is done by an **Opus 5.5** subagent (`model: "opus"`, read-only,
  full brief); the main session stays on **Sonnet 5.5** and does everything else, including all
  writes. Full rule: `rules/standing-rules.md` #16. Structures that stay `likely` / `unconfirmed` also get
  a **cross-model verification** by an independent Sonnet 5.5 subagent (#18).
- **Ask the scope before Steps 4, 4b, 4c, 5 and 6:** current filter, all rows, or something else (#17).
- **Never run SQL.** The user runs queries and INSERT statements themselves.
- **Every script is a dry run by default.** Show the dry-run output, get the user's OK, then re-run
  with `--write`. Re-fetch the sheet before every write and find rows by ref text, not row number.
- **Flag, never delete.** Flags go in the single `PartialRefFlag` column, in the tab's existing
  wording.
- **Never lose the original ref.** Whenever a final ref is written and it is not identical to the
  original (trimmed, de-spaced, re-cased, re-separated, extracted, generalised, alias mapped ...), write a
  note on the same row: `Original: "<original>" | Changed: <what> | Why: <reason>` (`FinalRefChange` on the
  brand tab, `RefChangeNote` on the final-refs tab). Anything beyond formatting needs a real reason.
  Several originals merged into one ref are all listed; notes are appended, never overwritten. Standing
  rule 19; helper `scripts/ref_change_note.py`.
- **Don't overclaim.** Say what was individually verified and what was accepted by pattern.
- **Completely tilted images are never silently accepted.** Slightly tilted is fine; a best pick that is
  still fully tilted or sideways is reported with its count and, only as the last resort, replaced by
  a web image (own images first, web search last). **Before any web search, tell the user how many
  watches have an improper image and ask whether to go ahead; wait for their yes.**
- Work from the session scratchpad directory for temporary files.

## Logging

After each step (or when pausing mid-step), append a dated section to
`D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Validation.md` (create it if the brand has none).
Keep it short and in the same style as the existing brand logs:

- formats found for this brand and which are current vs vintage
- counts at each step (unique refs, flagged by type, rows filled, statements written)
- decisions the user made and why (scope exclusions, wording choices, accepted risks)
- brand-specific findings worth remembering (flag wording used, `Sheet4` column, manufacturer name)

If a brand turns up a new **kind** of edge case that is not in `rules/edge-cases.md`, tell the user
and offer to add it as a one-line check there. Don't edit the rules without the user's OK.

## Open items

- The master-values workbook is in `reference/config.md`; Step 5 and Step 4b use it.
- `TotalWatchCount` source: the workflow doc says to take it from the brand tab, but earlier work
  sometimes filled blanks from the `WatchIds` count. Ask the user which to use if it comes up.
- `scripts/pick_best_image.py` now holds back best picks that are fully tilted or sideways (default;
  `--write-tilted` writes them). It still writes NOT_WATCH / UNDETERMINED picks and lists them for
  manual review; `--skip-unusable` holds those back too.
