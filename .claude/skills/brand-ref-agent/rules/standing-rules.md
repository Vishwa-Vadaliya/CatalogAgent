---
type: Rule
title: Standing rules (apply in every step)
description: Hard rules the brand-ref-agent skill follows in every step — never run SQL, re-fetch before writes, respect filters, verify before flagging, never delete.
tags: [skills, brand-ref-agent, rules, standing-rules]
timestamp: 2026-10-31
---
# Standing rules (apply in every step)

1. **Never run SQL** against any database, with any tool, even if the user says "go ahead". When
   data must come from the DB, the user runs their own query and pastes the result into the sheet.
   INSERT statements are written as sheet formulas for the user to run.
2. **Re-fetch the live sheet right before every write.** The user edits the sheet at the same time.
   Never write from a snapshot taken earlier in the conversation or in an earlier step.
3. **Respect the live filter and sort. Find rows by ref text (on the variations tab: by `VariationId`),
   never by cached row number.**
   - Read visibility from the sheet itself (`visible_row_numbers()` in `sheets_client.py`). When the
     user quotes a count, confirm it matches.
   - Some tabs have a live sort tied to the filter, so rows move between calls.
   - All writes go through `safe_batch_write()`, which re-reads the key column, finds each target
     row by exact ref text, and skips any ref that is missing or appears more than once.
4. **Never use `WatchId` to decide duplicates.** Use normalized ref text, image, dial color and case
   material.
5. **Verify from several angles before calling a ref invalid or unconfirmed:**
   - the official brand site
   - brand + ref alone
   - auction houses (Christie's, Sotheby's, Bonhams, Antiquorum)
   - dealer sites (chrono24, eBay)

   One missed search proves nothing. Accept a search-summary claim only if one of the returned
   links actually backs it.
6. **Don't overclaim confidence.** State how many refs were individually confirmed and how many
   were accepted by pattern. Answer "how sure are you" with numbers.
7. **Set ref columns to TEXT format before writing**, so values like `330.100.1` don't become
   numbers or dates.
8. **Match the tab's existing flag wording** (see `flag-vocabulary.md`).
9. **Never delete rows. Flag them** in `PartialRefFlag`.
10. **One reported error means the whole set gets re-checked** for the same failure mode, not just
    that row.
11. **Every script runs as a dry run by default.** Show the dry-run summary, including sample
    target cells so the ref/row alignment can be checked, and get the user's OK before re-running
    with `--write`.
12. **Stop at the end of every step.** Report exact counts and wait for the go-ahead. Never open the
    next step's file without it.
13. **Work from the session scratchpad directory.** Never put scratch files in a git repo.
14. **Know the brand's reference numbers before judging any value.** Run Step 1b (deep brand
    research) **first, before reading the brand data**, and keep the brand reference profile. The data
    tab does not decide what is valid. Every ref structure in the data must be classified
    there (valid current / valid vintage / alias / not a reference / unknown) with evidence. A number is
    only called a caseback, case or serial number when the profile shows how that number is recognised.
15. **Image picks: own images first, web last; never accept a completely tilted best pick.** Report how
    many best picks are fully tilted or sideways. Search the web only for those references, and only
    after the own-image pick has been made, and **only after telling the user the count ("N watches
    have an improper image and need a web search") and getting their yes.** A web image is checked
    with the same tilt test and the user is told it is external.
16. **Research on reference numbers runs on Opus 5.5; everything else stays on Sonnet 5.5.**
    - "Research" means judging what a reference number is or whether it is real: Step 1b (deep brand
      research), the web verification in Step 2 (rule 5), and the web checks of variations in Step 4c.
    - How: start the research as a subagent with the Agent tool and `model: "opus"` (Opus 5.5,
      `claude-opus-5-5`). Brief it fully (brand, the exact refs, what to verify, the profile and rules
      it needs), because it knows only the brief. It does **read-only** research and returns findings
      with the links that back them. It does **not** write to any sheet.
    - When the findings come back, the main session (Sonnet 5.5, `claude-sonnet-5-5`) reads them, applies
      standing rules 5 and 6 (verify, don't overclaim) and does every sheet write itself. Sonnet 5.5 is
      the default for all other work (layout, image picks, filling values from images, formulas, logs).
    - Say in the report which findings came from the Opus research run.
    - If the Agent tool or the Opus model is unavailable, say so and ask the user. Don't quietly do the
      research on Sonnet.
    - Image-based work (Step 4b) is not reference research, so it stays on Sonnet. Web searches that
      Step 4b needs for a dial / case are also done by the main session.
17. **Ask the scope before Steps 4, 4b, 4c, 5 and 6.** Ask: "current filter, all rows, or something else
    (a list of refs / VariationIds)?" Wait, state the exact row count for that scope and get it confirmed,
    then use it for every dry run and write in the step. Don't assume the filter and don't assume "all".
    In Step 4c, if the filter shows only some of a reference's variations, say so and ask whether to widen
    to whole references.
18. **Cross-model verification of unsettled structures.** Any reference structure or rule whose confidence
    is `likely` or `unconfirmed` (Step 1b section 3, Step 1 item 6) is checked by a fresh Sonnet 5.5
    subagent, independent of the Opus researcher and **not told the first answer**. It becomes `confirmed`
    only when the models agree **and** a link you opened backs it. Agreement without a link stays `likely`;
    disagreement stays `unconfirmed` and goes to the user with both answers. Never use it to downgrade a
    confirmed claim without re-opening the link. Check all unsettled structures, not a sample.
19. **Never lose the original ref: every change between an original ref and the final ref carries a note.**
    - Whenever a final ref is written and it is **not identical** to the original (trimmed, de-spaced,
      re-cased, separators standardised, extracted from longer text, a prefix or suffix dropped,
      generalised, an alias mapped, a look-alike character fixed, scientific notation decoded), write a
      note on the same row saying **what the original was, what changed, and why.**
    - Columns: `FinalRefChange` on the brand tab (next to `FinalRef`), `RefChangeNote` on the
      `<brand> final refs` tab. Format: `Original: "<original>" | Changed: <what> | Why: <reason>`.
    - Formatting-only changes (whitespace, case, separators, unicode) get a standard reason. **Anything
      else needs a real reason from you** (rule applied, profile section, user's decision, confirming
      link). Do not write a note without one, and do not write the final ref without its note.
    - When several originals collapse into one final ref, the surviving row lists all of them.
    - A blank note means the final is identical to the original.
    - Never overwrite an existing note. If the final changes again, **append**, so the path from the
      original to the final stays readable.
    - Use `scripts/ref_change_note.py` (dry run first; it blocks any judgement change that has no reason).
    - This is separate from `PartialRefFlag`: the flag says the row is a duplicate, partial or invalid;
      the note says the value was altered and why. A row can carry both.
