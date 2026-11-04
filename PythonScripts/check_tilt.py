"""
Catalog image tilt checker
==========================
Reads image URLs from the "Catalog Images tilted" Google Sheet (or a local CSV),
downloads each image, measures how far the watch's long axis is from vertical,
and flags the ones that are NOT properly vertical.

Flags
-----
OK            watch is within --tolerance degrees (default 30) of vertical -> "best" image
TILTED        rotated more than --tolerance AND the symmetry check agrees it is not upright
BORDERLINE    edge method says tilted but the symmetry check says upright (mesh bracelet,
              curved case...): check by eye - NOT counted as improper
HORIZONTAL    watch lies sideways
UNDETERMINED  couldn't find a clear watch (very low contrast / empty / round crop)
DOWNLOAD_ERROR  image could not be fetched or decoded

How it measures
---------------
1. Edge method: strong edges vote with their direction modulo 90 deg -> rotation from vertical.
2. Symmetry method (second opinion): the rotation that makes the picture most left-right
   symmetric. Used only to veto false TILTED calls, e.g. woven bracelets.
3. Sideways check: after de-rotating, edge content wider than tall -> HORIZONTAL.
Default tolerance 30 deg was set from review of the first 550 rows: angled brand shots up to
~28 deg (Richard Mille, desk clock) were judged fine, real problems measured 33 deg or more.

Outputs (in --out, default D:\\catalog_image_tilt_checker\\output)
-------
results.csv            every image with flag + angle   (resumable: re-running skips done rows)
flagged.csv            only the images that are not OK
best_images.csv        only the OK images
previews/              annotated thumbnails of flagged images (axis line drawn on top)
report.html            visual gallery of flagged images, worst first

Usage
-----
  # from the Google Sheet (service account key):
  python check_tilt.py --key "C:\\Users\\user\\Downloads\\quiet-radius-509511-c5-521e04a3da8b.json"

  # quick test on 200 rows:
  python check_tilt.py --key "..." --limit 200

  # from a local CSV that has 'catalogid' and 'primaryimageurl' columns:
  python check_tilt.py --csv rows.csv

  # check single files / URLs:
  python check_tilt.py --images some.jpg https://.../x.webp
"""
import argparse
import csv
import html
import io
import math
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import cv2
import numpy as np
import requests
from PIL import Image

SHEET_ID = "1uys6ktk31Lo3SGUSuX4UR6NyLMx0-n7FEG_-AuKXvo0"
ID_COL = "catalogid"
URL_COL = "primaryimageurl"
HORIZONTAL_EXTENT_RATIO = 1.33  # edge content this much wider than tall => watch lies on its side (set from reviewed rows: false flag 1.27, confirmed >= 1.37)
ANALYSIS_SIZE = 700  # longest side used for analysis (speed)

FIELDS = ["catalogid", "manufacturername", "referencenumber", "url",
          "flag", "angle_deg", "sym_angle_deg", "coherence_pct", "extent_ratio", "note"]


# --------------------------------------------------------------------------- #
# Image analysis
# --------------------------------------------------------------------------- #
def _sobel(gray):
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    return gx, gy, np.hypot(gx, gy)


def _symmetry_angle(gray):
    """Second opinion on the tilt: find the rotation that makes the picture most left-right symmetric.

    Works on the edge-strength map, centre-weighted so corner stamps/logos matter little.
    Unlike the edge-direction vote it is not fooled by mesh/woven bracelets or curved cases.
    Returns (angle_deg, score); + = clockwise on screen, same convention as theta.
    """
    sc = 256.0 / max(gray.shape)
    small = cv2.resize(gray, (int(gray.shape[1] * sc), int(gray.shape[0] * sc)), interpolation=cv2.INTER_AREA)
    small = cv2.GaussianBlur(small, (3, 3), 0)
    _, _, E = _sobel(small)
    E = np.minimum(E, np.percentile(E, 99))
    h, w = E.shape
    yy, xx = np.mgrid[0:h, 0:w]
    win = np.exp(-(((xx - w / 2) / (0.38 * w)) ** 2 + ((yy - h / 2) / (0.45 * h)) ** 2) / 2)
    E = (E * win).astype(np.float32)
    xs_ = np.arange(w, dtype=np.float32)

    def score(alpha):
        M = cv2.getRotationMatrix2D((w / 2, h / 2), alpha, 1.0)
        R = cv2.warpAffine(E, M, (w, h), flags=cv2.INTER_LINEAR, borderValue=0)
        col = R.sum(axis=0)
        if col.sum() <= 0:
            return -1.0
        tx = w / 2 - float((col * xs_).sum() / col.sum())          # put the mass centroid on the centre column
        R = cv2.warpAffine(R, np.float32([[1, 0, tx], [0, 1, 0]]), (w, h), flags=cv2.INTER_LINEAR, borderValue=0)
        R = R - R.mean()
        F = R[:, ::-1]
        d = float((R * R).sum())
        return float((R * F).sum() / d) if d > 0 else -1.0

    best = max(np.arange(-50, 50.1, 2.0), key=score)
    best = max(np.arange(best - 2, best + 2.1, 0.5), key=score)
    return float(best), score(best)


