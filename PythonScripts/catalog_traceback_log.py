"""Append change rows to the Catalog Traceback log (Sheet2).

One row per manual catalog change: a ReferenceNumber renamed, a ModelName renamed, a
catalog row or model deleted, or a duplicate merged into a surviving row.

Dry run by default. Nothing is written without --write.

    # one change, from a JSON object
    python catalog_traceback_log.py --record "{...}"

    # several, from a JSON array in a file
    python catalog_traceback_log.py --records-file rows.json --write

Credentials come from GOOGLE_APPLICATION_CREDENTIALS (see PythonScripts/google_auth.py).
The structure is built by catalog_traceback_setup.py; this script only appends to it.
"""
import argparse
import csv
import json
import os
import sys
import warnings
from datetime import date, datetime

warnings.filterwarnings("ignore", category=FutureWarning)

from googleapiclient.discovery import build  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from google_auth import credentials, SHEETS_RW  # noqa: E402

SPREADSHEET_ID = "1l23GqhRziHUNjeijLtxVTAZurtdhjPTKNkbV5xTvqEE"
DEFAULT_TAB = "Sheet2"
HEADER_ROW = 2          # 1-based: row 2 holds the column names
DATA_START = 3          # 1-based: data begins on row 3

HEADERS = [
    "Date", "ChangedBy", "Brand",
    "CatalogId", "ReferenceNumber", "EnrichmentId",
    "ModelId", "ModelName",
    "Action", "Field", "OldValue", "NewValue", "MergedIntoId", "Reason",
    "Accept/Reject",
]

ACTIONS = ["Renamed", "Deleted", "Merged"]
FIELDS = ["ReferenceNumber", "ModelName", "CatalogId"]
DECISIONS = ["Pending", "Accepted", "Rejected"]

# Columns that together identify a change, for the duplicate check.
DUP_KEY = ["CatalogId", "ModelId", "Action", "Field", "OldValue", "NewValue"]

PLACEHOLDERS = {"n/a", "na", "none", "-", "null"}


def col_letter(idx):
    s, n = "", idx + 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def svc():
    return build("sheets", "v4", credentials=credentials(SHEETS_RW), cache_discovery=False)


def q(tab):
    return "'" + tab.replace("'", "''") + "'"


def read_tab(service, tab):
    return service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=q(tab) + "!A1:ZZ",
        valueRenderOption="UNFORMATTED_VALUE").execute().get("values", [])


def check_header(vals):
    """The layout must be exactly as expected, or we refuse to write by column letter."""
    if len(vals) < HEADER_ROW:
        return ["tab has fewer than %d rows - run catalog_traceback_setup.py first" % HEADER_ROW]
    got = [str(c).strip() for c in vals[HEADER_ROW - 1]]
    got = got[:len(HEADERS)] + [""] * max(0, len(HEADERS) - len(got))
    problems = []
    for i, (want, have) in enumerate(zip(HEADERS, got)):
        if want != have:
            problems.append("column %s: expected %r, found %r" % (col_letter(i), want, have))
    return problems


def norm(v):
    return str(v).strip() if v is not None else ""


def validate(rec, idx):
    """Problems with one record. Vocabulary must match the sheet's dropdowns exactly."""
    problems = []
    action = norm(rec.get("Action"))
    field = norm(rec.get("Field"))

    if action not in ACTIONS:
        problems.append("Action %r is not one of %s" % (action, ACTIONS))
    if field and field not in FIELDS:
        problems.append("Field %r is not one of %s" % (field, FIELDS))

    if not norm(rec.get("CatalogId")) and not norm(rec.get("ModelId")):
        problems.append("neither CatalogId nor ModelId given - the row would identify nothing")

    if action == "Renamed":
        if not norm(rec.get("OldValue")) or not norm(rec.get("NewValue")):
            problems.append("Renamed needs both OldValue and NewValue")
        if not field:
            problems.append("Renamed needs Field (ReferenceNumber or ModelName)")
    if action == "Merged" and not norm(rec.get("MergedIntoId")):
        problems.append("Merged needs MergedIntoId - the id that survived")

    decision = norm(rec.get("Accept/Reject")) or "Pending"
    if decision not in DECISIONS:
        problems.append("Accept/Reject %r is not one of %s" % (decision, DECISIONS))

    if norm(rec.get("EnrichmentId")).lower() in PLACEHOLDERS:
        problems.append("EnrichmentId must be left blank, never a placeholder")

    d = norm(rec.get("Date"))
    if d:
        try:
            datetime.strptime(d, "%Y-%m-%d")
        except ValueError:
            problems.append("Date %r is not yyyy-mm-dd" % d)

    unknown = [k for k in rec if k not in HEADERS]
    if unknown:
        problems.append("unknown field(s) %s - not a column on the sheet" % unknown)

    return ["record %d: %s" % (idx, p) for p in problems]


