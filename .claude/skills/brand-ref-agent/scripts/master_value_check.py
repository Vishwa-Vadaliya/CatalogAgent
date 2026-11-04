"""Step 5: compare DialColor / CaseMaterial / ModelName values on a final-refs tab with the master list.

Read-only. Never changes a value. Reports, per field, the values that are not in the master list,
with row counts and a near-match suggestion where one exists.

The master list comes from a sheet tab (a column per field, header row) or a CSV file with the same
layout. Column headers are matched by name: DialColor / CaseMaterial / ModelName (aliases accepted,
e.g. "Dial Color", "CaseMaterials", "Model").

usage:
  python master_value_check.py --tab "X final refs" --master-sheet "<spreadsheetId>:<tab>"
  python master_value_check.py --tab "X final refs" --master-sheet "<tab in RawRefsToAssign>"
  python master_value_check.py --tab "X final refs" --master-csv master.csv
  python master_value_check.py --tab "X final refs" --master-book <spreadsheetId> --manufacturer "Jaeger-LeCoultre"
    (a workbook with tabs DialColor[ColorName], Material[MaterialName], Model[ModelName + ManufacturerName])
  add --include-flagged to also check rows that carry a PartialRefFlag.
"""
import argparse
import csv
import difflib
import re
import sys
from collections import Counter

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402

FIELDS = {
    "DialColor": ["DialColor", "DialColors", "Dial Color", "Dial Colour", "Colour", "Color"],
    "CaseMaterial": ["CaseMaterial", "CaseMaterials", "Case Material", "Material"],
    "ModelName": ["ModelName", "Model Name", "Model", "Models"],
}


def key(v):
    return re.sub(r"\s+", " ", str(v).strip().lower())


def load_book(args):
    """Master workbook with tabs DialColor (ColorName), Material (MaterialName), Model (ModelName, ManufacturerName)."""
    svc = sc.service()

    def tab(name):
        return svc.spreadsheets().values().get(spreadsheetId=args.master_book, range=f"{sc.q(name)}!A1:H20000").execute().get("values", [])

    master = {}
    for field, tname, vcol in (("DialColor", "DialColor", "ColorName"), ("CaseMaterial", "Material", "MaterialName")):
        rows = tab(tname)
        i = sc.find_col(rows[0], vcol)
        master[field] = {str(r[i]).strip() for r in rows[1:] if i < len(r) and str(r[i]).strip()}
        print(f"master {field} (tab {tname}): {len(master[field])} values")
    rows = tab("Model")
    mi, ci = sc.find_col(rows[0], "ModelName"), sc.find_col(rows[0], "ManufacturerName")
    want = sc.norm_ref(args.manufacturer or "")
    master["ModelName"] = {str(r[mi]).strip() for r in rows[1:] if mi < len(r) and ci < len(r) and sc.norm_ref(r[ci]) == want and str(r[mi]).strip()}
    print(f"master ModelName (tab Model, manufacturer {args.manufacturer!r}): {len(master['ModelName'])} values of {len(rows) - 1} rows")
    return master


def load_master(args):
    if args.master_book:
        return load_book(args)
    if args.master_csv:
        with open(args.master_csv, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.reader(fh))
    else:
        spec = args.master_sheet
        if ":" in spec and len(spec.split(":")[0]) > 25:
            ssid, tab = spec.split(":", 1)
            res = sc.service().spreadsheets().values().get(
                spreadsheetId=ssid, range=f"{sc.q(tab)}!A1:ZZ").execute()
            rows = res.get("values", [])
        else:
            rows = sc.get_values(spec, "A1:ZZ")
    if not rows:
        raise SystemExit("master list is empty")
    hdr = rows[0]
    master = {}
    for field, aliases in FIELDS.items():
        idx = sc.find_col(hdr, *aliases, required=False)
        if idx is None:
            print(f"master list has no column for {field} (headers: {hdr}) - skipping that field")
            continue
        vals = {str(r[idx]).strip() for r in rows[1:] if idx < len(r) and str(r[idx]).strip()}
        master[field] = vals
        print(f"master {field}: {len(vals)} values")
    return master


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--master-sheet")
    g.add_argument("--master-csv")
    g.add_argument("--master-book", help="spreadsheet id of a workbook with tabs DialColor / Material / Model")
    ap.add_argument("--manufacturer", help="manufacturer name used to filter the Model tab (with --master-book)")
    ap.add_argument("--include-flagged", action="store_true")
    ap.add_argument("--status-header", help="status column of a variations tab (VariationStatus): only rows whose status "
                    "starts with --status-keep are checked (replaces the PartialRefFlag filter)")
    ap.add_argument("--status-keep", default="Keep")
    ap.add_argument("--visible-only", action="store_true",
                    help="only rows currently visible under the tab's filter (the user's live filter)")
    ap.add_argument("--out", help="CSV of mismatches")
    a = ap.parse_args()

    master = load_master(a)
    headers, rows = sc.read_tab(a.tab)
    c_flag = sc.find_col(headers, "PartialRefFlag", required=False)
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    cols = {f: sc.find_col(headers, f, required=False) for f in master}
    vis = sc.visible_row_numbers(a.tab, len(rows)) if a.visible_only else None
    c_status = sc.find_col(headers, a.status_header) if a.status_header else None
    if c_status is not None:
        a.include_flagged = False
        c_flag = None
    data = [r for i, r in enumerate(rows, 1) if i > 1 and r[c_ref].strip() and (vis is None or i in vis)
            and (a.include_flagged or c_flag is None or not r[c_flag].strip())
            and (c_status is None or r[c_status].strip().lower().startswith(a.status_keep.lower()))]
    print(f"\ntab {a.tab!r}: {len(data)} rows checked ({'all' if a.include_flagged else 'clean full refs only'}"
          f"{', visible rows only' if vis is not None else ''})")

    out_rows = []
    for field, mvals in master.items():
        c = cols[field]
        if c is None:
            print(f"\n{field}: column not found on the tab - skipped")
            continue
        mkeys = {key(v): v for v in mvals}
        counts = Counter(r[c].strip() for r in data if not sc.is_null(r[c]))
        blank = sum(1 for r in data if sc.is_null(r[c]))
        unique = len(counts)
        missing = {v: n for v, n in counts.items() if key(v) not in mkeys}
        exact_case = sum(1 for v in counts if v in mvals)
        print(f"\n=== {field}: {unique} unique values, {blank} blank rows, "
              f"{unique - len(missing)} in master ({exact_case} exact-case), {len(missing)} NOT in master ===")
        for v, n in sorted(missing.items(), key=lambda x: -x[1]):
            sug = difflib.get_close_matches(v, list(mvals), n=1, cutoff=0.75)
            print(f"   {v!r}: {n} row(s)" + (f"  -> similar master value: {sug[0]!r}" if sug else ""))
            out_rows.append({"field": field, "value": v, "rows": n, "suggestion": sug[0] if sug else ""})
        casing = [v for v in counts if key(v) in mkeys and v not in mvals]
        if casing:
            print(f"   (case/spacing differs from master for {len(casing)} value(s), e.g. "
                  f"{[(v, mkeys[key(v)]) for v in casing[:5]]})")
    if a.out and out_rows:
        with open(a.out, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=["field", "value", "rows", "suggestion"])
            w.writeheader()
            w.writerows(out_rows)
        print(f"\nmismatches -> {a.out}")
    print("\nread-only: no values were changed.")


if __name__ == "__main__":
    main()
