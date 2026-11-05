---
type: Document
title: Session Summary — 2026-10-17 (Jacob & Co. / Girard-Perregaux / Roger Dubuis)
description: Session summary covering multi-brand watch-reference data-quality work and hard-learned standing rules for Jacob & Co., Girard-Perregaux, and Roger Dubuis.
tags: [documents, session-summary, jacob-and-co, girard-perregaux, roger-dubuis]
timestamp: 2026-10-24
---

# Session Summary — 2026-10-17 (Jacob & Co. / Girard-Perregaux / Roger Dubuis)

**Context:** Long-running, multi-brand watch-reference data-quality project, done entirely via
Python scripts calling the Google Sheets API (service account creds at
`C:\Users\user\.secrets\ew-sheets-sa.json`). All tabs worked on this
session live in workbook `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg` (titled
"RawRefsToAssign"). Reference material/plans live in `D:\EW\Scripts\Queries\Vishva\` —
`Brand_Reference_Validation_Workflow.md` is the master methodology doc; each brand also has its
own `{Brand}_Reference_Validation.md`. **No file existed yet for Girard-Perregaux or Roger
Dubuis** at the end of this session — that's a pending task (see below).

## Standing hard-learned rules

- Always re-fetch a tab's filter (`basicFilter.criteria`) fresh before replicating it in
  Python — never trust cached criteria across turns.
- This specific workbook's **Girard-Perregaux tab has a live sort tied to its filter** — row
  numbers shift unexpectedly (discovered when row 667 silently became a different ref). Always
  re-locate rows by ref-string content, never by cached row number, before writing.
- Structural "this ref looks like a truncated/typo'd version of that ref" signals are
  **necessary but not sufficient** — must cross-check against (a) `ReferenceNumberId` NULL-ness
  (strongest single flag for "unconfirmed"), (b) whether the brand's own official site/dealers
  independently confirm the exact string, and (c) whether the candidate's segments are
  known-valid codes used elsewhere. Blind string-similarity (Hamming distance, prefix-matching)
  alone produces heavy false positives on brands with dense structured numbering (Jacob & Co.,
  Girard-Perregaux) — roughly 1-in-3 "candidates" turn out to be real typos, the rest are
  genuine distinct variants.
- When a brand's official reference format is genuinely uncertain, **web-verify against the
  actual brand site** before assuming a "unified structure" — some brands (Girard-Perregaux)
  use multiple valid concatenation conventions depending on model line; "fixing" formatting
  without verification risks introducing new errors.

## Work completed this session, by tab

### 1. Jacob & Co. (`Jacob&co. final refs` tab)

- Filled `DialColor` for 327 filtered blank rows — abandoned automated pixel-based color
  classification (produced absurd results, e.g. called a rainbow-gem dial "Gray") and did full
  manual visual review of all 324 viewable images instead. Established rule:
  **Skeletonized > Paved > named-color/Multi-colored** precedence (fully gem-paved dial, any
  color, = "Paved" even with colored stones; open-worked movement = "Skeletonized" regardless
  of accent colors). Corrected 93 rows after this rule was clarified mid-task. 3 rows left
  blank (corrupted/wrong images).
- Web-researched and corrected `CaseMaterial` for 20 flagged rows with non-standard
  casing/values (e.g. "Black Carbon" → confirmed actually "Stainless steel" for Epic X Bridges
  family).
- Found and fixed a real blind spot in partial-ref detection: original check only caught
  `ref + "A..."` truncations; fixed to match on "same string up to last dot" regardless of what
  follows. Found 7 more genuine partials this way. Further hardened by testing a
  "no-length-restriction" exhaustive version — confirmed complete for this pattern.
- Ran full single-character-difference (Hamming-1) typo sweep (48 unique candidate pairs with
  `ReferenceNumberId=NULL`), web-verifying every one. Found and flagged as **invalid**
  (format: `"Invalid - unconfirmed, likely typo of <correct ref>"`): `AT100.40.AC.AC.BBALA`,
  `EC430.21.AA.AB.A`, `MI501.30.BD.AA.A`, `AS300.40.AA.AD.A`, `EX100.43.PS.BW.AL`, plus 6 more
  from a second pass (`BU200.20.AE.AB.ABRUA`, `BU200.21.AE.AB.ABRUA`, `EC400.22.AE.AA.ABRUA`,
  `EC400.21.AF.AA.ABRUA`, `EC440.43.AB.AA.ABRUA`, `EX120.10.AD.AB`) — **14 total new
  invalid/partial flags** this session, on top of 185 pre-existing.
- Filled blank `TotalWatchCount` for 833 rows by counting each row's own `WatchIds`.
- Cross-checked `Jacob&co. final refs` against `Sheet4` col M (Jacob & Co catalog, 51 refs):
  found 1 exact duplicate (`AT100.95.KR.SR.B` — user flagged it) and 8 partial-ref
  relationships (catalog has generic base, final-refs has fuller suffix) — flagged all 8 in
  **both** `Sheet4` col N and the corresponding final-refs rows (with distinct wording:
  `"Base ref X already present in catalog (Sheet4) as partial"` since the final-refs side holds
  the *full* ref, not the partial one).
- Updated `D:\EW\Scripts\Queries\Vishva\Jacob_and_Co_Reference_Validation.md` with all of the
  above (DialColor methodology, CaseMaterial pass, corrected partial-detection logic, invalid-
  ref table, final state: ~1016 clean rows after latest flags).

### 2. Girard-Perregaux (`Girard-Perregaux final refs` tab)

- Tab uses its own pre-existing flag vocabulary in `PartialRefFlag`: `"Junk"`, `"Partial"`,
  `"Already in catalog (Sheet4: '...')"`.
- Checked 823-row filter: 0 duplicates, 0 literal-prefix truncations. Found 9
  structurally-anomalous `ReferenceNumberId=NULL` rows (wrong digit count, lowercase, embedded
  text/commas, case-mismatched duplicate) and flagged them `Junk`/`Partial` per severity.
- User pushed back on relying on `WatchIds`-overlap as the sole evidence; redid validation by
  **decoding the actual GP reference structure** (`XXXXX-MM-DDD-CCCC`, where MM = case-material
  code from a known vocabulary) and confirmed all 54 "close-match" candidates differ only in
  segments holding legitimately-reused codes — confirmed real, not typos.
- User asked to verify GP's official reference convention: **confirmed via real
  girard-perregaux.com pages** that "D"-variant models genuinely use a concatenated format
  officially (e.g. `49555D11A1A1-BB60`, `80189D11A431-11A`, `49523D11A171-11A` — all real, live
  GP URLs), but **always with exactly one dash before the final segment** — zero-dash versions
  were never found on the official site, only on retailer listings (likely retailer formatting
  drift).
- Full-tab breakdown of structural formatting found: 15 dot-separated (safe, mechanical fix —
  **done**, all 15 fixed), 1001 fully-concatenated (zero dashes — confirmed need the final dash
  inserted per official convention, **not yet executed**), 356 partially-concatenated (**not
  yet executed**), 179 space/slash/word-based "vintage-style" refs (genuinely mixed bag — some
  real, e.g. `2580 OGN 220`/`49525 OGN874` independently confirmed on EveryWatch; others are
  data corruption like `49865 WW.TC` where a model name leaked into the ref field, or dealer
  notes like `NOS` leaking in).
- User decided: **don't add any of the 179 space/slash refs** — flag them all in
  `PartialRefFlag`. Found 175 of 179 were *already* flagged (`Junk`/`Partial`) from earlier
  work; flagged the remaining 4 (`1945  , LE 0/13`, `25932 / AN 652`, `49525 OGN874`,
  `75000 BR-396`) as `Junk`.
- **Mid-task discovery:** sheet rows had silently resorted (due to the live sort+filter),
  invalidating cached row numbers. Re-verified by ref-string (not row number) that all prior
  writes (9 structural flags, 15 dot-fixes) landed correctly and intact — confirmed no data
  loss, just relocated rows.
- **Pending/open:** the 1001 zero-dash and 356 partial-dash refs still need the dash-insertion
  fix applied (logic validated, not yet run); the 179 space/slash bucket is fully flagged but
  not further investigated per-ref; no `Girard_Perregaux_Reference_Validation.md` file created
  yet.

### 3. Roger Dubuis (`Roger dubis final refs` tab)

- Confirmed official reference format via rogerdubuis.com: full form `RDDBEX####` and short
  form `DBEX####` are **both legitimate official forms** of the same reference (brand itself
  uses the short form on spec labels); other real collection-code prefixes include DBHO
  (Hommage), DBVE (Velvet), DBKS (King Square), DBMG (Monegasque), DBSE (Sympathie), DBPU
  (Pulsion).
