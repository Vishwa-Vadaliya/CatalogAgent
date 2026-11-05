"""
Pick the most vertical watch image per reference and write its URL into the FinalImageUrl column.

Derived from D:\\catalog_image_tilt_checker\\pick_best_image.py. The picking logic is UNCHANGED:
score(), the CLIP not-watch check, analyse_url(), the min-by-score choice and the rules about which
cells get written are the same. What changed is everything around it:

  * tab, sheet id and column positions are arguments (no editing the script per brand);
  * the ref column and the FinalImageUrl column are found by header name when not given;
  * the sheet is read up to its real row count (the old script silently stopped at row 2500);
  * the output column letter follows --final-col (the old write range was hard-coded to "R");
  * just before writing, every target row is re-checked against the live sheet by its ref text,
    and rows that moved (live sort/filter) are re-located or skipped, never written blindly;
  * labels and the docstring now say what the code does; the backup file is timestamped;
  * opt-in --skip-unusable (default off = old behaviour) leaves TILTED/HORIZONTAL/NOT_WATCH picks
    unwritten; a summary says how many images had a failed CLIP check.

  python pick_best_image.py --tab "<brand> final refs" --first-url-col X            # dry run -> CSV only
  python pick_best_image.py --tab "<brand> final refs" --first-url-col X --write

Which cells are written (same as before):
  * empty / 'NULL' / other non-URL text  -> the best image's URL (not if every candidate failed to
    download);
  * a hand-pick digit 1..5               -> that slot's URL (your pick is kept, now as a URL);
  * a cell that already holds a URL      -> left alone.
"""
import argparse
import csv
import re
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

warn_filter = __import__("warnings")
warn_filter.filterwarnings("ignore", category=FutureWarning)

CHECK_TILT_DIR = Path(r"D:\catalog_image_tilt_checker")
sys.path.insert(0, str(CHECK_TILT_DIR))
from google.auth import default as google_default
from googleapiclient.discovery import build

import cv2
import numpy as np
from PIL import Image

import check_tilt as ct

SHEET_ID = "1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg"
N_URLS = 5
NOT_WATCH_AT = 0.5                         # CLIP probability above which an image counts as box/non-watch
RUNS_DIR = CHECK_TILT_DIR / "runs"


# ----------------------------------------------------------------- picking logic (unchanged)
def score(flag, angle, coh):
    """Lower = better. Upright OK images first, by smallest angle."""
    a = abs(float(angle)) if angle not in ("", None) else 90.0
    if flag in ("OK", "BORDERLINE"):
        return a
    if flag == "TILTED":
        return 100 + a
    if flag == "UNDETERMINED":
        return 200 + a
    return 300 + a                        # HORIZONTAL


_clip = {}
_clip_lock = threading.Lock()
GOOD_PROMPTS = [
    "a product photo of a wristwatch",
    "a close-up photo of a watch dial",
    "a watch worn on a wrist",
    "a watch held in a hand",
    "a luxury watch with a metal bracelet",
    "a watch with a leather strap",
]
BAD_PROMPTS = [
    "a watch box and packaging with warranty booklets and papers",
    "an empty gift box",
    "a stack of documents and papers",
    "a storefront or boutique interior",
    "a logo or text banner",
    "a portrait of a person",
    "a watch movement or loose parts on a table",
]


def not_watch_prob(img_rgb):
    """CLIP zero-shot: probability mass on 'box / papers / non-watch' prompts (0..1)."""
    import open_clip
    import torch
    with _clip_lock:
        if not _clip:
            torch.set_num_threads(2)
            m, _, pre = open_clip.create_model_and_transforms("ViT-B-32", pretrained="laion2b_s34b_b79k")
            m.eval()
            tok = open_clip.get_tokenizer("ViT-B-32")
            with torch.no_grad():
                t = m.encode_text(tok(GOOD_PROMPTS + BAD_PROMPTS))
                t /= t.norm(dim=-1, keepdim=True)
            _clip.update(model=m, pre=pre, text=t)
        with torch.no_grad():
            x = _clip["pre"](Image.fromarray(img_rgb)).unsqueeze(0)
            f = _clip["model"].encode_image(x)
            f /= f.norm(dim=-1, keepdim=True)
            p = (100 * f @ _clip["text"].T).softmax(dim=-1)[0]
    return float(p[len(GOOD_PROMPTS):].sum())


