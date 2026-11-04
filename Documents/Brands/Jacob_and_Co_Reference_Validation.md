---
type: Document
title: Jacob & Co. — Reference Validation Notes
description: Notes on Jacob & Co. watch reference-number validation — confirmed conventions, scope/phases, validation decisions, and duplicate detection methodology.
tags: [documents, jacob-and-co, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Jacob & Co. — Reference Validation Notes

Spreadsheet: `RawRefsToAssign` (ID `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg`)
Source tab: `Jacob & Co.` (6,596 rows) · Working tab: `Jacob&co. final refs` (1,711 rows)

## Reference conventions confirmed valid

Jacob & Co. uses **two genuine, coexisting conventions** — neither is "the" pattern:

1. **Modern dot-notation**: e.g. `EX110.20.AA.AJ.A` — 2-3 letter model-line code + dot-separated
   segments for case/dial/bracelet material codes.
2. **Legacy short codes** for earlier "Five Time Zone" / "Epic" lines: e.g. `JC-1`, `JCM24DA`,
   `H24`, `E1C`. These are not a lesser/older form of the modern codes — both are genuine,
   independently-confirmed reference styles used in parallel across the brand's catalog.

## Scope and phases

- **Phase A** (`ReferenceNumberId != NULL`): 4,169 rows populated via the default filter.
- **Phase B** (`RawReferenceNumber`, `ReferenceNumberId = NULL`): 2,426 rows, built via a
  cleanup/extraction pipeline (exact match against Phase A valid set → formatting-noise
  normalization → missing-separator reconstruction → leave blank if genuine noise).
- Total `FinalRef` population: 5,961 rows before duplicate corrections.

## Validation decisions and corrections

- **`AT112.30.DR.UA.ABALABALA` vs `AT112.30.DR.UA.ABALA`** — the *fuller*-looking string was
  itself an invalid typo (duplicated "BALA" segment at the end). Exception to the general
  "prefer the fuller ref" heuristic: here the **shorter/partial-looking one was kept** as
  correct, and the bad "full" string was deleted outright (not merely flagged partial),
  since it was never a valid reference at all.
- **`E11` / `E12` / `E14`** — could not be confirmed as real references after multiple
  search angles; cleared (left blank) rather than guessed.
- **Missing-first-letter typo pattern**: a data-entry error where the leading letter(s) of a
  dot-notation code were dropped, e.g. `X100.20.PS.PP.A` for the real `EX100.20.PS.PP.A20AA`;
  `T520.24.NS.QG.A` for `PT520.24.NS.QG.A`; `200.40.AE.AB.A` for `BU200.40.AE.AB.A`. Fixed by
  prefixing the missing letter(s) once the full form was independently confirmed.

## Duplicate detection methodology (refined through trial and error)

1. **Exact-match after normalization** (strip non-alnum, uppercase) — cheap, catches hidden
   case/space duplicates.
2. **Prefix-based partial/full detection** (`n2.startswith(n1)`) — the original method, but
   has real false positives: short "base model" codes can have many legitimate numbered
   variants that are *not* truncations of each other. Example: `Q1121` legitimately coexists
   with `Q11210` / `Q11211` / `Q11215` as distinct, individually-confirmed Tambour chronograph
   variants — confirmed via spec lookup before accepting either direction.
3. **Non-prefix substring embedding** (`n1 in n2` but `not n2.startswith(n1)`) — catches a
   redundant prefix stuck onto an already-complete code. This is the check that surfaced the
   real Jacob & Co. duplicate: `V.2Q2B` found embedded inside `JC-V2Q2B`.
4. **Blind Levenshtein edit-distance** — tried and **explicitly rejected** as too noisy for
   this brand. At edit-distance ≤ 2 it produced 3,138 candidate pairs, the vast majority being
   genuinely distinct real products that differ by one digit/letter as part of the brand's
   actual dense numbering convention (e.g. `JC-1D`/`JC-2D`/`JC-3D`, `GR3-14`/`GR3-15`/`GR3-24`,
   `JC-V2Q1`/`JC-V2Q5`/`JC-V2Q8`/`JC-V2Q9`, `H24SSG`/`H24SSR`, `JCM-22`/`JCM-28`/`JCM29`).
   Conclusion: any "close" pair found this way must be individually verified against a source
   (is this exact string a real, distinct confirmed product?) — never flagged by string
   similarity alone.

## Confirmed duplicate pairs (resolved as partial, pointing to the full ref)

| Partial | Full | Notes |
|---|---|---|
| `JC-E1C` | `E1C` | |
| `JC-E1R` | `E1R` | |
| `JC-E2SSB` | `E2SSB` | |
| `JC-E2SSCP` | `E2SSCP` | |
| `V.2Q8` | `JC-V2Q8` | |
| `V2-Q5` | `JC-V2Q5` | |
| `V.2Q2B` | `JC-V2Q2B` | confirmed via embedding check |
| `GR5-35` | `JC-GR5-35` | |
| `X100.20.PS.PP.A` | `EX100.20.PS.PP.A20AA` | missing-letter typo |
| `X100.21.YR.PY.A` | `EX100.21.YR.PY.A` | missing-letter typo |
| `T520.24.NS.QG.A` | `PT520.24.NS.QG.A` | missing-letter typo |
| `T500.40.NS.OG.A` | `PT500.40.NS.OG.A` | missing-letter typo |
| `200.40.AE.AB.A` | `BU200.40.AE.AB.A` | missing-letter typo |
| `JC-30DC` | `JC30JDC` | |
| `q2B` | `JC-V2Q2B` | later identified: Q2B/V.2Q2B/JC-V2Q2B all collapse to the same watch |
| `V.2Q3RG` | `JC-V2Q3RGI` | confirmed via spec match (Epic I V.2, rose gold chronograph) |

**Resolution policy**: mark one ref of a confirmed pair with
`PartialRefFlag = "Partial - full ref present: <other ref>"` — never delete for this class of
duplicate (contrast with the `AT112...ABALABALA` case above, which was an outright invalid
typo, and `E11`/`E12`/`E14`, which were fully cleared as unconfirmed/non-existent).

Five "M-insertion" candidate pairs (`AC-12`/`ACM12`, `JC7DA`/`JCM7DA`, `JC-123`/`JCM123`,
`JC-126D`/`JC127D`, `JCM-122`/`JCM123`) were investigated in depth and **all found to be
distinct real products**, not duplicates — `ACM` is Jacob & Co.'s own separate 40mm
chronograph sub-line (ACM-3, ACM-7, ACM-11 all independently real), and EveryWatch's own
database lists `JC123`/`JCM123` and `JC7DA`/`JCM7DA` as separate, distinct watches with
different specs/years.

## Image picking (Step 8)

- 1,370 full refs (after the duplicate-resolution pass) went through the image-picking
  pipeline; **1,358 of 1,370 got a `FinalImageUrl`** — 12 rows had a literal `NULL` in the
  `Images` column (no candidate image exists at all), correctly left blank.
- Selection rule: prefer vertical/straight-on shots showing the full watch (dial + strap),
  never a worn-wrist, boxed, angled, or cropped shot.
- A tilt-recheck pass was run on every row where the picked position wasn't #1, since that's
  where a wrong angle call is most likely to hide — this caught at least one real correction
  (`Q12MP`, reverted back to position 1 after an over-correction).

## Column layout used (`Jacob&co. final refs`)

`Referencenumbers, ReferenceNumberId, WatchIds, Length, TotalWatchCount, PartialRefFlag, '',
SourceRowId, ReferenceNumberId, FirstWatchId, FirstWatchPublishWatchId, DialColor,
CaseMaterial, ModelName, Images, FinalImageurl`

## DialColor fill-in pass (327-row filter: Length visible + PartialRefFlag blank + DialColor blank)

- **Automated pixel/color-extraction classification was tried and rejected.** A script that
  cropped the center of each image and nearest-matched dominant colors against a palette
  produced an implausible distribution (152 of 327 called "Multi-colored") and badly
  misclassified real cases on spot-check: a fully rainbow-gem-paved dial came back "Gray", a
  black/copper/silver skeleton came back plain "Black". Root cause: Jacob & Co. pieces are
  heavily gem-paved/skeletonized, which defeats simple dominant-color sampling. Conclusion:
  **no color-math shortcut works for this brand** — every row was visually reviewed by actually
  looking at the image.
- **DialColor decision rules established with the user, in priority order:**
  1. **Skeletonized wins over everything else.** If the dial itself (not just the bezel) is an
     open-worked/visible-movement design, the color is `Skeletonized` regardless of any accent
     colors present (gold bridges, colored jewels on the bezel, etc.).
  2. **Paved wins over any specific color or "Multi-colored" for a fully gem/diamond-covered
     dial** — this applies even when the stones are colored (a fully rainbow-gem-paved dial is
     `Paved`, not `Multi-colored`; a fully single-color gem-paved dial, e.g. all-emerald, is
     also `Paved`, not `Green`) — **corrected mid-session**: initially monochrome-gem-paved
     dials were being called by their color name (e.g. `Green`/`Red`/`Yellow`) and
     rainbow-gem-paved ones `Multi-colored`; the user clarified both should be `Paved`, and all
     prior writes were corrected in a follow-up batch (93 rows fixed to `Paved`, after excluding
     2 rows the user had meanwhile re-marked `Skeletonized`).
  3. Otherwise: 3+ genuinely distinct non-gem colors → `Multi-colored`; 2 or fewer → pick the
     dominant one from the standard vocabulary (Black, White, Silver, Gray, Blue, Light blue,
     Green, Brown, Champagne, Golden, Orange, Pink, Purple, Red, Salmon, Turquoise, Yellow,
     Opal).
- Of 327 filtered rows, 324 had a usable image; 3 had a corrupted/unreadable image file and 1
  more (`BU200.20.AA.AC.A`) had an image that was actually an unrelated stock photo (wrong
  brand) — all 4 left unfilled rather than guessed.

## CaseMaterial correction pass (20-row filter: non-standard casing/spelling)

- Filter isolated rows where `CaseMaterial` didn't match any of the sheet's 18 standard values
  (`Stainless steel`, `Rose gold`, `18k rose gold`, `White gold`, `Yellow gold`, `Titanium`,
  `Ceramic`, `Sapphire`, `Platinum`, `Palladium`, `Plastic`, `Carbon fiber`, `DLC`,
  `Black DLC`, `PVD`, `PVD-coated titanium`, `Skeletonized`, `paved`) — these 20 had
  genuinely different capitalization/wording (`18K Rose Gold`, `Black gold`, `Black Carbon`,
  etc.), not blanks.
- **Each of the 20 was individually web-verified** against the actual reference number (not
  just re-cased) — this caught one real correction: `EX120.11.A1.AB.A` was recorded as
  "Black Carbon" but its Epic X Bridges family is confirmed **stainless steel with black DLC
  coating**, not carbon, across every legitimate retailer listing.
- 5 of the 20 had no listing for the *exact* reference; material was inferred from a strong,
  consistent pattern across sibling references in the same model line (documented per-row in
  the chat, not repeated here) rather than left unconfirmed.
- Jacob & Co.'s Bugatti Chiron "Sapphire Crystal" line (`BU210.80.*`) and the Twin Turbo
  Furious Sapphire Crystal line (`TT220.80.*`) use **`Sapphire`** as the actual case material —
  the entire case is machined from a single block of sapphire crystal, not just the crystal/lens.

## Partial-ref detection — corrected methodology (important fix mid-session)

- **The original prefix-matching check (`long_ref.startswith(short_ref)`) has a real blind
  spot** and under-detects: it only catches a short "placeholder" ref (ending in a bare `.A`)
  as partial when the longer ref's extra suffix happens to start with the letter `A`
  (e.g. `EX110.20.AA.AF.A` → `EX110.20.AA.AF.ABRUA` is caught; but `EC323.20.AB.AB.A` →
  `EC323.20.AB.AB.BBRUA` is **not** caught, because `BBRUA` doesn't start with `A`, even though
  it's the exact same kind of placeholder-vs-full relationship).
- **Fixed check**: match on "same base string up to and including the final dot" instead of
  raw string-prefix, restricted to cases where the short ref's final segment is literally the
  single placeholder character `A` (the only character confirmed, via dozens of prior examples
  and one explicit user-confirmed case, `EC323.20.AB.AB.A`/`.BBRUA` — verified identical watch
  via image comparison AND independent web listings on both UK and US retailers — to be used as
  a generic/incomplete marker in this dataset). Re-running this corrected check against the
  **entire tab** (not just the currently-filtered subset) found 7 more genuinely missed partial
  refs beyond the ones already flagged:
  `EC323.20.AB.AB.A`, `BT543.30.BD.BD.A`, `OI100.21.AA.AA.A`, `OI100.30.AA.AA.A`,
  `BU300.21.AA.AA.A`, `AM500.40.AC.SD.A`, `BU200.21.AH.AB.A` — all flagged.
- **Do not generalize the "same base" match to any final segment, only the literal `.A`
  placeholder.** Broadening it (any 1+ character final segment against any longer same-base
  ref) produces heavy false positives — most single-letter-different suffixes
  (e.g. `K` vs `GHB4D`, `AC` vs `AD`/`KE`) are genuinely distinct real colorway codes within
  the same model family, not truncations. Confirmed false-positive example investigated:
  `EX110.20.AA.AE.ABRUA` superficially "matches under" the malformed `EX110.20.AA.AE.A.ABRUA`
  (stray extra dot) — but the shorter one here is actually the *correct* full reference, and
  the longer one is the anomaly, the reverse of the usual pattern.

## Invalid/typo detection — separate from partial-ref detection

- A true typo (not a truncation) surfaces as a Hamming-distance-1 (single character swapped)
  match against another real ref, **but string similarity alone cannot distinguish a typo from
  a legitimate distinct colorway code** — Jacob & Co. genuinely uses huge families of
  single-letter-different variants (e.g. dozens of `BQ030.10.RH.K*` codes are all real). The
  only reliable signal is **web verification**: does any legitimate dealer confirm the
  suspect reference on its own, or does every hit trace back to replica/counterfeit sites (or
  to nothing at all)?
- **Confirmed invalid (typo) refs found and flagged this way**, each cross-checked against the
  sheet's own `ReferenceNumberId = NULL` (unlinked/unmatched) signal as corroborating evidence:

  | Invalid ref | Correct ref | Evidence |
  |---|---|---|
  | `AT100.40.AC.AC.BBALA` | `AT100.40.AC.AC.CBALA` | Every web hit for `BBALA` is a replica-seller page; `CBALA` is confirmed by multiple authorized dealers (Watches of Mayfair, Chrono24, wywatl) as the genuine "Astronomia Tourbillon Chinese Zodiac" |
  | `EC430.21.AA.AB.A` | `EC430.21.AA.AA.A` | No dealer lists the `AA.AB` combination at all; only `AA.AA` and `AB.AA` are confirmed |
  | `MI501.30.BD.AA.A` | `ML501.30.BD.AA.A` | "MI" only appears via EveryWatch's own listing (not independent); every outside dealer (Watches of Mayfair, JamesEdition) calls it `ML501...` (Jacob & Co.'s "Millionaire" line prefix) |
  | `AS300.40.AA.AD.A` | `AS300.40.AA.AE.A` | No dealer lists `AA.AD`; `AA.AE` ("Astronomia Solar Constellations & Planets") is well-confirmed by many sellers |

  Flagged in `PartialRefFlag` with `"Invalid - unconfirmed, likely typo of <correct ref>"` —
  a distinct wording from the `"Partial - full ref present: ..."` convention, since this is a
  different defect class (a wrong/mistyped reference, not a truncated-but-otherwise-correct one).
- **A structural 1-char-diff + single-match sweep of the whole tab turns up ~48-57 more
  candidates**, but most are expected to be real distinct variants, not typos — each one needs
  individual web verification before being trusted, same as above. Not fully worked through as
  of the last session; picking this up again means re-running the same single-ref web-search
  check per candidate, not trusting the structural match alone.

## Single-character-difference sweep — completed in full

Picked up where the earlier session left off (48 structural candidates, only ~12 individually
web-verified at the time). Finished verifying all remaining unique pairs — scope was
properly-formatted, unflagged refs with `ReferenceNumberId = NULL` and exactly one
Hamming-distance-1 match elsewhere in the tab. Final result:

- **9 more confirmed invalid** (flagged `"Invalid - unconfirmed..."` in `PartialRefFlag`):
  `BU200.20.AE.AB.ABRUA`, `BU200.21.AE.AB.ABRUA` (both: every hit is a replica-site listing,
  while the real dealer-confirmed ref for each ends in bare `.A`), `EC400.22.AE.AA.ABRUA`,
  `EC400.21.AF.AA.ABRUA` (both unconfirmed anywhere; real sibling is
  `EC400.22.AF.AA.ABRUA`), `EC440.43.AB.AA.ABRUA` (the "440" Tri-Compax line uses an "AC"
  suffix, not "AB" — likely cross-contaminated with the "430" line's real
  `EC430.43.AB.AA.ABRUA`), `EX120.10.AD.AB` (no official match at all, no confident redirect).
- **~20 confirmed genuinely valid**, not flagged — important pattern reinforced again: a
  structural near-match plus an unconfirmed exact string is *not* enough on its own. Several
  rows turned out to be real products simply missing their fuller sibling from our own
  catalog (`EX110.20.AC.AJ.A`, `OI100.40.AA.AB.A`, `BT543.40.BR.BR.A` — all independently
  confirmed as real Jacob & Co. designs by dealers, just not in the exact suffix form sitting
  in our sheet) — these were *not* flagged, since there's no actual error, just a
  catalog-completeness gap.
- **Conclusion on this method**: individual web verification remains mandatory, no shortcut.
  Roughly 1 in 3 structural candidates in this brand's data turns out to be a real typo; the
  other 2 in 3 are genuine distinct products the structural match coincidentally resembles.

## "Same base, longer match exists" sweep — made exhaustive (no length restriction)

The original version of this check was scoped to the user's requested length brackets
(16-19 short vs 19-22 long). Re-ran with **no length restriction at all** against the full
tab to close the gap. Found exactly 9 total same-base candidates in the then-current clean
filter, all individually resolved (5 genuine, 3 flagged as issues, 1 confirmed non-issue
where the "short" one was actually the correct ref and the longer one was a separate stray-dot
anomaly). This check is now provably exhaustive for the base-match pattern — re-run it fresh
any time new rows are added or the filter changes, since "exhaustive" is a point-in-time
guarantee, not a permanent one.

## State as of last check

- Current live filter on `Jacob&co. final refs` (Length visible + PartialRefFlag blank):
  **1030 rows**, confirmed 0 duplicates, 0 remaining partial-ref candidates (via the corrected
  same-base check), 0 rows with a non-blank `PartialRefFlag` leaking through the filter.
- `PartialRefFlag` hidden-values count in the live filter: 193 (176 original + 9 from an
  earlier catalog cross-check + 7 from the corrected-methodology pass + 4 invalid/typo flags,
  with some filter-refresh timing lag along the way — always re-check the live filter's
  `hiddenValues` list directly rather than assuming a prior count still holds).
