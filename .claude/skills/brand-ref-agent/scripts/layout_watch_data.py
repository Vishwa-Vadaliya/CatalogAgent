"""Step 3: reshape the user's pasted watch-data query output into the standard final-refs layout.

The user pastes their query output (header row + data, columns such as ReferenceNumberId,
FirstWatchId, FirstWatchPublishWatchId, DialColor, CaseMaterial, ModelName, Images) either into a
separate tab or into free columns of the final-refs tab itself. This script maps each pasted row to
its final-refs row by ReferenceNumberId and writes the standard watch-data block, the image
candidate columns, and the SourceLink / FinalImage formulas.

Dry run by default.

usage:
  python layout_watch_data.py --tab "X final refs" --source-tab "pasted data"
  python layout_watch_data.py --tab "X final refs" --source-tab "X final refs" --source-col AM
  add --create-headers to create missing standard headers, --write to write.

In-place mode: when the query output was pasted straight into the standard columns (H..O) of the
final-refs tab, on the right rows, use --in-place (no --source-tab). It first checks the alignment
(FirstWatchId is one of the row's WatchIds; the pasted ReferenceNumberId equals the identity one),
refuses to continue if any row fails, then only finishes the layout: NULL text -> blank, image
candidate columns, SourceLink and FinalImage formulas, headers.
"""
import argparse
import sys
from collections import Counter

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402

# standard position (0-based) used only when a header has to be created
STANDARD = {"SourceRowId": 7, "ReferenceNumberId#2": 8, "FirstWatchId": 9, "FirstWatchPublishWatchId": 10,
            "DialColor": 11, "CaseMaterial": 12, "ModelName": 13, "Images": 14, "FinalImageUrl": 15,
            "SourceLink": 16, "FinalImage": 17}
NAMES = {"SourceRowId": ["SourceRowId"], "ReferenceNumberId#2": ["ReferenceNumberId"],
         "FirstWatchId": ["FirstWatchId"], "FirstWatchPublishWatchId": ["FirstWatchPublishWatchId"],
         "DialColor": ["DialColor"], "CaseMaterial": ["CaseMaterial"], "ModelName": ["ModelName"],
         "Images": ["Images"], "FinalImageUrl": ["FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl"],
         "SourceLink": ["SourceLink", "Sourcelink"], "FinalImage": ["FinalImage"]}
MAX_CANDIDATES = 10


def clean(v):
    v = str(v).strip()
    return "" if sc.is_null(v) else v


def read_source(tab, start_col):
    vals = sc.get_values(tab, "A1:ZZ")
    if not vals:
        return []
    start = sc.col_index(start_col) if start_col else 0
    hdr = vals[0][start:]
    width = 0
    for i, h in enumerate(hdr):
        if str(h).strip():
            width = i + 1
    hdr = [str(h).strip() for h in hdr[:width]]
    out = []
    for r in vals[1:]:
        seg = (list(r) + [""] * (start + width))[start:start + width]
        if any(str(c).strip() for c in seg):
            out.append({sc.norm_header(h): c for h, c in zip(hdr, seg) if h})
    return out