def analyse_url(url):
    try:
        img = ct.load_image(url)
    except Exception as e:
        return dict(url=url, flag="DOWNLOAD_ERROR", angle="", coh="", score=1000.0, note=str(e)[:60])
    try:
        r = ct.analyse(img, 30.0, 45.0)
    except Exception as e:
        return dict(url=url, flag="UNDETERMINED", angle="", coh="", score=900.0, note=str(e)[:60])
    sc = score(r["flag"], r["angle_deg"], r.get("coherence_pct"))
    note = r.get("note", "")
    try:
        small = cv2.cvtColor(cv2.resize(img, (300, int(300 * img.shape[0] / img.shape[1]))), cv2.COLOR_RGB2GRAY)
        if r["flag"] == "UNDETERMINED":
            # tight close-ups have no measurable edges: trust the symmetry check instead
            sym, _ = ct._symmetry_angle(small)
            if abs(sym) <= 15:
                sc = abs(sym)
                note = f"close-up, symmetry says {sym:.1f} deg"
        h, w = small.shape
        ph, pw = max(3, int(0.12 * h)), max(3, int(0.12 * w))
        corners = [small[:ph, :pw], small[:ph, -pw:], small[-ph:, :pw], small[-ph:, -pw:]]
        clean = all(np.median(c) > 200 and c.std() < 25 for c in corners)
        if not clean:
            sc += 8                            # coloured / busy background (hand-held, lifestyle shots)
    except Exception:
        pass
    nw = 0.0
    try:
        nw = not_watch_prob(img)
    except Exception as e:
        note += f" [clip failed: {str(e)[:40]}]"
    flag = r["flag"]
    if nw > NOT_WATCH_AT:
        flag, sc = "NOT_WATCH", sc + 500
        note = f"box/packaging/non-watch p={nw:.2f}"
    return dict(url=url, flag=flag, angle=r["angle_deg"], coh=r.get("coherence_pct", ""),
                score=sc, note=note, nw=round(nw, 2))


# ----------------------------------------------------------------- sheet helpers
def col_letter(i):
    s, n = "", i + 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def col_index(letter):
    n = 0
    for ch in letter.upper():
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def norm_header(h):
    return re.sub(r"[^a-z0-9]", "", str(h).lower())


