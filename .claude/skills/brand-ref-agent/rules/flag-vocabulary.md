---
type: Rule
title: PartialRefFlag wording
description: Rules for how to word the PartialRefFlag column — match the tab's existing style, the shared vocabulary for new tabs, and what a blank flag means.
tags: [skills, brand-ref-agent, rules, flag-vocabulary]
timestamp: 2026-10-31
---
# `PartialRefFlag` wording

## Rule 1: the tab's existing wording wins

Before writing any flag, read a sample of the tab's current `PartialRefFlag` values and reuse that
style. `partial_checks.py` prints the tab's existing flag values with their counts for this.

- Tabs that use **descriptive sentences** keep using sentences.
- Tabs that use **short tags** keep using tags.

## Rule 2: for a new tab, use the shared set

| Situation | Short-tag style | Sentence style |
|---|---|---|
| Truncated version of a fuller ref in the set | `Partial` | `Partial - full ref present: <full ref>` |
| Duplicate (case, space or punctuation only) | `Duplicate` | `Duplicate of <ref>` |
| Unconfirmed, likely typo | `Invalid` | `Invalid - unconfirmed, likely typo of <ref>` |
| Not a reference at all | `Junk` | `Junk - <reason>` |
| Already in the catalog | `Already in catalog (Sheet4: '<catalog ref>')` | same |
| Catalog holds the base, final refs hold the full ref | `Base ref <X> already present in catalog (Sheet4) as partial` | same |

For a new tab, ask the user which style to use (short tags or sentences) before writing any flags.

## Rule 3: what blank means

A blank `PartialRefFlag` means a clean full ref. Only blank rows go on to Steps 3–6. Flagged rows
stay on the tab as a record and are never deleted.

## Rule 4: never overwrite an existing flag automatically

If a row already has a flag and a new one would differ, list the row for the user instead of
replacing the flag. `partial_checks.py --apply` only fills blank cells.

## Rule 5: a changed ref is noted, not flagged

`PartialRefFlag` describes the **row** (duplicate, partial, invalid, already in catalog). It is not
where a changed value is explained. When a final ref differs from its original (trimmed, re-cased,
re-separated, extracted, generalised ...), the change goes in the note column (`FinalRefChange` on the
brand tab, `RefChangeNote` on the final-refs tab), format
`Original: "<original>" | Changed: <what> | Why: <reason>`. See standing rule 19. A row can have a
blank flag and a note (a clean ref that was tidied), a flag and no note (a duplicate left as it was), or both.