def finish_in_place(a, headers, rows, col, c_ref, c_flag, first_url):
    c_watch = sc.find_col(headers, "WatchIds")
    c_id = sc.find_col(headers, "ReferenceNumberId", occurrence=1)
    L = sc.col_letter
    DATA = ["ReferenceNumberId#2", "FirstWatchId", "FirstWatchPublishWatchId", "DialColor", "CaseMaterial", "ModelName", "Images"]
    targets, no_data, flagged_with_data, misaligned = [], [], 0, []
    for r in rows[1:]:
        ref = r[c_ref].strip()
        if not ref:
            continue
        has = any(r[col[k]].strip() for k in DATA)
        if c_flag is not None and r[c_flag].strip() and not a.include_flagged:
            flagged_with_data += 1 if has else 0
            continue
        if not has:
            no_data.append(ref)
            continue
        wids = {x.strip() for x in r[c_watch].split(",") if x.strip()}
        fw = clean(r[col["FirstWatchId"]])
        rid2, rid1 = clean(r[col["ReferenceNumberId#2"]]), clean(r[c_id])
        if (fw and fw not in wids) or (rid1 and rid2 and rid1 != rid2):
            misaligned.append(ref)
            continue
        targets.append((ref, r))
    print(f"in-place: rows with data on clean refs: {len(targets)} | clean refs with no pasted data: {len(no_data)} | "
          f"flagged refs that carry data (skipped): {flagged_with_data} | misaligned rows: {len(misaligned)}")
    if misaligned:
        print("ALIGNMENT FAILED, nothing will be written. First rows:", misaligned[:10])
        sys.exit(1)
    if no_data:
        print("   clean refs with no data (first 10):", no_data[:10])
    k_col, p_col = L(col["FirstWatchPublishWatchId"]), L(col["FinalImageUrl"])
    raw, formulas, blanks, nulls = [], [], Counter(), Counter()
    for ref, r in targets:
        for key in ["FirstWatchPublishWatchId", "DialColor", "CaseMaterial", "ModelName", "Images"]:
            v = r[col[key]]
            if sc.is_null(v) and v != "":
                raw.append((ref, col[key], ""))
                nulls[key] += 1
            if sc.is_null(v):
                blanks[key] += 1
        urls = [u.strip() for u in r[col["Images"]].split(",") if u.strip().lower().startswith("http")]
        for j in range(MAX_CANDIDATES):
            if j < len(urls):
                raw.append((ref, first_url + j, urls[j]))
        if not urls:
            blanks["image candidates"] += 1
        formulas.append((ref, col["SourceLink"], f'=IF({k_col}{{row}}="","","https://everywatch.com/watch/"&{k_col}{{row}})'))
        formulas.append((ref, col["FinalImage"], f'=IF({p_col}{{row}}="","",IMAGE({p_col}{{row}}))'))
    print("'NULL' text cleared to blank:", dict(nulls) or "none")
    print("blank values among filled rows:", dict(blanks) or "none")
    print(f"image candidate columns {L(first_url)}..{L(first_url + MAX_CANDIDATES - 1)} | planned: {len(raw)} value cells + {len(formulas)} formula cells")
    if a.write:
        sc.set_text_format(a.tab, c_ref, write=True)
    sc.safe_batch_write(a.tab, raw, key_header=headers[c_ref], write=a.write, label="finish layout")
    sc.safe_batch_write(a.tab, formulas, key_header=headers[c_ref], write=a.write, value_input="USER_ENTERED", label="formulas")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True, help="final refs tab")
    ap.add_argument("--source-tab", help="tab holding the pasted query output (not needed with --in-place)")
    ap.add_argument("--in-place", action="store_true", help="the data is already in H..O of the final-refs tab on the right rows")
    ap.add_argument("--source-col", help="first column letter of the pasted block (if on the same tab)")
    ap.add_argument("--first-url-col", default="X", help="first image-candidate column letter")
    ap.add_argument("--include-flagged", action="store_true", help="also fill rows that have a PartialRefFlag")
    ap.add_argument("--create-headers", action="store_true")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_flag = sc.find_col(headers, "PartialRefFlag", required=False)
    c_id = sc.find_col(headers, "ReferenceNumberId", occurrence=1)

    col = {}
    missing = []
    for key, names in NAMES.items():
        occ = 2 if key == "ReferenceNumberId#2" else 1
        idx = sc.find_col(headers, *names, occurrence=occ, required=False)
        if idx is None:
            missing.append(key)
        else:
            col[key] = idx
    if missing:
        print("missing headers:", missing)
        if not a.create_headers:
            print("re-run with --create-headers to add them at the standard positions "
                  f"({ {k: sc.col_letter(STANDARD[k]) for k in missing} }).")
            sys.exit(1)
        for k in missing:
            col[k] = STANDARD[k]
        sc.write_cells(a.tab, [(f"{sc.col_letter(STANDARD[k])}1", NAMES[k][0]) for k in missing],
                       write=a.write, label="headers")

    first_url = sc.col_index(a.first_url_col)
    if a.in_place:
        return finish_in_place(a, headers, rows, col, c_ref, c_flag, first_url)
    if not a.source_tab:
        sys.exit("give --source-tab, or --in-place if the data is already in the tab")
    src = read_source(a.source_tab, a.source_col)
    print(f"source rows read: {len(src)} from {a.source_tab!r}"
          f"{' starting at ' + a.source_col if a.source_col else ''}")
    if src:
        print("source columns:", sorted(src[0].keys()))
    by_id = {}
    for s in src:
        k = clean(s.get("referencenumberid", ""))
        if k:
            by_id.setdefault(k, []).append(s)
    dup_src = {k: v for k, v in by_id.items() if len(v) > 1}
    by_ref = {}
    for s_ in src:
        rk = sc.norm_ref(clean(s_.get("referencenumber", "")))
        if rk:
            by_ref.setdefault(rk, []).append(s_)
    if by_ref:
        print(f"pasted data also has a ReferenceNumber column ({len(by_ref)} refs): used to match refs that have no RNId")

    targets, no_id, unmatched = [], [], []
    for i, r in enumerate(rows[1:], start=2):
        ref = r[c_ref].strip()
        if not ref:
            continue
        if c_flag is not None and r[c_flag].strip() and not a.include_flagged:
            continue
        rid = clean(r[c_id])
        row_src, via = None, ""
        if rid and rid in by_id:
            row_src, via = by_id[rid][0], "rnid"
        elif sc.norm_ref(ref) in by_ref:
            row_src, via = by_ref[sc.norm_ref(ref)][0], "ref"
        if row_src is None:
            (unmatched if rid else no_id).append(ref)
            continue
        targets.append((ref, rid, row_src, via))

    via_counts = Counter(t[3] for t in targets)
    print(f"matched by ReferenceNumberId: {via_counts.get('rnid', 0)} | matched by ref text: {via_counts.get('ref', 0)}")
    used_ids = {rid for _, rid, _, via in targets if via == "rnid"}
    used_refs = {sc.norm_ref(ref) for ref, _, _, via in targets if via == "ref"}
    unused_src = [k for k in by_id if k not in used_ids and not any(
        sc.norm_ref(clean(x.get("referencenumber", ""))) in used_refs for x in by_id[k])]
    print(f"final-refs rows to fill: {len(targets)} | refs with no RNId and no ref-text match: {len(no_id)} | "
          f"refs with an RNId not in the pasted data: {len(unmatched)} | pasted RNIds matching no ref: {len(unused_src)}")
    if dup_src:
        print(f"WARNING: {len(dup_src)} ReferenceNumberIds appear more than once in the pasted data (first row used): "
              f"{list(dup_src)[:8]}")
    for label, lst in (("no RNId", no_id), ("not in pasted data", unmatched)):
        if lst:
            print(f"   {label} (first 10): {lst[:10]}")
    if unused_src:
        print(f"   pasted RNIds with no ref (first 10): {unused_src[:10]}")

    L = sc.col_letter
    k_col, p_col = L(col["FirstWatchPublishWatchId"]), L(col["FinalImageUrl"])
    writes_raw, writes_formula, blanks = [], [], Counter()
    n = 0
    for ref, rid, s, via in targets:
        n += 1
        vals = {
            "SourceRowId": clean(s.get("sourcerowid", "")) or str(n),
            "ReferenceNumberId#2": rid or clean(s.get("referencenumberid", "")),
            "FirstWatchId": clean(s.get("firstwatchid", "")),
            "FirstWatchPublishWatchId": clean(s.get("firstwatchpublishwatchid", "") or s.get("publishwatchid", "")),
            "DialColor": clean(s.get("dialcolor", "")),
            "CaseMaterial": clean(s.get("casematerial", "")),
            "ModelName": clean(s.get("modelname", "")),
            "Images": clean(s.get("images", "")),
        }
        for key, v in vals.items():
            if key != "SourceRowId" and not v:
                blanks[key] += 1
            writes_raw.append((ref, col[key], v))
        urls = [u.strip() for u in vals["Images"].replace("\n", ",").split(",") if u.strip().lower().startswith("http")]
        for j in range(MAX_CANDIDATES):
            writes_raw.append((ref, first_url + j, urls[j] if j < len(urls) else ""))
        if not urls:
            blanks["image candidates"] += 1
        writes_formula.append((ref, col["SourceLink"],
                               f'=IF({k_col}{{row}}="","","https://everywatch.com/watch/"&{k_col}{{row}})'))
        writes_formula.append((ref, col["FinalImage"], f'=IF({p_col}{{row}}="","",IMAGE({p_col}{{row}}))'))

    print("\nblank fields among filled rows:", dict(blanks) or "none")
    print(f"image candidate columns: {L(first_url)}..{L(first_url + MAX_CANDIDATES - 1)} (up to {MAX_CANDIDATES} URLs)")
    print(f"planned: {len(writes_raw)} value cells + {len(writes_formula)} formula cells")

    if a.write:
        sc.set_text_format(a.tab, c_ref, write=True)
    sc.safe_batch_write(a.tab, writes_raw, key_header=headers[c_ref], write=a.write, label="watch data")
    sc.safe_batch_write(a.tab, writes_formula, key_header=headers[c_ref], write=a.write,
                        value_input="USER_ENTERED", label="formulas")


if __name__ == "__main__":
    main()
