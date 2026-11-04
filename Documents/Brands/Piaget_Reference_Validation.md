---
type: Document
title: Piaget — Reference Validation Notes
description: Notes on Piaget watch reference-number validation — the four confirmed coexisting reference formats and related validation decisions.
tags: [documents, piaget, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Piaget — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Piaget` (35,221 rows) · Working tab: `Piaget final refs` (4,436 rows, final)

## Reference conventions confirmed valid

Four coexisting, genuine Piaget formats — confirmed individually via multiple sources:

1. **`G0A` + 5 digits** — modern Richemont-era SKU format (e.g. `G0A41003`, `G0A51031`).
   Note: the sheet's source data mixes `G0A` (correct, digit zero) and `GOA` (letter O) —
   both spellings were kept in `FinalRef` as originally entered, but normalized to `G0A` when
   written into the `Piaget final refs` tab's `Referencenumbers` column.
2. **`P1` + 4–5 digits** (+ optional single-letter suffix) — Possession line (e.g. `P10402`,
   `P10098A`). **This entire category (267 refs) was later removed** from the working list by
   explicit user decision (a scope exclusion, not a validity call — `P10402` and others were
   individually confirmed real).
3. **Bare vintage numeric** (3–6 digits, e.g. `9154`, `902`, `921`, `924`) — a complete,
   standalone reference, confirmed to represent the **leather-strap** configuration of a model.
4. **Vintage numeric + suffix** (e.g. `7131C701`, `9706A6`, `80564K81`) — the same base model
   on a **metal bracelet**; the suffix is a bracelet/case-material code. Confirmed explicitly:
   *"the base number alone is used when the watch is on a leather strap, and the suffix is
   appended when it's on a metal bracelet."* **Bare and suffixed forms of the same base are
   not duplicates of each other** — this was the single most important recurring judgment call
   for this brand, re-confirmed individually many times (`902`/`921`/`924`/`9025`/`9021`/`9023`
   as genuinely distinct models; `7131`/`7131C701`; `74101`/`74101A6`).
5. **Secondary formats confirmed real but low-volume**: `DV####-##` (jewelry/Extra-flat line,
   e.g. `DV4479-33`), `GGP98###` (a secondary catalog cross-reference code paired with vintage
   refs, e.g. `91545 P31 (GGP98024)`).
6. **No systemic vintage→`G0A` renumbering exists.** Explicitly researched and ruled out: `G0A`
   is the brand's *current, ongoing* catalog (Polo FortyFive, Altiplano Origin, Possession,
   Emperador Coussin), not a renaming of 1960s–80s vintage models. A small number of
   individual rows (`34011`→`G0A34011`, `15027`→`G0A15027`, `15173`→`G0A15173`,
   `30107`→`G0A30107`, `27050`→`G0A27050`, `48022`→`G0A48022`, `32120`→`G0A32120`) were
   confirmed — via matching `ModelName` in the source data — to be isolated data-entry errors
   (the `G0A` prefix dropped), not evidence of a systemic conversion. Those 7 bare-digit rows
   were flagged partial and removed from the working list; 4 other coincidental bare/`G0A`
   digit matches (`80564`/`G0A80564`, `20000`/`G0A20000`, `41544`/`G0A41544`,
   `41545`/`G0A41545`) were confirmed genuinely different watches and kept as-is.

## Phase A / Phase B scope

- **Phase A** (`ReferenceNumberId != NULL`): 28,948 rows → 3,539 unique values.
- **Phase B** (`RawReferenceNumber`, `ReferenceNumberId = NULL`): 6,273 rows → 3,243 unique
  values, 422 resolved by exact dotless match to an already-confirmed Phase A value.
- A **data-corruption bug** was found and fixed: 14 `RawReferenceNumber` cells had been stored
  as actual numbers in the original source sheet, so Google Sheets auto-parsed text like
  `"9236 E47"` into scientific notation (`9.236×10⁵⁰`). Decoded deterministically
  (`mantissa × 10^exponent`, confirmed exact for all 14) and corrected, e.g. `9.24E+50` →
  `9236 E47`, `1.52E+27` → `15244 E23`.

## Step 5 — duplicate/partial detection (extensive)

- **333 pure spacing/punctuation-variant groups** collapsed (e.g. `9706A6`/`9706 A6`/
  `9706 A 6` are the same reference) — resolved by enforcing one canonical pattern sheet-wide:
  **fully concatenated, no spaces/dots/hyphens** (e.g. `16033M401D`, not `16033 M 401D`).
