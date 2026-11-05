---
type: Knowledge
title: Catalog traceback — logging a catalog change
description: How a manual catalog change (rename, delete, merge) is recorded in the Catalog Traceback sheet — the vocabulary, the two stage lookups, the verification rules per action, and what is filled for each kind of change.
tags: [knowledge, catalog, traceback, change-log, google-sheets, workflow]
db: EWMaster
keywords: [Catalog Traceback, tbl_CAT_Catalog_d, tbl_CAT_Model_d, tbl_CAT_Manufacturer_d, StatusID, Renamed, Deleted, Merged, change log]
timestamp: 2026-11-05
---

# Catalog traceback — logging a catalog change

Used when someone has renamed, deleted or merged something in the catalog by hand and it needs to go
into the **Catalog Traceback** log. The `/log-catalog-change` skill sequences this; the facts live here.

The column layout is documented once, in [../../Data/Sheets.md](../../Data/Sheets.md) under
"Catalog Traceback — `Sheet2` structure". Don't repeat it here — read it there.

## 1. Why the log has to be written by hand

The database cannot say *when* a change happened:

| Table | Soft delete | Records when it changed? |
|---|---|---|
| `tbl_CAT_Model_d` | `StatusID = 3` | `UpdatedDate` — but it moves on **any** edit, so it means "last touched" |
| `tbl_CAT_Catalog_d` | `StatusID = 3` | **nothing** — `CreatedDate` only, there is no `UpdatedDate` |

So a catalog row sitting at `StatusID = 3` carries no trace of when it got there or who did it.
Detection after the fact is impossible; the row is logged at the moment the change is made.

`StatusID` on both tables: `1` = Active, `2` = Draft, `3` = Deleted.

## 2. Vocabulary — must match the sheet's dropdowns exactly

| Column | Allowed values |
|---|---|
| `Action` | `Renamed`, `Deleted`, `Merged` |
| `Field` | `ReferenceNumber`, `ModelName`, `CatalogId` |
| `Accept/Reject` | `Pending`, `Accepted`, `Rejected` — always written as `Pending` |

`Deleted` not `Delete`; `ReferenceNumber` not `Reference`. A near-miss is rejected by the sheet's
data validation. `Field = CatalogId` means a whole catalog row was deleted, not that an id changed.

## 3. What gets filled, per change

| Change | Columns filled |
|---|---|
| Catalog row deleted | `CatalogId`; `Field` = `CatalogId`; no `OldValue`/`NewValue` |
| Reference renamed | `CatalogId`, `ReferenceNumber`; `Field` = `ReferenceNumber`; `OldValue` + `NewValue` |
| Model renamed or deleted | `ModelId`, `ModelName`, `CatalogId` (as context); `Field` = `ModelName`; no `ReferenceNumber` |
| Duplicate merged | as for the entity, plus `MergedIntoId` = the id that **survived** |

`ReferenceNumber` and `ModelName` hold the value **as it was before the change**, so the row always
identifies the record as it existed. On a rename that repeats `OldValue`; on a delete those columns
are the only record of what went.

**`EnrichmentId` is always left blank.** It lives in `EveryWatch.dbo.tbl_RE_ReferenceEnrichment`
(join `re.CatalogId = cat.CatalogId`, the way `sp_Get_CatalogDetails` does it), which is outside the
MCP grant — that grant covers `EWMaster` on stage only. Never write a placeholder such as `n/a`; an
empty cell is what a later backfill expects. Even with access the link is weak: `re.CatalogId` is
frequently `NULL` and one catalog row can map to several enrichments.

## 4. The two lookups

Only the one relevant to the change is run. Named columns only — `SELECT *` on a batch can hit the
256 KB response cap. Style per [../../Rules/10-sql-style.md](../../Rules/10-sql-style.md).

### The MCP accepts only ONE condition per query

The parser rejects `AND` **anywhere** — in a `JOIN ... ON` *and* in `WHERE`. Both confirmed on live
runs: *"the function AND is not allowed here"*. So every query here has at most one `WHERE`
condition and no compound join.

Consequences, all of them load-bearing:

- The manufacturer's `StatusID` is returned as a **column**, not filtered in the `ON` clause. Do
  **not** move it to `WHERE` instead — that turns the `LEFT JOIN` into an inner join and can drop
  the catalog row entirely.
- **A filter you cannot express becomes a filter you apply yourself**, by returning the column and
  picking from the rows. See §5 for the model-by-name case.
- Doing that makes the **500-row cap a real risk**: a broad single-condition query can silently
  truncate and look exactly like "no such record". Always compare the row count you got against
  what you expected, and say so if the result is at the cap.
- `;` at the end is also rejected. `WITH (NOLOCK)` is dropped — these are single-row reads, so the
  hint buys nothing.

```sql
-- catalog row + brand
SELECT cat.CatalogId, cat.ReferenceNumber, cat.ModelId, cat.StatusID,
       cat.ManufacturerId, m.ManufacturerName, m.StatusID AS ManufacturerStatusID
FROM dbo.tbl_CAT_Catalog_d cat
LEFT JOIN dbo.tbl_CAT_Manufacturer_d m ON m.ManufacturerId = cat.ManufacturerId
WHERE cat.CatalogId = <id>
```

