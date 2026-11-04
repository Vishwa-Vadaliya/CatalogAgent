---
type: Skill Step
title: "Step 1b — Deep brand research: learn the brand's reference numbers before judging any value"
description: Mandatory deep-research step that builds an evidence-backed brand reference profile before any reference is validated.
tags: [skills, brand-ref-agent, steps, research]
timestamp: 2026-10-31
---
# Step 1b — Explore the whole brand first (runs BEFORE Step 1, reading the brand data)

> **Model:** the research in this step runs on **Opus 5.5** (a read-only subagent with `model: "opus"`);
> the main session stays on Sonnet 5.5. Claims that stay `likely` or `unconfirmed` get an independent
> **cross-model verification** (section 3). See `rules/standing-rules.md` #16 and #18.

**Order of the first steps: 1b → 1 → 2.** This step comes first. The agent does **not** open the
brand's data tab until the research is done, so the brand's data cannot shape what the agent believes
about the brand. Step 1 then reads the data and tests it against what was learned here.

**Purpose:** build **concrete, evidence-backed knowledge of how this brand numbers its watches**, from
the internet only: every reference structure that exists, which are valid references (current or
vintage), and which numbers that look like references are **not** (caseback numbers, case numbers,
serials, movement numbers, warranty codes, model or limited-edition numbers, dealer SKUs …). The output
is a **draft brand reference profile**. Step 1 completes it with the data and decides which structures
to keep; Step 2 uses it as its rulebook.

This replaces the short "landscape research" (workflow Step 0). It goes deeper and it is mandatory,
for every brand, including brands that look easy.

## Why this step exists

Without it the agent judges refs by pattern and by what the sheet happens to contain. On the
Jaeger-LeCoultre run that meant discovering late that: the brand has several formats at once (modern
`Q`-numbers, legacy dotted `XXX.C.MM`, vintage `E###`, `NNNN.NN`, long dotted forms); one dotted
number can correspond to a whole family of `Q` numbers; the number engraved on the caseback is a
**case code and a case serial, not the catalog ref**; and plain 6–7 digit numbers in the data were
case serials. Each of those needed its own research and its own re-check of flags that were already
written. Learn it once, up front, and do not take the data's word for it.

## Do

### 1. Research the whole brand across all five lanes (no data needed)

Input: the brand name only. Run the lanes yourself or hand them to the Opus subagent(s) (one per lane
is fine; a brief per agent must name the brand, the lane, and what to return: findings with a **URL for
each claim** and a confidence level). Sub-agent reports are model output: check that the links actually
say what the report says (Standing Rule 5), and never let a sub-agent's conclusion stand in for your
own check.

| Lane                          | Question to answer                                                                                                                                                                                                                                                                                                                                                                   | Typical sources                                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A. Current catalogue**      | Which ref formats and prefixes are on the manufacturer's site today? How is a ref presented to the buyer (watch page, spec sheet, warranty card)?                                                                                                                                                                                                                                    | official site (may block fetches, e.g. 403: say so and use search-result URLs that name the ref), authorised-dealer pages, press releases                      |
| **B. Vintage / discontinued** | Which older formats existed, in which era, for which lines? Are they still used by dealers and auction houses?                                                                                                                                                                                                                                                                       | auction houses (Christie's, Sotheby's, Phillips, Bonhams, Antiquorum), Collectorsquare, Bachmann-Scher, brand wikis, collector forums, museum / heritage pages |
| **C. Anatomy**                | What does each segment mean (case or model code, material digit, movement code, dial code, strap code, colour code)? Which suffix letters mean something (strap vs bracelet, limited edition, retailer)?                                                                                                                                                                             | reference guides, forum threads, service/parts documents, dealer descriptions of the same watch under two numbers                                              |
| **D. Not a reference**        | Which numbers appear on the watch or in the listing but are **not** the catalog ref: caseback engravings, case serial numbers, movement/caliber numbers, warranty or certificate numbers, date or batch codes, limited-edition "x/500", internal factory codes, dealer SKUs, price-list codes. Where is each found (dial, caseback, movement, card, box) and what does it look like? | auction lots (they often list "Reference" and "Case No." separately), forum threads on caseback markings, manuals, dealer photos of casebacks                  |
| **E. Verification oracle**    | For _this_ brand, which sources reliably confirm a ref, which are unreliable (replica sites, templated database pages), and which block automated access? How do you recognise two numbers for the same watch (alias, old/new number, dotted spelling of a coded number)?                                                                                                            | the research from lanes A–D, plus spot checks of 10–15 refs found online                                                                                       |

For each claim, record the evidence and how sure you are: **confirmed** (a link that says it),
**likely** (consistent evidence, no direct statement), or **unconfirmed** (one weak source, or from
memory). Search several ways (the structure alone, brand + a sample ref, a sample ref + its model, the
structure + "caseback"), because one missed query proves nothing.

