---
type: Plan
title: "Build Plan — /log-catalog-change (Catalog Traceback logger)"
description: Plan for the skill that logs catalog renames, deletes and merges into the Catalog Traceback sheet — the conversation flow, the stage lookups, verify-and-warn, and the rule/index changes it needs.
tags: [plans, vishwa, catalog-traceback, skill-build, google-sheets]
timestamp: 2026-11-05
---
# Build Plan — `/log-catalog-change` (Catalog Traceback logger)


## Context

The team edits the watch catalog by hand: renaming a `ReferenceNumber` on a catalog row, renaming a
`ModelName`, deleting a catalog row or model (soft delete, `StatusID = 3`), or merging a duplicate
into a surviving row. None of it is tracked.

The **Catalog Traceback** sheet (`Sheet2`, built earlier in this session) is now the change log, with
a settled 15-column structure. What's missing is the thing that fills it. Today a person has to
remember to open the sheet, find the right columns, and type the brand, reference and model by hand —
so entries are sparse, inconsistent, and often never written at all.

We established that the database **cannot** tell us when a change happened:

| Table | `StatusID` | Records *when* it changed? |
|---|---|---|
| `tbl_CAT_Model_d` | ✓ | `UpdatedDate` — but moves on *any* edit |
| `tbl_CAT_Catalog_d` | ✓ | **✗ none** — `CreatedDate` only |

So detection-after-the-fact is impossible for catalog rows, and the log has to be written **at the
moment the person makes the change**. This skill makes that cheap enough to actually happen: the user
states the change in one line, the skill fills in what it can from the database, shows one preview
row, and appends it on confirmation.

**Outcome:** logging a catalog change takes one sentence instead of eight typed cells, and the
brand / reference / model fields come from the database rather than memory.

---

## 0. Environment — settled

**The manual catalog edits are made on stage**, the same environment my MCP grant reads. So
verification in §4 is meaningful and gets built as designed.

One thing to confirm during build, not a blocker: the grant reports `mask: true`. Before relying on
value comparison, check that `ReferenceNumber` and `ModelName` come back unmasked from a real
lookup — a masked value would make every rename check fail for the wrong reason. If they are masked,
the rename check degrades to "row exists" and the plan says so in the preview rather than claiming a
value match.

---

## Other constraints

1. **Read-only, stage, `EWMaster` only.** 500 rows/query, 15s timeout, 256 KB response, 60 calls/min.
   The skill can never write to the database.
