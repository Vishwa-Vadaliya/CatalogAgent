---
type: Document
title: Standard `<brand> final refs` tab layout
description: Standard column layout for new "<brand> final refs" tabs, with notes on finding columns by header name on older tabs.
tags: [skills, brand-ref-agent, layout, final-refs]
timestamp: 2026-10-31
---
# Standard `<brand> final refs` tab layout

Use this layout for **new** final-refs tabs. (The brand source tab also gets a note column, `FinalRefChange`, to the right of `FinalRef`, with the same format: see standing rule 19.) On an existing tab, keep its own order and always find
columns **by header name**: older tabs differ, e.g. Jacob & Co. has `PartialRefFlag` in F,
`Sourcelink` before `FinalImageurl`, and the INSERT in AH.

| Col | Header | Filled by | Notes |
|---|---|---|---|
| A | `Referencenumbers` | Step 2 | TEXT format |
| B | `PartialRefFlag` | Step 2 (workflow Step 5) | Blank = clean full ref. TEXT format. |
| C | `ReferenceNumberId` | Step 2 (workflow Step 6) | The *identity* RNId (1st `ReferenceNumberId` header) |
| D | `WatchIds` | Step 2 | Comma-separated, TEXT |
| E | `TotalWatchCount` | Step 2 | |
| F | `Length` | Step 2 | `=LEN(A<row>)` or a value |
| G | *(blank spacer)* | — | |
| H | `SourceRowId` | Step 3 | |
| I | `ReferenceNumberId` | Step 3 | 2nd `ReferenceNumberId` header (watch-data block) |
| J | `FirstWatchId` | Step 3 | |
| K | `FirstWatchPublishWatchId` | Step 3 | |
| L | `DialColor` | Step 3 | |
| M | `CaseMaterial` | Step 3 | |
| N | `ModelName` | Step 3 | |
| O | `Images` | Step 3 | Comma-joined, as pasted |
| P | `FinalImageUrl` | Step 4 | Written by the image picker |
| Q | `SourceLink` | Step 3 | Formula, see below |
| R | `FinalImage` | Step 3 | Formula, see below |
| S | `RefChangeNote` | Step 2 (workflow Steps 6-7) | Present when the final ref differs from its original: `Original: "<original>" \| Changed: <what> \| Why: <reason>`. Blank = identical to the original. Several originals merged into one row are all listed (`Originals (3): ...`). Append, never overwrite. TEXT format. See standing rule 19. |
| T–W | *(blank)* | — | |
| X–AG | *(no header)* | Step 3 | Image candidates, one URL per column, up to 10. The picker reads the first 5 (X–AB). |
| AH | *(blank)* | — | |
| AI | `InsertStatement` | Step 6 | INSERT formula |

## Formulas (`<row>` = the row's own number)

**SourceLink**

```
="https://everywatch.com/watch/"&K<row>
```

`K` = the `FirstWatchPublishWatchId` column. Leave the cell blank when that cell is blank or NULL.

**FinalImage**

```
=IMAGE(P<row>)
```

`P` = the `FinalImageUrl` column.

**InsertStatement**: built by `scripts/build_insert_formulas.py`. Every cell value is wrapped in
`SUBSTITUTE(x,"'","''")` so single quotes can't break the SQL:

```
="INSERT INTO #CreateCatalogQueue (ReferenceNumber, ManufacturerName, ModelName, CaseMaterials, DialColors, PrimaryImageURL, SourceLink, StatusId, UserID) VALUES ('"&SUBSTITUTE(A<row>,"'","''")&"','<Manufacturer>','"&SUBSTITUTE(N<row>,"'","''")&"','"&SUBSTITUTE(M<row>,"'","''")&"','"&SUBSTITUTE(L<row>,"'","''")&"','"&SUBSTITUTE(P<row>,"'","''")&"','"&SUBSTITUTE(Q<row>,"'","''")&"',1,6);"
```

Rendered result:

```sql
INSERT INTO #CreateCatalogQueue (ReferenceNumber, ManufacturerName, ModelName, CaseMaterials, DialColors, PrimaryImageURL, SourceLink, StatusId, UserID) VALUES ('<Ref>','<Manufacturer>','<ModelName>','<CaseMaterial>','<DialColor>','<FinalImageUrl>','<SourceLink>',1,6);
```

`StatusId` is always `1` and `UserID` is always `6`.

---

# Variations tab (`<brand> final refs Variation`): Steps 3 to 6

Since the watch-data query returns every possible variation of each reference, the watch data no longer
goes into the final-refs tab (columns H to R above stay empty in this flow; the final-refs tab remains the
list of validated references). It goes into its own tab, one row per variation. Find columns by header name.

| Block | Header | Filled by | Notes |
|---|---|---|---|
| pasted | `ReferenceNumber`, `ReferenceNumberId`, `FirstWatchId`, `FirstWatchPublishWatchId`, `DialColor`, `CaseMaterial`, `ModelName`, `Images`, watch count (e.g. `WatchCount`) | the user (query output) | `NULL` text is cleared to blank in Step 3 |
| added | `VariationId` | Step 3 | `V00001` ..., unique per row, the key for every later step; TEXT |
| added | `VariationStatus` | Step 4c | blank / `Keep` / `Duplicate of <VariationId>` / `Not confirmed` / `Review` |
| added | `VariationNote` | Step 4c | reason / evidence for the status |
| added | `FilledNote` | Step 4b | source of a filled dial / case value (image, web page, user) |
| added | `FinalImageUrl` | Step 4 | written by the image picker |
| added | `SourceLink` | Step 3 | `=IF(K="","","https://everywatch.com/watch/"&K)` (K = FirstWatchPublishWatchId) |
| added | `FinalImage` | Step 3 | `=IF(P="","",IMAGE(P))` (P = FinalImageUrl) |
| spacer | *(blank)* | | |
| candidates | *(no header)* | Step 3 | up to 10 image URLs, one per column; the picker reads the first 5 |
| last | `InsertStatement` | Step 6 | one formula per row whose status is `Keep` |
