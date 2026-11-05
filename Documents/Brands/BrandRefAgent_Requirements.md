---
type: Document
title: Brand Reference Agent — Requirements
description: Requirements spec for the brand-ref-agent — goal, inputs/environment, and the 6-step process for producing clean reference numbers per brand.
tags: [documents, requirements, brand-ref-agent]
timestamp: 2026-10-24
---

# Brand Reference Agent — Requirements

## 1. Goal

Given a brand name, the agent produces the **largest possible set of unique, correct, full
reference numbers** for that brand. The set has no duplicates, partial refs or invalid refs. Each ref
is enriched with dial color, case material, model name and a primary image, and ends up as a
catalog-ready `INSERT` statement.

The agent follows the methodology in `Brand_Reference_Validation_Workflow.md` as it stands today.
That document will be revised in a later task. When it changes, this file's Step 2 points to the
new version automatically. Steps 3–6 below are new and are not covered by the workflow doc.

---

## 2. Inputs & environment

| Item | Value |
|---|---|
| Workbook | **RawRefsToAssign**, `1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg` |
| Access | Google Sheets API via Python (`google-api-python-client`, `google-auth`), service-account key `C:\Users\user\.secrets\ew-sheets-sa.json` |
| Brand source tab | Created or named by the user, one tab per brand. Columns: `WatchId, ModelId, RawReferenceNumber, ModelName, ReferenceNumberId, ReferenceNumber, TotalWatchCount, '', FinalRef` |
| Catalog refs | `Sheet4`. The user puts the brand's existing catalog refs in a column and says which one. |
| Master values (DialColor / CaseMaterial / ModelName) | **TBD. The user will provide the link.** |
| Image picker | `scripts/pick_best_image.py` in the skill (derived from `D:\catalog_image_tilt_checker\pick_best_image.py`, same picking logic, with arguments instead of hardcoded values) |
| Methodology | `D:\EW\Scripts\Queries\Vishva\Brand_Reference_Validation_Workflow.md` |
| Per-brand log | `D:\EW\Scripts\Queries\Vishva\<Brand>_Reference_Validation.md` |
| Scratch work | Session scratchpad directory, not the repo |

**Hard rule:** the agent never runs SQL against any database. When data has to come from the DB,
the user runs their own query and pastes the result into the sheet.

---

## 3. The 6 steps

The agent **stops at the end of every step**. It reports results with exact numbers and waits for
the user's go-ahead before starting the next step. It never chains steps on its own.

### Step 1 — Read the brand's data

- **Input:** brand name, which maps to its source tab in RawRefsToAssign.
- **Agent does:**
  - Reads the header row and finds columns **by name**, never by position.
  - Pulls `ReferenceNumber`, `RawReferenceNumber`, `ReferenceNumberId`, `TotalWatchCount` and
    `ModelName`.
  - Reads any live `basicFilter` on the tab.
  - Computes:
    - total rows
    - rows with `ReferenceNumberId` set and rows with it NULL
    - unique `ReferenceNumber` count
    - unique `RawReferenceNumber` count
- **Output:** a short scope summary.
- **Checkpoint:** the user confirms the scope.

### Step 2 — Validate and build final refs (per the workflow doc)

- **Input:** the Step 1 data.
- **Agent does:** runs `Brand_Reference_Validation_Workflow.md` in its order:
  1. brand-level landscape research on the official site
  2. Phase A: validate `ReferenceNumber` where `ReferenceNumberId` is set
  3. Phase B: extract a ref from `RawReferenceNumber` where `ReferenceNumberId` is NULL
  4. partial / duplicate / invalid-ref detection
  5. create the `<brand> final refs` tab with `ReferenceNumberId`, `WatchIds` and `TotalWatchCount`
  6. structural alignment and dedup
  7. cross-check against the brand's `Sheet4` catalog column
- **Rules for this step:**
  - Issues are **flagged in `PartialRefFlag`, never deleted**.
  - The workflow doc's own internal checkpoints still apply: stop after the landscape research,
    after Phase A, and after each later sub-step.