def analyse(img_rgb, tolerance, horizontal_at, sym_veto=15.0):
    """Return dict(flag, angle_deg, n_lines, foreground_pct, note, geom).

    1. Tilt: every strong edge pixel votes with its gradient direction, taken modulo 90 degrees
       (so vertical and horizontal edges - strap sides and bracelet links - agree). Curved edges
       (round case, dial) average out. The result is the angle the watch is rotated away from
       the nearest axis.  Column 'n_lines' stores the vote coherence in percent.
    2. Sideways check: after de-rotating, long VERTICAL edges (strap sides) should outnumber long
       HORIZONTAL edges. If not, the watch lies on its side -> HORIZONTAL.
    """
    h, w = img_rgb.shape[:2]
    scale = ANALYSIS_SIZE / max(h, w)
    if scale < 1:
        img_rgb = cv2.resize(img_rgb, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
        h, w = img_rgb.shape[:2]
    m = max(h, w)
    gray = cv2.GaussianBlur(cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY), (3, 3), 0)

    gx, gy, mag = _sobel(gray)
    pad = max(3, int(0.015 * m))
    valid = np.zeros_like(mag, bool)
    valid[pad:-pad, pad:-pad] = True
    thr = np.percentile(mag[valid], 92)
    sel = valid & (mag > max(thr, 20))
    if sel.sum() < 200:
        return dict(flag="UNDETERMINED", angle_deg="", coherence_pct="", extent_ratio="",
                    note="almost no edges (blank / low contrast)", geom=None)
    phi = np.arctan2(gy[sel], gx[sel])
    wt = mag[sel]
    z = np.sum(wt * np.exp(4j * phi))
    coh = abs(z) / wt.sum()
    theta = math.degrees(np.angle(z) / 4)          # in (-45, 45]; + = clockwise on screen
    geom = dict(cx=0.5, cy=0.5, length=0.4, ang=theta)
    if coh < 0.12:
        return dict(flag="UNDETERMINED", angle_deg=round(theta, 2), coherence_pct=round(100 * coh, 1),
                    extent_ratio="", note="no dominant straight edges (round close-up / coiled?)", geom=geom)

    # sideways check on the de-rotated image
    M = cv2.getRotationMatrix2D((w / 2, h / 2), theta, 1.0)   # +angle = CCW, undoes a clockwise tilt
    rot = cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    rx, ry, rmag = _sobel(rot)
    rsel = rmag > max(np.percentile(rmag[valid], 92), 20)
    ys, xs = np.nonzero(rsel & valid)
    ext_x = np.percentile(xs, 95) - np.percentile(xs, 5)
    ext_y = np.percentile(ys, 95) - np.percentile(ys, 5)
    ratio = ext_x / max(ext_y, 1)

    if ratio > HORIZONTAL_EXTENT_RATIO:
        ang = theta + 90 if theta <= 0 else theta - 90
        geom["ang"] = ang
        return dict(flag="HORIZONTAL", angle_deg=round(ang, 2), coherence_pct=round(100 * coh, 1),
                    extent_ratio=round(ratio, 2), note="content wider than tall", geom=geom)

    sym, sym_score = _symmetry_angle(gray)
    geom["sym"] = sym
    note = ""
    if abs(theta) <= tolerance:
        flag = "OK"
    elif abs(sym) <= sym_veto:
        flag = "BORDERLINE"      # edges say tilted, symmetry says upright (mesh bracelet / curved case): check by eye
        note = f"edge method {theta:.1f} deg but symmetry says {sym:.1f} deg"
    else:
        flag = "TILTED"
    return dict(flag=flag, angle_deg=round(theta, 2), coherence_pct=round(100 * coh, 1),
                extent_ratio=round(ratio, 2), sym_angle_deg=round(sym, 2), note=note, geom=geom)


