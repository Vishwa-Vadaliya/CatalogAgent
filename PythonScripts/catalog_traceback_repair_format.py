"""Apply the standard Catalog Traceback formatting to the data rows, leaving values untouched.

This is the single definition of how the log's data rows should look. Run it whenever the
sheet needs tidying — after a bulk write, or if a row was added in a way that did not inherit
the formatting (an append drops number formats; INSERT_ROWS drops everything).

It applies, from the first data row down:

  * the Action / Field / Accept-Reject dropdowns
  * TEXT on ReferenceNumber, ModelName, OldValue, NewValue; DATE on Date
  * per-column alignment — ids and statuses centred, names and free text left
  * wrapping, so a long Reason is readable
  * alternating row banding, so 45 rows can be scanned
  * the vertical rules between the column groups

Values, headers and the group bands in row 1 are never touched. Idempotent.

    python catalog_traceback_repair_format.py            # show the plan
    python catalog_traceback_repair_format.py --write    # apply it

Credentials come from GOOGLE_APPLICATION_CREDENTIALS (see PythonScripts/google_auth.py).
"""
import argparse
import os
import sys
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)

from googleapiclient.discovery import build  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from google_auth import credentials, SHEETS_RW  # noqa: E402
from catalog_traceback_log import (  # noqa: E402
    SPREADSHEET_ID, DEFAULT_TAB, DATA_START, HEADERS, check_header, col_letter, read_tab)

DROPDOWNS = {
    "Action": ["Renamed", "Deleted", "Merged"],
    "Field": ["ReferenceNumber", "ModelName", "CatalogId"],
    "Accept/Reject": ["Pending", "Accepted", "Rejected"],
}
TEXT_COLUMNS = ["ReferenceNumber", "ModelName", "OldValue", "NewValue"]
DATE_COLUMNS = ["Date"]

# Ids, dates and statuses read better centred; names and free text read better left.
CENTRE = ["Date", "CatalogId", "EnrichmentId", "ModelId", "MergedIntoId",
          "Action", "Field", "Accept/Reject"]
LEFT = ["ChangedBy", "Brand", "ReferenceNumber", "ModelName",
        "OldValue", "NewValue", "Reason"]

BAND = {"red": 0.957, "green": 0.969, "blue": 0.980}   # the shaded alternate row
PLAIN = {"red": 1.0, "green": 1.0, "blue": 1.0}
GROUP_STARTS = ["CatalogId", "ModelId", "Action", "Accept/Reject"]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tab", default=DEFAULT_TAB)
    ap.add_argument("--write", action="store_true", help="apply; without this it is a dry run")
    args = ap.parse_args()

    service = build("sheets", "v4", credentials=credentials(SHEETS_RW), cache_discovery=False)

    meta = service.spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID,
        fields="sheets(properties(sheetId,title,gridProperties(rowCount)),bandedRanges)").execute()
    props = banded = None
    for s in meta["sheets"]:
        if s["properties"]["title"] == args.tab:
            props = s["properties"]
            banded = s.get("bandedRanges", [])
    if props is None:
        print("tab not found: %r" % args.tab)
        return 1
    sheet_id = props["sheetId"]
    row_count = props["gridProperties"]["rowCount"]

    vals = read_tab(service, args.tab)
    problems = check_header(vals)
    if problems:
        print("REFUSING - %r is not in the expected layout:" % args.tab)
        for p in problems:
            print("   " + p)
        return 1
    data_rows = max(len(vals) - (DATA_START - 1), 0)
    print("tab %r: %d data row(s), grid is %d rows, %d existing banded range(s)"
          % (args.tab, data_rows, row_count, len(banded)))
    print("formatting rows %d to %d\n" % (DATA_START, row_count))

    start = DATA_START - 1  # 0-based
    reqs = []

    def col_range(name):
        i = HEADERS.index(name)
        return {"sheetId": sheet_id, "startRowIndex": start,
                "startColumnIndex": i, "endColumnIndex": i + 1}

    for name, values in DROPDOWNS.items():
        print("  dropdown   %-14s %s" % (name, "/".join(values)))
        reqs.append({"setDataValidation": {
            "range": col_range(name),
            "rule": {"condition": {"type": "ONE_OF_LIST",
                                   "values": [{"userEnteredValue": v} for v in values]},
                     "strict": True, "showCustomUi": True}}})

    for name in TEXT_COLUMNS:
        print("  TEXT       %s" % name)
        reqs.append({"repeatCell": {
            "range": col_range(name),
            "cell": {"userEnteredFormat": {"numberFormat": {"type": "TEXT"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    for name in DATE_COLUMNS:
        print("  DATE       %s" % name)
        reqs.append({"repeatCell": {
            "range": col_range(name),
            "cell": {"userEnteredFormat": {
                "numberFormat": {"type": "DATE", "pattern": "yyyy-mm-dd"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    for name in CENTRE + LEFT:
        align = "CENTER" if name in CENTRE else "LEFT"
        print("  align      %-14s %s" % (name, align))
        reqs.append({"repeatCell": {
            "range": col_range(name),
            "cell": {"userEnteredFormat": {
                "horizontalAlignment": align,
                "verticalAlignment": "MIDDLE",
                "wrapStrategy": "WRAP"}},
            "fields": ("userEnteredFormat(horizontalAlignment,verticalAlignment,"
                       "wrapStrategy)")}})

    # alternating row banding - replace any existing one so re-running stays clean
    for b in banded:
        reqs.append({"deleteBanding": {"bandedRangeId": b["bandedRangeId"]}})
    print("  banding    alternating rows from %d down" % DATA_START)
    reqs.append({"addBanding": {"bandedRange": {
        "range": {"sheetId": sheet_id, "startRowIndex": start,
                  "startColumnIndex": 0, "endColumnIndex": len(HEADERS)},
        "rowProperties": {"firstBandColor": PLAIN, "secondBandColor": BAND}}}})

    # vertical rules between the column groups
    for name in GROUP_STARTS:
        i = HEADERS.index(name)
        reqs.append({"updateBorders": {
            "range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": row_count,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "left": {"style": "SOLID_MEDIUM",
                     "color": {"red": 0.25, "green": 0.25, "blue": 0.25}}}})
    print("  borders    group rules before %s" % ", ".join(GROUP_STARTS))

    print("\n%d request(s). Values are not touched." % len(reqs))
    if not args.write:
        print("DRY RUN - nothing applied. Re-run with --write.")
        return 0

    service.spreadsheets().batchUpdate(
        spreadsheetId=SPREADSHEET_ID, body={"requests": reqs}).execute()
    print("APPLIED")
    print("https://docs.google.com/spreadsheets/d/%s/edit" % SPREADSHEET_ID)
    return 0


if __name__ == "__main__":
    sys.exit(main())