- **Output:** a `<brand> final refs` tab where every row is either a clean full ref
  (`PartialRefFlag` blank) or flagged with a reason.
- **Checkpoint:** the user reviews the flags and counts.

### Step 3 — Watch data

- **Input:** the user runs their own watch-data query and pastes the raw output into the final-refs
  tab.
- **Agent does:** reorganizes the pasted data into the **standard final-refs layout** (Section 4):
  - Maps each pasted row to its final-refs row by `ReferenceNumberId`.
  - Reports any ref that has no data and any data row that matches no ref.
  - Puts `SourceRowId, ReferenceNumberId, FirstWatchId, FirstWatchPublishWatchId, DialColor,
    CaseMaterial, ModelName, Images` in the watch-data block.
  - Splits `Images` (comma-joined) into one URL per column in the image-candidates block.
  - Adds the `SourceLink` formula (`="https://everywatch.com/watch/"&<FirstWatchPublishWatchId cell>`)
    and the `FinalImage` formula (`=IMAGE(<FinalImageUrl cell>)`).
  - Sets ref columns to TEXT format.
- **Output:** a final-refs tab in the standard layout. The report gives counts of matched,
  unmatched and blank fields.
- **Checkpoint:** the user confirms the layout before image picking.

### Step 4 — Pick the best primary image

- **Input:** the image-candidate columns from Step 3.
- **Agent does:**
  1. Uses the agent's own copy of the picker, `scripts/pick_best_image.py` (same picking logic as
     `D:\catalog_image_tilt_checker\pick_best_image.py`, which stays untouched). It takes the tab
     and columns as arguments, so no constants are edited:
     - `--tab` = the brand's final-refs tab
     - `--first-url-col` = the first image-candidate column
     - `--final-col` = the `FinalImageUrl` column (found by header if not given)
  2. Runs a dry run first, through `scripts/run_image_picker.py`, which also checks that the
     candidate columns hold URLs. The picker reads the whole sheet (no row cap).
  3. Reviews the CSV, then runs again with `--write`. Before writing, the picker re-checks every
     target row against the live sheet by its ref text, and saves a timestamped backup of the old
     cell values.
- **Script behaviour to know:**
  - It only processes rows that are visible under the current filter.
  - It leaves cells that already hold a URL alone.
  - It replaces a hand-pick digit 1–5 with the URL in that slot.
  - By default it **still writes picks flagged TILTED, HORIZONTAL or NOT_WATCH**; `--skip-unusable`
    holds them back.
- **Output:** `FinalImageUrl` filled in. The report lists every row whose pick is not `usable`
  (TILTED, HORIZONTAL, NOT_WATCH, UNDETERMINED, DOWNLOAD_ERROR) so those rows get a manual review.
- **Checkpoint:** the user reviews the flagged picks.

### Step 5 — Master-value check

- **Input:** the final-refs tab (full refs only, `PartialRefFlag` blank) and the master-values
  sheet/doc.
- **Agent does:**
  - Takes the unique values of `DialColor`, `CaseMaterial` and `ModelName`.
  - Compares them against the master list, ignoring case and extra whitespace.
- **Output:** for each field, a list of values **not present in the master list**, with the row
  count for each value. Where an obvious near-match exists in the master list (case, spelling or
  plural difference), it is shown next to the value as a suggestion only.
- **Rule:** the agent does **not** change any value on its own. The user decides.
- **Checkpoint:** the user fixes the values, or tells the agent which replacements to apply.

### Step 6 — INSERT statements

- **Input:** the final-refs tab after Step 5.
- **Agent does:** writes one formula per **clean full-ref row** (`PartialRefFlag` blank) in the last
  column. The formula produces:

  ```sql
  INSERT INTO #CreateCatalogQueue (ReferenceNumber, ManufacturerName, ModelName, CaseMaterials, DialColors, PrimaryImageURL, SourceLink, StatusId, UserID) VALUES ('<Ref>','<Brand>','<ModelName>','<CaseMaterial>','<DialColor>','<FinalImageUrl>','<SourceLink>',1,6);
  ```

  - Build it as a sheet formula that references the row's cells, the same way the existing tabs do.
  - Use the brand's manufacturer name as it is spelled on earlier tabs.
  - Escape single quotes inside values.
  - Leave flagged rows without a statement.
