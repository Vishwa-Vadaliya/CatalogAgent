---
type: Skill Step
title: Step 2 — Validate and build the final refs
description: Validates references using the brand reference profile and the general workflow doc, ending with a clean or flagged "<brand> final refs" tab.
tags: [skills, brand-ref-agent, steps, validation]
timestamp: 2026-10-31
---
# Step 2 — Validate and build the final refs

> **Model:** the reference research in this step runs on **Opus 5.5** (a read-only subagent with `model: "opus"`); the main session stays on Sonnet 5.5 and does all sheet writes. See `rules/standing-rules.md` #16.

**Purpose:** end with a `<brand> final refs` tab where every row is a clean full ref (blank
`PartialRefFlag`) or is flagged with a reason.

## Before anything else: the brand reference profile

**Read `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Profile.md` first.** It comes from Step 1b and
is this step's rulebook: which structures are valid references, which numbers are caseback, case,
serial or other non-reference numbers, which pairings must be flagged on both sides, and which
sources can confirm a ref.

- **No profile, or the user skipped Step 1b?** Stop and run `steps/01b-deep-brand-research.md`
  (unless the user explicitly says to go without it, and then say so in every report).
- **The profile counts as workflow Step 0** (landscape research). Do not repeat that step; the
  profile is the deeper version of it.
- A structure in the data that the profile does not cover: **stop and extend the profile** with
  evidence before flagging it.
- Do not treat a number as a case number, serial or other non-reference unless the profile says how
  that number is recognised and cites evidence.

## Method: follow the workflow document

`D:\EW\Scripts\Queries\Vishva\Brand_Reference_Validation_Workflow.md`

**Read it now, in full**, then follow it in its own order. It is the current version, so don't
work from memory or from an earlier copy. Its sub-steps, with this skill's helpers:

| Workflow step | What | Helper |
|---|---|---|
| Step 0 | Brand-level landscape research | **done in Step 1b** (the profile) |
| Steps 1–3 | Phase A: validate `ReferenceNumber` where `ReferenceNumberId` is set; write `FinalRef` **and its `FinalRefChange` note** | `sheets_client.safe_batch_write`, `scripts/ref_change_note.py` |
| Step 4 | Phase B: extract `FinalRef` from `RawReferenceNumber` where RNId is NULL (**every extraction is a change: note it**) | `sheets_client.safe_batch_write`, `scripts/ref_change_note.py` |
| Step 5 | Duplicate / partial / invalid detection into **one `PartialRefFlag` column** | `scripts/partial_checks.py` |
| Step 6 | Create the `<brand> final refs` tab; fill `ReferenceNumberId`, `WatchIds`, `TotalWatchCount` and **`RefChangeNote`** | `sheets_client.add_sheet`, `insert_column`, `set_text_format`, `safe_batch_write` |
| Step 7 | Separator alignment (7a) and punctuation-insensitive dedup (7b); **append** to `RefChangeNote`, never replace it | `partial_checks.py` (the `normalized_duplicate` type), `scripts/ref_change_note.py` |

**Also read now:** `rules/edge-cases.md` (the checklist) and `rules/flag-vocabulary.md` (the flag
wording). Every detection pass runs against that checklist.

## Record every change to a ref (applies to every write of a final ref)

A final ref is often a **cleaned** version of what the data held: trimmed, de-spaced, re-cased,
re-separated, extracted from a longer string, a junk prefix or suffix dropped, generalised (a slash
suffix dropped, a karat or base ref chosen), an alias mapped, a look-alike character fixed. The final
value is fine, **but the original must never be lost and the reason must be on the row.**
Standing rule 19 is the full rule. In this step it means:

- **Wherever a final ref is written, write a change note next to it** whenever the final value is not
  identical to the original:
  - the brand tab (workflow Steps 1-4, the `FinalRef` column): note column **`FinalRefChange`**, to the
    right of `FinalRef`;
  - the `<brand> final refs` tab (workflow Step 6, the `Referencenumbers` column): note column
    **`RefChangeNote`** (column S in the standard layout, see `reference/final-refs-layout.md`).
