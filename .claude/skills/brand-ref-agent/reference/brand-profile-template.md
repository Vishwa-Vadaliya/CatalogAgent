---
type: Document
title: Brand reference profile — template
description: Template for the per-brand reference profile produced in Step 1b, with confidence levels for each claim about a brand's reference formats.
tags: [skills, brand-ref-agent, template, reference-profile]
timestamp: 2026-10-31
---
# Brand reference profile — template

Copy to `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Profile.md` in Step 1b. Fill every section.
Every claim carries a **source URL** and a **confidence**:

- **confirmed** — a source states it for this brand, and you checked that the link says so
- **likely** — consistent evidence from dealers/auctions but no direct statement, or one source only
- **unknown** — could not establish it (write what was tried)

Mark anything from memory as `unverified`. Unverified claims are not used as rules in Step 2.

```
# <Brand> — reference profile
Last updated: <date> | Researched by: <agent / user> | Sheet tab: <source tab> | ManufacturerName: <exact>

## 1. Summary (5 lines)
- Number of structures in the data / classified / unknown:
- Current vs vintage formats:
- Main risk of non-references in the data:
- Verification sources that work / that block access:

## 2. Valid reference formats
| Structure (digits=9, letters=A) | Example | Era / lines | Current or vintage | Segment meaning | Confidence | Source |
|---|---|---|---|---|---|---|

## 3. Aliases and pairings
(old/new number, a second spelling of the same ref, one number covering a family of others, with the rule and
how to recognise it. Say whether the pairing is 1:1.)
| Alias type | Example A | Example B | Rule | 1:1? | Confidence | Source |
|---|---|---|---|---|---|---|

## 4. Numbers that are NOT references
| Type (caseback code, case serial, caliber, warranty/certificate no., date/batch code, limited-edition no., dealer SKU, price-list code, other) | Looks like | Where it appears on the watch / listing | How to tell it from a ref | Values in the sheet that look like it | Confidence | Source |
|---|---|---|---|---|---|---|

## 5. Suffixes and codes that change meaning
(letters or digits at the end or inside that mean strap vs bracelet, limited edition, retailer, colour, etc.
Say which are the same ref and which are different configurations.)

## 6. Structure table (every structure that occurs in the data)
| Structure | Unique values | Rows | Class (valid current / valid vintage / alias / not a reference / unknown) | Notes |
|---|---|---|---|---|

## 7. Verification oracle
- Reliable sources (and what each is good for):
- Unreliable sources (replica sites, templated database pages, scraped duplicates):
- Sources that block automated access (status codes):
- Search patterns that worked:

## 8. Open questions and dead ends
(what is still unknown, what was tried, what to ask the user)

## 9. Rules this profile gives Step 2
(one line each: which structures are in scope, which are excluded and why, which pairings must be
flagged on both sides, which numbers must never be treated as refs.)
```
