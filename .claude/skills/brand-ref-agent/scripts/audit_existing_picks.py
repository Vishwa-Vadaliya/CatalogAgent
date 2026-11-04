"""Step 4 audit: tilt-check the images that are ALREADY in FinalImageUrl (read-only).

pick_best_image.py only fills empty FinalImageUrl cells and leaves existing URLs alone, so refs that
already have a final image never get a tilt check. This script gives them the same one, so that every
reference in scope has been tilt-checked before any web search is considered.

For each visible reference whose FinalImageUrl holds a URL:
  1. tilt-check that image (same analysis as the picker: UPRIGHT / SLIGHT accepted; FULLY TILTED or
     SIDEWAYS is the problem);
  2. if it is fully tilted or sideways, look for a better image among the reference's OWN candidate
     images first (own images first, web last): if one is acceptable it is listed as
     own_replacement_url;
  3. only if no own candidate is acceptable does the reference go into needs_web_existing.csv, the same
     columns as needs_web.csv, for the web fallback (after asking the user).

Nothing is written to the sheet. Replacing an existing image is always a separate step the user
approves.

usage:
  python audit_existing_picks.py --tab "X final refs" [--first-url-col Y] [--n-candidates 10] [--limit 20]
"""
import argparse
import csv
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sheets_client as sc  # noqa: E402
import pick_best_image as pbi  # noqa: E402

RUNS = Path(r"D:\catalog_image_tilt_checker\runs")
IMG = re.compile(r"\.(jpe?g|png|webp|gif|avif)(\?.*)?$", re.I)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--first-url-col", help="first candidate column letter (default: auto-detect right of FinalImageUrl)")
    ap.add_argument("--n-candidates", type=int, default=10, help="how many candidate columns to look at (default 10)")
    ap.add_argument("--web-flags", default="TILTED,HORIZONTAL")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--out-dir")
    a = ap.parse_args()
    web_flags = {x.strip().upper() for x in a.web_flags.split(",") if x.strip()}

    headers, rows = sc.read_tab(a.tab)
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_fin = sc.find_col(headers, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    g = lambda r, c: str(r[c]).strip() if len(r) > c else ""
    if a.first_url_col:
        first = sc.col_index(a.first_url_col)
    else:
        first = None
        for c in range(c_fin + 1, max(len(r) for r in rows)):
            if any(g(r, c).lower().startswith("http") and "," not in g(r, c) and IMG.search(g(r, c)) for r in rows[1:]):
                first = c
                print(f"auto-detected the first candidate column: {sc.col_letter(c)} (pass --first-url-col to override)")
                break
        if first is None:
            sys.exit("no candidate image columns found - pass --first-url-col")
    vis = sc.visible_row_numbers(a.tab, len(rows))
    jobs = []
    for i, r in enumerate(rows, 1):
        if i == 1 or i not in vis or len(r) <= c_ref or not g(r, c_ref):
            continue
        cur = g(r, c_fin)
        if cur.lower().startswith("http"):
            cands = [g(r, first + k) for k in range(a.n_candidates)]
            cands = [u for u in cands if u.lower().startswith("http") and u != cur]
            jobs.append((i, g(r, c_ref), cur, cands))
    if a.limit:
        jobs = jobs[:a.limit]
    print(f"visible references: {sum(1 for i in vis if i > 1)} | with an existing final image to check: {len(jobs)}", flush=True)
    if not jobs:
        return

    with ThreadPoolExecutor(a.workers) as ex:
        cur_res = list(ex.map(lambda j: pbi.analyse_url(j[2]), jobs))
    out, need_web, own_fix = [], [], []
    todo = [(j, r) for j, r in zip(jobs, cur_res) if r["flag"] in web_flags]
    print(f"existing final images that are completely tilted / sideways: {len(todo)} of {len(jobs)} - "
          f"looking for a better OWN candidate first ...", flush=True)
    cand_res = {}
    flat = [(j[1], u) for j, _ in todo for u in j[3]]
    with ThreadPoolExecutor(a.workers) as ex:
        for (ref, u), res in zip(flat, ex.map(lambda t: pbi.analyse_url(t[1]), flat)):
            cand_res.setdefault(ref, []).append(res)
    for (row, ref, cur, cands), r in zip(jobs, cur_res):
        rec = dict(row=row, ref=ref, picked_flag=r["flag"], picked_angle=r["angle"],
                   tilt_status=pbi.tilt_status(r["flag"], r["angle"]), n_candidates=len(cands), picked_url=cur,
                   current_R=cur, own_replacement_url="", own_replacement_flag="")
        if r["flag"] in web_flags:
            good = [c for c in cand_res.get(ref, []) if c["flag"] in ("OK", "BORDERLINE")]
            if good:
                b = min(good, key=lambda c: c["score"])
                rec.update(own_replacement_url=b["url"], own_replacement_flag=f"{b['flag']} {b['angle']}")
                own_fix.append(rec)
            else:
                need_web.append(rec)
        out.append(rec)

    d = Path(a.out_dir) if a.out_dir else RUNS / slug(a.tab)
    d.mkdir(parents=True, exist_ok=True)
    fields = list(out[0])
    with open(d / "audit_existing.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(out)
    nf = ["row", "ref", "picked_flag", "picked_angle", "tilt_status", "n_candidates", "picked_url", "current_R"]
    with open(d / "needs_web_existing.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=nf)
        w.writeheader()
        for r in need_web:
            w.writerow({k: r[k] for k in nf})
    bands = {}
    for r in out:
        bands[r["tilt_status"]] = bands.get(r["tilt_status"], 0) + 1
    print("\nexisting final images by tilt: " + str(bands))
    print(f"COMPLETELY TILTED / SIDEWAYS existing final images: {len(todo)}")
    print(f"   a better own candidate exists for: {len(own_fix)}  (listed as own_replacement_url, not applied)")
    print(f"   no acceptable own candidate, would need a web image: {len(need_web)}")
    print(f"results -> {d / 'audit_existing.csv'}")
    if need_web:
        print(f"web list -> {d / 'needs_web_existing.csv'}")
        print(f"\n>>> {len(need_web)} watch(es) have a completely tilted final image and no better own image. ASK THE USER "
              f"before any web search. <<<")


if __name__ == "__main__":
    main()