def find_header(headers, *names):
    targets = {norm_header(n) for n in names}
    for i, h in enumerate(headers):
        if norm_header(h) in targets:
            return i
    return None


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True, help="final refs tab name")
    ap.add_argument("--sheet-id", default=SHEET_ID)
    ap.add_argument("--key", default=None,
                    help="service-account json (optional; default = GOOGLE_APPLICATION_CREDENTIALS)")
    ap.add_argument("--first-url-col", default="X", help="column letter of the first of the 5 candidate URLs")
    ap.add_argument("--final-col", help="column letter to write into (default: found by header FinalImageUrl)")
    ap.add_argument("--ref-col", help="column letter of the reference (default: found by header, else A)")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--skip-unusable", action="store_true",
                    help="do not write picks flagged TILTED / HORIZONTAL / NOT_WATCH / UNDETERMINED / DOWNLOAD_ERROR")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--limit", type=int, help="only the first N references that have images")
    ap.add_argument("--last", type=int, help="only the last N references that have images")
    ap.add_argument("--out", help="results CSV (default: <tilt checker>\\runs\\<tab>\\pick_results.csv)")
    args = ap.parse_args()
    TAB = args.tab
    FIRST_URL_COL = col_index(args.first_url_col)
    out_path = Path(args.out) if args.out else RUNS_DIR / slug(TAB) / "pick_results.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    scopes = ["https://www.googleapis.com/auth/spreadsheets"]
    if args.key:
        from google.oauth2 import service_account
        creds = service_account.Credentials.from_service_account_file(args.key, scopes=scopes)
    else:
        creds, _ = google_default(scopes=scopes)
    sv = build("sheets", "v4", cache_discovery=False, credentials=creds)
    q = "'" + TAB.replace("'", "''") + "'"

    props = [s["properties"] for s in sv.spreadsheets().get(
        spreadsheetId=args.sheet_id, fields="sheets.properties(title,gridProperties)").execute()["sheets"]
        if s["properties"]["title"] == TAB]
    if not props:
        sys.exit(f"tab not found: {TAB!r}")
    nrows = props[0]["gridProperties"]["rowCount"]

    head = sv.spreadsheets().values().get(spreadsheetId=args.sheet_id, range=f"{q}!1:1").execute().get("values", [[]])[0]
    ref_idx = col_index(args.ref_col) if args.ref_col else find_header(head, "Referencenumbers", "ReferenceNumber")
    if ref_idx is None:
        ref_idx = 0
    R = col_index(args.final_col) if args.final_col else find_header(head, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    if R is None:
        sys.exit("FinalImageUrl column not found by header - pass --final-col")
    R_LETTER = col_letter(R)
    last_col = col_letter(max(FIRST_URL_COL + N_URLS - 1, R, ref_idx))
    print(f"tab {TAB!r}: ref column {col_letter(ref_idx)} | candidates {col_letter(FIRST_URL_COL)}.."
          f"{col_letter(FIRST_URL_COL + N_URLS - 1)} | writing to {R_LETTER} ({head[R] if R < len(head) else '?'}) | "
          f"sheet rows: {nrows}", flush=True)

    vals = sv.spreadsheets().values().get(
        spreadsheetId=args.sheet_id, range=f"{q}!A1:{last_col}{nrows}").execute().get("values", [])

    def cell(r, i):
        return str(r[i]).strip() if i < len(r) else ""

    # only the rows left visible by the sheet's filter
    meta = sv.spreadsheets().get(
        spreadsheetId=args.sheet_id, ranges=[f"{q}!A1:A{nrows}"],
        fields="sheets(properties.title,data.rowMetadata)").execute()
    rm = [s for s in meta["sheets"] if s["properties"]["title"] == TAB][0]["data"][0].get("rowMetadata", [])
    visible = {i + 1 for i, m in enumerate(rm) if not m.get("hiddenByFilter") and not m.get("hiddenByUser")}
    print(f"rows visible under your filter: {len(visible) - 1} (excluding header)", flush=True)

    jobs = []                                  # (sheet_row, ref, [urls], current final cell)
    for i, r in enumerate(vals[1:], start=2):
        if i not in visible:
            continue
        urls = [cell(r, FIRST_URL_COL + k) for k in range(N_URLS)]
        urls = [u if u.lower().startswith("http") else "" for u in urls]
        if any(urls):
            jobs.append((i, cell(r, ref_idx), urls, cell(r, R)))
    if args.limit:
        jobs = jobs[:args.limit]
    if args.last:
        jobs = jobs[-args.last:]
    n_empty = sum(1 for j in jobs if not j[3])
    n_digit = sum(1 for j in jobs if j[3].isdigit())
    n_url = sum(1 for j in jobs if j[3].lower().startswith("http"))
    print(f"references with images: {len(jobs)}  | cell empty: {n_empty}  | hand-pick digit: {n_digit}  "
          f"| already a URL: {n_url}  | other text: {len(jobs) - n_empty - n_digit - n_url}", flush=True)

    flat = [(ji, k, u) for ji, j in enumerate(jobs) for k, u in enumerate(j[2]) if u]
    cache = {}
    with ThreadPoolExecutor(args.workers) as ex:
        for n, (key, res) in enumerate(zip(flat, ex.map(lambda t: analyse_url(t[2]), flat)), 1):
            cache[(key[0], key[1])] = res
            if n % 200 == 0:
                print(f"  analysed {n}/{len(flat)}", flush=True)
    if not jobs:
        print("nothing to do")
        return

    rows_out, writes, agree, compared, skipped_unusable = [], [], 0, 0, 0
    for ji, (row_no, ref, urls, cur) in enumerate(jobs):
        cands = [(k, cache[(ji, k)]) for k in range(N_URLS) if urls[k]]
        best_k, best = min(cands, key=lambda c: (c[1]["score"], c[0]))
        usable = best["flag"] in ("OK", "BORDERLINE")
        rows_out.append(dict(row=row_no, ref=ref, current_R=cur, picked_slot=best_k + 1, picked_url=best["url"],
                             picked_flag=best["flag"], picked_angle=best["angle"], usable=usable,
                             all=" | ".join(f"{k + 1}:{c['flag']}:{c['angle']}" for k, c in cands)))
        if cur.isdigit() and 1 <= int(cur) <= N_URLS:
            compared += 1
            hand = cache.get((ji, int(cur) - 1))
            if int(cur) - 1 == best_k or (hand and hand["score"] <= best["score"] + 2):
                agree += 1
        if cur.isdigit() and 1 <= int(cur) <= N_URLS and urls[int(cur) - 1]:
            writes.append((row_no, ref, urls[int(cur) - 1], cur))     # keep your hand pick, now as a URL
        elif not cur.lower().startswith("http") and best["flag"] != "DOWNLOAD_ERROR":
            if args.skip_unusable and not usable:
                skipped_unusable += 1
            else:
                writes.append((row_no, ref, best["url"], cur))

    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows_out[0]))
        w.writeheader()
        w.writerows(rows_out)
    print(f"results -> {out_path}")
    print(f"agreement with your hand picks (same image or within 2 deg): {agree}/{compared}")
    print(f"picked flags: " + str({f: sum(1 for r in rows_out if r['picked_flag'] == f)
                                   for f in sorted({r['picked_flag'] for r in rows_out})}))
    clip_failed = sum(1 for v in cache.values() if "clip failed" in v.get("note", ""))
    if clip_failed:
        print(f"WARNING: the CLIP box/non-watch check failed for {clip_failed} image(s); they were treated as watches")
    print(f"cells to write: {len(writes)} (new picks: {sum(1 for w_ in writes if not w_[3].isdigit())}, "
          f"hand picks converted to URL: {sum(1 for w_ in writes if w_[3].isdigit())})"
          + (f" | unusable picks held back by --skip-unusable: {skipped_unusable}" if args.skip_unusable else ""))

    if args.write and writes:
        # the analysis took minutes: re-read the live sheet and re-locate every target by its ref text
        live = sv.spreadsheets().values().get(
            spreadsheetId=args.sheet_id, range=f"{q}!A1:{last_col}{nrows}").execute().get("values", [])
        pos = {}
        for i, r in enumerate(live[1:], start=2):
            k = cell(r, ref_idx)
            if k:
                pos.setdefault(k, []).append(i)
        final_writes, moved, skipped = [], 0, []
        for row_no, ref, url, old in writes:
            row = row_no
            if cell(live[row_no - 1] if row_no - 1 < len(live) else [], ref_idx) != ref:
                hits = pos.get(ref, [])
                if len(hits) != 1:
                    skipped.append((ref, row_no, "ref moved/ambiguous"))
                    continue
                row = hits[0]
                moved += 1
            cur_now = cell(live[row - 1], R)
            if cur_now != old:
                skipped.append((ref, row, f"cell changed since analysis ({cur_now[:20]!r})"))
                continue
            final_writes.append((row, url, old))
        print(f"re-checked against the live sheet: {len(final_writes)} ok ({moved} re-located by ref text), "
              f"{len(skipped)} skipped")
        for s_ in skipped[:10]:
            print("   skipped:", s_)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = out_path.with_name(f"{R_LETTER}_backup_before_write_{stamp}.csv")
        with open(backup, "w", newline="", encoding="utf-8") as fh:
            bw = csv.writer(fh)
            bw.writerow(["row", "old_value"])
            bw.writerows([(row, old) for row, _, old in final_writes])
        print(f"backup of old cell values -> {backup}")
        data = [{"range": f"{q}!{R_LETTER}{row}", "values": [[url]]} for row, url, _ in final_writes]
        for i in range(0, len(data), 400):
            sv.spreadsheets().values().batchUpdate(
                spreadsheetId=args.sheet_id,
                body={"valueInputOption": "RAW", "data": data[i:i + 400]}).execute()
        print(f"written {len(data)} cells to column {R_LETTER}")


if __name__ == "__main__":
    main()
