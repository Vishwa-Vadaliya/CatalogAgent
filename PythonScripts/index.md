---
type: Data Index
title: PythonScripts index
description: Index of the standalone Python scripts folder. Non-markdown files; no frontmatter added.
tags: [index, pythonscripts, python]
timestamp: 2026-11-04
---

# PythonScripts — index

- `check_tilt.py` — catalog image tilt checker: downloads image URLs and flags watches that aren't properly vertical (OK / TILTED / BORDERLINE / HORIZONTAL / UNDETERMINED).
- `pick_best_image.py` — picks the most vertical watch image per reference and writes its URL into the `FinalImageUrl` column.
- `prepare_review_sheet.py` — prepares a review sheet.
- `google_auth.py` — shared Google credentials for every script here, from Application Default
  Credentials (`GOOGLE_APPLICATION_CREDENTIALS`). No key path in any script. Run it directly to
  check the credentials resolve.
- `catalog_traceback_setup.py` — builds (or rebuilds) the Catalog Traceback change-log structure on
  a tab: two-row grouped header, dropdowns, text/date formats, notes. Dry run unless `--write`;
  backs the tab up to CSV first and refuses to overwrite real data rows.
- `catalog_traceback_log.py` — appends change rows to the Catalog Traceback log. Used by the
  `/log-catalog-change` skill. Dry run unless `--write`; checks the header, snapshots the tab and
  flags duplicates before appending, then puts back the number formats the append drops.
- `catalog_traceback_repair_format.py` — the one definition of how the Catalog Traceback data rows
  look: dropdowns, text/date formats, per-column alignment, wrapping, row banding and the group
  rules. Never touches values. Idempotent; run it after any bulk write or sheet rebuild.

## Note: two versions of `pick_best_image.py`

There is a second, **different** copy at
`.claude/skills/brand-ref-agent/scripts/pick_best_image.py` (434 lines vs 354 here). The skill's
copy is the reworked one: tab, sheet id and column positions are arguments instead of per-brand
edits, columns are found by header name, the sheet is read to its real row count (this older copy
stops at row 2500), the output column follows `--final-col` rather than a hard-coded "R", and target
rows are re-checked against the live sheet before writing.

Both were carried over rather than silently merged. **Use the skill's copy** — via
`/brand-ref-agent` — unless you specifically want the older standalone behaviour. If nobody needs
the old one, delete this copy rather than leaving two.
