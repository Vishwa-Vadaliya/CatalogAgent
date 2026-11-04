---
type: Rule
title: Edge-case checklist
description: Recurring edge cases to check for when detecting partial/invalid reference numbers across brands, mapped to partial_checks.py check types.
tags: [skills, brand-ref-agent, rules, edge-cases]
timestamp: 2026-10-31
---
# Edge-case checklist

These came up repeatedly across brands. Treat each as a check to run, not a one-off. Where a check
is automated, the `partial_checks.py` type name is shown in brackets.

## Partial-ref detection
- [ ] A shorter ref that is a prefix of a longer one can be a **distinct real variant**. Check the
      specs before flagging. `[prefix]`
- [ ] A short base code that prefixes **3 or more** longer refs is usually a standalone base, not a
      truncation. The script marks these `many_prefix`.
- [ ] Base vs base+suffix can be **different configurations** (strap vs bracelet, dial variant).
      They are not automatically duplicates.
- [ ] **Optional brand prefix:** official short and full forms of the same ref (e.g. with or
      without a 2-letter brand prefix) are the **same ref**. Check both directions.
      `[short_full_form]`
- [ ] **Truncation at the front:** a dropped leading letter or prefix. `[front_truncation]`
- [ ] **Fragment embedded mid-string.** `[embedded]`
- [ ] **Placeholder final segment:** "same base up to and including the last separator" with a
      short last segment. Don't widen it beyond the last segment. `[last_separator]`
- [ ] **The longer ref can be the wrong one** (duplicated segment, stray extra separator). Then keep
      the shorter ref and flag the longer one.
- [ ] Re-run the partial checks on the **whole tab with no length limit** after any merge or edit.
- [ ] Case- and whitespace-only differences are duplicates. `[normalized_duplicate]`

## Invalid / junk shapes
- [ ] Hash or GUID strings in the suffix position (long hex runs; real suffixes are 1–4 chars).
- [ ] A ref and a serial number joined with no separator (a confirmed ref plus 4 or more trailing
      digits).
- [ ] Supplier or caliber codes attached to the ref. Look up any unexplained 2–3 letter code.
- [ ] Words, material, karat or weight appended (`RARE`, `18K`, `WG`, `NOS` …).
- [ ] Two refs joined by a space, slash, comma or "AND". Ambiguous, so exclude them.
- [ ] Model names or dealer notes leaking into the ref field.
- [ ] Placeholder text (`XXX`, `TBD`, redacted digit runs).
- [ ] Serial numbers, date codes or factory codes that look like refs.
- [ ] A prefix outside the brand's known prefix set.
- [ ] Wrong digit count for the model family, lowercase, stray spaces. Compare against **refs from
      the same model family**, not one global length rule.
- [ ] Plausible-looking but unconfirmable: **flag or clear it, don't guess.**

## Numbers that look like refs but are not (decide from the brand profile, Step 1b)
- [ ] **Caseback engravings** (case code, case number, hallmark numbers). A brand can engrave a code
      that resembles its ref format without being the catalog ref.
- [ ] **Case serial numbers** (typically long plain digit runs; auction lots often list "Reference"
      and "Case No." separately).
- [ ] **Movement or caliber numbers** and rotor/bridge markings.
- [ ] **Warranty, certificate and card numbers**; **date, batch or production codes**.
- [ ] **Limited-edition numbers** ("123/500") and **internal factory or price-list codes**.
- [ ] **Dealer SKUs and stock numbers** in the ref field.
- [ ] For each of these: how does the brand present it, where does it sit on the watch, and what
      separates it from a ref? That answer comes from the profile with evidence. Never decide from
      the number's length or look alone.
- [ ] A structure whose rows are mostly case/serial numbers is a **scope decision for the user**, not
      an automatic delete. Report it with counts and evidence.

## Typo detection reliability
- [ ] Hamming-1 or Levenshtein similarity alone is **not evidence** on densely numbered brands.
      Only about 1 in 3 candidates are real typos, so web-verify every one. `[hamming1]`, report only.
- [ ] **A NULL `ReferenceNumberId` is the strongest "unconfirmed" signal.** A hit on a replica site
      does not count as confirmation.
- [ ] On brands that use **plain sequential numbers**, near-matches mean nothing. Don't run
      Hamming-1 there.
- [ ] **Decode what each segment means** (material code, dial code, …). A difference in a segment
      that holds a legitimately reused code is not a typo.
- [ ] A real product that is missing from our catalog is a **coverage gap, not an error**.

## Formats & normalization
- [ ] Several valid formats can exist at once: modern SKU, legacy short code, vintage numeric. The
      format can also vary **by model line**.
- [ ] **Verify the convention on the official site before normalizing separators.** Retailer
      listings drift (e.g. a dropped final dash).
- [ ] Count how many refs a proposed formatting fix would change, and show the user **before**
      changing anything.
- [ ] Lookalike characters: letter `O` vs digit `0`, letter `I` vs digit `1`.
- [ ] Cells stored as numbers can show in scientific notation and must be decoded back to the
      original ref.
- [ ] Excluding a whole category from scope is **not** an invalid call. Record it as a scope
      decision.

## Catalog (Sheet4) cross-check
- [ ] An exact match or a short/full-form match means "Already in catalog". `[catalog_exact]`,
      `[catalog_short_full]`
- [ ] The catalog holds the **base** and final refs hold the **fuller** ref: flag **both sides**,
      with wording that shows the direction. `[catalog_base_of_final]`
- [ ] The final ref is a prefix of a catalog ref, so the final ref is partial. `[final_base_of_catalog]`
- [ ] The catalog itself can contain errors. Note them; don't fix them silently.

## Enrichment (DialColor / CaseMaterial)
- [ ] DialColor precedence:
      1. **Skeletonized**
      2. **Paved** (fully gem-set, any stone colour)
      3. **Multi-colored** (3 or more non-gem colours)
      4. the dominant named colour
- [ ] Use visual review. Automated pixel classification proved unreliable.
- [ ] Leave the value blank if the image is corrupt, missing, or shows a different watch.
- [ ] Non-standard CaseMaterial values: web-verify them, don't just re-case them. If a value is
      inferred from sibling refs, say so.
- [ ] A master list or authoritative lookup tab overrides derived values.

## Sheet mechanics
- [ ] A ref with **more than one `ReferenceNumberId`**: report it as ambiguous. Don't pick one
      silently.
- [ ] Column order differs between tabs. Always find columns by header name.
- [ ] `NULL` strings pasted from SQL are written as blanks, so they can't leak into INSERT
      statements.