def draw_preview(img_rgb, geom, flag, angle, out_path, size=420):
    h, w = img_rgb.shape[:2]
    s = size / max(h, w)
    im = cv2.resize(img_rgb, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)
    ph, pw = im.shape[:2]
    if geom:
        cx, cy = geom["cx"] * pw, geom["cy"] * ph
        L = geom["length"] * max(ph, pw)
        t = math.radians(geom["ang"])
        dx, dy = math.sin(t) * L, math.cos(t) * L
        cv2.line(im, (int(cx - dx), int(cy - dy)), (int(cx + dx), int(cy + dy)), (255, 40, 40), 2)
        if "sym" in geom:
            ts = math.radians(geom["sym"])
            cv2.line(im, (int(cx - math.sin(ts) * L), int(cy - math.cos(ts) * L)),
                     (int(cx + math.sin(ts) * L), int(cy + math.cos(ts) * L)), (255, 200, 0), 1)  # symmetry axis
        cv2.line(im, (int(cx), 0), (int(cx), ph), (40, 220, 40), 1)  # true vertical reference
    cv2.rectangle(im, (0, 0), (pw, 24), (0, 0, 0), -1)
    cv2.putText(im, f"{flag}  {angle}deg", (6, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
    Image.fromarray(im).save(out_path, quality=85)


# --------------------------------------------------------------------------- #
# Input
# --------------------------------------------------------------------------- #
def rows_from_sheet(key_path):
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=["https://www.googleapis.com/auth/spreadsheets.readonly"])
    svc = build("sheets", "v4", credentials=creds, cache_discovery=False)
    meta = svc.spreadsheets().get(spreadsheetId=SHEET_ID).execute()
    tab = meta["sheets"][0]["properties"]["title"]
    vals = svc.spreadsheets().values().get(spreadsheetId=SHEET_ID, range=f"'{tab}'").execute().get("values", [])
    header = [c.strip().lower() for c in vals[0]]
    out = []
    for r in vals[1:]:
        r = r + [""] * (len(header) - len(r))
        out.append(dict(zip(header, r)))
    return out


def rows_from_csv(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return [{k.strip().lower(): v for k, v in row.items()} for row in csv.DictReader(f)]


# --------------------------------------------------------------------------- #
# Worker
# --------------------------------------------------------------------------- #
_local = threading.local()


def session():
    if not hasattr(_local, "s"):
        _local.s = requests.Session()
    return _local.s


def load_image(src):
    if src.lower().startswith(("http://", "https://")):
        import time
        for attempt in range(3):
            try:
                r = session().get(src, timeout=30, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36"})
                r.raise_for_status()
                break
            except requests.RequestException:
                if attempt == 2:
                    raise
                time.sleep(1.5 * (attempt + 1))
        data = r.content
    else:
        data = Path(src).read_bytes()
    im = Image.open(io.BytesIO(data))
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))  # flatten transparency onto white
    return np.array(Image.alpha_composite(bg, im).convert("RGB"))


def process(row, args, preview_dir):
    url = (row.get(URL_COL) or "").strip()
    base = {"catalogid": row.get(ID_COL, ""), "manufacturername": row.get("manufacturername", ""),
            "referencenumber": row.get("referencenumber", ""), "url": url}
    if not url or url.upper() == "NULL":
        return {**base, "flag": "DOWNLOAD_ERROR", "angle_deg": "", "coherence_pct": "",
                "extent_ratio": "", "note": "no image url"}
    try:
        img = load_image(url)
    except Exception as e:  # noqa: BLE001
        return {**base, "flag": "DOWNLOAD_ERROR", "angle_deg": "", "coherence_pct": "",
                "extent_ratio": "", "note": str(e)[:150]}
    res = analyse(img, args.tolerance, args.horizontal_at, args.sym_veto)
    if res["flag"] != "OK" and not args.no_previews:
        name = f"{res['flag']}_{str(base['catalogid'] or abs(hash(url)))}.jpg"
        try:
            draw_preview(img, res["geom"], res["flag"], res["angle_deg"], preview_dir / name)
            res["note"] = (res["note"] + " " if res["note"] else "") + f"preview={name}"
        except Exception:  # noqa: BLE001
            pass
    res.pop("geom")
    return {**base, **res}


# --------------------------------------------------------------------------- #
# Output
# --------------------------------------------------------------------------- #
def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def write_report(path, flagged):
    def sev(r):
        try:
            return -abs(float(r["angle_deg"]))
        except ValueError:
            return 0
    cards = []
    for r in sorted(flagged, key=sev)[:2000]:
        pv = ""
        if "preview=" in r["note"]:
            pv = r["note"].split("preview=")[1].split()[0]
        cards.append(
            f'<div class="c"><img loading="lazy" src="previews/{html.escape(pv)}">'
            f'<div><b>{html.escape(r["flag"])}</b> {html.escape(str(r["angle_deg"]))}&deg;<br>'
            f'{html.escape(r["manufacturername"])} {html.escape(r["referencenumber"])}<br>'
            f'id {html.escape(str(r["catalogid"]))} &middot; <a href="{html.escape(r["url"])}">source</a></div></div>')
    Path(path).write_text(
        "<!doctype html><meta charset=utf-8><title>Tilted catalog images</title>"
        "<style>body{font:14px sans-serif;background:#111;color:#eee;margin:16px}"
        ".g{display:flex;flex-wrap:wrap;gap:12px}.c{width:210px}.c img{width:210px;border-radius:4px}a{color:#8cf}</style>"
        f"<h2>{len(flagged)} flagged images (worst first, red line = watch axis, green = true vertical)</h2>"
        f'<div class="g">{"".join(cards)}</div>', encoding="utf-8")


# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", help="service-account JSON key (reads the Google Sheet)")
    ap.add_argument("--csv", help="local CSV with catalogid / primaryimageurl columns instead of the sheet")
    ap.add_argument("--images", nargs="+", help="check specific files/URLs directly")
    ap.add_argument("--out", default=r"D:\catalog_image_tilt_checker\output")
    ap.add_argument("--tolerance", type=float, default=30.0, help="max degrees off vertical still counted OK (default 30)")
    ap.add_argument("--sym-veto", type=float, default=15.0, help="if the symmetry check says the watch is within this many degrees of upright, a TILTED call becomes BORDERLINE (default 15)")
    ap.add_argument("--horizontal-at", type=float, default=45.0, help="beyond this angle = HORIZONTAL (default 45)")
    ap.add_argument("--workers", type=int, default=16)
    ap.add_argument("--offset", type=int, default=0, help="skip the first N data rows")
    ap.add_argument("--limit", type=int, help="only process N rows (after --offset)")
    ap.add_argument("--no-previews", action="store_true")
    ap.add_argument("--fresh", action="store_true", help="ignore earlier results.csv and start over")
    args = ap.parse_args()

    out = Path(args.out)
    preview_dir = out / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    if args.images:
        rows = [{ID_COL: Path(s).name, URL_COL: s} for s in args.images]
    elif args.csv:
        rows = rows_from_csv(args.csv)
    elif args.key:
        print("Reading Google Sheet ...")
        rows = rows_from_sheet(args.key)
    else:
        ap.error("give --key, --csv or --images")
    rows = rows[args.offset:]
    if args.limit:
        rows = rows[:args.limit]

    results_path = out / "results.csv"
    done = {}
    if results_path.exists() and not args.fresh and not args.images:
        done = {(r["catalogid"], r["url"]): r for r in rows_from_csv(results_path)}
        print(f"Resuming: {len(done)} rows already processed")
    todo = [r for r in rows if (r.get(ID_COL, ""), (r.get(URL_COL) or "").strip()) not in done]
    print(f"{len(rows)} rows, {len(todo)} to process")

    results = list(done.values())
    with ThreadPoolExecutor(args.workers) as ex:
        futs = [ex.submit(process, r, args, preview_dir) for r in todo]
        for i, f in enumerate(as_completed(futs), 1):
            results.append(f.result())
            if i % 200 == 0:
                print(f"  {i}/{len(todo)}")
                write_csv(results_path, results)  # checkpoint so a crash loses little

    write_csv(results_path, results)
    flagged = [r for r in results if r["flag"] != "OK"]
    best = [r for r in results if r["flag"] == "OK"]
    write_csv(out / "flagged.csv", flagged)
    write_csv(out / "best_images.csv", best)
    write_report(out / "report.html", [r for r in flagged if r["flag"] in ("TILTED", "BORDERLINE", "HORIZONTAL", "UNDETERMINED")])

    counts = {}
    for r in results:
        counts[r["flag"]] = counts.get(r["flag"], 0) + 1
    print("\nSummary:", counts)
    print(f"Best (upright) images : {len(best)}")
    print(f"Flagged (not proper)  : {len(flagged)}")
    print(f"Output folder         : {out}")
    if args.images:
        for r in results:
            print(f"  {r['flag']:<14} angle={r['angle_deg']:<7} {r['url']} {r['note']}")


if __name__ == "__main__":
    sys.exit(main())