2. **`Rules/00-core.md` A1** — every `SELECT` shown before it runs. You chose **one approval per
   logged change**. A1 and `Playbooks/MCP.md` both currently say the opposite ("one approval never
   covers a later one"), so this needs a named carve-out in the rule itself — a skill cannot quietly
   override an always-loaded rule. See §6.
3. **`EnrichmentId` (column F) stays blank — your decision, revisit later.** It lives in
   `EveryWatch.dbo.tbl_RE_ReferenceEnrichment` (join `re.CatalogId = cat.CatalogId`, as
   `sp_Get_CatalogDetails` does), outside the grant. Even with access, `re.CatalogId` is NULL-heavy
   and one catalog row maps to 0..N enrichments.
   - The skill leaves F empty and **never placeholders it** — no `n/a`, which would poison a later
     `COUNTBLANK` or lookup. It accepts a value only if you type one.
   - The column stays in the sheet, so a later backfill can fill it without a restructure.
   - Consequence to fix now: `Data/Sheets.md` currently lists `EnrichmentId` as filled for two of the
     three change types — a requirement the skill would meet 0% of the time. That table needs
     correcting to say "blank unless typed".
   - **To revisit later:** read access to `EveryWatch.dbo.tbl_RE_ReferenceEnrichment` would make a
     backfill script possible for rows already logged.
4. **Verify-and-warn, never block** (your choice) — with one addition, see §4.
5. **One change at a time**, with a batch path.

---

## 1. Shape: one `SKILL.md`, not a `steps/` folder

`image-match-review` is the right model, not `brand-ref-agent`: a linear, one-sitting workflow with
no resumable pipeline stays in a single `SKILL.md` that sequences the work and delegates the
substance to a `Knowledge/` workflow file.

```
.claude/skills/log-catalog-change/SKILL.md     ← new, ~60 lines, sequences only
Knowledge/workflows/catalog-traceback.md       ← new, the source of truth
PythonScripts/catalog_traceback_log.py         ← new, appends the row
```

Frontmatter follows the house format (`name`, one-sentence `description` ending in a
`Usage — "/log-catalog-change …"` clause, `tags` starting with `skills`, `timestamp`).

---

## 2. Files to create

### `Knowledge/workflows/catalog-traceback.md`
Holds the lookup queries verbatim, the verification rules, the `Action`/`Field` vocabulary, and the
fill patterns. Links to `Data/Sheets.md` for the column layout rather than repeating it.

### `PythonScripts/catalog_traceback_log.py`
Reuses what exists — no new credential or client code:
- `PythonScripts/google_auth.py` → `credentials(SHEETS_RW)`;
- sheet/tab constants and `col_letter()` from `PythonScripts/catalog_traceback_setup.py`.

Non-negotiables in the writer:
- **dry run by default**, `--write` to apply;
- **`values.append`**, letting Google choose the row — never a computed `A{lastRow+1}` from a stale
  read, which breaks under concurrent edits;
- **`valueInputOption="RAW"`** — `USER_ENTERED` turns `5711/1A-010` and `B1/M` into a date and a
  fraction;
- **header guard**: read row 2 and compare all 15 headers before writing; abort on any mismatch
  rather than writing by column letter into a shifted layout;
- **snapshot first** to `Output/Data/CatalogTraceback/Sheet2_before_<ts>.csv`, the convention already
  established — it is the only undo;
- **duplicate check**: match existing rows on (CatalogId|ModelId, Action, Field, OldValue, NewValue)
  and warn before appending a repeat;
- on a timeout of unknown outcome, **re-read the last rows before any retry** — never blind-retry.

### `.claude/skills/log-catalog-change/SKILL.md`
Goal, repo-root note, pointer to the workflow file, hard rules, the steps in §3.

---

## 3. The conversation flow (single change)

**Turn 0 — parse the invocation.** `/log-catalog-change deleted catalog 217141, duplicate of 235922`
yields Action=`Deleted`, entity=catalog, CatalogId=217141, MergedIntoId=235922, Reason, Field=`CatalogId`
with nothing asked. Also parse `renamed A to B`, `A -> B`, quoted values and relative dates.
`ChangedBy` comes from `git config user.name` (A2), never asked. `Date` defaults to today, **stated
in the preview, not silently assumed**.

**Turn 1 — one message, one ask.** Show the parsed slots with `?` on gaps, both lookup queries
verbatim, and any genuinely missing field — all in the same message, so it stays one round trip.
Then a single "run these through MCP?".

**Turn 2 — preview.** The 15 cells as a labelled list (15 columns wrap badly in a terminal), then a
`Checks` block, one line per check, `OK` / `WARN` with the DB value quoted. Ask
`append / edit <col> / cancel`.

**Turn 3 — append**, then re-read the written row and report where it landed.

### Resolving the record
Precedence: explicit `CatalogId` → `ModelId` → `ReferenceNumber` + brand → `ModelName` + brand.
**A bare integer is never auto-classified** — `217141` is a plausible CatalogId *and* ModelId; if the
user didn't say which, ask rather than querying both and doubling the approval surface.

| Rows found | Behaviour |
|---|---|
| 0 | Stop. Wrong id, hard-deleted, or prod-only. Offer re-check, or log unverified with the reason noted in column N |
| 1 | Proceed |
| >1 | Never auto-pick "the Active one" — on a delete log, the deleted row *is* the target. Show the candidates and ask |

A reference number appearing twice within one brand is itself a finding — surface it, don't resolve it.

### The two lookups
```sql
SELECT  cat.CatalogId, cat.ReferenceNumber, cat.ModelId, cat.StatusID,
        cat.ManufacturerId, m.ManufacturerName
FROM    dbo.tbl_CAT_Catalog_d  cat WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Manufacturer_d m WITH (NOLOCK)
       ON m.ManufacturerId = cat.ManufacturerId AND m.StatusID = 1
WHERE   cat.CatalogId = <id>;
```
```sql
SELECT  mo.ModelId, mo.ModelName, mo.StatusID, mo.UpdatedDate,
        mo.ManufacturerId, m.ManufacturerName
FROM    dbo.tbl_CAT_Model_d  mo WITH (NOLOCK)
LEFT JOIN dbo.tbl_CAT_Manufacturer_d m WITH (NOLOCK)
       ON m.ManufacturerId = mo.ManufacturerId AND m.StatusID = 1
WHERE   mo.ModelId = <id>;
```
Named columns only — `SELECT *` on a batch can hit the 256 KB cap. Style per `Rules/10-sql-style.md`.

---

## 4. Verify-and-warn — only if edits happen in stage (§0)

After a rename the database holds the **new** value, so the check is against `NewValue`, not `OldValue`.

| Action | Check | On failure |
|---|---|---|
| `Renamed` | current = `NewValue` | → OK |
| | current = `OldValue` | "the DB still shows the old value — the rename may not have been saved" |
| | current = neither | **"DB shows `<x>`, which is neither your old nor your new value"** — wrong id, or someone else changed it. Must not be collapsed into the case above |
| `Renamed` (model) | also `UpdatedDate` | if it predates the claimed date, that is positive evidence the rename never landed |
| `Deleted` | `StatusID = 3` | `1` → "still Active". `2` → "Draft, never published — 'deleted' may mean something else". 0 rows → hard delete or wrong id |
| `Merged` | loser `StatusID = 3`; survivor exists; survivor **not** deleted; **same `ManufacturerId`** | a missing survivor blocks by default; a cross-brand merge is a loud warning |

**One addition to your chosen behaviour, and I'd push for it:** when you override a warning, the skill
appends `[unverified: StatusID=1 on stage 2026-11-05]` to column N. The sheet has no verification
column, so without this the warning dies in the chat transcript and the row reads as clean forever.
"Warn but allow" is only safe if the sheet carries the doubt.

---

## 5. Batch path

- **One action + one field per batch.** Mixed actions split into sequential runs.
- One query (`WHERE CatalogId IN (…)`), shown in full, **one approval**.
- **Compare returned row count to requested id count** — a silent truncation at 500 would otherwise
  look like "these ids don't exist".
- One compact preview, one line per row with an `OK`/`WARN` flag and a `12 OK, 2 WARN` summary.
  Warned rows repeated beneath with reasons; unresolved ids listed separately, never dropped.
- Confirmation offers **`append all` / `append OK only` / `cancel`** — "append OK only" is what makes
  warn-but-allow survivable at scale.
- **Cap 50 rows per confirmation.** Beyond that nobody reads the preview and the confirmation is
  theatre; longer lists split into chunks of 50, each with its own yes.

---

## 6. Rule and index changes

| File | Change |
|---|---|
| `Rules/00-core.md` **A1** | Named carve-out: a skill may bundle the lookups for **one** logged change into a single approval, provided every query is shown verbatim in that ask. Scoped to this skill. **Needs your explicit go-ahead.** |
| `Playbooks/MCP.md` | Same carve-out — it repeats the per-query rule and would otherwise contradict A1. |
| `Data/Sheets.md` | Correct the fill-pattern table: `EnrichmentId` is **not** auto-filled and is blank unless typed. |
| `Playbooks/ROUTER.md` | New row: "catalog traceback, log a catalog change, renamed/deleted/merged a ref or model" → the skill. |
| `Skills/index.md` | Entry for `/log-catalog-change`. |
| `PythonScripts/index.md` | Add `catalog_traceback_log.py`, plus `google_auth.py` and `catalog_traceback_setup.py` — **both added this session and currently missing from the index.** |
| `Knowledge/enrichment.md` | **Correction found while exploring, now applied (2026-11-05):** it described `tbl_RE_ReferenceEnrichment` as keyed only on the watch side; it in fact has a `catalogId` column giving a direct catalog→enrichment link, used by `sp_Get_CatalogDetails`. *(An earlier draft of this plan also named `references-and-models.md` — that was wrong, it does not mention the table.)* |

---

## 7. Build order

0. **Save this plan into the repo** as `Output/Plans/vishwa/log-catalog-change-skill-plan.md` with its
   line in `Output/Plans/vishwa/index.md` (A2 — a plan lives with the project, not only in the
   user-level plans directory; this is the mistake recorded as Feedback entry 32).
1. `Knowledge/workflows/catalog-traceback.md` — settles the vocabulary everything else refers to.
2. `PythonScripts/catalog_traceback_log.py` — dry run first, tested against the live tab.
3. `.claude/skills/log-catalog-change/SKILL.md`.
4. Rule, router and index edits.

Nothing is committed or pushed at any point unless you ask (A1, added this session).

---

## 8. Verification

- **Dry run:** compose a record for a known catalog id; confirm the printed row and target cell are
  right and nothing is written.
- **Real write:** append one row; read the tab back and confirm `Date` is a real date,
  `OldValue`/`NewValue` are text, and the three dropdown columns pass validation (`Deleted` not
  `Delete`, `ReferenceNumber` not `Reference`).
- **Header guard:** temporarily rename a header and confirm the script aborts rather than writing into
  a shifted layout.
- **Duplicate guard:** log the same change twice and confirm the second is flagged.
- **Text coercion:** log a rename with `B1/M` → `B/1M` and confirm neither cell becomes a date.
- **End to end:** a catalog delete, a reference rename and a model rename, each producing the fill
  pattern in `Data/Sheets.md`.
- **Warning path:** log a delete for a `StatusID = 1` row; confirm the warning fires, the override
  works, and column N carries the `[unverified: …]` note.
- **Clean up** every test row and say which were written and removed.
