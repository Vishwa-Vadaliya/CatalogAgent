"""Step 3: prepare the `<brand> final refs Variation` tab from the user's pasted watch-data query output.

The user's query returns every possible variation (dial colour / case material / images ...) of each
reference of the brand, so one reference can have several rows. They paste that output (header row +
data) into a NEW tab. This script does NOT touch the final-refs tab. It only finishes the pasted tab:

  - VariationId         unique per row (V00001 ...), the key every later step finds rows by
                        (the reference text repeats, so it cannot be the key on this tab)
  - VariationStatus     blank until Step 4c (Keep / Duplicate of <id> / Not confirmed ...)
  - VariationNote       reason for the status (Step 4c)
  - FilledNote          where a blank dial / case value came from (Step 4b: image / web / user)
  - FinalImageUrl       filled by the image picker (Step 4)
  - SourceLink          formula, from FirstWatchPublishWatchId
  - FinalImage          =IMAGE(FinalImageUrl) preview formula
  - image candidates    up to 10 URLs from `Images`, one per column, after one blank spacer column
  - the literal text NULL in DialColor / CaseMaterial / ModelName / Images / FirstWatchPublishWatchId
    is cleared to blank

Dry run by default. Rows are written by row number, but only after a second read of the sheet confirms
that every target row still holds the same ReferenceNumber / FirstWatchId as in the first read.

usage:
  python prepare_variations_tab.py --tab "X final refs Variation"
  python prepare_variations_tab.py --tab "X final refs Variation" --write
"""
import argparse
import sys
from collections import Counter

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402

ADDED = ["VariationId", "VariationStatus", "VariationNote", "FilledNote", "FinalImageUrl", "SourceLink", "FinalImage"]
MAX_CANDIDATES = 10
COUNT_NAMES = ["WatchCount", "VariationWatchCount", "VariationCount", "TotalWatchCount", "WatchesCount", "Count"]