```sql
-- model row + brand
SELECT mo.ModelId, mo.ModelName, mo.StatusID, mo.UpdatedDate,
       mo.ManufacturerId, m.ManufacturerName, m.StatusID AS ManufacturerStatusID
FROM dbo.tbl_CAT_Model_d mo
LEFT JOIN dbo.tbl_CAT_Manufacturer_d m ON m.ManufacturerId = mo.ManufacturerId
WHERE mo.ModelId = <id>
```

The parser also rejected the trailing `;` and `WITH (NOLOCK)` is dropped here for the same reason —
these are single-row reads, so the hint buys nothing.

The brand join is the confirmed FK path: `tbl_CAT_Catalog_d.ManufacturerId` to
`tbl_CAT_Manufacturer_d.ManufacturerId`, filtered to `StatusID = 1`, giving `ManufacturerName`.

## 5. Resolving which record

Precedence: an explicit `CatalogId`, then `ModelId`, then `ReferenceNumber` + brand, then
`ModelName` + brand.

- **A bare integer is never classified on its own.** `217141` is a plausible `CatalogId` *and* a
  plausible `ModelId`. If the user didn't say which, ask — don't run both lookups to find out.
- A reference number is **not unique across brands**, so a ref needs a brand to resolve.
- **Finding a model by name + brand takes two conditions, which the MCP will not accept.** The
  working recipe is: filter on the **name only**, return `ManufacturerName`, and pick the brand's
  row out of the results yourself.

  ```sql
  SELECT mo.ModelId, mo.ModelName, mo.StatusID, mo.UpdatedDate,
         mo.ManufacturerId, m.ManufacturerName
  FROM dbo.tbl_CAT_Model_d mo
  LEFT JOIN dbo.tbl_CAT_Manufacturer_d m ON m.ManufacturerId = mo.ManufacturerId
  WHERE mo.ModelName LIKE '%<fragment>%'
  ```

  Choose the fragment to match **both spellings at once** when logging a rename, because the
  database holds the *new* name — e.g. `%hronograph%` catches `Chronograph` and `Chhronograph`
  alike. A live run of exactly this returned 115 models across every brand, three of them Rolex;
  that is well inside the 500-row cap, but a shorter fragment would not be. If the result comes
  back at the cap, narrow the fragment and say that the first attempt truncated.
- **0 rows** — stop and say so. Wrong id, or hard-deleted. Never invent a record.
- **more than 1 row** — show the candidates and ask. Never auto-pick "the Active one": when logging
  a delete, the deleted row *is* the target, so that heuristic is backwards half the time.
- The same reference twice within one brand is itself a finding — surface it, don't silently resolve.

## 6. Verification — check, warn, never block

**The check is optional and the user chooses it.** Ask whether to check against the database
before running anything; if they say no, write the row straight to the sheet with `Brand`,
`ReferenceNumber` and the model columns left blank. A row logged without a check is still a valid
log entry — the user was there, the database was not.

The manual edits are made on **stage**, which is what the MCP grant reads, so a mismatch is real
information rather than an environment difference.

**After a rename the database holds the NEW value**, so the comparison is against `NewValue`.

| Action | Expected | Warning when it differs |
|---|---|---|
| `Renamed` | current value = `NewValue` | this is the pass case |
| | current value = `OldValue` | "the DB still shows the old value — the rename may not have been saved" |
| | current value = neither | "DB shows X, which is neither the old nor the new value" — wrong id, or someone else changed it since. **Keep this case separate from the one above; it means something different.** |
| `Renamed` (model) | `UpdatedDate` not before the change date | if `UpdatedDate` predates the claimed change, that is positive evidence the rename never landed |
| `Deleted` | `StatusID = 3` | `1` means still Active. `2` means Draft, never published — "deleted" may mean something else here |
| `Merged` | loser `StatusID = 3`, survivor exists, survivor **not** deleted, **same `ManufacturerId`** | a missing survivor blocks by default; a cross-brand merge is a loud warning |

**Compare values case-insensitively.** A reference typed `14800ba` against a stored `14800BA` is
the same rename, not a mismatch — treat it as a pass. Write the **database's** spelling into the
sheet so the log matches the catalog, and say that you did; don't silently change what the user
typed. (This cost a round trip on the first live run.)

A warning never blocks. But when the user overrides one, **append the reason to column `N`**:

```
[unverified: StatusID=1 on stage 2026-11-05]
```

The sheet has no verification column, so without this the warning dies in the chat transcript and
the row reads as clean to everyone who sees it later.

## 7. Writing the row

`PythonScripts/catalog_traceback_log.py` does the write. It is a dry run unless `--write` is passed.

- Appends via the Sheets `values.append` API so Google picks the row — never a row number computed
  from an earlier read, which breaks when someone else is editing.
- `valueInputOption="RAW"`. With `USER_ENTERED`, `5711/1A-010` becomes a date and `B1/M` a fraction.
- Checks all 15 headers on row 2 before writing and aborts on any mismatch, rather than writing by
  column letter into a layout someone has shifted.
- **Leaves every written row fully formatted.** `values.append` drops number formats, so the script
  puts back TEXT/DATE, alignment (ids and statuses centred, names and free text left) and wrapping
  on the rows it just wrote. A sheet the team reads is not finished when only the values are right.
  `catalog_traceback_repair_format.py` applies the same standard — plus row banding and the group
  rules — to the whole tab, for bulk writes or after a rebuild.
- Snapshots the tab to `Output/Data/CatalogTraceback/Sheet2_before_<timestamp>.csv` first — that
  snapshot is the only undo.
- Warns when a matching row already exists (same id, `Action`, `Field`, `OldValue`, `NewValue`).
