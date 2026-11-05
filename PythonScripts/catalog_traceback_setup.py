"""Build the Catalog Traceback change-log structure on a tab (default: Sheet2).

What the log records: every manual change made to the catalog —
  * a ReferenceNumber renamed on a catalog row
  * a ModelName renamed on a model row
  * a catalog row / model / enrichment deleted
  * a duplicate merged into a surviving row

Layout: a two-row header. Row 1 groups the columns into blocks, row 2 holds the column
names. Only the columns relevant to a change get filled; the rest stay empty.

    catalog deleted      -> CatalogId, EnrichmentId        Field = CatalogId
    reference renamed    -> CatalogId, ReferenceNumber,
                            EnrichmentId                   Field = ReferenceNumber
    model renamed/deleted-> ModelId, ModelName, CatalogId  Field = ModelName

Dry run by default. Nothing is written without --write.

    python catalog_traceback_setup.py                 # show the plan
    python catalog_traceback_setup.py --write         # apply it

Credentials come from GOOGLE_APPLICATION_CREDENTIALS (see PythonScripts/google_auth.py).
"""
import argparse
import sys
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)

from googleapiclient.discovery import build  # noqa: E402

from google_auth import credentials, SHEETS_RW  # noqa: E402

SPREADSHEET_ID = "1l23GqhRziHUNjeijLtxVTAZurtdhjPTKNkbV5xTvqEE"

# group label -> (dark colour for the group row, light tint for the header row)
GROUP_COLOURS = {
    "LOG ENTRY":  ((0.35, 0.37, 0.40), (0.90, 0.91, 0.92)),
    "CATALOG":    ((0.11, 0.31, 0.49), (0.85, 0.90, 0.95)),
    "MODEL":      ((0.11, 0.40, 0.33), (0.85, 0.93, 0.91)),
    "CHANGE":     ((0.35, 0.22, 0.45), (0.92, 0.88, 0.95)),
    "REVIEW":     ((0.48, 0.31, 0.08), (0.98, 0.92, 0.80)),
}

# (group, header, width_px, note shown on the header cell)
COLUMNS = [
    ("LOG ENTRY", "Date", 100,
     "Date the change was made in the catalog (yyyy-mm-dd)."),
    ("LOG ENTRY", "ChangedBy", 110,
     "Who made the change."),
    ("LOG ENTRY", "Brand", 130,
     "Manufacturer name, so the log can be filtered by brand."),

    ("CATALOG", "CatalogId", 100,
     "tbl_CAT_Catalog_d.CatalogId. Fill for any change to a catalog row, and as context "
     "for a model change."),
    ("CATALOG", "ReferenceNumber", 170,
     "The reference number on that catalog row, as it was BEFORE the change. "
     "Leave blank for a model-only change. Plain text."),
    ("CATALOG", "EnrichmentId", 110,
     "tbl_RE_ReferenceEnrichment.ReferenceEnrichmentId for that catalog row."),

    ("MODEL", "ModelId", 90,
     "tbl_CAT_Model_d.ModelId. Fill for a model change."),
    ("MODEL", "ModelName", 170,
     "The model name, as it was BEFORE the change. Leave blank for a catalog-only change. "
     "Plain text."),

    ("CHANGE", "Action", 100,
     "Renamed, Deleted or Merged."),
    ("CHANGE", "Field", 140,
     "What the change was to: ReferenceNumber, ModelName, or CatalogId when a whole "
     "catalog row was deleted."),
    ("CHANGE", "OldValue", 190,
     "Value BEFORE the change. Fill for Renamed and Merged; blank for a plain Deleted, "
     "where the identifying columns above already say what went. Plain text, so refs like "
     "5711/1A-010 and B1/M are kept exactly as typed."),
    ("CHANGE", "NewValue", 190,
     "Value AFTER the change. Fill for Renamed. Plain text."),
    ("CHANGE", "MergedIntoId", 110,
     "For Merged / duplicate deletes: the id of the row that SURVIVED, i.e. where this "
     "record went. Answers 'where did it go'."),
    ("CHANGE", "Reason", 300,
     "Why the change was made, in words. e.g. 'caseback number, not a reference'."),

    ("REVIEW", "Accept/Reject", 130,
     "The reviewer's decision on this change: Pending until someone reviews it, then "
     "Accepted or Rejected."),
]

DROPDOWNS = {
    "Action": ["Renamed", "Deleted", "Merged"],
    "Field": ["ReferenceNumber", "ModelName", "CatalogId"],
    "Accept/Reject": ["Pending", "Accepted", "Rejected"],
}

# Columns that must stay literal text. A reference like "B1/M" or "5711/1A-010"
# is otherwise silently reinterpreted by Sheets as a date or a fraction.
TEXT_COLUMNS = ["ReferenceNumber", "ModelName", "OldValue", "NewValue"]
DATE_COLUMNS = ["Date"]

