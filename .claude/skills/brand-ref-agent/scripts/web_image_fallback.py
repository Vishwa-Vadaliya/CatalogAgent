"""Step 4, last resort: find a non-tilted image on the web for references whose best own image is
still completely tilted (or sideways).

Order of work (do NOT skip ahead): 1. pick_best_image.py / run_image_picker.py picks the best of the
reference's own candidate images. 2. Only references it lists in needs_web.csv (best pick FULLY
TILTED or SIDEWAYS) come here. 3. THE USER IS ASKED FIRST: tell them how many references have an
improper (completely tilted) best image and ask whether to go ahead with the web search; search only
after they say yes. 4. The AGENT then searches the web for those references (web search / fetch
tools, not this script) and writes the candidate image URLs it found into a CSV
(ref,url,source_page). 5. This script checks every candidate with the same tilt and not-a-watch tests
as the picker, rejects small images, picks the best acceptable one per reference, and (with --write)
writes it into FinalImageUrl. It never touches a reference that is not in needs_web.csv.
`--candidates` refuses to run without --user-approved, which the agent passes only after the user
has said yes to the web search.

usage:
  python web_image_fallback.py --tab "X final refs" --list                      # count + context; then ASK THE USER
  python web_image_fallback.py --tab "X final refs" --candidates cands.csv --user-approved          # dry run
  python web_image_fallback.py --tab "X final refs" --candidates cands.csv --user-approved --write

candidates CSV columns: ref, url, source_page   (several rows per ref are fine)

An accepted web image is: downloadable, at least --min-side pixels on its shorter side, flagged OK or
BORDERLINE by the tilt check (slightly tilted is fine), and not a box / non-watch photo. Web images
come from other sites: keep the source_page (it is saved in the results CSV) and tell the user the
image is external.
"""
import argparse
import csv
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sheets_client as sc  # noqa: E402
import pick_best_image as pbi  # noqa: E402  (same scoring, tilt and CLIP checks as the picker)