- **Output:** the INSERT column filled in. The report counts statements written and rows skipped,
  with the reason for each skip.
- **Checkpoint:** the user takes the statements and runs them in their own DB tool. The agent does
  not run them.

---

## 4. Standard final-refs tab layout

| Block | Columns |
|---|---|
| Ref identity | `Referencenumbers, PartialRefFlag, ReferenceNumberId, WatchIds, TotalWatchCount, Length` |
| Spacer | blank column |
| Watch data | `SourceRowId, ReferenceNumberId, FirstWatchId, FirstWatchPublishWatchId, DialColor, CaseMaterial, ModelName, Images` |
| Image output | `FinalImageUrl, SourceLink, FinalImage` |
| Image candidates | one URL per column, starting at the column passed to the image script (`--first-url-col`) |
| Last column | `INSERT INTO #CreateCatalogQueue …` formula |

If an existing brand tab already uses a slightly different order, keep that tab's order. Read the
headers by name every time.

---

## 5. Standing rules (every step)

1. **Re-fetch the live sheet right before every write.** The user edits the sheet at the same time
   as the agent.
2. **Replicate the live filter from `basicFilter`. Never assume row order.** Some tabs have a live
   sort tied to the filter, so rows move between calls. Before a write, find each target row **by
   its ref text** and print-check the ref/row alignment.
3. **Never use `WatchId` to decide duplicates.** Use the normalized ref text, image, dial and case
   material.
4. **Verify from several angles before calling a ref invalid or unconfirmed:**
   - official site
   - brand + ref
   - auction houses
   - dealer sites
   One missed search proves nothing. Don't accept a search-summary claim unless a returned link
   backs it.
5. **Don't overclaim confidence.** Say how many refs were individually confirmed and how many were
   accepted by pattern.
6. **Set ref columns to TEXT before writing**, so values aren't turned into numbers or dates.
7. **Match the tab's existing flag wording** (see Section 7).
8. **Never delete rows. Flag them.**
9. **When the user reports one error, re-check the whole set for the same failure mode.**

---

## 6. Generalized edge cases

These came up repeatedly across brands. Treat each as a check to run, not a one-off.

### 6.1 Partial-ref detection
- A shorter ref that is a prefix of a longer one **can be a distinct real variant**. Check specs
  before flagging.
- A short base code that prefixes many unrelated longer refs is a **standalone base**, not a
  truncation.
- Base vs base+suffix can be **different configurations** of the same model (strap vs bracelet,
  dial variant). They are not automatically duplicates.
- **Optional brand prefix:** some brands have official short and full forms of the same ref. Treat
  them as the same ref and check for duplicates in **both directions**.
- **Truncation is not always at the end.** Also catch:
  - a dropped leading letter or prefix
  - a fragment embedded mid-string
- **Placeholder final segment:** match on "same base up to and including the last separator", not
  a raw `startswith`. Don't widen it beyond the last segment, or false positives flood in.
- **The longer ref can be the wrong one**, e.g. a duplicated segment or a stray extra separator.
  Then keep the shorter ref and flag the longer one.
- Re-run partial checks on the **whole tab with no length limit** after any merge or edit. A clean
  result is only true for that moment.

### 6.2 Invalid / junk shapes
- Hash or GUID strings sitting in the suffix position.
- A ref and a serial number joined with no separator.
- Supplier or caliber codes attached to the ref.
- Words, material or karat notes appended to the ref.
- Two refs joined by a space, slash, comma or "AND". These are ambiguous, so exclude them.
- Model names or dealer notes leaking into the ref field.
- Placeholder text (`XXX`, `TBD`, redacted digits).
- Serial numbers, date codes or factory codes that look like a reference.
- A prefix outside the brand's known prefix set.
- Structural outliers: wrong digit count, lowercase, stray spaces.
- If a ref looks plausible but can't be confirmed, **clear or flag it. Don't guess.**

