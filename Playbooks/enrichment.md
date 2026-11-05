---
type: Playbook
title: Enrichment correction & review
description: Enrichment work — rule fixes, multiple-ENR collisions, dial-colour dedup, and per-brand image match review.
tags: [playbook, enrichment, enr, multiple-match, image-match]
timestamp: 2026-11-04
---

# Playbook — enrichment correction & review

## Read first

- [../Knowledge/enrichment.md](../Knowledge/enrichment.md) — ENR tables, type ids, what multiple ENR means.
- [../Knowledge/watches.md](../Knowledge/watches.md) — draft vs publish, the `IsDeleted` scope.
- [../Rules/10-sql-style.md](../Rules/10-sql-style.md) — especially B8 (stage `tblWatch` first), B9 (match on ids), B10 (`IsDeleted` only on the watch tables).
- Then, for the specific job:
  - rule authoring → [../Documents/Enrichment/Catalog-Enrichment-Complete-Guide.md](../Documents/Enrichment/Catalog-Enrichment-Complete-Guide.md) and `…-Rules-Documentation.md`
  - multiple match → [../Documents/Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md](../Documents/Enrichment/Catalog-Enrichment-Multiple-Match-Disambiguation.md)
  - how a rule actually runs → [../Documents/Enrichment/Catalog-Enrichment-Runtime-Pipeline.md](../Documents/Enrichment/Catalog-Enrichment-Runtime-Pipeline.md)
  - named dial variants → [../Documents/Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md](../Documents/Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md)

**A full per-brand image match review is its own skill** — use `/image-match-review <Brand>` rather
than rebuilding it here.

## Steps

1. **Pin down the brand and the scope.** Resolve the brand to its `ManufacturerId` — and say which
   database's id you mean, they differ ([../Knowledge/databases.md](../Knowledge/databases.md)).
2. **Establish the baseline before changing anything** — how many watches are affected, split by
   with-ref / without-ref and by enrichment type. One query, temp tables, no fix yet.
3. **Diagnose.** Give read-only queries and ask for the results (A1). Don't propose a fix from an
   assumption about what the data looks like.
   - Has an ENR → `TblWatchEnrichmentResults` (keyed on the **draft** WatchId).
   - No ENR → `tbl_RE_DiscardedWatch` (seek by WatchId, never scan by type).
   - Multiple ENR → `tbl_RE_DataToFix`, `ReferenceEnrichmentId IS NULL`, **no `IsFixed` filter**.
4. **Decide the fix yourself** once the diagnosis is conclusive — don't pause to ask the user to
   agree first. Only stop and ask if the evidence (data + image + signed/verified status) stays
   genuinely ambiguous after checking it.
5. **Write the fix** per B7: preview `SELECT` with an action flag, `BEGIN TRAN` with COMMIT/ROLLBACK
   commented out, a fresh TransactionId per B6. Draft tables only — publishing propagates
   ([../Knowledge/watches.md](../Knowledge/watches.md)). **No publish call in the file** (A9).
6. **Deliver** per [OUTPUT.md](OUTPUT.md).

## Traps

- The manufacturer id is different in the two databases. Check which one the query needs.
- `IsDeleted` exists only on `tblWatch` / `tblWatch_d` — adding it elsewhere silently drops rows.
- Dial colour and case material are link tables, not columns, and a watch can have several.
- The manufacturer-wide image match score defaults to 0.89 — lowering it is a deliberate step in the
  ENR workflow, not a bug.
- A one-off fix touches the `_d` table only; don't write a second UPDATE against the published table.