HEADER_ROW = 1          # 0-based: row 2 holds the column names
DATA_START = 2          # 0-based: data begins on row 3
WHITE = {"red": 1.0, "green": 1.0, "blue": 1.0}
DARK_TEXT = {"red": 0.13, "green": 0.13, "blue": 0.13}


def rgb(t):
    return {"red": t[0], "green": t[1], "blue": t[2]}


def col_letter(idx):
    s, n = "", idx + 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def group_spans():
    """[(group, start_idx, end_idx_exclusive)] in column order."""
    spans, start = [], 0
    for i in range(1, len(COLUMNS) + 1):
        if i == len(COLUMNS) or COLUMNS[i][0] != COLUMNS[start][0]:
            spans.append((COLUMNS[start][0], start, i))
            start = i
    return spans


def svc():
    return build("sheets", "v4", credentials=credentials(SHEETS_RW), cache_discovery=False)


def tab_meta(service, tab):
    meta = service.spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID,
        fields="sheets(properties(sheetId,title,gridProperties))").execute()
    for s in meta["sheets"]:
        if s["properties"]["title"] == tab:
            return s["properties"]
    raise SystemExit(f"tab not found: {tab!r}. Tabs: "
                     f"{[s['properties']['title'] for s in meta['sheets']]}")


def existing_rows(service, tab):
    """Rows the tab already holds, beyond the two header rows."""
    q = "'" + tab.replace("'", "''") + "'"
    vals = service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=f"{q}!A1:ZZ").execute().get("values", [])
    return max(len(vals) - 2, 0), vals


def backup_tab(service, tab, path):
    """Save whatever the tab holds right now to a CSV, before anything is cleared."""
    import csv
    q = "'" + tab.replace("'", "''") + "'"
    vals = service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=f"{q}!A1:ZZ").execute().get("values", [])
    with open(path, "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh).writerows(vals)
    return len(vals), path


def clear_tab(service, sheet_id, tab):
    """Wipe values, formats, notes, validation and merges — no trace of the old layout."""
    q = "'" + tab.replace("'", "''") + "'"
    service.spreadsheets().values().clear(
        spreadsheetId=SPREADSHEET_ID, range=f"{q}!A1:ZZ", body={}).execute()
    service.spreadsheets().batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": [
        {"updateCells": {"range": {"sheetId": sheet_id},
                         "fields": "userEnteredFormat,note,dataValidation"}},
        {"unmergeCells": {"range": {"sheetId": sheet_id}}},
    ]}).execute()