### 6.3 Typo detection reliability
- String similarity alone (Hamming-1, Levenshtein) **is not evidence** on densely numbered brands.
  Only about 1 in 3 candidates turned out to be real typos, so web-verify every candidate.
- **A NULL `ReferenceNumberId` is the strongest single "unconfirmed" signal.** A hit on a replica
  site does not count as confirmation.
- On brands that use **plain sequential numbers**, near-matches mean nothing, so skip this check.
- **Decode what each segment means** (material code, dial code and so on). A difference in a segment
  that holds a legitimately reused code is not a typo.
- A real product that is simply missing from our catalog is a **coverage gap, not an error**.

### 6.4 Formats & normalization
- A brand can have **several valid formats at once**: modern SKU, legacy short code, vintage
  numeric. The format can also differ **by model line**.
- **Verify the convention on the brand's official site before normalizing separators.** Retailer
  listings drift.
- Watch for lookalike characters (letter `O` vs digit `0`).
- Cells stored as numbers can show in scientific notation and must be decoded back to the original
  ref.
- Excluding a whole category from scope is **not** the same as calling it invalid. Record it as a
  scope decision.

### 6.5 Catalog (Sheet4) cross-check
- Flag exact matches and short/full-form matches as "Already in catalog".
- When the catalog holds the **base** and final refs hold the **fuller** ref, flag **both sides**
  with wording that shows the direction.
- The catalog itself can contain errors. Note them; don't fix them silently.

### 6.6 Enrichment (DialColor / CaseMaterial)
- DialColor precedence:
  1. **Skeletonized**
  2. **Paved** (fully gem-set, any stone colour)
  3. **Multi-colored** (3 or more distinct non-gem colours)
  4. the dominant named colour
- Use **visual review**. Automated pixel/colour classification proved unreliable.
- Leave the cell blank if the image is corrupt, missing, or shows a different watch.
- CaseMaterial must come from the allowed list. Web-verify non-standard values rather than just
  re-casing them. If a value is inferred from sibling refs, note that.
- An authoritative lookup tab or master list overrides any derived value.

### 6.7 Sheet mechanics
- A ref with **more than one `ReferenceNumberId`**: report it as ambiguous. Don't pick one
  silently.
- Column layouts differ between brand tabs. Always read the headers.

---

## 7. Flag vocabulary (`PartialRefFlag`)

A tab's **existing wording wins**. Read a sample of its current flags first. The shared set used so
far:

| Situation | Wording |
|---|---|
| Truncated version of a fuller ref in the set | `Partial - full ref present: <ref>` / `Partial` |
| Unconfirmed, likely typo | `Invalid - unconfirmed, likely typo of <ref>` |
| Not a reference at all | `Junk` |
| Already in the catalog | `Already in catalog (Sheet4: '<ref>')` |
| Catalog has the base, final refs has the full ref | `Base ref <X> already present in catalog (Sheet4) as partial` |

Blank `PartialRefFlag` = a clean full ref. Only these rows move on to Steps 3–6.

---

## 8. Deliverables per brand

1. A `<brand> final refs` tab in the standard layout, with clean full refs plus flagged rows.
2. `FinalImageUrl` filled in, plus a list of picks that need manual review.
3. A master-value mismatch list for DialColor, CaseMaterial and ModelName.
4. An INSERT statement for every clean full ref.
5. An updated `<Brand>_Reference_Validation.md` log recording:
   - formats found
   - counts
   - flags and their reasons
   - decisions the user made

---

## 9. Open items

- **Master-values link:** pending from the user (needed for Step 5).
- **Workflow doc revision:** `Brand_Reference_Validation_Workflow.md` will be corrected and
  improved next. Step 2 follows whatever version is current.
- **TotalWatchCount source:** the workflow doc says to take it from the brand tab, but on past
  brands blanks were filled from the `WatchIds` count. Decide which one is the rule.
- **Image script writes non-usable picks.** Either accept that and review them manually (current
  plan), or change the script later.
- **Missing per-brand logs:** Girard-Perregaux and Roger Dubuis have no
  `<Brand>_Reference_Validation.md` yet.
