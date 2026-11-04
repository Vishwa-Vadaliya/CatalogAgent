---
type: Data Index
title: .claude/skills/brand-ref-agent/scripts index
description: Index of the Python scripts the brand-ref-agent skill's steps run. Non-markdown files; no frontmatter added.
tags: [index, skills, brand-ref-agent, scripts, python]
timestamp: 2026-10-31
---

# .claude/skills/brand-ref-agent/scripts — index

- `read_brand_data.py` — Step 1: reads a brand's source tab (refs, raw refs, counts, model names).
- `ref_structures.py` — Step 1b: inventories reference structures for the deep brand research.
- `partial_checks.py` — Step 2: automated partial/duplicate/invalid ref detection.
- `sheets_client.py` — shared Google Sheets read/write client (incl. `safe_batch_write`); holds the default `SPREADSHEET_ID`/`KEY_PATH`.
- `prepare_variations_tab.py` — Step 3: prepares the pasted variations tab (`VariationId`, image columns).
- `layout_watch_data.py` — old Step 3 script, no longer used in the current flow.
- `pick_best_image.py` / `run_image_picker.py` — Step 4: picks the best primary image per row (tilt-checker based).
- `web_image_fallback.py` — Step 4: web image replacement for picks that are still tilted.
- `audit_existing_picks.py` — audits existing image picks.
- `ref_change_note.py` — Step 2: records every changed ref (original, change, reason).
- `master_value_check.py` — Step 5: checks DialColor/CaseMaterial/ModelName against the master list.
- `build_insert_formulas.py` — Step 6: writes catalog-ready `INSERT INTO #CreateCatalogQueue` formulas.
- `requirements.txt` — Python package requirements for these scripts.
