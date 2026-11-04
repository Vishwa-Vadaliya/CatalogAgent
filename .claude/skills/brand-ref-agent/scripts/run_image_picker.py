"""Step 4: run the best-image picker (scripts/pick_best_image.py) for one final-refs tab.

pick_best_image.py takes the tab and column positions as arguments, so nothing is patched or copied.
This wrapper checks the tab first (headers, candidate URLs present), runs the picker, and summarizes
the CSV. Dry run by default (CSV only); --write passes --write to the picker.

usage:
  python run_image_picker.py --tab "X final refs" [--first-url-col X] [--limit 20]
  python run_image_picker.py --tab "X final refs" --write [--skip-unusable]

Without --first-url-col the first candidate column is auto-detected: the first column right of
FinalImageUrl whose cells hold single image URLs (.jpg/.png/.webp ...). The detection is printed.

Tilt gate: best picks that are still fully tilted or sideways are NOT written (--write-tilted writes
them anyway); the count is printed and the references are listed in needs_web.csv. Finding a better
image on the web is the last step: see web_image_fallback.py and steps/04-pick-best-image.md.
"""
import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sheets_client as sc  # noqa: E402

PICKER = HERE / "pick_best_image.py"
RUNS = Path(r"D:\catalog_image_tilt_checker\runs")
N_URLS = 5


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--first-url-col", help="column letter of the first of the 5 candidate URLs (default: auto-detect)")
    ap.add_argument("--key-header", help="header of the column that identifies each row (default: the reference column). "
                    "Use VariationId on a variations tab, where the reference text repeats")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--all-rows", action="store_true", help="ignore the sheet filter and process every row (default: only the visible rows)")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--skip-unusable", action="store_true",
                    help="don't write picks flagged TILTED/HORIZONTAL/NOT_WATCH/UNDETERMINED/DOWNLOAD_ERROR")
    ap.add_argument("--write-tilted", action="store_true",
                    help="also write best picks that are fully tilted / sideways (default: hold them for the web step)")
    ap.add_argument("--tilt-ok-deg", type=float, default=30.0, help="tilt tolerance in degrees (default 30)")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    c_ref = sc.find_col(headers, a.key_header) if a.key_header else sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    r_idx = sc.find_col(headers, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    if a.first_url_col:
        first = sc.col_index(a.first_url_col)
    else:
        img_url = re.compile(r"\.(jpe?g|png|webp|gif|avif)(\?.*)?$", re.I)
        first = None
        for c in range(r_idx + 1, max(len(r) for r in rows)):
            n = sum(1 for r in rows[1:] if c < len(r) and str(r[c]).lower().startswith("http")
                    and "," not in str(r[c]) and img_url.search(str(r[c]).strip()))
            if n:
                first = c
                a.first_url_col = sc.col_letter(c)
                print(f"auto-detected the first candidate column: {a.first_url_col} ({n} image URLs); "
                      f"pass --first-url-col to override")
                break
        if first is None:
            sys.exit("could not find the candidate image columns right of FinalImageUrl - pass --first-url-col")
    has_urls = sum(1 for r in rows[1:] if any(str(r[first + k]).lower().startswith("http") for k in range(N_URLS)))
    print(f"tab {a.tab!r}: ref column {sc.col_letter(c_ref)}; FinalImageUrl = column {sc.col_letter(r_idx)}; "
          f"candidates {sc.col_letter(first)}..{sc.col_letter(first + N_URLS - 1)}; "
          f"rows with URLs: {has_urls} of {len(rows) - 1}")
    if has_urls == 0:
        print("no image URLs found in the candidate columns - run Step 3 first or fix --first-url-col")
        sys.exit(1)
    filled = sum(1 for r in rows[1:] if str(r[r_idx]).lower().startswith("http"))
    print(f"FinalImageUrl already holds a URL in {filled} rows (the picker leaves those alone)")

    out_dir = RUNS / slug(a.tab)
    out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / "pick_results.csv"
    cmd = [sys.executable, str(PICKER), "--tab", a.tab, "--first-url-col", a.first_url_col,
           "--final-col", sc.col_letter(r_idx), "--ref-col", sc.col_letter(c_ref),
           "--out", str(csv_path), "--workers", str(a.workers)]
    if a.limit:
        cmd += ["--limit", str(a.limit)]
    if a.all_rows:
        cmd.append("--all-rows")
    if a.skip_unusable:
        cmd.append("--skip-unusable")
    if a.write_tilted:
        cmd.append("--write-tilted")
    cmd += ["--tilt-ok-deg", str(a.tilt_ok_deg)]
    if a.write:
        cmd.append("--write")
    print("running:", " ".join(cmd[1:]), flush=True)
    rc = subprocess.run(cmd).returncode
    print(f"picker exit code {rc}; outputs in {out_dir}")

    if csv_path.exists():
        with open(csv_path, encoding="utf-8") as fh:
            res = list(csv.DictReader(fh))
        tilted = [r for r in res if r.get("needs_web") == "True"]
        bad = [r for r in res if r["usable"] != "True" and r.get("needs_web") != "True"]
        print(f"\nrows picked: {len(res)}")
        print(f"best picks still COMPLETELY TILTED / SIDEWAYS: {len(tilted)}"
              f"{'' if a.write_tilted else ' (held back, not written)'} -> web fallback needed for these only")
        for r in tilted[:25]:
            print(f"   row {r['row']} {r['ref']}: {r['tilt_status']} ({r['picked_flag']}, {r['picked_angle']} deg) "
                  f"of {r.get('n_candidates', '?')} candidates")
        print(f"other picks not usable (box/not a watch, undetermined, download error): {len(bad)}")
        for r in bad[:25]:
            print(f"   row {r['row']} {r['ref']}: flag={r['picked_flag']} slot={r['picked_slot']}")
        if tilted:
            print(f"\n>>> {len(tilted)} watch(es) have an improper (completely tilted) best image and would need a web "
                  f"search. ASK THE USER whether to go ahead; do not search until they say yes. <<<")
            print(f"list: {out_dir / 'needs_web.csv'} | then: web_image_fallback.py --list")


if __name__ == "__main__":
    main()
