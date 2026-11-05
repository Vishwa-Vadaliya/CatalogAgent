---
type: Document
title: Config
description: Rarely-changing facts the brand-ref-agent skill needs — workbook/access details, document paths, and image-picker settings.
tags: [skills, brand-ref-agent, config]
timestamp: 2026-10-31
---
# Config

Facts the agent needs that rarely change. If one of these moves, fix it here and in
`scripts/sheets_client.py`, where the defaults live.

## Workbook & access

| Item | Value |
|---|---|
| Workbook | **RawRefsToAssign**, `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg` |
| Credentials | Application Default Credentials — **no key path in code or in the prompt**. See below. |
| Script defaults | `SPREADSHEET_ID` in `scripts/sheets_client.py` |
| Python | `python` (3.11). Packages listed in `scripts/requirements.txt` |

### Credentials — never pass a key path

Scripts get credentials from the `GOOGLE_APPLICATION_CREDENTIALS` environment variable, set once
at the Windows **user** level, so it applies in every folder, terminal and session. Nothing needs
to be told where the key is — not a script, not the agent.

```python
from google.auth import default
creds, _ = default(scopes=["https://www.googleapis.com/auth/spreadsheets"])
```

`scripts/sheets_client.py` already does this via its `credentials()` helper; just call `service()`.

| | |
|---|---|
| Env var | `GOOGLE_APPLICATION_CREDENTIALS` |
| Current value | `C:\Users\user\.secrets\ew-sheets-sa.json` |
| Service account | `mcp-sheets-services@quiet-radius-509511-c5.iam.gserviceaccount.com` |

To point at a different service account, change the variable — not any file:

```powershell
[Environment]::SetEnvironmentVariable(
    'GOOGLE_APPLICATION_CREDENTIALS', '<path to key>.json', 'User')
```

A new Google Sheet must be **shared with the service-account email above** before any script can
read it. That is the usual cause of a 403 on a sheet that opens fine in the browser.

The key file is a live credential: it lives outside every repo and must never be committed.

## Documents

| Doc | Path |
|---|---|
| Spec | `D:\EW\Scripts\Queries\Vishva\requirements.md` |
| Methodology (Step 2) | `D:\EW\Scripts\Queries\Vishva\Brand_Reference_Validation_Workflow.md` |
| Per-brand logs | `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Validation.md` |
| Per-brand reference profile (Step 1b output; template in `reference/brand-profile-template.md`) | `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Profile.md` |

## Models

| Work | Model |
|---|---|
| Main session, layout, image picks, filling values, writes, logs | Sonnet 5.5 (`claude-sonnet-5-5`) |
| Research on reference numbers (Step 1b, Step 2 web verification, Step 4c variation web checks) | Opus 5.5 (`claude-opus-5-5`), as a read-only subagent (`model: "opus"`) |
| Cross-model verification of `likely` / `unconfirmed` structures (Step 1b, Step 1) | A fresh Sonnet 5.5 subagent (`model: "sonnet"`), independent of the Opus researcher, not told the first answer |

See `rules/standing-rules.md` #16 and #18.

## Image picker (Step 4)

| Item | Value |
|---|---|
| Script | `scripts/pick_best_image.py` in this skill (same picking logic as the old `D:\catalog_image_tilt_checker\pick_best_image.py`, with the tab and columns as arguments). Run through `scripts/run_image_picker.py`. The old script is untouched and unused. |
| Web fallback | `scripts/web_image_fallback.py`: last resort for references whose best own image is still completely tilted (lists them in `needs_web.csv`; the agent supplies candidate URLs) |
| Dependency | `D:\catalog_image_tilt_checker\check_tilt.py` (imported by the picker) |
| Run outputs | `D:\catalog_image_tilt_checker\runs\<tab-slug>\` (`pick_results.csv` + timestamped backup of old cell values) |

## Sheet4: catalog refs per brand

Each brand's existing catalog refs sit in one column of `Sheet4`. Columns known so far:

| Column | Brand |
|---|---|
| A (B = `PresentInFinalRefsTab`) | Girard-Perregaux |
| E (F = `PresentInRDFinalRefsTab`), J | Roger Dubuis |
| M (N = `PartialRefFlag`), Q | Jacob & Co. |

Columns get reused and added over time, so always confirm the column with the user for a new brand.

## Master values (Step 5)

Master-values workbook: `1fNuS-iNetR3RYS2iMxyrb6ZgX0Ju4tb5ApsGQuhOy3A` with tabs `DialColor`, `Material`, and
`Model` (columns `ModelId, ModelName, ManufacturerId, ManufacturerName, TransactionID, DraftID`). Run it with:

```
python <skill>\scripts\master_value_check.py --tab "<brand> final refs" --master-book 1fNuS-iNetR3RYS2iMxyrb6ZgX0Ju4tb5ApsGQuhOy3A --manufacturer "<ManufacturerName>"
```

A brand can be absent from the `Model` tab (Daniel Roth has no manufacturer there), then every model name is "not in master".

## Manufacturer name for INSERT statements (Step 6)

Use the spelling already used on that brand's earlier INSERT statements. Known so far:

| Brand | ManufacturerName |
|---|---|
| Jacob & Co. | `Jacob & co` |
| Credor | `credor` |
| Girard-Perregaux | `Girard-Perregaux` |
| Daniel Roth | `Daniel Roth` |

For a brand not listed here, ask the user for the exact name before writing statements, then add it
to this table.