def to_row(rec):
    """One record -> the 15 cells, in column order."""
    out = dict(rec)
    out.setdefault("Date", date.today().strftime("%Y-%m-%d"))
    out.setdefault("Accept/Reject", "Pending")
    return [norm(out.get(h)) for h in HEADERS]


def existing_rows(vals):
    rows = []
    for r in vals[DATA_START - 1:]:
        cells = [norm(c) for c in r]
        cells += [""] * max(0, len(HEADERS) - len(cells))
        rows.append(dict(zip(HEADERS, cells)))
    return rows


def find_duplicates(rec, rows):
    """Rows already logging this same change."""
    if not any(norm(rec.get(k)) for k in DUP_KEY):
        return []
    hits = []
    for n, r in enumerate(rows, start=DATA_START):
        if all(norm(rec.get(k)) == r.get(k, "") for k in DUP_KEY):
            hits.append((n, r))
    return hits


def snapshot(vals, backup_dir, tab):
    os.makedirs(backup_dir, exist_ok=True)
    name = "%s_before_%s.csv" % (tab, datetime.now().strftime("%Y%m%d_%H%M%S"))
    path = os.path.join(backup_dir, name)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh).writerows(vals)
    return path


TEXT_COLUMNS = ["ReferenceNumber", "ModelName", "OldValue", "NewValue"]
DATE_COLUMNS = ["Date"]


def sheet_id_of(service, tab):
    meta = service.spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID,
        fields="sheets(properties(sheetId,title))").execute()
    for s in meta["sheets"]:
        if s["properties"]["title"] == tab:
            return s["properties"]["sheetId"]
    raise SystemExit("tab not found: %r" % tab)


