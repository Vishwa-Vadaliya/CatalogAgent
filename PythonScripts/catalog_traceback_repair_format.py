"""Re-apply the Catalog Traceback data formatting to the data rows, leaving values untouched.

Needed when rows were added in a way that did not inherit the tab's formatting (an append with
insertDataOption=INSERT_ROWS does exactly that). Re-applies, from the first data row down:

  * the Action / Field / Accept-Reject dropdowns
  * the TEXT number format on ReferenceNumber, ModelName, OldValue, NewValue
  * the DATE format on Date

Values, headers and the group bands are not touched. Idempotent — safe to re-run.

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
    SPREADSHEET_ID, DEFAULT_TAB, DATA_START, HEADERS, check_header, col_letter, q, read_tab)

DROPDOWNS = {
    "Action": ["Renamed", "Deleted", "Merged"],
    "Field": ["ReferenceNumber", "ModelName", "CatalogId"],
    "Accept/Reject": ["Pending", "Accepted", "Rejected"],
}
TEXT_COLUMNS = ["ReferenceNumber", "ModelName", "OldValue", "NewValue"]
DATE_COLUMNS = ["Date"]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tab", default=DEFAULT_TAB)
    ap.add_argument("--write", action="store_true", help="apply; without this it is a dry run")
    args = ap.parse_args()

    service = build("sheets", "v4", credentials=credentials(SHEETS_RW), cache_discovery=False)

    meta = service.spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID,
        fields="sheets(properties(sheetId,title,gridProperties(rowCount)))").execute()
    props = None
    for s in meta["sheets"]:
        if s["properties"]["title"] == args.tab:
            props = s["properties"]
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
    print("tab %r: %d data row(s), grid is %d rows" % (args.tab, data_rows, row_count))
    print("re-applying formatting from row %d down to row %d\n" % (DATA_START, row_count))

    names = HEADERS
    reqs = []
    start = DATA_START - 1  # 0-based

    for name, values in DROPDOWNS.items():
        i = names.index(name)
        print("  dropdown  %s %-14s %s" % (col_letter(i), name, "/".join(values)))
        reqs.append({"setDataValidation": {
            "range": {"sheetId": sheet_id, "startRowIndex": start,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "rule": {"condition": {"type": "ONE_OF_LIST",
                                   "values": [{"userEnteredValue": v} for v in values]},
                     "strict": True, "showCustomUi": True}}})

    for name in TEXT_COLUMNS:
        i = names.index(name)
        print("  TEXT      %s %s" % (col_letter(i), name))
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": start,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {"numberFormat": {"type": "TEXT"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    for name in DATE_COLUMNS:
        i = names.index(name)
        print("  DATE      %s %s" % (col_letter(i), name))
        reqs.append({"repeatCell": {
            "range": {"sheetId": sheet_id, "startRowIndex": start,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {
                "numberFormat": {"type": "DATE", "pattern": "yyyy-mm-dd"}}},
            "fields": "userEnteredFormat.numberFormat"}})

    print("\n%d formatting request(s). Values are not touched." % len(reqs))
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