def clean(v):
    v = str(v).strip()
    return "" if sc.is_null(v) else v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True, help="the new variations tab holding the pasted query output")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    if not rows:
        sys.exit("tab is empty - paste the query output first")
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_rnid = sc.find_col(headers, "ReferenceNumberId", required=False)
    c_fw = sc.find_col(headers, "FirstWatchId", required=False)
    c_pub = sc.find_col(headers, "FirstWatchPublishWatchId", "PublishWatchId", required=False)
    c_dial = sc.find_col(headers, "DialColor")
    c_case = sc.find_col(headers, "CaseMaterial")
    c_model = sc.find_col(headers, "ModelName", required=False)
    c_img = sc.find_col(headers, "Images")
    c_cnt = sc.find_col(headers, *COUNT_NAMES, required=False)
    print(f"tab {a.tab!r}: {len(rows) - 1} data rows | ref col {sc.col_letter(c_ref)} | "
          f"watch-count column: {headers[c_cnt] if c_cnt is not None else 'NOT FOUND (Step 4c needs one - ask the user which column)'}")
    if c_fw is None or c_pub is None:
        print("note: FirstWatchId / FirstWatchPublishWatchId missing - SourceLink cannot be built for those rows")

    # columns: reuse existing headers, else append after the last pasted header
    last = max((i for i, h in enumerate(headers) if str(h).strip()), default=-1)
    col, new_headers, nxt = {}, [], last + 1
    for name in ADDED:
        idx = sc.find_col(headers, name, "Sourcelink" if name == "SourceLink" else name, required=False)
        if idx is None:
            idx = nxt
            nxt += 1
            new_headers.append((idx, name))
        col[name] = idx
    first_url = max(col.values()) + 2          # one blank spacer column, then the candidates
    L = sc.col_letter
    print(f"added columns: {', '.join(f'{n}={L(col[n])}' for n in ADDED)} | image candidates {L(first_url)}..{L(first_url + MAX_CANDIDATES - 1)}")

    data_rows = [(i + 1, r) for i, r in enumerate(rows) if i > 0 and clean(r[c_ref])]
    existing_ids = {r[col["VariationId"]].strip() for _, r in data_rows if col["VariationId"] < len(r) and r[col["VariationId"]].strip()}
    seq = max([int(x[1:]) for x in existing_ids if x[:1] == "V" and x[1:].isdigit()] or [0])

    raw, formulas, blanks, nulls = [], [], Counter(), Counter()
    per_ref = Counter(clean(r[c_ref]) for _, r in data_rows)
    for rn, r in data_rows:
        cur = r[col["VariationId"]].strip() if col["VariationId"] < len(r) else ""
        if not cur:
            seq += 1
            raw.append((rn, col["VariationId"], f"V{seq:05d}"))
        for key, c in (("DialColor", c_dial), ("CaseMaterial", c_case), ("ModelName", c_model),
                       ("Images", c_img), ("FirstWatchPublishWatchId", c_pub)):
            if c is None:
                continue
            v = r[c]
            if v.strip() and sc.is_null(v):
                raw.append((rn, c, ""))
                nulls[key] += 1
            if sc.is_null(v):
                blanks[key] += 1
        urls = [u.strip() for u in r[c_img].replace("\n", ",").split(",") if u.strip().lower().startswith("http")]
        if not urls:
            blanks["image candidates"] += 1
        for j in range(MAX_CANDIDATES):
            if j < len(urls):
                raw.append((rn, first_url + j, urls[j]))
        if c_pub is not None:
            kc = L(c_pub)
            formulas.append((rn, col["SourceLink"], f'=IF({kc}{rn}="","","https://everywatch.com/watch/"&{kc}{rn})'))
        pc = L(col["FinalImageUrl"])
        formulas.append((rn, col["FinalImage"], f'=IF({pc}{rn}="","",IMAGE({pc}{rn}))'))

    n_refs = len(per_ref)
    dist = Counter(per_ref.values())
    print(f"\nvariation rows: {len(data_rows)} | unique references: {n_refs} | "
          f"rows per reference: {dict(sorted(dist.items())[:12])}{' ...' if len(dist) > 12 else ''}")
    if c_rnid is not None:
        multi = {}
        for _, r in data_rows:
            multi.setdefault(clean(r[c_ref]), set()).add(clean(r[c_rnid]))
        many = [k for k, v in multi.items() if len(v - {''}) > 1]
        if many:
            print(f"WARNING: {len(many)} references carry more than one ReferenceNumberId (report, do not pick): {many[:8]}")
    print("blank values among the rows:", dict(blanks) or "none")
    print("'NULL' text cleared to blank:", dict(nulls) or "none")
    print(f"planned: {len(new_headers)} headers, {len(raw)} value cells, {len(formulas)} formula cells")
    for rn, c, v in raw[:4]:
        print(f"   sample {L(c)}{rn} = {str(v)[:70]!r}   (row holds ref {clean(rows[rn - 1][c_ref])!r})")

    if not a.write:
        print("\ndry run - nothing written (re-run with --write)")
        return

    # second read: every target row must still be the same row
    h2, rows2 = sc.read_tab(a.tab)
    for rn, r in data_rows:
        r2 = rows2[rn - 1] if rn - 1 < len(rows2) else None
        same = r2 is not None and r2[c_ref] == r[c_ref] and (c_fw is None or r2[c_fw] == r[c_fw])
        if not same:
            sys.exit(f"ABORT: row {rn} changed since the first read (the sheet is being edited). Nothing written. Re-run.")
    sc.set_text_format(a.tab, c_ref, write=True)
    sc.set_text_format(a.tab, col["VariationId"], write=True)
    sc.write_cells(a.tab, [(f"{L(i)}1", n) for i, n in new_headers], write=True, label="headers")

    def push(items, mode):
        data = [{"range": f"{sc.q(a.tab)}!{L(c)}{rn}", "values": [[v]]} for rn, c, v in items]
        for i in range(0, len(data), sc.CHUNK):
            sc.service().spreadsheets().values().batchUpdate(
                spreadsheetId=sc.SPREADSHEET_ID, body={"valueInputOption": mode, "data": data[i:i + sc.CHUNK]}).execute(num_retries=5)
        print(f"written {len(data)} cells ({mode})")

    push(raw, "RAW")
    push(formulas, "USER_ENTERED")


if __name__ == "__main__":
    main()
