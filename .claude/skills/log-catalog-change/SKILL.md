---
name: log-catalog-change
description: Record a manual catalog change in the Catalog Traceback sheet — take what the user says ("deleted catalog 217141, duplicate of 235922"), ask anything missing one simple question at a time, optionally check it against the database, and append the row. Usage — "/log-catalog-change <what you changed>", or "/log-catalog-change" on its own to be asked.
tags: [skills, log-catalog-change, catalog, traceback, change-log, google-sheets]
timestamp: 2026-11-05
---

# Log a catalog change

**Goal:** turn one sentence from the user into one correct row in the **Catalog Traceback** log,
asking as little as possible along the way.

**Repo root:** the folder containing `Knowledge/` and `Rules/` — every path below is relative to it.

**Single source of truth:** `Knowledge/workflows/catalog-traceback.md` holds the vocabulary, the
lookups, the verification rules and the fill patterns. `Data/Sheets.md` holds the column layout.
Read the workflow file first and follow it. This skill only sequences the work.

## How to talk to the user

This matters as much as the steps. Get it wrong and the skill is annoying to use.

- **One question at a time.** Never stack two questions in one message.
- **Always multiple choice**, using `AskUserQuestion`, with the options the user is most likely to
  pick. A free-text option comes last, so they can always type their own answer.
- **Short, plain answers between questions.** A line or two. No tables of parsed fields, no SQL
  unless they asked for the database check, no restating what they just told you.
- **Don't ask what you can infer.** If the user said "catalog 217141", you know the entity and the
  id — don't confirm it back at them.
- Save the detail for the final preview, which is the one place it belongs.

## Hard rules

- **Never write to the database.** The grant is read-only, stage, `EWMaster` only.
- **The database check is optional and the user chooses it** — see step 3. Don't run it, and don't
  show SQL, unless they asked for it.
- When they do ask for it, show the query before running it. A1 allows **one** approval covering the
  lookups for a single logged change, provided every query is shown verbatim in that ask. That
  carve-out is for this skill only.
- **Never write to the sheet without a preview and an explicit yes.**
- **`EnrichmentId` is left blank** and never placeholdered.
- A warning never blocks — but if the user overrides one, the override goes into the `Reason`
  column, not just the chat.
- Don't commit or push unless asked.

## Steps

1. **Parse what the user already said.** From `/log-catalog-change deleted catalog 217141,
   duplicate of 235922` take `Action=Deleted`, entity=catalog, `CatalogId=217141`,
   `MergedIntoId=235922`, `Reason`, `Field=CatalogId` — and ask nothing.
   Also handle `renamed A to B`, `A -> B`, quoted values and relative dates.
   - `ChangedBy` from `git config user.name` (A2: Ravi / Vishva / Janvi). Never asked.
   - `Date` defaults to today. Shown in the preview, not asked.

2. **Ask for anything genuinely missing — one question each, multiple choice.**
   Only ask for what you cannot infer. Typical gaps and their options:

   | Missing | Question | Options |
   |---|---|---|
   | Action | What did you do to it? | Renamed / Deleted / Merged into another row |
   | Entity, on a bare number | Is 217141 a catalog row or a model? | Catalog row / Model |
   | NewValue on a rename | What is it now? | *(free text — ask plainly)* |
   | Reason | Why was it changed? | the two or three most likely reasons for that action, e.g. for a delete: Duplicate / Invalid reference / Caseback number, not a reference |

   If nothing is missing, skip straight to step 3.

3. **Ask whether to check it against the database.** Always this question, always these options:

   > **Check this against the database first?**
   > - **Yes, check it** — reads the row on stage to fill in brand and reference, and confirms the
   >   change actually landed
   > - **No, just log it** — writes what you told me straight to the sheet

   - **"No"** → go to step 5. Brand, reference and model stay blank unless the user typed them.
     That is fine; the row is still a valid log entry.
   - **"Yes"** → step 4.

4. **Only if they said yes:** show the lookup query, ask once to run it, then run and verify.
   - 0 rows → say so plainly and ask whether to log it anyway.
   - More than 1 → show the candidates and ask which. Never auto-pick the Active one.
   - Verify per workflow §6, and report the result in one or two lines — not a report.

5. **Preview the row** as a labelled list of all 15 columns, with blanks shown as blank. If the
   database was checked, one short line per check. Then ask:
   **append / edit a column / cancel.**
   - On an overridden warning, append `[unverified: <what the DB showed> on stage <date>]` to
     `Reason` before writing.

6. **Append** with `PythonScripts/catalog_traceback_log.py` — dry run, then `--write`:

   ```
   python PythonScripts/catalog_traceback_log.py --record "<json>"
   python PythonScripts/catalog_traceback_log.py --record "<json>" --write
   ```

   It checks the header, snapshots the tab, flags duplicates, appends with `RAW`, and puts back the
   number formats the append drops.

7. **Report in one line:** which row it landed on, plus the sheet link.

## Batch

When the user pastes several ids: **one action and one field per batch**.

- Ask the database-check question once for the whole batch, not per row.
- If checking: one query with `WHERE CatalogId IN (…)`, shown in full, one approval. Compare the
  returned row count against the ids asked for — a truncation at the 500-row cap otherwise looks
  like "these ids don't exist".
- One compact preview, one line per row, with an `OK`/`WARN` flag and a `12 OK, 2 WARN` summary.
- Offer `append all` / `append OK only` / `cancel`.
- Cap 50 rows per confirmation; the script enforces it.

## Resuming

Nothing to resume — each invocation logs one change (or one batch) and ends. To correct a row
already written, edit it in the sheet rather than appending a second row, and say which row changed.
