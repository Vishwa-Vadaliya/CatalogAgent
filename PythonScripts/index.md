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
