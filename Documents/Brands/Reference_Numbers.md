---
type: Document
title: Reference numbers & models — cleanup knowledge
description: How to decide on reference-number and model cleanup across brands, plus Cartier-specific reference patterns.
tags: [documents, reference-numbers, cleanup, cartier]
timestamp: 2026-10-24
---

# Reference numbers & models — cleanup knowledge

How to decide on reference-number and model cleanup, plus brand-specific reference patterns (Cartier). DB facts about reference numbers and models live in [Knowledge/references-and-models.md](../../Knowledge/references-and-models.md).

---

## 1. Ref / model cleanup decisions

- Decide by watch knowledge + web search — **not** by watch count, active/pending flag or smaller id. Watch count ≥ 10 → extra care; never Delete without checking whether it can be merged.
- Keep the **brand-standard format** (brand website): "RM 001" not "rm001"; check spacing (e.g. Franck Muller) before keeping.
- Appearing in search results doesn't prove a ref is correct.
- Merge: spacing/zero-padding (`PAM 24` → `PAM024`), missing prefix (IWC `3714` → `IW3714`), AP `0` vs `O` (`O` correct, `15186OR`), `OO` vs `00`, separators, Richard Mille keyword variants → clean "RM 011".
- Models: shorthand → full (`Perpetual` → Oyster Perpetual), misspelling → correct (`Caltrava` → Calatrava), case size/dial variants aren't models (`Lady-Datejust 26` → Lady-Datejust, `Deepsea D-Blue` → Deepsea), nicknames merge (TV / TV Watch / Television). Descriptions aren't model names. A specific model beats the generic family.
- A shared name can be valid (Piaget "Tank" = valid vintage model).
- Several possible targets → leave unchanged, note "multiple possible target" (only genuine cases).
- Ref pairs: changed core digits = different (182.068 ≠ 182.086); same digits moved = same (PAM 852 = PAM00852). Judge each pair individually.
- **Delete ref** = completely wrong (caliber, movement, case size, random number). Non-standard pattern may be vintage → don't delete on that alone.
- Valid **partial ref** with many children (HH1.210) stays; not a synonym of one full ref.
- Combined string → split only if each part is a valid ref (W1532656 stays; W153 never valid).
- Omega `-68`/`-69`/`-76` = year suffix (145.022-68 → 145.022). Some stored refs are case numbers ("OP 6714 … ideally PAM00287").
- Slug issue: ReferenceNumber exactly equals a model name → assign that ModelId.

## 2. Cartier

- Watches often carry a 4-digit **case number** or serial instead of the W ref → never match the catalog by ReferenceNumber. One case number → many W refs (2384 → W51008Q3, W51027Q4, W51007Q4).
- Cartier refs (catalog `##temp` → EveryWatch) → match `tblReferenceNumber.ReferenceNumber` directly with `ManufacturerId = 23`, no manufacturer-name join.
- `2384/W51007Q4` → corrected ref is the W ref only. 6-digit dealer codes (W, WA, WZ, WAT, WWL, WWM, WP) aren't refs → keep the case number.
- Variation uniqueness: only a different strap **material** makes a new variation.
