"""Build the Catalog Traceback change-log structure on a tab (default: Sheet2).

What the log records: every manual change made to the catalog —
  * a ReferenceNumber renamed on a catalog row
  * a ModelName renamed on a model row
  * a catalog row / model / enrichment deleted
  * a duplicate merged into a surviving row

Dry run by default. Nothing is written without --write.

    python catalog_traceback_setup.py                 # show the plan
    python catalog_traceback_setup.py --write         # apply it
    python catalog_traceback_setup.py --tab ChangeLog --write

Credentials come from GOOGLE_APPLICATION_CREDENTIALS (see PythonScripts/google_auth.py).
"""
import argparse
import sys
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)

from googleapiclient.discovery import build  # noqa: E402

from google_auth import credentials, SHEETS_RW  # noqa: E402

SPREADSHEET_ID = "1l23GqhRziHUNjeijLtxVTAZurtdhjPTKNkbV5xTvqEE"

# (header, width_px, note shown on the header cell)
COLUMNS = [
    ("Date", 100,
     "Date the change was made in the catalog (yyyy-mm-dd)."),
    ("ChangedBy", 110,
     "Who made the change."),
    ("Brand", 130,
     "Manufacturer name, so the log can be filtered by brand."),
    ("EntityType", 110,
     "What this row is about: Catalog, Model or Enrichment. "
     "Determines which of the three Id columns identifies the row."),
    ("CatalogId", 100,
     "tbl_CAT_Catalog_d.CatalogId. Fill for EntityType = Catalog."),
    ("ModelId", 90,
     "tbl_CAT_Model_d.ModelId. Fill for EntityType = Model, or as context for a catalog row."),
    ("EnrichmentId", 110,
     "tbl_RE_ReferenceEnrichment.ReferenceEnrichmentId. Fill for EntityType = Enrichment."),
    ("Action", 100,
     "Renamed, Deleted or Merged."),
    ("Field", 130,
     "Which field changed: ReferenceNumber or ModelName. Leave blank for a plain Deleted."),
    ("OldValue", 200,
     "The value BEFORE the change. Always fill for Renamed and Merged. "
     "Plain text, so refs like 5711/1A-010 and B1/M are kept exactly as typed."),
    ("NewValue", 200,
     "The value AFTER the change. Fill for Renamed. Plain text."),
    ("MergedIntoId", 110,
     "For Merged / duplicate deletes: the id of the row that SURVIVED, "
     "i.e. where this record went. Answers 'where did it go'."),
    ("Reason", 300,
     "Why the change was made, in words. e.g. 'caseback number, not a reference'."),
    ("Ticket", 110,
     "Jira key or source sheet that triggered the change."),
    ("Status", 110,
     "Review decision: Pending, Accepted or Rejected."),
]

DROPDOWNS = {
    "EntityType": ["Catalog", "Model", "Enrichment"],
    "Action": ["Renamed", "Deleted", "Merged"],
    "Field": ["ReferenceNumber", "ModelName"],
    "Status": ["Pending", "Accepted", "Rejected"],
}

# Columns that must stay literal text. A reference like "B1/M" or "5711/1A-010"
# is otherwise silently reinterpreted by Sheets as a date or a fraction.
TEXT_COLUMNS = ["OldValue", "NewValue"]
DATE_COLUMNS = ["Date"]

HEADER_BG = {"red": 0.17, "green": 0.24, "blue": 0.31}
HEADER_FG = {"red": 1.0, "green": 1.0, "blue": 1.0}


def col_letter(idx):
    s, n = "", idx + 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


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
    """How many data rows the tab already holds (so we never clobber real data)."""
    q = "'" + tab.replace("'", "''") + "'"
    vals = service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=f"{q}!A1:Z").execute().get("values", [])
    return max(len(vals) - 1, 0), vals[0] if vals else []


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
    """Wipe values, formats, notes and validation so no trace of the old layout is left."""
    q = "'" + tab.replace("'", "''") + "'"
    service.spreadsheets().values().clear(
        spreadsheetId=SPREADSHEET_ID, range=f"{q}!A1:ZZ", body={}).execute()
    service.spreadsheets().batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": [
        {"updateCells": {
            "range": {"sheetId": sheet_id},
            "fields": "userEnteredFormat,note,dataValidation"}},
        {"unmergeCells": {"range": {"sheetId": sheet_id}}},
    ]}).execute()