- Checked 338-row filter: 0 duplicates, 0 literal-prefix truncations, all 338 match the correct
  general pattern `^(RD)?DB[A-Z]{2}\d{4}$`.
- Explicitly checked (per user's specific ask) whether any ref's short form AND full form both
  exist as **separate rows** anywhere in the 447-row tab — **0 found**, confirmed in both
  directions.
- Noted that Roger Dubuis's Hamming-1 "close match" check is **not a meaningful signal** here
  (unlike GP/Jacob&Co) because refs are plain sequential integers — every ref has numeric
  neighbors by definition, so proximity alone means nothing for this brand.
- Compared `Roger dubis final refs` against `Sheet4` col J (215 catalog refs): found 108 total
  duplicates (10 exact-string + 98 short/full-form matches) — **all 108 confirmed already
  correctly flagged** as `"Already in catalog (Sheet4: '...')"`, none leaking into the current
  338-row filter, 0 blanks. Nothing new needed here.
- **Pending/open:** no `Roger_Dubuis_Reference_Validation.md` file created yet; no outstanding
  data-quality issues identified for this tab (clean on all checks run so far).

## Immediate next steps (explicitly flagged as open, not yet actioned)

1. Create `Girard_Perregaux_Reference_Validation.md` and `Roger_Dubuis_Reference_Validation.md`
   in `D:\EW\Scripts\Queries\Vishva\`, matching the established format of the other brand
   files.
2. Execute the GP dash-insertion fix for the 1001 fully-concatenated + 356
   partially-concatenated refs (methodology validated against official GP pages; just needs to
   be run).
3. User's last question before this summary was just asking where the plan/workflow files
   live (answered — `Brand_Reference_Validation_Workflow.md` is the master doc) — no technical
   task was left mid-stream beyond the two items above.