- **166 + 5 + 3 = 174 genuine truncated-data-entry duplicates** found via prefix-containment
  (a low-frequency short form that's a near-exact prefix of exactly one dominant full form,
  e.g. `84023K`→`84023K81`, `9902 D`→`9902D2`, `80327K`→`80327K81`). All marked
  `PartialRefFlag` on the source tab, excluded from the working list — never deleted.
- **~2,822 bare/suffix pairs classified as NOT duplicates** by the leather-strap/bracelet
  convention — a representative sample (~70+ individual pairs) was web-search-verified with
  zero contradictions found; the rest accepted by structural pattern, disclosed as such.
- **99 "ambiguous" short-code prefix candidates** (a short code prefixing *multiple* unrelated
  longer codes) — concluded to be the same false-positive shape as the confirmed `902`/`921`/
  `924` pattern (the very fact that one short code matches many unrelated full codes is itself
  evidence it's a real standalone base, not a truncation of any one of them). No action taken.
- **94 ambiguous `ReferenceNumberId` cases** (one ref text, two different catalog IDs) —
  comma-joined per user instruction, later trimmed to a single ID (the one with the larger
  associated `TotalWatchCount`) when the user asked for VLOOKUP compatibility.

## Invalid-ref sweep (critical lessons — see also the main workflow doc's Step 5 rules)

A loose classification regex let several classes of invalid "reference" through; found via a
user-driven full-length audit and fixed in multiple rounds:

- **Hash/GUID strings misclassified as a suffix ref** (e.g. `415001DEE2FDB438`, a 16-char hex
  string) — excluded.
- **Ref + serial number concatenated with no separator** (not caught by the earlier
  separator-based strip) — e.g. `7131C70141545`→`7131C701`, `761C701405252`→`761C701`.
  Recovered by matching the longest known-valid prefix and stripping the trailing digit run.
- **Third-party movement/caliber codes stuck onto a serial, not a real ref at all**: `AS` =
  A. Schild, a vintage ebauche movement supplier — the `<8-digit><AS><5-digit>` shape (63
  entries, e.g. `40991244AS08218`) was pure case/movement serial data, not a Piaget reference.
  All excluded.
- **Word/material/brand-name junk appended**: `927PIAGET`→`927`, `9451D2OVAL`→`9451D2`,
  `930DELIVERY`→`930`, `9154JADE`→`9154`, `8393MOP`→`8393`.
- **Gold-purity notation appended** (ends in a literal karat figure, e.g. `915418K`→`9154`,
  `12431A618K`→`12431A6`) — 13+ instances found and stripped. Carefully distinguished from the
  *real* `K`+digits suffix convention (`K81`, `K60`), which never ends in bare `K`.
  **Regex bug caught mid-fix**: an initial check for "digit sequence ending in K" was too loose
  and flagged legitimate `K81`/`K60`-style suffixes as false positives — fixed by anchoring
  strictly to end-of-string (`\d{1,2}K$`, literal trailing `K` with nothing after it).
- **Two distinct refs joined together** (by space, slash, or the word "AND") — excluded as
  ambiguous rather than guessed, e.g. `81684AND9154`, `9930THIN90930`.
- **A genuine regex-escaping bug**: `\$` instead of `$` for an end-of-string anchor silently
  made an exclusion filter match nothing (reported "excluded 15" when 78 were expected). Caught
  by comparing expected vs. actual counts rather than trusting a silent run — now a standing
  rule in the workflow doc (sanity-check every classification regex against a known match and
  non-match example before trusting its output).

**Final state**: 4,436 rows, all passing a strict, sanity-checked validation against the five
confirmed conventions above, re-verified clean across every reference length (3–11 characters)
with zero remaining normalized-duplicate keys.

## Confidence tracking

A `ConfidenceLevel` column was added to the working tab: **45 rows marked "Individually
confirmed"** (explicitly returned in a cited search result during this work), the remaining
rows marked **"Pattern-matched only"** (fits a confirmed convention, not itself individually
searched) — except `G0A` refs, where the "Pattern-matched only" flag was removed entirely per
explicit instruction (user is confident in `G0A` validity as a category).

## Column layout used (`Piaget final refs`)

`Referencenumbers, ConfidenceLevel, ReferenceNumberId, WatchIds, TotalWatchCount` — simpler
than the other brands' final-refs tabs since no image-picking pass has been run yet for Piaget.

## Not yet done

- Step 8 (image picking) has not been started for Piaget.