def build_requests(sheet_id, ncols):
    """Formatting requests: header style, freeze, widths, notes, dropdowns, number formats."""
    reqs = []
    names = [c[0] for c in COLUMNS]

    # header row: bold, white on dark, centred, wrapped
    reqs.append({"repeatCell": {
        "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1,
                  "startColumnIndex": 0, "endColumnIndex": ncols},
        "cell": {"userEnteredFormat": {
            "backgroundColor": HEADER_BG,
            "horizontalAlignment": "CENTER",
            "verticalAlignment": "MIDDLE",
            "wrapStrategy": "WRAP",
            "textFormat": {"bold": True, "foregroundColor": HEADER_FG, "fontSize": 10}}},
        "fields": ("userEnteredFormat(backgroundColor,horizontalAlignment,"
                   "verticalAlignment,wrapStrategy,textFormat)")}})

    # freeze the header
    reqs.append({"updateSheetProperties": {
        "properties": {"sheetId": sheet_id, "gridProperties": {"frozenRowCount": 1}},
        "fields": "gridProperties.frozenRowCount"}})

    # column widths
    for i, (_, width, _) in enumerate(COLUMNS):
        reqs.append({"updateDimensionProperties": {
            "range": {"sheetId": sheet_id, "dimension": "COLUMNS",
                      "startIndex": i, "endIndex": i + 1},
            "properties": {"pixelSize": width}, "fields": "pixelSize"}})

    # a note on each header cell documenting the column
    for i, (_, _, note) in enumerate(COLUMNS):
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"note": note}, "fields": "note"}})

    # dropdowns on the data rows
    for name, values in DROPDOWNS.items():
        i = names.index(name)
        reqs.append({"setDataValidation": {
            "range": {"sheetId": sheet_id, "startRowIndex": 1,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "rule": {
                "condition": {"type": "ONE_OF_LIST",
                              "values": [{"userEnteredValue": v} for v in values]},
                "strict": True, "showCustomUi": True}}})

    # plain text on the value columns, so refs are never reinterpreted
    for name in TEXT_COLUMNS:
        i = names.index(name)
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": 1,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {"numberFormat": {"type": "TEXT"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    for name in DATE_COLUMNS:
        i = names.index(name)
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": 1,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {
                "numberFormat": {"type": "DATE", "pattern": "yyyy-mm-dd"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    # filter over the whole header
    reqs.append({"setBasicFilter": {"filter": {
        "range": {"sheetId": sheet_id, "startRowIndex": 0,
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

    nrows, current_header = existing_rows(service, args.tab)

    print(f"spreadsheet : Catalog Traceback ({SPREADSHEET_ID})")
    print(f"tab         : {args.tab!r} (gid {sheet_id})")
    print(f"existing    : {nrows} data row(s), {len(current_header)} header cell(s)")
    if current_header:
        print(f"              current header: {current_header}")
    print()
    print(f"planned header ({ncols} columns):")
    for i, (name, width, note) in enumerate(COLUMNS):
        dd = DROPDOWNS.get(name)
        extra = []
        if dd:
            extra.append("dropdown: " + "/".join(dd))
        if name in TEXT_COLUMNS:
            extra.append("plain text")
        if name in DATE_COLUMNS:
            extra.append("date yyyy-mm-dd")
        tail = ("   [" + "; ".join(extra) + "]") if extra else ""
        print(f"  {col_letter(i):>2}  {name:<13} {width:>4}px{tail}")

    if nrows and not args.force:
        print(f"\nREFUSING: {args.tab!r} already holds {nrows} data row(s).")
        print("Rebuilding would overwrite the header above existing data.")
        print("Re-run with --force only if you are sure, or pick an empty --tab.")
        return 1

    if not args.write:
        print("\nDRY RUN — nothing written. Re-run with --write to apply.")
        return 0

    from datetime import datetime
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    n, path = backup_tab(service, args.tab, f"{args.backup_dir}/{args.tab}_before_{stamp}.csv")
    print(f"\nbacked up {n} existing row(s) -> {path}")

    clear_tab(service, sheet_id, args.tab)
    print("cleared the tab (values, formats, notes, validation, merges)")

    service.spreadsheets().values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"'{args.tab}'!A1:{col_letter(ncols - 1)}1",
        valueInputOption="RAW",
        body={"values": [[c[0] for c in COLUMNS]]}).execute()
    print(f"\nwrote header: {ncols} cells")

    service.spreadsheets().batchUpdate(
        spreadsheetId=SPREADSHEET_ID,
        body={"requests": build_requests(sheet_id, ncols)}).execute()
    print("applied: header style, frozen row, widths, header notes, "
          "dropdowns, text/date formats, filter")
    print(f"\nDONE -> https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit#gid={sheet_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
