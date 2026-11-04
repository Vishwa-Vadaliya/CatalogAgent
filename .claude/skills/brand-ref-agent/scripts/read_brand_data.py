"""Step 1: scope summary for a brand source tab. Read-only.

usage: python read_brand_data.py --tab "Jacob & Co."
"""
import argparse
import sys
from collections import Counter

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True, help="brand source tab name")
    a = ap.parse_args()

    tabs = sc.list_tabs()
    if a.tab not in tabs:
        close = [t for t in tabs if a.tab.lower() in t.lower() or t.lower() in a.tab.lower()]
        print(f"tab {a.tab!r} not found. Similar tabs: {close or 'none'}")
        print(f"all tabs: {list(tabs)}")
        sys.exit(1)

    headers, rows = sc.read_tab(a.tab)
    data = rows[1:]
    print(f"tab: {a.tab} | rows (excl. header): {len(data)}")
    print(f"headers: {headers}")

    c_ref = sc.find_col(headers, "ReferenceNumber")
    c_raw = sc.find_col(headers, "RawReferenceNumber", required=False)
    c_rnid = sc.find_col(headers, "ReferenceNumberId", required=False)
    c_twc = sc.find_col(headers, "TotalWatchCount", required=False)
    c_model = sc.find_col(headers, "ModelName", required=False)
    c_final = sc.find_col(headers, "FinalRef", required=False)
    c_flag = sc.find_col(headers, "PartialRefFlag", required=False)

    flt = sc.describe_filter(a.tab)
    print("live filter:", flt if flt else "none")
    vis = sc.visible_row_numbers(a.tab, len(rows))
    vis_data = [r for i, r in enumerate(rows, start=1) if i > 1 and i in vis]
    print(f"rows visible under the current filter: {len(vis_data)}")

    def has_id(r):
        return c_rnid is not None and not sc.is_null(r[c_rnid])

    with_id = [r for r in data if has_id(r)]
    without_id = [r for r in data if not has_id(r)]
    print(f"\nReferenceNumberId set: {len(with_id)} | NULL/blank: {len(without_id)}")

    refs = Counter(r[c_ref].strip() for r in with_id if not sc.is_null(r[c_ref]))
    print(f"unique ReferenceNumber (Phase A population): {len(refs)}  (rows: {sum(refs.values())})")
    if c_raw is not None:
        raws = Counter(r[c_raw].strip() for r in without_id if not sc.is_null(r[c_raw]))
        print(f"unique RawReferenceNumber (Phase B population, RNId NULL): {len(raws)}  (rows: {sum(raws.values())})")
    if c_twc is not None:
        tot = 0
        for r in data:
            try:
                tot += int(float(r[c_twc]))
            except (ValueError, TypeError):
                pass
        print(f"TotalWatchCount column sum: {tot}")
    if c_model is not None:
        models = Counter(r[c_model].strip() for r in data if not sc.is_null(r[c_model]))
        print(f"unique ModelName: {len(models)} | top 8: {models.most_common(8)}")
    if c_final is not None:
        filled = sum(1 for r in data if not sc.is_null(r[c_final]))
        print(f"FinalRef already filled: {filled} rows ({len({r[c_final].strip() for r in data if not sc.is_null(r[c_final])})} unique)")
    if c_flag is not None:
        print(f"PartialRefFlag already present: {Counter(r[c_flag].strip() for r in data if r[c_flag].strip()).most_common(6)}")

    print("\nmost common ReferenceNumbers:", refs.most_common(8))
    print("sample refs (every ~Nth):", list(refs)[:: max(1, len(refs) // 8)][:8])

    final_tab = [t for t in tabs if t.lower().startswith(a.tab.lower().split()[0]) and "final refs" in t.lower()]
    print("\nexisting final-refs tab(s) for this brand:", final_tab or "none yet")


if __name__ == "__main__":
    main()
