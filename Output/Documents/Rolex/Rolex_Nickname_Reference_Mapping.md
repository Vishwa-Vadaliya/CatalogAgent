---
type: Research Note
title: Rolex collector-nickname → reference number mapping (draft)
description: Researched mapping of well-known collector nicknames to specific Rolex reference numbers, for matching against tbl_CAT_Catalog_d.NicknameId. Draft — needs confirmation before any SQL is run.
tags: [rolex, nickname, catalog, research]
timestamp: 2026-11-05
owner: Janvi
status: draft — pending confirmation
---

# Rolex nickname → reference mapping (draft)

Rolex never assigns these names itself — collectors/dealers coined them, and public sources disagree
on some reference numbers. This list only includes nicknames where multiple sources agree, or where
the disagreement is noted. **High confidence** rows are safe to match by exact `ReferenceNumber`;
**check** rows need a decision before use.

## High confidence (model + bezel/dial colorway is essentially unique to the ref)

| Nickname | Model | Reference(s) |
|---|---|---|
| Pepsi | GMT-Master II | 126710BLRO |
| Pepsi (vintage) | GMT-Master | 1675, 6542 |
| Batman | GMT-Master II | 116710BLNR |
| Sprite | GMT-Master II | 126720VTNR |
| Hulk | Submariner Date | 116610LV |
| Kermit | Submariner | 16610LV |
| Starbucks | Submariner Date | 126610LV |
| Smurf | Submariner | 116619LB |
| Panda | Daytona | 116500LN (white dial variant) |
| Paul Newman | Daytona (vintage) | 6239, 6241 |
| Steve McQueen | Explorer II | 1655 |
| Polar | Explorer II | 226570 (white dial variant) |
| James Cameron / Deepsea D-Blue | Sea-Dweller Deepsea | 116660, 126660 (D-Blue dial variant) |
| Great White / Single Red | Sea-Dweller | 1665 |
| Triple Six | Sea-Dweller | 16660 |

## Check before using — sources disagree or name is ambiguous

| Nickname | Model | Candidates | Issue |
|---|---|---|---|
| Coke | GMT-Master II | 16710, 16760 | Two generations both carry red/black bezel |
| Root Beer | GMT-Master / GMT-Master II | 1675/3, 16753, 126711CHNR | Several generations, "Clint Eastwood" sometimes used for same colorway |
| Wimbledon | Datejust | 126334, 126300 | Depends on green vs. non-green "Wimbledon" text dial |
| Turn-O-Graph | Datejust | 16264, 116264 | Multiple generations |
| Buckley | Datejust | 16104 | Low source agreement |
| President | Day-Date | President is the **bracelet name**, not tied to one reference | Likely out of scope — it's not a ref-specific nickname |
| John Mayer | Daytona | 116508 | Single-source |

## Not resolved yet (mentioned in guides, no reference found)

Bart Simpson, Pussy Galore, Stella (dial, not ref-specific), Milgauss "Z-Blue"/"GV" variants, Cellini,
Air-King, Yacht-Master nicknames. Needs a follow-up pass if these are in scope.

## Open questions before building SQL

1. Only match the **"High confidence"** table for the first pass, or include "Check" rows with a
   chosen candidate ref?
2. Match on exact `ReferenceNumber` string only, or also match a `ParentCatalogId` so variant refs
   under a parent stub inherit the nickname?
3. "President" is a bracelet nickname, not a single-ref nickname — exclude it from this effort?