def reapply_formats(service, tab, first_row, last_row):
    """values.append drops userEnteredFormat.numberFormat on the rows it writes (it keeps
    dataValidation). Put the TEXT and DATE formats back, so a later hand-edit of one of these
    cells is not coerced into a date or a fraction."""
    sid = sheet_id_of(service, tab)
    reqs = []
    for name, nf in ([(n, {"type": "TEXT"}) for n in TEXT_COLUMNS]
                     + [(n, {"type": "DATE", "pattern": "yyyy-mm-dd"}) for n in DATE_COLUMNS]):
        i = HEADERS.index(name)
        reqs.append({"repeatCell": {
            "range": {"sheetId": sid,
                      "startRowIndex": first_row - 1, "endRowIndex": last_row,
                      "startColumnIndex": i, "endColumnIndex": i + 1},
            "cell": {"userEnteredFormat": {"numberFormat": nf}},
            "fields": "userEnteredFormat.numberFormat"}})
    service.spreadsheets().batchUpdate(
        spreadsheetId=SPREADSHEET_ID, body={"requests": reqs}).execute()
    return len(reqs)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--record", help="one change as a JSON object")
    src.add_argument("--records-file", help="path to a JSON array of changes")
    ap.add_argument("--tab", default=DEFAULT_TAB)
    ap.add_argument("--write", action="store_true", help="apply; without this it is a dry run")
    ap.add_argument("--allow-duplicate", action="store_true",
                    help="append even when a matching row already exists")
    ap.add_argument("--backup-dir", default="../Output/Data/CatalogTraceback",
                    help="where the pre-write CSV snapshot goes")
    args = ap.parse_args()

    if args.record:
        raw = json.loads(args.record)
    else:
        with open(args.records_file, encoding="utf-8") as fh:
            raw = json.load(fh)
    records = raw if isinstance(raw, list) else [raw]

    if not records:
        print("no records given")
        return 1
    if len(records) > 50:
        print("REFUSING: %d records. Cap is 50 per run so the preview stays reviewable."
              % len(records))
        return 1

    service = svc()
    vals = read_tab(service, args.tab)

    header_problems = check_header(vals)
    if header_problems:
        print("REFUSING to write - %r is not in the expected layout:" % args.tab)
        for p in header_problems:
            print("   " + p)
        print("\nRe-run PythonScripts/catalog_traceback_setup.py, or fix the tab by hand.")
        return 1
    print("header check: OK (%d columns match)" % len(HEADERS))

    problems = []
    for i, rec in enumerate(records, 1):
        problems += validate(rec, i)
    if problems:
        print("\nREFUSING to write - invalid record(s):")
        for p in problems:
            print("   " + p)
        return 1

    rows = [to_row(r) for r in records]
    current = existing_rows(vals)

    print("\nplanned rows (%d):\n" % len(rows))
    blocked = False
    for i, (rec, row) in enumerate(zip(records, rows), 1):
        print("  --- record %d ---" % i)
        for h, v in zip(HEADERS, row):
            print("    %-16s %s" % (h, v if v else "(blank)"))
        for n, d in find_duplicates(rec, current):
            print("    ** DUPLICATE of row %d (logged %s by %s) **"
                  % (n, d.get("Date") or "?", d.get("ChangedBy") or "?"))
            if not args.allow_duplicate:
                blocked = True
        print()

    if blocked:
        print("REFUSING: a matching row already exists. "
              "Re-run with --allow-duplicate to append anyway.")
        return 1

    if not args.write:
        print("DRY RUN - nothing written. Re-run with --write to append %d row(s) to %r."
              % (len(rows), args.tab))
        return 0

    path = snapshot(vals, args.backup_dir, args.tab)
    print("snapshot of %d row(s) -> %s" % (len(vals), path))

    # append: let Sheets choose the row, so a concurrent edit is never overwritten.
    # RAW, so refs like 5711/1A-010 and B1/M are not reinterpreted as dates or fractions.
    # NOT insertDataOption="INSERT_ROWS": inserted rows do not inherit the tab's data validation
    # or number formats, so the dropdowns and the TEXT format would be missing on every logged row
    # and the formatted rows would be pushed down. The default (OVERWRITE) writes into the existing
    # grid rows, which already carry both. Append never reaches a row that holds data.
    resp = service.spreadsheets().values().append(
        spreadsheetId=SPREADSHEET_ID,
        range="%s!A%d:%s" % (q(args.tab), DATA_START, col_letter(len(HEADERS) - 1)),
        valueInputOption="RAW",
        body={"values": rows}).execute(num_retries=3)

    updated = resp.get("updates", {}).get("updatedRange", "(unknown)")
    print("APPENDED %d row(s) -> %s" % (len(rows), updated))

    # restore the number formats the append dropped
    try:
        rng = updated.split("!")[-1]
        nums = [int(x) for x in __import__("re").findall(r"\d+", rng)]
        first, last = (nums[0], nums[-1]) if nums else (DATA_START, DATA_START)
        n = reapply_formats(service, args.tab, first, last)
        print("re-applied %d number format(s) to rows %d-%d "
              "(append drops them; dropdowns survive)" % (n, first, last))
    except Exception as exc:                      # never fail the log over formatting
        print("WARNING: could not re-apply number formats: %s" % exc)
        print("         the values are written and correct; run "
              "catalog_traceback_repair_format.py --write to fix the formatting")
    print("https://docs.google.com/spreadsheets/d/%s/edit" % SPREADSHEET_ID)
    return 0


if __name__ == "__main__":
    sys.exit(main())
