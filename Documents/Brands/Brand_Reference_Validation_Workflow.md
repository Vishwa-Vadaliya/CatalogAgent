---
type: Document
title: Brand Reference Validation & Enrichment — General Workflow
description: Generalized step-by-step workflow for validating and enriching brand reference numbers in the RawRefsToAssign Google Sheet, used by the brand-ref-agent skill.
tags: [documents, workflow, reference-validation, brand-ref-agent, google-sheets]
timestamp: 2026-10-24
---

# Brand Reference Validation & Enrichment — General Workflow

This document generalizes the process followed across all brand tabs worked on so far
(Bovet, Credor, Daniel Roth2, Louis Vuitton, Jacob & Co.) in the
**RawRefsToAssign** Google Sheet (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`).

Goal: given only a brand tab name, run through these steps without needing each one
re-explained. The one thing that legitimately varies brand-to-brand is the specific
validation heuristics/edge cases (see Step 3) — flag those for user input when unsure,
but everything else below is standard operating procedure.

## Tooling setup (do this once per session)

- Access is via the Google Sheets API using a service-account key
  (`C:\Users\user\.secrets\ew-sheets-sa.json`), through Python
  (`google-api-python-client`, `google-auth`) — there is no native Sheets MCP tool.
- Do all work from the session scratchpad directory. Never touch the local `ew-db`/Scripts
  repo for this — it's unrelated.
- Standard header layout across brand source tabs:
  `WatchId, ModelId, RawReferenceNumber, ModelName, ReferenceNumberId, ReferenceNumber, TotalWatchCount, '', FinalRef/Finalref`
- Reads: `spreadsheets().values().get()`. Writes: `.values().update()` (single range) or
  `.values().batchUpdate()` (many ranges, chunked at ~500 per call). Structural changes
  (insert column, number format, background color, checkbox data validation) go through
  `spreadsheets().batchUpdate()` with `insertDimension` / `repeatCell` requests.
- Always set the ref/FinalRef column to **TEXT** number format before writing, so values
  like `Q1111` or `330.100.1` don't get misparsed as numbers/dates.

## Standing rules (apply throughout, not just once)

1. **Always re-fetch the live sheet immediately before any write.** The user edits the
   same sheet concurrently; rows, filters, and columns can shift between turns. Never
   write based on a stale in-memory snapshot from earlier in the conversation.
2. **Replicate the sheet's live filter server-side, never assume row order.** A user's
   "current filter" must be read from the sheet's `basicFilter` object
   (`filterSpecs[].filterCriteria.hiddenValues` per column index) and applied
   programmatically to determine exactly which rows are visible. Confirm the computed
   visible-row count matches the number the user stated before proceeding.
3. **Never use `WatchId` as a signal for duplicate detection.** Duplicate/partial-vs-full
   ref judgments must be based on reference text (normalized), image, dial color, and
   case material — never WatchId, which does not reliably indicate whether two rows are
   the same physical watch.
4. **Verify before declaring something invalid/unconfirmed.** Never call a reference
   "unconfirmed" after a single missed search. Try multiple angles: brand + ref alone,
   ref + specific auction houses (Christie's, Sotheby's, Bonhams, Antiquorum), ref +
   "case number", site-specific searches (chrono24, eBay, official brand site). Only
   after several genuinely different angles come up empty should something be treated
   as unconfirmed.
5. **Don't trust unsourced claims inside a WebSearch summary.** A search tool's prose
   summary can assert "X is confirmed to be Y" without any of the actually-returned
   source links backing that specific claim. Always cross-check that a claimed
   confirmation is attributable to one of the returned URLs/titles before accepting it.
   If a summary sentence has no matching link, treat it as unconfirmed, not confirmed.
6. **Don't overclaim confidence level.** If a large bucket of refs was accepted on
   *structural pattern* grounds (matching a convention confirmed via a sample of
   individually-verified refs) rather than each one being individually traced to a
   source, say so plainly when asked "are you sure" / "did you verify all of these."
   Pattern-based confidence and per-item external verification are different claims —
   never blur them.
7. **Small thumbnails lie about tilt/rotation.** When judging "is this photo tilted /
   is this the same watch," a small comparison thumbnail can look fine but actually be
   an angled/perspective shot. Escalate to full-resolution single-image comparison
   whenever a pick is even slightly ambiguous, and proactively re-check comparisons
   done at small thumbnail size if a systematic image-comparison pass just happened.
8. **When asked "how sure are you," answer with numbers, not vibes.** State exactly how
   many refs were individually source-confirmed vs. accepted by pattern/convention, and
   what would be required to close the gap (e.g. "would take N more search batches").
9. **Ask permission before starting each phase/step — don't chain the whole workflow
   autonomously.** Given just a brand tab name, run Step 0 (brand-level landscape
   research) through to completion on its own and report back, then wait for the
   go-ahead before starting Phase A (Step 1's `ReferenceNumberId != NULL` pass). Phase A
   likewise runs to completion on its own, but then **stop and report** rather than
   continuing into Phase B (the `RawReferenceNumber` pass, Step 4) or into later steps
   (duplicate detection, populating a final-refs tab, dedup listing, etc.)
   without being told to proceed. Each major phase/step gets its own explicit go-ahead —
   see the checkpoint at the end of Step 0, the end of Step 3, and the note at the top of
   Step 4.

## Step 0 — Brand-level reference landscape research (before touching the sheet)

Before looking at any row of the sheet, spend a research pass understanding the brand's
reference numbering **at the catalog/manufacturer level** — this is separate from, and
comes before, Step 2 (which looks at structural *format* once you're already working with
the sheet's own values). Step 0 is about the brand overall, not this sheet's data yet.

1. **Check what's on the manufacturer's current official site/catalog.** Identify which
   reference formats and prefixes represent the brand's **current, in-production**
   lineup (e.g. Piaget's `G0A` SKUs today) versus formats that only ever appeared in
   **discontinued/vintage** lines. Note the approximate era each format belongs to if it's
   discoverable (e.g. "vintage numeric + suffix, mostly 1960s–1990s" vs "modern dot/SKU
   notation, 2000s–present").
2. **Identify every coexisting convention**, not just the dominant one — brands often ran
   multiple valid systems in parallel (a modern SKU system alongside a legacy short-code
   system for older lines still sold or serviced). Don't assume the newest-looking format
   is the only valid one, and don't assume the oldest-looking format is automatically
   invalid just because it's no longer produced — discontinued is not the same as invalid.
3. **Research general validity signal, not individual refs yet.** At this stage the goal
   is a brand-wide picture (what formats exist, which are current vs. vintage, roughly how
   reliable each is to verify online), not confirming specific values from the sheet —
   that per-value work happens later in Step 2/3 once the sheet's actual unique values are
   in hand.
4. **Report this landscape to the user before proceeding to Step 1.** Summarize plainly:
   what reference formats exist for this brand, which are the manufacturer's current
   catalog format(s), which are vintage/discontinued, and an honest read on how well each
   format tends to be individually documented online (some vintage brands are sparsely
   indexed outside auction houses — flag that expectation now rather than after Step 5's
   confidence tracking surfaces it). Wait for the user's acknowledgment/go-ahead before
   moving into Step 1's row-level scoping work.

## Step 1 — Establish scope: which rows and which unique values

The user now only needs to give a **brand tab name** — nothing else. The default entry
point and phase order is fixed and should be run without being re-explained each time:

1. **Phase A default filter: `ReferenceNumberId != NULL`.** Confirm the target tab and
   read its header row to identify the relevant columns (`ReferenceNumber`,
   `RawReferenceNumber`, `ReferenceNumberId`, `FinalRef`, etc.) — column order is not
   always identical across brand tabs, so don't assume positions. Do not wait for the
   user to state a row count or set a filter themselves — compute the
   `ReferenceNumberId != NULL` visible set directly (per Standing Rule 2, still read the
   sheet's live `basicFilter` if one already exists and reconcile with it; otherwise
   just compute the row set from the raw column values). State the resulting row count
   back to the user as confirmation of scope before doing anything else.
2. From that row set, pull the `ReferenceNumber` column and compute the **unique
   values** with counts (`collections.Counter`). Work off the unique set, not every
   row — this collapses a population of thousands of rows down to a tractable few
   hundred/thousand distinct values to validate, then maps results back to all matching
   rows at the end. This is "Phase A" — see Steps 2–3 for how to validate it and the
   checkpoint at the end of Step 3 for the handoff to Phase B (the `RawReferenceNumber`
   pass).

## Step 2 — Understand the brand's real reference-number convention(s)

Before validating anything, spend a handful of searches establishing the brand's actual
reference format(s), because:
- A brand may have **more than one** valid convention (e.g. Jacob & Co. has a modern
  dot-notation system like `EX110.20.AA.AJ.A` *and* an older short-code system like
  `JC-1` / `JCM24DA` / `H24` for earlier lines — both are genuine, neither is "the"
  pattern).
- Structurally similar-looking strings are not automatically all valid or all invalid —
  confirm the convention with real examples pulled from the sheet's own data, across a
  few different frequency tiers (very common, moderately common, rare), not just the
  single most common value.
- Watch out for **look-alike but different fields**: a code that matches the reference
  format structurally might actually be a *date code*, *factory/manufacture code*,
  *serial number*, or *limited-edition counter* rather than a true model reference
  (e.g. Louis Vuitton's 2-letter+4-digit codes are a universal date-code stamp system
  used across all product categories, not a distinct model reference — confirmed by
  cross-referencing against LV's own published factory-code table). Don't assume a
  structural match is a semantic match; verify what the code actually denotes.

## Step 3 — Validate the unique reference values (Stage 1)

This is the step that varies most by brand — bring edge cases to the user when a
judgment call isn't clear-cut. The general procedure:

1. **Structural triage first.** Bucket unique values by pattern: (a) values that cleanly
   match a confirmed convention, (b) short/atypical codes needing individual checks,
   (c) obvious non-candidates (plain English phrases, brand/model names entered as if
   they were refs, pure short numbers, fraction-style limited-edition counts, hashes,
   serial numbers). This triage should be done programmatically (regex) so the
   individual-verification effort concentrates on the ambiguous middle, not the whole
   list.
2. **Batch WebSearch the ambiguous bucket.** Group several refs per query
   (`Brand "REF1" OR "REF2" OR "REF3" OR ... model line`) to cover ground efficiently,
   then re-check anything not resolved by the grouped pass with individual, more
   targeted queries (brand + ref alone, ref + auction house names, ref + "case number").
   Apply Standing Rules 4–5 throughout.
3. **When a user pushes back with "are you sure" / "I found a source" / "this looks
   valid":** re-run the check with a different angle rather than defending the original
   call, and if the user supplies a specific link, fetch it directly (`WebFetch`) and
   quote exactly what it says before accepting or rejecting the correction.
4. **Mark checkboxes / write validity flags** as instructed (e.g. a `Stage1Valid`
   boolean column with data-validation checkboxes) rather than only reporting in chat,
   so the validity call is durably recorded on the sheet.
5. **Two-stage framework, when the brand/tab calls for it:** Stage 1 is per-ref external
   validity. Stage 2 (when requested) is whole-column duplicate detection plus deeper
   cross-source verification — treat these as sequential, separate passes, not one
   combined pass.

### Checkpoint — end of Phase A

Once the `ReferenceNumber` column (`ReferenceNumberId != NULL` population) has been
validated and `FinalRef` written for the valid ones, **stop.** Report to the user:
how many unique values were found, how many rows got a `FinalRef`, how many/which were
excluded and why. Explicitly ask them to check the result. **Do not start Phase B
(Step 4, the `RawReferenceNumber` pass) until the user confirms** — this is a hard gate,
not a formality to rush past.

## Step 4 — Extracting FinalRef from RawReferenceNumber (Phase B — only after user confirmation)

Only begin this step once the user has reviewed Phase A's output and told you to
proceed. Some rows have `ReferenceNumberId = NULL` — meaning the system couldn't cleanly
match them to a catalog reference — with only a **raw, unstructured** text field to work
from. General procedure:

1. Filter to that population (`ReferenceNumberId = NULL`, i.e. whatever Phase A's
   filter excluded) by computing it directly, the same way as Phase A.
2. Get unique `RawReferenceNumber` values (there is usually heavy duplication here too).
3. Build a **cleanup/extraction pipeline**, in this rough order of preference:
   - Exact match against the *already-confirmed-valid* set from Step 3 — highest
     confidence, no new verification needed.
   - Normalize obvious formatting noise: strip stray internal spaces around
     separators, fix a stray delimiter right after a model-code prefix, convert a
     hyphen to the brand's real segment separator where it clearly plays that role,
     strip a leading garbage prefix (e.g. a brand name accidentally concatenated on
     front) or a trailing appended serial/production-run suffix.
   - **Reconstruct missing separators** for fully-concatenated strings by matching the
     brand's known segment-length structure (e.g. Jacob & Co: 2–3 letter code + 3
     digits + 2 digits + 2-char + 2-char + suffix) — but only accept a reconstruction
     when the material/dial-code segments actually contain letters, not just digits
     (pure-digit "reconstructions" are usually just serial numbers coincidentally the
     right length, not real refs).
   - Cross-check a fully-stripped-of-punctuation ("dotless") version of the raw value
     against a dotless lookup built from the already-confirmed valid refs — a match
     there is strong reconstruction evidence.
   - Anything left is either genuine unstructured noise (serial numbers, placeholder
     text like "TBD"/"Unknown"/"Custom", limited-edition counters, generic material
     notes like "MOP", brand/collection names entered as if they were refs, foreign-
     language text, hashes) — leave blank, don't guess.
4. Re-verify a live sample of target cells immediately before writing (Standing Rule 1),
   then write only to the `FinalRef`/`Finalref` column — never touch other columns
   unless explicitly asked.
5. Report back precisely: how many rows got a value, how many were left blank and why
   (with representative examples of each exclusion category), and flag anything found
   that looks like a **wrong-category** entry (e.g. a jewelry/earring reference showing
   up in a watch reference column) rather than silently dropping it.

## Steps 5–7 are separate, later asks — not auto-chained after Phase B

Steps 5 (duplicates), 6 (populating a final-refs tab), and 7 (dedup-ignoring-punctuation)
are each their own distinct request the user makes once they're ready for that stage of a
given brand — usually in a later message, sometimes a later session. Don't infer that
finishing Phase B means "now also do duplicate detection." Treat each as needing its own
go-ahead, exactly like the Phase A → Phase B gate above. It's fine to *offer* the natural
next step in one line once a phase is done (the way the checkpoint after Phase A does), but
wait for an explicit yes before starting it. Picking the primary image is not part of this
workflow — it is done separately, outside this document.

## Step 5 — Duplicate / partial-vs-full ref detection

When asked to check a column of "final" refs for duplicates:

0. **Add a single `PartialRefFlag` column, and record every finding of this step in it only.**
   Place it directly after the reference column of the list being checked (on a
   `<brand> final refs` tab, the column next to `Referencenumbers`), set it to TEXT format, and
   leave it blank for clean full refs. If the tab already has a `PartialRefFlag` column, reuse
   it — never add a second one. Every duplicate and partial ref found below (and any invalid ref
   from the sweep in point 5) gets its flag written into this one column, using the tab's existing
   flag wording if it has any. Don't use other columns, checkboxes, or highlights for this, and
   never delete the flagged row.
1. **Never rely on WatchId** (Standing Rule 3). Compare normalized ref text, image,
   dial color, and case material.
2. **Partial vs. full ref** (a distinct, simpler check the user may separate out): treat
   ref A as "partial" if some other ref B in the same set is a **case/whitespace-
   insensitive prefix match** of A with extra trailing characters (e.g. `QA172` is
   partial because `QA172A` exists). Compute this exhaustively (all-pairs) over the
   *normalized* strings so hidden case/space duplicates aren't missed. When reporting,
   list which fuller ref(s) each partial one relates to, but flag genuinely short base
   codes (2–4 chars) that happen to prefix many unrelated-looking refs as needing a
   closer look — a prefix match doesn't always mean redundancy (e.g. `Q1121` legitimately
   coexists with `Q11210`/`Q11211`/`Q11215` as distinct chronograph variants, not
   truncated duplicates of each other — check the actual specs before assuming either
   direction).
3. **Image/dial/material-based duplicate check** (the deeper check, when the user wants
   true "same physical watch" duplicates, not just text-prefix relationships): build
   comparison pairs, download the relevant images, and compare them at a generous size
   (≥180px per thumbnail), escalating to full-resolution single images whenever a pair is
   ambiguous (Standing Rule 7). Flag the partial/redundant one in `PartialRefFlag` once
   confirmed, and always re-verify uncertain cases (skeleton dials described as one color,
   diamond-bezel vs. plain, bracelet vs. strap, different dial art) rather than assuming a
   shared image family means duplicate.
4. Re-run recheck passes when the user reports even one specific error — a single
   caught mistake usually means the same failure mode affected other rows too; don't
   fix only the reported instance in isolation.
5. **Do a dedicated invalid-ref sweep as part of this step, not just partial-vs-full.**
   A loose classification regex (e.g. `\d{3,6}[A-Z0-9]{1,10}` for "base + suffix") will
   happily accept things that are not references at all. Before calling Step 5 done,
   explicitly check the working set for each of these shapes, not just at Step 3/4 time
   but again on the final, merged list:
   - **Hash/ID strings masquerading as a suffix ref**: long hex-looking strings (e.g. a
     16-character `[0-9A-F]` string) that happen to fit the length envelope of a real
     base+suffix ref. Real suffixes are short (1–4 chars); anything materially longer
     is almost certainly a database hash/GUID fragment, not a reference.
   - **Ref + serial/case-number concatenated with *no* separator.** The separator-based
     strip (space/dash/slash) only catches part of this family — also check for a
     recognizable, already-confirmed base+suffix as a *prefix* of a longer string, with
     a trailing run of 4+ digits (or more junk) left over. Strip to the confirmed prefix.
   - **Third-party movement/caliber codes stuck onto a real ref** (e.g. `AS` = A. Schild,
     a vintage ebauche movement supplier — look up what *any* unexplained 2–3 letter
     code actually stands for before assuming it's part of the brand's own reference
     convention). A code from an unrelated supplier/brand is never part of a valid ref;
     strip it or exclude the row if the result is ambiguous.
   - **Word/brand-name/material junk appended or embedded** (e.g. `RARE`, `OVAL`,
     `FLAT`, `DELIVERY`, `PIAGET`, `18K`, `WG`, weight-in-grams) — strip to the
     recognizable ref, exclude if nothing recognizable remains.
   - **Two distinct refs joined together** (by a space, slash, or even the word "AND") —
     do not guess which one is "correct"; exclude the row as ambiguous and say so.
   - **Literal placeholder text** (`XXX`, `TBD`, redacted-looking digit runs) — exclude.
   Treat this sweep as mandatory, not optional, on the final merged list — run it again
   after every merge/rewrite, since merging can surface new length/shape outliers that
   weren't visible when the same bad value was just one of many near-identical rows.
6. **Surface every invalid/ambiguous ref found to the user immediately, with the
   proposed action, rather than silently dropping or silently keeping it** — state
   plainly "found N invalid refs of shape X, here's what I'll do", and only proceed
   once the pattern is clear. Do not wait for the user to stumble onto a bad value
   after the fact; a dedicated sweep (point 5) should surface it first.
7. **Regex discipline — verify behavior, don't assume it.** A single mis-escaped
   anchor (e.g. a stray `\$` instead of `$` for end-of-string) silently turns an
   "ends here" check into "must contain a literal character", which can make an
   exclusion/classification filter match nothing without raising any error. After
   writing any filter/classification regex that will gate an exclude-or-keep decision
   on live data, sanity-check it against a known-should-match and a
   known-should-not-match example before trusting its output, and explicitly print
   the resulting counts to confirm they look plausible (e.g. "excluded 63, expected
   ~63" — not "excluded 15" when 78 were expected) rather than trusting a silent run.

**Downstream rule established from this step: once refs are flagged partial vs. full,
every step after this one (Step 6 onward — ReferenceNumberId/WatchIds population and the
Step 7 structural/dedup checks) operates on the *full* refs
(`PartialRefFlag` blank) only. Partial refs are excluded from further work, not deleted —
they stay on the final-refs tab as a record, just outside the working set for everything
downstream of this point.**

## Step 6 — Creating the "final refs" tab and populating ReferenceNumberId / WatchIds

Don't wait for the user to create the `<brand> final refs` tab — create it yourself as
part of this step, the same way the ones for Louis Vuitton, Credor, and Jacob & Co. were
made:

1. Create a new sheet/tab named `<brand> final refs` (match the casing/naming style
   already used for other brands in this workbook, e.g. `credor final refs`,
   `louis vuitton final refs`, `Jacob&co. final refs`) via `batchUpdate` `addSheet`.
2. Populate column A (header `Referencenumbers`) with the unique, confirmed-valid
   `FinalRef` values from the brand's source tab (the output of Steps 1–4) — this is
   the same unique-value set already computed during validation, so reuse it rather
   than recomputing from scratch.
3. Insert `ReferenceNumberId` and `WatchIds` columns after column A — or after
   `PartialRefFlag` if Step 5 already added it there — (`insertDimension`) and set them to
   TEXT format.
4. Build a lookup from the **source brand tab**, grouping by `FinalRef`/`Finalref`:
   for each unique ref, collect the set of `WatchId`s and the (should-be-single)
   `ReferenceNumberId`. Flag and report any ref with more than one distinct
   `ReferenceNumberId` as ambiguous rather than silently picking one.
5. Write `ReferenceNumberId` and a comma-separated `WatchIds` string per row. Report
   the match rate (e.g. "612/612 matched, zero ambiguous") so the user knows the
   mapping was clean.
6. If the tab also carries a `TotalWatchCount` column, source it from the matching
   column in the main brand tab (not computed from the WatchIds count) — verify by
   spot-checking existing rows for the actual relationship before assuming.

## Step 7 — Deduplicating a "final refs" list ignoring whitespace/special characters

This step operates on the **full refs only** — exclude anything flagged `PartialRefFlag`
in Step 5 before doing any of the following (see the note at the end of Step 5).

### Step 7a — Structural (separator-position) alignment check, done *first*

Before running the dedup/duplicate check itself, check whether the working set's
reference strings share a consistent **segment structure** (where the separators —
dots, hyphens, etc. — fall relative to letters/digits), and flag any ref whose separator
placement doesn't match the dominant structure for its apparent segment lengths.

Example: if the working set is mostly `[3 chars].[2 chars].[rest]` (e.g. `123.ol.ijgkg`,
`562.jh.iuytr`, `458.lk.ujedw`) but one ref reads `123.oli.jgkg` (dot after 3 chars
instead of 2), that's very likely a misplaced separator, and the corrected form should
match the dominant structure (`123.ol.ijgkg`-style split), not be left as-is.

- Bucket refs by structural "shape" (e.g. digit/letter-class + separator-position
  fingerprint, similar to the length/structure fingerprinting used in Step 2/3) and look
  for a ref whose shape is a near-miss of a much more common shape — i.e. same
  characters, same total length, just the separator one or two positions off.
- This is a **proposal, not an automatic fix.** Compile every ref you think has a
  misplaced separator, together with the corrected form and the dominant pattern it's
  being aligned to, and **show this list to the user before writing anything.** Only
  apply the corrections once the user has reviewed and approved them — never silently
  "fix" a reference's internal structure.
- After approved corrections are applied, re-run the normalized-duplicate check below,
  since fixing a separator can turn a previously-distinct-looking ref into an exact
  duplicate of another.

### Step 7b — Dedup ignoring whitespace/special characters

When asked to list unique values from a `FinalRef` column while ignoring whitespace and
punctuation for the purpose of dedup:

1. Normalize every non-blank value by stripping all non-alphanumeric characters and
   upper-casing, and group by that normalized key.
2. Within each group, choose a representative spelling to display — prefer a properly
   formatted variant (e.g. one that retains the brand's real separator characters) over
   a mangled one, falling back to the most frequently-occurring raw spelling.
3. Report the before/after counts (e.g. "5,961 non-blank values → 1,714 unique after
   normalization") so the collapse is visible, not just the final list.

## Communicating progress and honesty about confidence

- Give exact progress numbers when asked mid-task ("21 of 36 pages done"), not vague
  reassurance, and don't stop working while answering a status question unless asked to.
- When a large volume of refs is accepted by structural-pattern confidence rather than
  individual verification, say so explicitly and offer (without being asked) to run the
  more exhaustive one-by-one pass if the user wants that level of rigor — and be clear
  about the cost (roughly how many more search batches it would take).
- Never claim "confirmed on a manufacturer/external source" for anything that was only
  pattern-matched. If pushed on a specific value, re-verify it properly rather than
  defending the original classification.
