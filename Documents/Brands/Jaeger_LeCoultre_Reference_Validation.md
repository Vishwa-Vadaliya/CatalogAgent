---
type: Document
title: Jaeger-LeCoultre — Reference Validation Log
description: Dated session log of Jaeger-LeCoultre reference-number validation run with the brand-ref-agent skill, including format research and step progress.
tags: [documents, jaeger-lecoultre, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Jaeger-LeCoultre — Reference Validation Log

Workbook `RawRefsToAssign` (`1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`), source tab
`Jaeger-LeCoultre`. Run with the `brand-ref-agent` skill. Catalog refs: `Sheet4` column T (758
refs). ManufacturerName for INSERT statements: `Jaeger-LeCoultre`.

## 2026-10-18 — Step 1 (scope)

- Source tab: 85,276 rows, no filter, no sort. Columns found by name (`ReferenceNumberId` is the
  2nd column here, unlike other brands).
- `ReferenceNumberId` set: 71,307 rows (4,621 unique `ReferenceNumber` = Phase A). NULL: 13,969
  rows (7,117 unique `RawReferenceNumber` over 13,940 rows = Phase B).
- 393 unique `ModelName`s (top: Reverso 15,842 rows, Master 6,417, Master Control 2,835,
  Memovox 2,543).
- No `FinalRef`, no `PartialRefFlag`, no `JLC final refs` tab yet.

## 2026-10-18 — Step 2 / workflow Step 0 (landscape research)

Official site pages could not be opened (HTTP 403); official claims rest on search snippets that
quote jaeger-lecoultre.com, plus dealer / auction pages. JLC publishes no explanation of its own
numbering.

Formats seen on the web:
- **Current: `Q` + 7 digits** (Q3858520, Q1238420, Q9038670). JLC product pages show it as
  "Internal reference JLQ3858520 (Q3858520)". Well indexed. Informal structure from a forum and a
  collectors' wiki: digits 1–3 base/case type, 4 case material, 5 strap, 6 dial colour, 7 dial
  specialty. Meaning of the `Q` prefix: not found.
- **Legacy dotted `xxx.c.dd`** (270.8.62, 145.8.79 S, 140.8.89): dealer/auction listings, 1990s–2000s;
  no official decoder. Dotted and Q refs coexist on the same watch (Polaris Q9008470 with case ref
  841.8.37.S). Variants: letters inside (`268 D 47`), trailing `S`, undotted (`145879`, `270562`).
- **`E855`-style** codes: real 1960s Memovox references on dealer pages; the `E` prefix is not
  explained anywhere found.
- **Case numbers** (engraved serials, e.g. 3506407, 1946267) are not references; they look the
  same as a Q ref without its prefix, so plain 6–7 digit values need checking.
- The prefix is dropped in places: Watchbase lists "3858522 (aka Q3858522)".
- A changed last digit (Q3858520 vs Q3858522) can be a distinct real reference, not a typo.
- `Q` + trailing letter (e.g. Q385842A): no web results found, but the catalog (Sheet4 col T)
  holds 103 such refs (e.g. Q207857J), so they exist at least in our own catalog.

Documentation level: modern Q refs well indexed (individually verifiable); dotted refs mostly
dealer/auction (mostly pattern-based); E-codes and plain 4–6 digit numbers sparse.

Shapes in Phase A (4,621 unique): plain digits 1,594; `9.9.9` 846; `Q` + digits 845; `9.9` 145;
digits + letter 142; `9.9.9.S` 127; `Q`+digits+letter 112; `9-9` 76; `Q… or …` 71; space-separated
61; many joined `X / Y` values (254 refs contain `/`, " or " or " / ").

Catalog overlap (Sheet4 col T, 758 refs, 582 plain `Q`+digits): only 3 Phase A refs match
as written; 491 more match once a `Q` is added in front; 322 `Q` refs also exist in the sheet as
a separate Q-less ref. So the `Q` prefix is effectively optional here: short form vs full form
(see edge case "optional brand prefix").

## 2026-10-18 — Phase A triage (workflow Steps 1-3), read-only so far

Shape buckets of the 4,621 Phase A refs: Q+7 digits 631; Q+6 digits+letter 101; Q+3d+letter+3d 41;
dotted 9.9.9(+S) 1,018; dotted with a letter segment 40; dotted 9.9 145; E-codes 79; plain digits
1,594 (2-5 digits: 438, 6-7 digits: 1,153); digits+letter 133; joined two-value 265; other Q-forms
102; space-separated 153; other 319 (calibre codes K###, brand text, lowercase, JLQ+7 digits).

Plain 6-7 digit refs (1,153): Q-form in catalog (Sheet4 col T) 402; Q-form elsewhere in the sheet
320; no counterpart anywhere 431 (172 seven-digit, of which 39 have Q-like structure; 259
six-digit). User's view: plain 6-7 digit values are not valid refs unless shown otherwise.

Web sample (36 ambiguous plain values): 2 confirmed as references (2661120 as Q2661120, Reverso
Duetto; 2265 as vintage Memovox "Ref. 2265"); the rest not surfaced by search (not proof of
absence). Case numbers and serials have the same look on auction pages, so the no-counterpart
group is treated as likely case serials, an inference only. K825 is the Memovox calibre, not a
reference.

Joined values: 71 are the same ref twice ("Q3612421 or 3612421"), 115 are a dotted ref plus a Q
ref, the rest are other pairs. Nothing written yet; FinalRef column does not exist on the source
tab.

## 2026-10-18 — Phase A written (FinalRef column added on the source tab, column H)

Decisions: plain digits whose Q form already exists (catalog or sheet) are skipped (402 + 320
plain digits, 98 digits+letter, 43 Q-less Q-codes); dotted `9.9` and short plain numbers (2-5
digits) included for now; joined values reduced to one ref (same ref twice -> Q form; dotted+Q ->
Q part; Q + bracketed dotted -> Q part); other joined pairs left for a later decision; repeats
to be flagged in PartialRefFlag in Step 5.

Written: `FinalRef` on 56,777 rows = 2,758 unique source refs -> 2,662 distinct FinalRef values
(86 values produced more than once, 108 already in the catalog col T; both to be flagged in
Step 5). Skipped 863 refs (10,296 rows), excluded 454 refs (431 plain 6-7 digits with no Q
counterpart = likely case serials, 15 K### calibre codes, 3 scientific-notation numbers, 3 plain
8+ digits, 2 text values). Left blank for a decision: 546 refs (416 other shapes, 68 other joined
pairs, 35 digits+letter, 21 JLQ+7 digits, 6 Q-less Q-codes). Only a web sample of plain numbers
was individually checked; Q, dotted and E groups are accepted by pattern. Phase B (the 13,969
rows with no ReferenceNumberId) not started.

## 2026-10-18 — Phase B written (FinalRef from RawReferenceNumber, rows with no ReferenceNumberId)

Scope: 13,969 rows with RNId NULL = 7,117 unique raw values over 13,940 rows (29 rows have no raw
value). Rules: same as Phase A plus extraction of a single Q / dotted token from longer text,
dotted + Q joined -> Q part, dotless 6-digit match to a Phase A dotted ref (51 raw values), Q form
already existing -> skip.

Written: `FinalRef` on 7,220 rows = 2,965 raw values -> 1,658 distinct refs: 681 already a Phase A
FinalRef, 256 already in the catalog (col T), 721 new. Sheet total now 63,997 rows with a FinalRef.
Skipped 102 raw values (329 rows, Q form exists). Excluded 976 raw values (1,393 rows): 511 plain
6-7 digits with no Q counterpart (likely case serials), 305 text without digits, 148 plain 8+
digits, 7 scientific-notation numbers, 5 calibre codes. Held for a decision: 3,074 raw values
(4,998 rows): 1,457 unrecognised shapes; 847 short plain numbers (2-5 digits) and 260 dotted
`9.9` values, which Phase A included only because the database had linked them (74 of the
`9.9` values are the start of a longer Phase A dotted ref, 26 short numbers and 10 `9.9` values
exist as Phase A FinalRefs); 274 other joined pairs; 116 with several refs in the text
(short vs long dotted spelling); 62 digits+letter; 58 JLQ+7 digits. Accepted by pattern; no raw
value individually checked on the web.

## 2026-10-19 — Correction: "scientific-notation numbers" are recoverable

The 10 values shown as 1.66E+04 etc. are real numbers with a scientific display format
(`0.00E+00`); the digits are intact in the cell. The scripts read the displayed text, so they looked
lost. `sheets_client.read_tab` now reads stored values. True values: 16634, 11000 and 129350
(linked to a ReferenceNumberId); 136350, 132340, 130350, 525340, 509240, 604350 and 1663400000
(not linked). Under the existing rules only 16634 and 11000 (short plain, linked) qualify for
FinalRef; the six-digit ones stay excluded (no Q counterpart, likely case serials) and the
10-digit one is excluded. Not yet written.

## 2026-10-19 — Decisions on held groups; extra FinalRef writes

User decisions: (1) dotted `9.9`: include the valid ones, report the unsure ones; (2) map every
`JLQ`+7 digits value to its `Q` form (final-refs tab will drop the duplicates, so where the Q ref
exists the J form is not listed separately); (3) `16634` / `11000` only if valid on the web;
(4) all other held groups (847 short plain numbers in Phase B, other joined pairs, several refs in
one text, digits+letter without a Q form, Q-less Q-codes, unrecognised shapes) are NOT added.

Web checks: `16634` is the stem of Master Grand Tourbillon refs Q16634E0 / Q16634E6 / Q16634V2 (a
partial, not a standalone ref); `11000` not found anywhere. Neither added. `JLQ1338421` confirmed
on a dealer page as the same watch as `Q1338421`; official-site "Internal reference JLQ... (Q...)"
wording could not be fetched (403) and is unconfirmed; in our own data 71 of 79 JLQ values already
exist as written Q refs and 60 are in the catalog.

Dotted `9.9` (395 distinct): 120 four-digit.two-digit values are the valid group (2 of 4 sampled
confirmed on dealer pages); 106 are truncated forms of longer refs (24 of those were already
written in Phase A and will be flagged Partial in Step 5); 169 unsure (37 already written in
Phase A): 36 two-three-digit, 47 three.three, 6 five-six-digit.one, 80 other.

Written: 221 rows: 133 JLQ rows -> Q form (51 linked, 82 raw) and 88 rows for 44 valid dotted
4.2 raw values.

## 2026-10-19 — Final refs tab built (workflow Step 6)

Created tab `Jaeger-LeCoultre final refs` (right after the source tab) with Referencenumbers,
PartialRefFlag (blank, not yet run), ReferenceNumberId, WatchIds, TotalWatchCount, Length.
3,683 distinct FinalRef values, 64,218 WatchIds (identical to the source grouping). 2,671 refs have
a ReferenceNumberId; 1,012 (the new refs found only through the raw column) have none (left
blank). 98 refs have more than one ReferenceNumberId in the source; the id with the most rows was
written and all ids are listed in `jlc_ambiguous_rnid.csv` (scratchpad) for a decision.
TotalWatchCount: sum of the source tab's distinct values per ReferenceNumberId (2,671 refs); for
the 1,012 refs with no value in the source it is the count of WatchIds. Source value and count of
WatchIds agree for only 1,437 of 2,573 single-id refs, so they are different measures.

## 2026-10-19 — Step 5 flags written on `Jaeger-LeCoultre final refs` (sentence style)

User decisions: sentences; flag every truncated ref (a longer ref exists); flag "catalog holds the
base ref" cases. 686 of 3,683 refs flagged (2,997 clean), each ref assigned one reason in priority
order: 372 Already in catalog (exact) + 80 Already in catalog (other spelling) = 452 "Already in
catalog (Sheet4: '...')"; 94 dotted spellings of a Q ref on the tab + 34 duplicate spellings (kept
the dominant 3.1.2 shape, flagged the odd one) + 2 Q-prefixed dotted refs = 130 "Duplicate of ...";
96 "Partial - full ref present: ..." (separator-aligned truncations, e.g. 109.8.37 vs 109.8.37.S);
6 "Base ref ... already present in catalog (Sheet4) as partial"; 2 "Junk - not a reference" (QSS,
0.53).
Not flagged, left for review: 156 prefix hits that are only digit overlaps across formats, 16
front-truncation, 58 embedded, 1,674 one-character-different pairs (report only), `Q177T47V` and six
`015.xxx.6` refs with a leading zero. Catalog side (Sheet4 col T) not flagged: no flag column next to it yet.
Flags are pattern-based; none individually checked on the web.

## 2026-10-19 — Step 5 round 2: remaining spellings, odd refs, catalog side

- 30 more "Duplicate of ..." flags on the short/full-form pairs left over after round 1 (dotted
  spelling vs Q spelling of the same ref, plain digits vs E-code). Per pair the flagged side is the
  one in the catalog, otherwise the one with fewer watches; for the three plain-digit/E-code pairs
  (11013, 13001, 21004) the plain-digit side was flagged. The Q-prefixed dotted spellings (Q146802,
  Q270862, Q272154, Q2668410, Q140880S, Q147237S, Q172879S, Q192H470) were flagged as duplicates of
  the dotted ref because the dotted ref has far more watches (270.8.62 has 1,091).
- Web check of the odd refs: `Q177T47V` is a genuine reference (Master Compressor Extreme W-Alarm
  "Valentino Rossi", titanium, 946 pieces; dotted form 177.T4.7V) - left clean. `Q177T471` was not
  found, so it is not a correction. `015.022.6`, `015.024.6`, `015.029.6`, `015.030.6`, `015.035.6`
  were not found anywhere (leading zero + 3.3.1 shape is not a JLC format seen elsewhere): flagged
  "Invalid - unconfirmed, no matching official reference found". Thin evidence: Chrono24, Watchbase
  and the Grail wiki were not searched directly.
- Totals on the tab: 721 flagged, 2,962 clean.
- Catalog side: new `Sheet4` column U `PresentInFinalRefsTab` next to catalog column T: 379 of the 758
  catalog refs flagged, "Yes - present as '<final ref spelling(s)>'" or, where the catalog holds the
  base of a longer final ref, "Partial - full ref present: <final ref(s)>".

## 2026-10-20 — Step 3 (watch data layout) written

The user pasted the watch-data query output straight into columns H..O of the final refs tab on the
2,962 clean refs. Alignment verified (FirstWatchId is one of the row's WatchIds on 2,962 of 2,962;
pasted ReferenceNumberId equals column C wherever both exist; no flagged ref carries data), so
`layout_watch_data.py --in-place` only finished the layout: `NULL` text cleared to blank
(FirstWatchPublishWatchId 354, ModelName 438, DialColor 194, CaseMaterial 82, Images 96), image
candidates split into X..AG (up to 10 URLs per ref; 96 refs have no image), SourceLink and
FinalImage formulas on all 2,962 rows, headers FinalImageUrl / SourceLink / FinalImage added.
Blank on clean refs now: model 438, dial 194, case 82. FinalImageUrl is still empty (Step 4).

## 2026-10-20 — Step 4 (best primary image) written

Full run of `scripts/pick_best_image.py` (same picking logic as the original tilt checker) over 2,866 refs / 9,337 images, `--write --skip-unusable`. Picked flags: OK 2,479; BORDERLINE 2; UNDETERMINED 253; HORIZONTAL 55; NOT_WATCH 52; TILTED 25. Wrote 2,481 `FinalImageUrl` cells (OK + BORDERLINE); 385 not-usable picks were held back and left empty; 96 refs have no image candidates at all. Live re-check before writing: 2,481 re-located by ref text, 0 skipped. Backup of the old column P and the full results CSV are in
`D:\catalog_image_tilt_checker\runs\jaeger-lecoultre-final-refs\`.

## 2026-10-20 — No-dot "S" refs checked on the web and flagged (12 refs)

Dealers write the trailing S as "NNN.N.NN.S" or fully undotted ("144294S"); the dotted-with-S-attached
form ("144.2.94S") was never seen. `176.8.37` (any spelling) was not found anywhere; the real
neighbours are `174.8.37.S` (Master Ultra Thin) and `147.8.37.S` (Master Control Date), both already on
the tab, so the sheet's `176.8.37` (Master Ultra Thin, 11 watches) and `176.8.37S` (Master Control Date,
2 watches) are probably transposed digits. Flagged "Invalid - unconfirmed, likely typo of <real ref>":
176.8.37, 176.8.37S, 149.3.34S (149.6.34.S), 116.7.84S (166.7.84), 145.2.26S (146.2.26.S), 148.8.98S
(140.8.98.S), 185.2.35S (186.2.35.S); "Invalid - unconfirmed, no matching official reference found":
176.8.46S; "Duplicate of ...": 144.2.94S, 165.7.89S, 145.6.79S, 166.7.84S (found only without the S or
as "144.2.94 S"). Evidence is thin (snippet-based search; 147.8.37.S from a search summary only).

## 2026-10-20 — 176.8.37: flag cleared after a direct catalogue check

Loupe has a page for "Jaeger-LeCoultre Master Ref. 176.8.37" (market value ~$8,982, no dial or model
detail), so the ref appears in at least one listing; Loupe also has 174.8.37, 147.8.37 and 176.8.38
(176.8.36 returns 404 there although a dealer lists 176.8.36.S, so Loupe is not complete). No
dealer/auction page was found for 176.8.37; Watchbase, Gazette Drouot and Bernard Watch returned 403.
The "likely typo of 174.8.37.S" flag on `176.8.37` (11 watches) was therefore removed; the ref is kept
as unconfirmed (dial/model not verified). `176.8.37S` (2 watches) stays flagged as a likely typo of
147.8.37.S. 174.8.37.S: Master Ultra Thin, champagne dial, 39 mm (Blowers); a silver-dial Master
Ultra Thin Date 174.8.37.S is only in an unopened search summary. Totals: 732 flagged, 2,951 clean.

## 2026-10-20 — Individual re-verification of the "invalid" flags

Each flagged ref was checked on its own (Loupe per-ref page, 3+ spellings in a web search, and the
guessed real ref). Loupe pages are weak evidence in both directions (auto-built from listings; 404s
exist for real refs such as 176.8.36).
- `176.8.37S`: Loupe has "Master Ref. 176.8.37S"; no dealer hit. Flag CLEARED (weakly confirmed). The
  guess 147.8.37.S is a real silver-dial Control Date, so the sheet's black dial does not fit it.
- `145.2.26S`, `148.8.98S`, `185.2.35S`, `116.7.84S`: not found as written; the guessed refs
  (146.2.26.S, 140.8.98.S, 186.2.35.S, 166.7.84) are confirmed real. 145.2.26S also appears as a dealer
  typo on a 146.2.26S listing (spec block). Flags kept ("likely typo of ...").
- `149.3.34S` not found; 149.6.34.S is real but black-dial against the sheet's cream. Flag kept.
- `176.8.46S` not found anywhere. Flag kept.
- `015.022.6` / `015.024.6`: Loupe stub pages exist (1 listing at $1,121 / none), no model or dial;
  `015.029.6`, `015.030.6`, `015.035.6`: nothing found anywhere (Loupe 404). No JLC series starting
  015 / 15.0xx.6 found. All five flags kept pending a decision on the first two.
Totals: 731 flagged, 2,952 clean.

## 2026-10-20 — Base vs ".S" vs attached "S": one spelling per family

Web check of 16 base/.S families (Phillips, Collectorsquare, 1stdibs, Bonhams, European Watch, Loupe, ...):
the base and its .S matched in specs for 7 families (142.8.92, 142.2.92, 145.8.31, 140.2.80,
145.2.79, 140.2.93, 145.8.79), 9 could not be compared (no dealer page for the base spelling), none
was clearly a different watch. No source explains the S; dials vary within one spelling; dealers
(and ~10 modern Q refs' "alternate reference") overwhelmingly write ".S" or the undotted "NNNNNNS".
Rule applied: keep the dotted ".S" form where it exists (a spelling already in the catalog wins); the
plain base and the attached "S" are flagged "Duplicate of X.S"; where only a base exists the base stays
and the attached "S" is "Duplicate of <base>". Changes: the base flags "Partial - full ref present:
X.S" were reworded to "Duplicate of X.S" (a base is not a truncation of its .S, including 7 bases
with more watches than their .S: 142.8.92, 142.2.92, 145.8.31, 140.2.80, 145.2.79, 145.1.79, 145.2.31);
176.8.37S, 140.840.987S and 165.7.3S flagged "Duplicate of <base>". 176.8.37S's flag had been cleared
earlier on a weak Loupe page; the web check never found the dotted-with-S-attached form for any ref.
Confidence moderate: 0 contradictions, small sample, S meaning unknown.
Follow-up fix: Q140898S and Q140.8.98.S -> "Duplicate of 140.8.98.S" (Q140.8.98.S had pointed at the
clean Q140898S); Q145879S -> "Duplicate of 145.8.79" (the base spelling that is in the catalog).
Totals after the S rule and these fixes: 736 flagged, 2,947 clean.

## 2026-10-20 — Last "other shape" refs checked (images + web)

`Q142292` (2 watches) and `Q142892` (1 watch) are real watches (a rose-gold and a steel Master
Geographic with a silver dial, checked on the sheet images) written with a made-up ref: seller pages
(Essential Watches, European Watch) title them "Q142292" / "Q142892" but say "also known as 142.2.92,
Q1422420" and list "142.8.92" with the real Q ref Q1428420. Official Q refs Q1422420 (53 watches) and
Q1428420 (118 watches) are on the tab with matching case and dial. Flagged "Duplicate of Q1422420" and
"Duplicate of Q1428420". `Q16634E7` (white-gold Master Grand Tourbillon with a hand-painted crane
scene, image checked) is a real ref (Wristler page "Ref. no. Q16634E7"; Hourstriker page; same family
as Q16634E0/E6/V2): kept clean. Totals: 738 flagged, 2,945 clean.

## 2026-10-21 — Dotted refs that already have a corresponding Q ref present

What a dotted ref is: JLC's older catalog reference. First block (3 digits) = model line (260 =
Reverso 100%, 266 = Reverso Duetto 92%, 140 = Master Control/Calendar); second digit = case material
(.1. yellow gold 99%, .2. rose gold 99%, .3. white gold 96%, .6. platinum 95%, .5./.8. steel 99-100%);
last two digits = strap/dial code per a collectors' wiki (rough guideline). Different from the engraved
case number and the calibre. A dotted ref pairs with a family of Q refs that share one 4-digit Q block
(99% of pairing rows); the leading digits of the dotted and the Q ref do not match (240.8.72 <-> Q3038420).
Pairing evidence = rows where sellers wrote both together (source tab): 240.8.72 goes with Q3038420
(11 rows), Q3038120 (2), Q303847A (1).
Decision (user): dotted refs for which the corresponding Q refs are already present are flagged.
Applied to dotted 3.1.2 / .S refs with a well-supported partner (written with the Q ref on >= 3 rows,
material digit agrees, Q ref clean on the tab): 133 refs, 17,204 watches: 83 with one partner "Duplicate
of Q...", 50 with several partners "Older number of Q1, Q2, ..." (e.g. 270.8.62, 1,091 watches).
Left clean: 69 weak links (partner backed by only 1-2 rows), ~900 dotted refs with no Q partner at all.
Not yet decided: 65 dotted refs (2,227 watches, e.g. 176.8.64.S, 176.8.40.S, 277.8.62) whose strong Q
partners are already in the catalog (flagged "Already in catalog" on this tab).

## 2026-10-21 — Dotted refs flagged against ALL their Q partners (clean or not)

User decision: flag a dotted ref whenever its corresponding Q refs exist, whether those Q refs are
clean on the tab or flagged (already in the catalog). Second pass over the dotted 3.1.2 / .S refs
still clean (599): 66 more flagged (2,258 watches): 43 "Duplicate of Q..." and 23 "Older number of
Q1, Q2, ...", e.g. 214.8.62 -> "Older number of Q3858522, Q3858520, Q3978480", 176.8.40.S, 176.8.64.S,
277.8.62, 272.8.54 (partners already in the catalog). Same support test as before (written together
with the Q ref on >= 3 rows, material digit agrees). Left clean: 74 weak links (partner backed by 1-2
rows), 459 dotted refs with no Q partner written with them, and the other dotted shapes (3.3.1,
3.3.3, letter segments, 2-part) which were not part of this rule.
Total dotted refs flagged against Q refs so far: 199.

## 2026-10-21 — Plain number vs E-code pairs (E876 / 876 ...)

Web check (Wind Vintage, Collectorsquare, WatchProSite, Bonhams/Christie's/Antiquorum lots): 5 examples
of the same watch written with and without the E (855 incl. one listing titled "Ref. 855" whose body says
"reference E 855", 159 by one author in one post, 876 and 875 with matching calibre 916 / era),
0 examples of different watches. "E" = "etanche" (waterproof) per one dealer (Wind Vintage), no JLC
source. Confidence about 75% for 855, 875, 876, 159; no evidence either way for 853, 857, 871, 873,
393, 557, 2643. Decision (user): flag the plain number as "Duplicate of E###" (the E form is what
auction houses and specialists write). Applied to the 15 clean pairs whose model names agree or are
unknown on one side (855, 876, 875, 853, 857, 1335, 858, 874, 873, 871, 557, 159, 365, 2638, 163).
Held, both left clean: 2643 (Shark vs Deep Sea Chronograph), 393 (Classic vs Vintage), 373 (Powermatic
vs Powerwind): the sheet shows different models, so they may be separate refs or mis-assigned rows.

## 2026-10-21 — The 74 weak dotted links flagged too (no-risk decision)

User decision: take no risk, flag all 74 dotted refs whose Q link was written with the dotted ref on only
1-2 rows (or whose material digit differed). Wording `Older number of Q..., (weak link)` so they can be told
apart from the 199 well-supported flags (and cleared later if a link turns out to be wrong). The
list is in `Jaeger_LeCoultre_Weak_Dotted_Links.md`. All come from the source sheet's own written pairs; none
was checked on the web. 3,445 watches. About 459 dotted refs with no written Q partner and 801 refs in
other dotted shapes (3.3.1, long 3.3.3, letter segments, 2-part) stay clean and were not tested for Q
partners; a 12-ref web sample found no confirmed Q partner for any of them (4 are pre-Q era).

## 2026-10-21 — The last three plain/E-code pairs flagged

User decision: flag the plain twin of the three pairs that had been held because the sheet showed
different model names: 2643 (Shark vs E2643 Deep Sea Chronograph), 393 (Classic vs E393 Vintage),
373 (Powermatic vs E373 Powerwind) -> "Duplicate of E2643 / E393 / E373". The model-name difference is
unexplained (possibly mis-assigned rows) and no web evidence was gathered for these three pairs.
Total plain/E-code pairs flagged: 18 (+3 earlier: 11013, 13001, 21004).

## 2026-10-21 — Every dotted shape checked for corresponding Q refs

User decision: for ALL dotted refs, if corresponding Q refs are present, flag them. Third pass over every
clean dotted shape (letter segments, 3.3.3 long forms, 3.3.1, 2-part, other): evidence = a Q ref written
in the same source cell as the dotted ref (60 refs: 45 on >= 3 rows, 15 weak with "(weak link)"), plus,
for the long 3.3.3 refs, the Q partners of their short base ref (110 refs; base = block1 + first digit of
block2 + first two digits of block3, e.g. 260.840.862B -> 260.8.86; the base exists on the tab for 210 of 234
long refs). 170 refs flagged, 2,089 watches, all "Older number of Q..." (letter segments such as 192.T.25,
174.8.C1, 160.T.25; long refs such as 140.840.892B via 140.8.89). The full plan is in
`jlc_all_dotted_plan.csv` (scratchpad). No Q partner was found written with any 2-part or 3.3.1 dotted
ref. Clean dotted refs left: about 459 standard 3.1.2 refs with no written Q partner, 2-part and 3.3.1
refs, and long refs whose base has no Q partner. Evidence is source-sheet pairings plus the base-ref
inference; not individually checked on the web.

## 2026-10-21 — New column `CorrespondingQRefs` on the final refs tab

User request: a column listing, comma separated, the corresponding Q refs of every dotted ref flagged
against Q refs, for tracking. Column G (blank spacer) turned out to hold the user's own helper formula
(`INSERT INTO ##watches(WatchId,ReferenceNumberId) VALUES(...)`, no header), so a new column C was
inserted right after `PartialRefFlag`; every column from the old C onward moved one to the right and
all formulas adjusted (the helper formula now sits in H). 555 dotted refs (25,387 watches) carry the
list: every Q ref named in their flag plus partners the flag truncated (e.g. 214.8.62 -> Q3858522, Q3858520,
Q3978480; 270.8.62 -> six Q refs). The scripts find columns by header name, so nothing else needed
changing. The 555 include the 94 dotted spellings flagged "Duplicate of Q..." in an earlier round.

## 2026-10-21 — The 120 "NNNN.NN" refs checked for duplicates / partials; 9120.42 vs 912.042 flipped

All 120 refs of the form NNNN.NN (e.g. 6029.22) were compared with every other dotted ref on the tab (same
digits with different dot positions; shortened form of a longer ref; digits embedded in a longer ref).
Result: 116 have no relative; 4 are spelling duplicates of 3.1.2 or 3.3 refs and were already flagged
(2608.47, 2651.86, 2706.43, 9120.42). No partial of a longer dotted ref was found. The digits after the dot
encode the case metal (.21 yellow gold 95%, .22 white gold 100%, .42 steel 100%, .32 silver 100%).
9120.42 / 912.042: refs starting with 9 are 49 in the 9xxx.xx style and 1 in the 9xx.xxx style; the web check
found 4 pages using "9120.42" (awco.nl Vogue NOS, Belmont Vogue Tank Rectangle, Loupe, goldammer) and none
using "912.042" (Loupe 404). Flags flipped: 9120.42 now clean, 912.042 flagged "Duplicate of 9120.42".
9120.42 had no watch data, so ModelName (Vogue), DialColor (Blue), CaseMaterial (Stainless steel), Images,
FirstWatchId / FirstWatchPublishWatchId, FinalImageUrl and the 10 image-candidate cells were copied from the
912.042 row into its blank cells and the SourceLink / FinalImage / preview formulas added; ReferenceNumberId,
WatchIds and TotalWatchCount of the two rows were left unchanged. Confidence about 90%.

## 2026-10-21 — Caseback check of every ref structure; the XXX.C.MM structure is engraved

Web check of the 55 unique ref structures among the 2,484 clean refs (N = digit, a = letter): no structure
has a verified statement that its ref is engraved on the watch, except `NNN.N.NN` (the `270.8.62` shape):
one TimeZone owner (2008) writes "The ref.no. engraved on my watch is 270.8.62" with a 7-digit serial
beneath it, and says his box and warranty card show a different number (270.84.10 / Q2708410). The
collectors' wiki describes the engraved caseback number as `xxx-c-mm`: case code, material (8 = steel),
movement code (62 = calibre 822), "different from the catalog number though the format is similar".
Unverified signals: `250.8.86` stamped (Catawiki, unreadable), `20002` and `390` "inside the caseback"
(Gazette Drouot summaries, unreadable). Auction lots for all other formats list the reference next to a
separate 6-7 digit case number. Q refs: on the warranty card / tag / website, probably not engraved.
User decision/observation: the structure XXX.C.MM (our NNN.N.NN, 402 clean refs) is found on the caseback.
Consequence for interpretation: the dotted XXX.C.MM ref is the engraved case code (case type, material,
movement), so one dotted ref covers several Q refs of the same case family with different dials and
straps; the last two digits are the MOVEMENT code, not the dial/strap code assumed earlier. The flags
"Older number of Q..." / "Duplicate of Q..." remain consistent with this. Source link not yet checked.

## 2026-10-21 - Steps 5 and 6 finished (scope: 2,389 refs)

Scope: clean refs (blank PartialRefFlag) with Length not 2 or 3. The 55 plain 2-3 digit refs are left out of the master-value work and the INSERT statements.

- **Partial / Q flags added this session:** `Q2668410` / `266.8.410` flipped (Q kept, dotted flagged, watch data copied); 22 partials of Q-flagged full refs (`146.2.26`, `147.8.57`, truncated refs such as `270.6`); 9 more partials of clean longer refs (`165.7.3`, `155.1.9`, `251.8.8`, `305.8.3`, `170.7.8`, `250.5.1`, `252.86`, `121.01`, `5001.4`); 8 lost-leading-digit typos flagged `Invalid - unconfirmed, likely typo of <ref>` (`25.5.86`, `14.8.93`, `49.8.95`, `70.1.54`, `26.1.08`, `26.1.86`, `26.1.54`, `15.5.31`). Final: 1,239 flagged, 2,444 clean (2,389 in scope).
- **Not decided, left clean:** `247.307` (real ref, dot misplaced; `247.3.07`), `215.019`/`215.024`/`215.009` (probably Atmos-type clock refs), `140.034`, `140.118`, `141.118`, `144.223`, `200.701`, `268.386`, `210.272`, `240.362`, and four unfound `NN.N.NN` refs (`25.1.59`, `12.5.08`, `26.8.47`, `27.0.63`). Web check found no confirmation either way.
- **Master values (workbook `1fNuS-iNetR3RYS2iMxyrb6ZgX0Ju4tb5ApsGQuhOy3A`, tabs DialColor / Material / Model, 51 JLC models):** `Copper` -> `Brown`; `18k gold`/`Gold`/`9K Yellow Gold` -> `Yellow gold`; `Pink gold` -> `Rose gold`; `Metal`, `Gilt-metal`, `Nickel`, `Chrome`, `Glass` cleared.
- **Blank dial / case filled** (master values only): 111 + 17 dials (images, some with web), 8 + 10 + 32 case materials (web, then image-based on the user's instruction; gold shade from photos is medium confidence). Still blank on the 2,389: 12 dial, 6 case.
- **ModelName:** 150 names were not in master. Confidence report: `Jaeger_LeCoultre_ModelName_Confidence.md` (only 4 confirmed on jaeger-lecoultre.com, which returns 403 to direct fetches). Removed 20 names (confidence <= 15, plus `Ultra Thin`, `Extra-Flat`; 153 cells cleared). Merged near-duplicates: 15 pairs (48 cells), `Geographique` -> `Geographic`, `Misterioso`/`Mystérieuse` -> `Mysterious`. Pairs that differ by a complication were deliberately not merged (`Master Compressor` vs `GMT`, `Diving Alarm` vs `Diving GMT`, `Diving Chronograph` vs `Pro Geographic`, `Reverso Grande` vs `GMT`, `Reverso Tourbillon` vs `Reverso Gyrotourbillon`). 112 names still not in master (user will handle). 550 of 2,389 refs have no ModelName.
- **Step 6:** `InsertStatement` formulas written in column AJ for 2,389 refs (ManufacturerName `Jaeger-LeCoultre`, StatusId 1, UserID 6). No literal `NULL` in any field. Empty values: ModelName 550, FinalImageUrl ~375, SourceLink ~318 (268 rows have an image but no source link).
- Sheet columns Q (SourceLink) and R (FinalImageUrl) were swapped by the user since the layout was built; scripts find columns by header name.
