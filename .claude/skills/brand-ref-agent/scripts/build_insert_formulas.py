"""Step 6: write one INSERT INTO #CreateCatalogQueue formula per clean full-ref row.

Dry run by default. The statements are sheet formulas (same approach as the existing tabs); this
script never runs SQL. Rows with a PartialRefFlag, or without a ref, get no statement. Every cell
value is wrapped in SUBSTITUTE(x,"'","''") so single quotes cannot break the SQL.

usage:
  python build_insert_formulas.py --tab "X final refs" --manufacturer "Jacob & co"
  python build_insert_formulas.py --tab "X final refs" --manufacturer "Jacob & co" --write
  add --verify to compare the rendered text with existing statements (read-only check).
"""
import argparse
import sys
from collections import Counter

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402

HEAD = ("INSERT INTO #CreateCatalogQueue (ReferenceNumber, ManufacturerName, ModelName, CaseMaterials, "
        "DialColors, PrimaryImageURL, SourceLink, StatusId, UserID) VALUES (")


def esc(s):
    return str(s).replace("'", "''")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--manufacturer", required=True, help="exact ManufacturerName text, e.g. 'Jacob & co'")
    ap.add_argument("--statement-col", help="column letter for the statements (default: existing InsertStatement/last column)")
    ap.add_argument("--status-id", type=int, default=1)
    ap.add_argument("--user-id", type=int, default=6)
    ap.add_argument("--exclude-lengths", default="",
                    help="comma-separated Length values to leave out (e.g. 2,3 for the plain short numbers)")
    ap.add_argument("--key-header", help="unique row key header (VariationId on a variations tab); default: the ref column")
    ap.add_argument("--status-header", help="header of the status column (VariationStatus on a variations tab); "
                    "only rows whose status starts with --status-keep get a statement")
    ap.add_argument("--status-keep", default="Keep")
    ap.add_argument("--visible-only", action="store_true",
                    help="only rows currently visible under the tab's filter (default: all rows)")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--verify", action="store_true", help="compare with existing INSERT cells, no writes")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    formulas = sc.read_tab(a.tab, render="FORMULA")[1]
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_flag = sc.find_col(headers, "PartialRefFlag", required=False)
    c_key = sc.find_col(headers, a.key_header) if a.key_header else c_ref
    c_status = sc.find_col(headers, a.status_header) if a.status_header else None
    c_model = sc.find_col(headers, "ModelName")
    c_case = sc.find_col(headers, "CaseMaterial", "CaseMaterials")
    c_dial = sc.find_col(headers, "DialColor", "DialColors")
    c_img = sc.find_col(headers, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    c_link = sc.find_col(headers, "SourceLink", "Sourcelink")
    c_stmt = sc.find_col(headers, "InsertStatement", required=False)
    c_len = sc.find_col(headers, "Length", required=False)
    excl = {x.strip() for x in a.exclude_lengths.split(",") if x.strip()}
    if a.statement_col:
        c_stmt = sc.col_index(a.statement_col)
    TARGET = "INSERT INTO #CreateCatalogQueue"
    if c_stmt is None:
        existing = [i for i, col in enumerate(zip(*rows[1:])) if any(TARGET in str(v) for v in col)]
        c_stmt = existing[0] if existing else len(headers) + 1
        print(f"statement column not named; using {sc.col_letter(c_stmt)}"
              f"{' (existing #CreateCatalogQueue cells found there)' if existing else ' (new column after the last header)'}")
    others = Counter(str(r[c_stmt])[:30] for r in rows[1:] if c_stmt < len(r) and str(r[c_stmt]).strip()
                     and not str(r[c_stmt]).startswith(TARGET))
    if others and not a.verify:
        print(f"REFUSING: column {sc.col_letter(c_stmt)} already holds other content {dict(others.most_common(3))}. "
              "Pick a free column with --statement-col.")
        sys.exit(1)

    L = sc.col_letter

    def wrap(c):
        return f'SUBSTITUTE({L(c)}{{row}},"\'","\'\'")'

    manu = esc(a.manufacturer).replace('"', '""')
    formula = ('="' + HEAD + "'\"&" + wrap(c_ref) + f'&"\',\'{manu}\',\'"&' + wrap(c_model) + '&"\',\'"&' + wrap(c_case)
               + '&"\',\'"&' + wrap(c_dial) + '&"\',\'"&' + wrap(c_img) + '&"\',\'"&' + wrap(c_link)
               + f'&"\',{a.status_id},{a.user_id});"')

    vis = sc.visible_row_numbers(a.tab, len(rows)) if a.visible_only else None
    writes, skipped = [], Counter()
    ready_missing = Counter()
    literal_null = Counter()
    for rn, r in enumerate(rows[1:], start=2):
        ref = r[c_ref].strip()
        if not ref:
            continue
        if vis is not None and rn not in vis:
            skipped["hidden by the filter (--visible-only)"] += 1
            continue
        if c_status is not None:
            if not r[c_status].strip().lower().startswith(a.status_keep.lower()):
                skipped[f"{a.status_header} not '{a.status_keep}' ({r[c_status].strip()[:25] or 'blank'})"] += 1
                continue
        elif c_flag is not None and r[c_flag].strip():
            skipped["flagged (PartialRefFlag set)"] += 1
            continue
        if excl and c_len is not None and str(r[c_len]).strip() in excl:
            skipped[f"Length in {sorted(excl)} (left out on request)"] += 1
            continue
        for name, c in (("ModelName", c_model), ("CaseMaterial", c_case), ("DialColor", c_dial), ("FinalImageUrl", c_img)):
            if sc.is_null(r[c]):
                ready_missing[name] += 1
                if str(r[c]).strip().upper() == "NULL":
                    literal_null[name] += 1
        writes.append((r[c_key].strip(), c_stmt, formula))

    print(f"clean full-ref rows: {len(writes)} | skipped: {dict(skipped) or 'none'}")
    print("clean rows with an empty field (statement still written, field is blank in it):",
          dict(ready_missing) or "none")
    print("  ...of which hold the literal text NULL (it is written into the statement as the word NULL):",
          dict(literal_null) or "none")
    print("\nformula template:\n  " + formula.replace("{row}", "<row>"))

    if a.verify:
        ok = bad = 0
        shown = 0
        for i, r in enumerate(rows[1:], start=1):
            ref = r[c_ref].strip()
            cell = r[c_stmt].strip() if c_stmt < len(r) else ""
            if not ref or not cell.startswith(TARGET):
                continue
            expect = (f"{HEAD}'{esc(ref)}','{esc(a.manufacturer)}','{esc(r[c_model])}','{esc(r[c_case])}',"
                      f"'{esc(r[c_dial])}','{esc(r[c_img])}','{esc(r[c_link])}',{a.status_id},{a.user_id});")
            if cell == expect:
                ok += 1
            else:
                bad += 1
                if shown < 3:
                    shown += 1
                    print(f"   MISMATCH row {i + 1}:\n     existing: {cell[:260]}\n     rendered: {expect[:260]}")
        print(f"\nverify: {ok} existing statements identical to what this script renders, {bad} differ")
        return

    sc.safe_batch_write(a.tab, writes, key_header=headers[c_key], value_input="USER_ENTERED",
                        write=a.write, label="insert statements")
    if a.write:
        if c_stmt >= len(headers) or not headers[c_stmt].strip():
            sc.write_cells(a.tab, [(f"{L(c_stmt)}1", "InsertStatement")], write=True, label="header")


if __name__ == "__main__":
    main()