The result is the list of **every structure the brand uses or has used**, each with: an example, era,
what the segments mean, current / vintage / alias / not-a-reference, and its confidence.

### 2. Write the draft brand reference profile

Create `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Profile.md` from
`reference/brand-profile-template.md`. If a profile already exists, **update it** instead of starting
again, and say what changed. Every format and every "not a reference" rule carries a source URL and a
confidence level. Claims from memory are marked `unconfirmed` and are not used as rules.

### 3. Cross-model verification of the `likely` and `unconfirmed` structures

Every structure or rule whose confidence is **likely** or **unconfirmed** gets a second, independent
opinion from a **different model** than the one that researched it:

1. For each such claim, start a fresh subagent on **Sonnet 5.5** (`model: "sonnet"`), separate from the
   Opus researcher. Give it **only the question**, not the Opus answer: "For brand X, is the structure
   `<pattern>` (example `<ref>`) a catalog reference number, a case/serial/other number, or something
   else? Search the official site, dealers and auction houses; return a link for every claim." Not
   telling it the first answer keeps the check independent.
2. Compare the two answers:
   - **They agree and the verifier returns a link that really says it** (you open the link): the
     structure becomes **confirmed**. Note both models and the link.
   - **They agree but there is no link that backs it:** it stays `likely`. Two models repeating the same
     thing from memory is not evidence.
   - **They disagree:** it stays `unconfirmed`, both answers and links are written in the profile, and
     it goes on the list for the user.
3. Never use the cross-check to *lower* a confirmed claim; if the verifier contradicts a confirmed one,
   re-open the link and report the conflict.
4. Do the whole set, not a sample (Standing Rule 10). Report how many structures were checked, how
   many moved to confirmed, how many stayed likely, how many conflicted.
5. If Opus or the Sonnet subagent is not available, say so and ask the user. Do not quietly skip this.

### 4. Report and stop

## Report

- Formats found: for each, an example, the era, current vs vintage, what each segment means, and the
  confidence level (before and after the cross-model check).
- **Numbers that are not references**: each type, where it appears, and how to recognise it.
- Aliases and pairings (old/new number, dotted spelling of a coded number, one number covering a
  family of others), with the rule.
- What was individually confirmed vs inferred; the structures where the two models **disagreed**; what
  is unknown and what was tried; any source that blocked access.
- Which research findings came from the Opus run and which from the cross-check.

## Checkpoint

**Stop.** The user reviews the draft profile and may correct it. Only then read
`steps/01-read-brand-data.md`. Step 1 reads the data and decides which structures to keep.

## Rules for this step

- **Evidence, not memory.** Do not describe a brand's numbering from general knowledge alone. If a
  claim comes from memory, mark it `unconfirmed` and either check it or leave it out of the rules.
- **Do not decide a number is a case number or serial from its length or look alone.** Find out how
  the brand marks and presents those numbers, and show the evidence (an auction lot that lists both,
  a caseback photo description, a brand statement).
- **Don't open the brand's data tab in this step.** The research is independent of the data.
- **Say how sure you are.** Use the three levels in the template (confirmed, likely, unconfirmed) and
  give counts.
- **Record dead ends** (blocked sites, templated database pages, replica sites) so the next run does
  not repeat them.
- Writing the profile file is the only write in this step. No sheet writes.

## Worked example (depth to aim for): Jaeger-LeCoultre

Learned on the Jaeger-LeCoultre run; a profile for the next brand should be at least this specific.

- **Formats in the data (61 structures):** modern `Q` + 7 digits, `Q` + 6 digits + letter,
  `Q` + 3 digits + letter + 3 digits; legacy dotted `XXX.C.MM` (3-digit case/model code, 1-digit case
  material, 2-digit movement code); the same with a `.S` suffix; long dotted `XXX.CMM.NNN`; vintage
  `NNNN.NN` where the last two digits are a case-metal code; vintage `E###` (1960s–70s); short plain
  numbers.
- **Pairing:** one dotted ref can correspond to a family of `Q` numbers that share a 4-digit block and
  differ in strap and dial; dealers also write a `Q` number's digits with dots (`290.11.20` =
  `Q2901120`). Not 1:1, and the two spellings both appear in the data.
- **Not references:** the caseback carries a case code (`xxx-c-mm`) and a 6–7 digit **case serial**
  number; auction lots list "Reference" and "Case No." separately. Plain 6–7 digit values in the data
  were case serials. Supplier or caliber codes and dealer notes also leaked into the ref field.
- **Oracle:** the official site returned 403 to direct fetches; evidence came from dealer, auction and
  database pages; some database pages were templated and were treated with caution.
- **What it changed:** the flag rules (a dotted ref flagged against its `Q` numbers, partials of
  flagged refs flagged too), the scope (case serials excluded), and which structures needed web
  verification one by one.