def build_requests(sheet_id, ncols):
    reqs = []
    names = [c[1] for c in COLUMNS]

    # --- row 1: group bands, merged across each block, white on the group colour
    for group, start, end in group_spans():
        dark, _ = GROUP_COLOURS[group]
        if end - start > 1:
            reqs.append({"mergeCells": {
                "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1,
                          "startColumnIndex": start, "endColumnIndex": end},
                "mergeType": "MERGE_ALL"}})
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1,
                      "startColumnIndex": start, "endColumnIndex": end},
            "cell": {"userEnteredFormat": {
                "backgroundColor": rgb(dark),
                "horizontalAlignment": "CENTER", "verticalAlignment": "MIDDLE",
                "textFormat": {"bold": True, "foregroundColor": WHITE, "fontSize": 10}}},
            "fields": ("userEnteredFormat(backgroundColor,horizontalAlignment,"
                       "verticalAlignment,textFormat)")}})

    # --- row 2: column names, dark text on the light tint of the same group
    for group, start, end in group_spans():
        _, light = GROUP_COLOURS[group]
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": HEADER_ROW, "endRowIndex": HEADER_ROW + 1,
                      "startColumnIndex": start, "endColumnIndex": end},
            "cell": {"userEnteredFormat": {
                "backgroundColor": rgb(light),
                "horizontalAlignment": "CENTER", "verticalAlignment": "MIDDLE",
                "wrapStrategy": "WRAP",
                "textFormat": {"bold": True, "foregroundColor": DARK_TEXT, "fontSize": 10}}},
            "fields": ("userEnteredFormat(backgroundColor,horizontalAlignment,"
                       "verticalAlignment,wrapStrategy,textFormat)")}})

    # freeze both header rows
    reqs.append({"updateSheetProperties": {
        "properties": {"sheetId": sheet_id, "gridProperties": {"frozenRowCount": 2}},
        "fields": "gridProperties.frozenRowCount"}})

    # column widths
    for i, (_, _, width, _) in enumerate(COLUMNS):
        reqs.append({"updateDimensionProperties": {
            "range": {"sheetId": sheet_id, "dimension": "COLUMNS",
                      "startIndex": i, "endIndex": i + 1},
            "properties": {"pixelSize": width}, "fields": "pixelSize"}})

    # a note on each column-name cell documenting the column
    for i, (_, _, _, note) in enumerate(COLUMNS):
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": HEADER_ROW, "endRowIndex": HEADER_ROW + 1,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"note": note}, "fields": "note"}})

    # dropdowns on the data rows
    for name, values in DROPDOWNS.items():
        i = names.index(name)
        reqs.append({"setDataValidation": {
            "range": {"sheetId": sheet_id, "startRowIndex": DATA_START,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "rule": {"condition": {"type": "ONE_OF_LIST",
                                   "values": [{"userEnteredValue": v} for v in values]},
                     "strict": True, "showCustomUi": True}}})

    # plain text on every column that can hold a reference or a name
    for name in TEXT_COLUMNS:
        i = names.index(name)
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": DATA_START,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {"numberFormat": {"type": "TEXT"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    for name in DATE_COLUMNS:
        i = names.index(name)
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": DATA_START,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {
                "numberFormat": {"type": "DATE", "pattern": "yyyy-mm-dd"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    # vertical rule between the groups, so the blocks read apart
    for _, start, end in group_spans()[1:]:
        reqs.append({"updateBorders": {
            "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1000,
                      "startColumnIndex": start, "endColumnIndex": start + 1},
            "left": {"style": "SOLID_MEDIUM", "color": {"red": 0.25, "green": 0.25, "blue": 0.25}}}})

    # filter over the column-name row
    reqs.append({"setBasicFilter": {"filter": {
        "range": {"sheetId": sheet_id, "startRowIndex": HEADER_ROW,
                  "startColumnIndex": 0, "endColumnIndex": ncols}}}})
    return reqs


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tab", default="Sheet2", help="tab to build the structure on (default Sheet2)")
    ap.add_argument("--write", action="store_true", help="apply; without this it is a dry run")
    ap.add_argument("--force", action="store_true",
                    help="allow rebuilding a tab that already holds data rows")
    ap.add_argument("--backup-dir", default=".",
                    help="where the pre-change CSV backup is written (default: current dir)")
    args = ap.parse_args()

    service = svc()
    props = tab_meta(service, args.tab)
    sheet_id = props["sheetId"]
    ncols = len(COLUMNS)

    nrows, vals = existing_rows(service, args.tab)

    print(f"spreadsheet : Catalog Traceback ({SPREADSHEET_ID})")
    print(f"tab         : {args.tab!r} (gid {sheet_id})")
    print(f"existing    : {nrows} data row(s) below the header")
    for i, row in enumerate(vals[:2], 1):
        print(f"              row {i}: {row}")
    print()

    spans = group_spans()
    print(f"planned layout ({ncols} columns, 2 header rows):\n")
    print("  row 1  " + " | ".join(
        f"{g} ({col_letter(s)}:{col_letter(e - 1)})" for g, s, e in spans))
    print()
    for group, start, end in spans:
        print(f"  [{group}]")
        for i in range(start, end):
            name = COLUMNS[i][1]
            extra = []
            if name in DROPDOWNS:
                extra.append("dropdown: " + "/".join(DROPDOWNS[name]))
            if name in TEXT_COLUMNS:
                extra.append("plain text")
            if name in DATE_COLUMNS:
                extra.append("date yyyy-mm-dd")
            tail = ("   [" + "; ".join(extra) + "]") if extra else ""
            print(f"     {col_letter(i):>2}  {name:<16}{tail}")
    print()

    if nrows and not args.force:
        print(f"REFUSING: {args.tab!r} already holds {nrows} data row(s).")
        print("Rebuilding would overwrite them. Re-run with --force only if you are sure.")
        return 1

    if not args.write:
        print("DRY RUN — nothing written. Re-run with --write to apply.")
        return 0

    from datetime import datetime
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    n, path = backup_tab(service, args.tab, f"{args.backup_dir}/{args.tab}_before_{stamp}.csv")
    print(f"backed up {n} existing row(s) -> {path}")

    clear_tab(service, sheet_id, args.tab)
    print("cleared the tab (values, formats, notes, validation, merges)")

    group_row, header_row = [], []
    for group, start, end in spans:
        group_row.append(group)
        group_row.extend([""] * (end - start - 1))
    header_row = [c[1] for c in COLUMNS]

    service.spreadsheets().values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"'{args.tab}'!A1:{col_letter(ncols - 1)}2",
        valueInputOption="RAW",
        body={"values": [group_row, header_row]}).execute()
    print(f"wrote 2 header rows: {ncols} columns")

    service.spreadsheets().batchUpdate(
        spreadsheetId=SPREADSHEET_ID,
        body={"requests": build_requests(sheet_id, ncols)}).execute()
    print("applied: group bands, merges, header style, frozen rows, widths, notes, "
          "dropdowns, text/date formats, group borders, filter")
    print(f"\nDONE -> https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit#gid={sheet_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