- **Note format** (one line, `|`-separated, so it can be filtered):
  `Original: "<original>" | Changed: <what> | Why: <reason>`.
  - **What** names every change in order: `trimmed 1 leading and 2 trailing whitespace`,
    `removed internal spaces`, `changed to upper case`, `separators changed from space to dot`,
    `removed leading text "JL"`, `removed trailing text "/172.8.79.S"`, `added leading text "Q"`,
    `replaced look-alike character(s): "O" -> "0"`, `decoded from scientific notation`,
    `value replaced by a different reference`. Quote removed text exactly as it was written,
    punctuation included.
  - **Why** is the reason. Formatting-only changes get a standard reason automatically. **Any other
    change needs a real reason written by you** (the rule that applied, the profile section, the user's
    decision, the link that confirmed it), for example `junk prefix JLQ on a Q-ref already in the
    catalog` or `user rule: a slash suffix may be dropped`.
  - **Several different originals that collapse into one final ref** (a dedup): the surviving row lists
    all of them, `Originals (3): "a" ; "b" ; "c" | Changed: ...`, so nothing is lost when the other rows
    are flagged `Duplicate`.
- A blank note means the final value is **identical** to the original.
- **Never overwrite an existing note.** If the final ref changes again later (for example in workflow
  Step 7 separator alignment), **append** the new change to the existing note instead of replacing it,
  so the full path from the original to the final stays readable.
- **Helper:** `scripts/ref_change_note.py` fills the note from the original and final columns. It
  describes the mechanical changes by itself and **will not write a row whose change needed judgement
  until you supply the reason** (`--reason-col`). Dry run by default, as every script is.

```
python <skill>\scripts\ref_change_note.py --tab "<brand>" --orig-col RawReferenceNumber --final-col FinalRef \
       --note-col FinalRefChange [--reason-col <reason column>] [--out <scratchpad>\notes.csv]
# after the user has seen the dry run and the blocked list:  add --write
```

- Report the counts every time: how many finals were unchanged, how many have a formatting-only note,
  how many have a judgement note, and how many are still blocked for want of a reason.
- This is a different thing from `PartialRefFlag`: the flag says the *row* is a duplicate / partial /
  invalid. The change note says the *value* was altered from its original and why. A row can have both.

The workflow's own checkpoints still apply: **stop after the landscape research**, **after
Phase A**, and before each later sub-step.

## Running the checks (workflow Step 5)

```
# dry run: findings per type + CSV, no writes
python <skill>\scripts\partial_checks.py --tab "<brand> final refs" --catalog "Sheet4:<col>" --out <scratchpad>\findings.csv

# after the user has reviewed the findings: write flags for the approved types only
python <skill>\scripts\partial_checks.py --tab "<brand> final refs" --catalog "Sheet4:<col>" \
       --apply --types normalized_duplicate,last_separator,catalog_exact --style tags|sentences [--add-flag-col]
```

- The script **lists** `prefix`, `many_prefix` and `hamming1` candidates but they need verification
  (specs, official site, web search). `hamming1` can never be applied automatically.
- `--apply` only fills **blank** `PartialRefFlag` cells and never deletes anything.
- Ask the user for the flag **style** (tags or sentences) unless the tab already has flags; match
  the tab's existing wording.
- Compare `--catalog` findings with the user's `Sheet4` column. Flag the **catalog side too**
  where the workflow calls for it (e.g. `Sheet4` column next to the catalog refs), writing with
  `sheets_client.safe_batch_write` after the user agrees the wording.
- After flags are written, **re-run the dry run on the whole tab** (edge-case rule: a clean result
  is only true for that moment).

## Report

Per phase: counts (unique values, rows given a `FinalRef`, excluded and why); **how many finals differ
from their original and how they split (formatting-only / judgement / blocked, see "Record every change
to a ref")**; then per flag type:
how many, with examples; what was verified individually vs accepted by pattern (Standing Rule 6);
and anything ambiguous (more than one `ReferenceNumberId` for a ref, scope exclusions).

## Checkpoint

**Stop** after each workflow phase as the document says. At the end of this step the user reviews
the flags and counts. Then read `steps/03-watch-data-layout.md`.
