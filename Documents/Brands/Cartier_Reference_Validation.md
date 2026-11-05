---
type: Document
title: Cartier reference-number project — current state
description: Current state of the Cartier reference-number project — key sheet tabs, confirmed reference conventions, valid structural patterns, and open items.
tags: [documents, cartier, reference-validation, brand-ref-agent]
timestamp: 2026-10-24
---

# Cartier reference-number project — current state

Work happens entirely via Python scripts calling the Google Sheets API (service account creds at `C:\Users\user\.secrets\ew-sheets-sa.json`), in the **second workbook**: `1IB6isLK_WiKOtiRAu6ouUEAkCJAgTt81seFQ85rvtn0`.

## Key tabs and their roles
- **All Refs final** — master per-ReferenceNumberId rollup (RefSource, ReferenceNumberId, RefName, watch counts, Top10WatchIds, ValidFlag, InCatalog, W-ref lists). **Column layout shifts frequently** as the user inserts/renames columns — always re-fetch headers by letter (`A1`, `B1`, ... one at a time) before writing, never trust positional array indexing. As of last check: O="W Refs" (combined list), P="Catalog Refs" (subset in catalog), Q="Non catalog refs", R/S/T=counts, U="Added from title & desc" (refs we appended that came from title&desc, not originally in O).
- **Catalog** — 3717 raw catalog ReferenceNumbers in column I, with a "len" helper column H. Column J used for ad-hoc fix notes, convention: `"the correct ref is - {fix}"` (established by the user's own pre-existing note, we followed it).
- **Catalogs** — cleaner catalogid + referencenumber mapping (nearly 1:1, no duplicate structure found).
- **title& desc** — 4244 rows of scraped listing titles/descriptions per WatchId, with `ReferenceNumber` (raw/caseback ref) and `W_Match` (W-style ref extracted from listing text) and `Context_5_before_after`. Joins to "All Refs final" via `ReferenceNumberId`. Very useful for resolving ambiguous truncation candidates (real-world confirmation of which digit was dropped).
- **Unique W Refs from O** — tab we built: all unique W refs pulled from "All Refs final" col O, with OccurrenceCount + linked ReferenceNumberIds/RefNames. User later added columns E-J (ReferenceNumber, Source, CatalogId, ReferenceNumberId, WatchIds) and a Source classification (Catalog/EveryWatch/RawRef/NotFound). Col K = "Present in All Refs final (col P)" flag we added.
- **All W refs data** — per-unique-W-ref enrichment (Source, ReferenceNumber, DialColor, CaseMaterial, ModelName, PublishWatchId, Images), same Source categories (Catalog/EveryWatch/RawRef/NotFound).
- **Sheet18** — authoritative DialColor/CaseMaterial/ModelName/PublishWatchId/Images lookup by ReferenceNumber, used to override "All W refs data".
- **RawRefsToAssign** — 10,520 rows of dirty/unassigned RawReferenceNumber + WatchIds. We added column C "ExtractedReferenceNumber".

## Confirmed Cartier reference conventions (web-verified)
- Modern format: `W` + material letter (S=steel, G=gold, J=jewelry, 2=two-tone, H=high horology, P=platinum) + 2-letter model family (SA=Santos, TA=Tank, BB=Ballon Bleu, CH=Crash, CL=Clé) + 4 digits. E.g. `WSTA0059`.
- `CR` prefix (e.g. `CRWSSA0089`) is optional/equivalent — "Cartier Reference", same watch without it.
- Caseback-era numeric codes are legitimate standalone refs, not junk: 9-digit (1973-80s, ref+serial combined), 6-digit (1980s-90s), 4-digit (1996-2014 transitional). A bare numeric caseback code and a full W-ref can validly refer to the same watch from different eras.
- `HPI`/`HPB` prefix (no W) confirmed real via live cartier.com product URLs (`CRHPI01705`) — high-jewelry watch line.
- **Genuine Cartier references are only ever all-numeric OR W-prefixed** (plus the confirmed HPI/HPB exception). An "A" prefix is NOT a valid Cartier reference — on pre-2009 watches that's the *serial number* format (letters-then-digits), not the reference. Confirmed by removing 27 A-prefixed rows from RawRefsToAssign extraction.
- No public source anywhere links an H-prefix ref (HPI/HPB/HLSD/HSA/HP) to a specific caseback number — Cartier's internal cross-reference between caseback-number and full reference is never published; same gap exists for other brands (e.g. Credor).

## 14 confirmed valid structural patterns (A=letter, X=digit), derived from Catalog tab's 3717 refs
AAAAXXXX, AXXXXXXX, AAXXXXXX, AXXXXXAX, AAAXXXXX, AAXXXXAX, AXAAXXXX, AXXXXXX, AAXXXXAA, AXXXXXXA, AAXXXXXA, XXXXXXXX, AAAXXXX, XXXX, AAAXXXXXX (15 total incl. the rare HPC-style one).
Known-invalid one-off patterns (each exactly 1 occurrence in the whole catalog, confirmed errors): `A XXXXXXX` (stray space, e.g. `W 3140001`), `AAAAXXX` (missing digit, `WGRN011`→should be `WGRN0011`), `AAAAAXXXX` (extra letter, `WHHSA0027`→should be `WHSA0027`). The `AXXXXAX` pattern (9 occurrences, e.g. `W2001C4`) is suspected truncated — valid only at 8 chars (`AXXXXXAX`, e.g. `W31043M7`).
**Caution**: pure-numeric patterns (`XXXX`, `XXXXXXXX`) have very weak evidentiary backing (1 and 4 confirmed examples respectively) — when applying this whitelist to new/dirty data (e.g. RawRefsToAssign), cross-check pure-numeric matches against actual Catalog data before trusting them; they produced 0/995 confirmed hits when checked.

## Open items not yet resolved
- **RawRefsToAssign col C**: ~220 extracted refs with non-W/non-numeric/non-HPI(B) prefixes (`TO...`, `CC...`, `MG...`, `BF...`, `L...`, `M...`, etc.) likely aren't genuine Cartier watch refs either — same issue as the removed A-prefix ones. User hasn't yet confirmed whether to clear these too.
- **Unique W Refs from O**: 147 of 1381 unique W refs appear under more than one ReferenceNumberId/RefName group (e.g. `W1002653` under both `590005` and `1615`) — possible mis-grouped duplicates, not yet investigated.
- `W2519` and `W3142` are known incomplete/web-address-fragment refs (flagged low-confidence) — confirmed NOT in Catalog col P either.
- `WAZ1120` (row 606 in "All W refs data") has no match in Sheet18.
