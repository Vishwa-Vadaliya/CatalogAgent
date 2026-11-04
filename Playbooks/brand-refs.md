---
type: Playbook
title: Brand reference validation
description: Validating a brand's reference numbers — when to use the brand-ref-agent skill, and how to handle the smaller ref/model questions that don't need the full run.
tags: [playbook, brand-refs, references, validation]
timestamp: 2026-11-04
---

# Playbook — brand reference validation

## The full brand run is a skill

For "build the set of valid references for `<Brand>`" — researching the brand's numbering, reading
the `RawRefsToAssign` sheet, validating, adding variations and images, filling dial and case,
checking master values and generating catalog INSERTs — run **`/brand-ref-agent <Brand>`**
(or `/brand-ref-agent <Brand> from step 4` to resume). Don't rebuild that flow by hand.

## Read first — for anything smaller

- [../Knowledge/references-and-models.md](../Knowledge/references-and-models.md) — catalog side vs watch side, synonym, parent/child, the clean-name functions.
- [../Documents/Brands/Brand_Reference_Validation_Workflow.md](../Documents/Brands/Brand_Reference_Validation_Workflow.md) — the general workflow.
- [../Documents/Brands/Reference_Numbers.md](../Documents/Brands/Reference_Numbers.md) — cleanup knowledge and Cartier patterns.
- The brand's own file in `../Documents/Brands/` if one exists (Bovet, Cartier, Credor, Daniel Roth, Jacob & Co, JLC, Louis Vuitton, Piaget) — and the past queries in `Output/Queries/<Person>/<Brand>/`.
- [../Data/Sheets.md](../Data/Sheets.md) for the sheet.

## Steps for a smaller ref/model task

1. **Resolve the brand to an id** before anything else, and say which database's id
   ([../Knowledge/databases.md](../Knowledge/databases.md)).
2. **Resolve text to ids.** A reference number arriving as text is looked up once in
   `tblReferenceNumber` (+ `ManufacturerId`) and then matched by id only — never join `tblWatch` on
   the text column (B9).
3. **Scope the ref set correctly:** include active *and* pending, no `IsDeleted` filter (that flag
   lives only on the watch tables), whole table unless the user sets a floor.
4. **Classify, don't guess** — Correct vs Synonym vs Merge vs parent/child has a precise meaning in
   the knowledge file. Use those words as the knowledge file defines them.
5. **Deliver** per [OUTPUT.md](OUTPUT.md); brand queries go in `Output/Queries/<Person>/<Brand>/`.

## Traps

- Flags are not mutually exclusive — active+pending exists, so don't treat them as a status enum.
- A caseback or movement number is not a reference number; the brand research step exists to tell
  them apart.
- Rolex and Tudor refs from raw may carry a leading `m`/`M`.
- The sheet keeps old decision columns — add new ones beside them, never overwrite (A5).