RUNS = Path(r"D:\catalog_image_tilt_checker\runs")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def read_needs_web(paths):
    """Read one or more needs-web CSVs (needs_web.csv from the picker, needs_web_existing.csv from the audit)."""
    out, byref = [], {}
    for path in paths:
        if not path.exists():
            continue
        with open(path, encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r["ref"] not in byref:
                    r["from_file"] = path.name
                    r["audit_current_R"] = ""
                    byref[r["ref"]] = r
                    out.append(r)
                # a ref listed in the audit file keeps the final-image URL the audit saw, even when the same
                # ref was already listed by the picker's needs_web.csv
                if path.name == "needs_web_existing.csv":
                    byref[r["ref"]]["audit_current_R"] = r.get("current_R", "")
    if not out:
        sys.exit("no needs_web CSV found (or it is empty) - run the picker (needs_web.csv) and/or "
                 "audit_existing_picks.py (needs_web_existing.csv) first")
    return out


def check_candidate(item, min_side):
    ref, url = item["ref"], item["url"]
    res = dict(ref=ref, url=url, source_page=item.get("source_page", ""), flag="", angle="", score="", size="", status="")
    if not url.lower().startswith(("http://", "https://")):
        res["status"] = "rejected: not a URL"
        return res
    try:
        img = pbi.ct.load_image(url)
        h, w = img.shape[:2]
        res["size"] = f"{w}x{h}"
        if min(h, w) < min_side:
            res["status"] = f"rejected: too small (min side {min(h, w)} < {min_side})"
            return res
    except Exception as e:
        res["status"] = f"rejected: download failed ({str(e)[:50]})"
        return res
    a = pbi.analyse_url(url)
    res.update(flag=a["flag"], angle=a["angle"], score=a["score"])
    if a["flag"] in ("OK", "BORDERLINE"):
        res["status"] = "acceptable (" + pbi.tilt_status(a["flag"], a["angle"]).lower() + ")"
    else:
        res["status"] = f"rejected: {pbi.tilt_status(a['flag'], a['angle']).lower()}" + (f" - {a.get('note', '')[:50]}" if a.get("note") else "")
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--key-header", help="header of the unique row key (VariationId on a variations tab; default: the reference column). "
                    "The `ref` column of the candidates CSV then holds those keys")
    ap.add_argument("--needs-web", help="needs_web CSV(s), comma-separated (default: needs_web.csv and "
                                        "needs_web_existing.csv in the tab's run folder)")
    ap.add_argument("--replace-existing", action="store_true",
                    help="allow replacing an existing, completely tilted FinalImageUrl (only references listed in "
                         "needs_web_existing.csv, and only if the cell is unchanged since the audit)")
    ap.add_argument("--list", action="store_true", help="print the references that need a web image, with context")
    ap.add_argument("--candidates", help="CSV with columns ref,url,source_page")
    ap.add_argument("--user-approved", action="store_true",
                    help="the user has been told how many references need a web image and said yes to the web search")
    ap.add_argument("--min-side", type=int, default=400, help="reject images whose shorter side is smaller (default 400)")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--out", help="results CSV (default: web_fallback_results.csv in the tab's run folder)")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    run_dir = RUNS / slug(a.tab)
    paths = [Path(p.strip()) for p in a.needs_web.split(",")] if a.needs_web else [run_dir / "needs_web.csv", run_dir / "needs_web_existing.csv"]
    need = read_needs_web(paths)
    need_refs = {r["ref"] for r in need}
    recorded_cur = {r["ref"]: r["audit_current_R"] for r in need if r.get("audit_current_R")}
    headers, rows = sc.read_tab(a.tab)
    c_ref = sc.find_col(headers, a.key_header) if a.key_header else sc.find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_fin = sc.find_col(headers, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    ctx_cols = {n: sc.find_col(headers, n, required=False) for n in ("ModelName", "DialColor", "CaseMaterial")}
    by_ref = {str(r[c_ref]).strip(): r for r in rows[1:] if len(r) > c_ref}

    if a.list or not a.candidates:
        print(f"{len(need)} reference(s) whose best own image is still completely tilted / sideways "
              f"(web search is the last resort, only for these):")
        print(f"\n>>> ASK THE USER BEFORE SEARCHING: {len(need)} watch(es) have an improper (completely tilted) best "
              f"image and would need a web search. Should I go ahead? Do not search until they say yes. <<<\n")
        for r in need:
            row = by_ref.get(r["ref"], [])
            ctx = {n: (str(row[c]).strip() if c is not None and len(row) > c else "") for n, c in ctx_cols.items()}
            print(f"  {r['ref']:<26} {r['tilt_status']:<13} model={ctx['ModelName'] or '-'} | dial={ctx['DialColor'] or '-'} | case={ctx['CaseMaterial'] or '-'}")
        print("\nOnly after the user says yes: search each one (brand + exact ref, dealer / auction / official pages) for "
              "a straight front view of the dial, save the found image URLs as a CSV: ref,url,source_page, and re-run "
              "with --candidates ... --user-approved.")
        return
    if not a.user_approved:
        sys.exit(f"STOP: {len(need)} reference(s) need a web image. Ask the user first (tell them the count and ask "
                 f"whether to go ahead with the web search). Re-run with --user-approved only after they say yes.")

    with open(a.candidates, encoding="utf-8") as fh:
        cands = [r for r in csv.DictReader(fh) if r.get("ref") and r.get("url")]
    outside = sorted({c["ref"] for c in cands if c["ref"] not in need_refs})
    if outside:
        print(f"IGNORED: {len(outside)} candidate reference(s) not in needs_web.csv (web images are only for fully tilted best "
              f"picks): {outside[:10]}")
    cands = [c for c in cands if c["ref"] in need_refs]
    seen, uniq = set(), []
    for c in cands:
        k = (c["ref"], c["url"].strip())
        if k not in seen:
            seen.add(k)
            uniq.append(dict(c, url=c["url"].strip()))
    print(f"checking {len(uniq)} candidate image(s) for {len({c['ref'] for c in uniq})} reference(s) ...", flush=True)
    with ThreadPoolExecutor(a.workers) as ex:
        results = list(ex.map(lambda c: check_candidate(c, a.min_side), uniq))

    best = {}
    for r in results:
        if r["status"].startswith("acceptable") and (r["ref"] not in best or r["score"] < best[r["ref"]]["score"]):
            best[r["ref"]] = r
    out_path = Path(a.out) if a.out else run_dir / "web_fallback_results.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["ref", "url", "source_page", "flag", "angle", "size", "score", "status", "chosen"])
        w.writeheader()
        for r in results:
            w.writerow(dict(r, chosen=(best.get(r["ref"]) is r)))
    print(f"results -> {out_path}")
    got = set(best)
    no_cand = sorted(need_refs - {c["ref"] for c in uniq})
    none_ok = sorted({c["ref"] for c in uniq} - got)
    print(f"references needing a web image: {len(need_refs)} | with an acceptable web image: {len(got)} | "
          f"candidates found but none acceptable: {len(none_ok)} | no candidate supplied: {len(no_cand)}")
    for ref in sorted(got):
        b = best[ref]
        print(f"   {ref:<26} {b['flag']:<10} {b['angle']} deg  {b['size']}  {b['url'][:70]}")
    if none_ok:
        print("none acceptable (tilted / small / not a watch / download failed):", none_ok[:15])
    if no_cand:
        print("no candidate URL supplied for:", no_cand[:15])

    if a.write and got:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        h2, rows2 = sc.read_tab(a.tab)                       # live re-read right before writing
        live = {str(r[c_ref]).strip(): r for r in rows2[1:] if len(r) > c_ref}
        writes, skipped = [], []
        for ref in sorted(got):
            cur = str(live[ref][c_fin]).strip() if ref in live and len(live[ref]) > c_fin else ""
            if ref not in live:
                skipped.append((ref, "ref not on the tab any more"))
            elif cur.lower().startswith("http") and not (a.replace_existing and ref in recorded_cur and cur == recorded_cur[ref]):
                skipped.append((ref, "FinalImageUrl already holds a URL" + ("" if a.replace_existing else " (use --replace-existing for audited tilted ones)")))
            else:
                writes.append((ref, c_fin, best[ref]["url"]))
        backup = out_path.with_name(f"web_fallback_backup_{stamp}.csv")
        with open(backup, "w", newline="", encoding="utf-8") as fh:
            bw = csv.writer(fh)
            bw.writerow(["ref", "old_value"])
            for ref, _, _ in writes:
                bw.writerow([ref, str(live[ref][c_fin]) if len(live[ref]) > c_fin else ""])
        print(f"skipped: {skipped}" if skipped else "no skips")
        sc.safe_batch_write(a.tab, writes, key_header=headers[c_ref], value_input="RAW", write=True, label="web images")
        print(f"backup of old cell values -> {backup}")
        # the preview column (plain-URL 'FinalImage', read by =image(...)) must follow the new FinalImageUrl
        sc.sync_preview_column(a.tab, [ref for ref, _, _ in writes], write=True, backup_dir=str(out_path.parent))
    elif got:
        print("\ndry run: nothing written. Re-run with --write to put these into FinalImageUrl.")


if __name__ == "__main__":
    main()
