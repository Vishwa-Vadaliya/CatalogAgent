"""Step 1b helper: inventory the *shapes* (structures) of the reference values on a brand tab.

Read-only. Every digit becomes `9`, every letter `A`, separators stay, so `270.8.62` -> `999.9.99` and
`Q2706440` -> `A9999999`. The table shows, per shape: how many unique values, how many rows, examples,
and the first/last separator layout. The agent uses it to make sure the deep brand research covers
**every structure that actually occurs in the data**, and classifies each one as valid format /
not-a-reference / unknown in the brand profile.

usage:
  python ref_structures.py --tab "<source tab>" [--col ReferenceNumber|RawReferenceNumber|FinalRef]
                           [--top 60] [--examples 4] [--out <scratchpad>\\structures.csv]
"""
import argparse
import csv
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402


def shape(v):
    s = re.sub(r"[0-9]", "9", v)
    s = re.sub(r"[A-Za-z]", lambda m: "A" if m.group(0).isupper() else "a", s)
    return s


def collapse(sh):
    """Run-length view: 999999 -> 9{6}, so shapes of different length group visually."""
    return re.sub(r"(.)\1{2,}", lambda m: f"{m.group(1)}{{{len(m.group(0))}}}", sh)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--col", default="ReferenceNumber", help="header of the column to inventory")
    ap.add_argument("--top", type=int, default=60)
    ap.add_argument("--examples", type=int, default=4)
    ap.add_argument("--out", help="CSV with every shape")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    c = sc.find_col(headers, a.col)
    c_w = sc.find_col(headers, "TotalWatchCount", required=False)
    vals = Counter()
    watches = Counter()
    for r in rows[1:]:
        v = str(r[c]).strip() if len(r) > c else ""
        if sc.is_null(v):
            continue
        vals[v] += 1
        if c_w is not None and len(r) > c_w:
            try:
                watches[v] = max(watches[v], int(float(str(r[c_w]).strip() or 0)))
            except ValueError:
                pass

    by_shape = defaultdict(list)
    for v in vals:
        by_shape[shape(v)].append(v)

    print(f"tab {a.tab!r}, column {a.col!r}: {sum(vals.values())} non-empty rows, {len(vals)} unique values, "
          f"{len(by_shape)} distinct structures\n")
    print(f"{'structure':<28}{'unique':>8}{'rows':>8}   examples")
    ordered = sorted(by_shape.items(), key=lambda kv: -sum(vals[v] for v in kv[1]))
    for sh, vs in ordered[:a.top]:
        ex = ", ".join(sorted(vs, key=lambda x: -vals[x])[:a.examples])
        print(f"{collapse(sh):<28}{len(vs):>8}{sum(vals[v] for v in vs):>8}   {ex}")
    if len(ordered) > a.top:
        rest = ordered[a.top:]
        print(f"... {len(rest)} more structures ({sum(len(v) for _, v in rest)} values); use --out for all")

    # things that are very often NOT a reference: pure long digit runs, hashes, spaces, lowercase, joined values
    flags = Counter()
    for v in vals:
        if re.fullmatch(r"\d{8,}", v):
            flags["8+ digit plain number (serial / id?)"] += 1
        if re.fullmatch(r"[0-9a-fA-F]{16,}", v):
            flags["long hex run (hash / GUID?)"] += 1
        if re.search(r"\s|/|,|&|\band\b", v, re.I):
            flags["contains space / slash / comma / AND (joined values?)"] += 1
        if re.search(r"[a-z]", v):
            flags["contains lowercase"] += 1
    print("\nvalues to examine first in the research (possible non-references):")
    for k, n in flags.most_common():
        print(f"  {n:>6}  {k}")

    if a.out:
        with open(a.out, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["structure", "collapsed", "unique_values", "rows", "examples"])
            for sh, vs in ordered:
                w.writerow([sh, collapse(sh), len(vs), sum(vals[v] for v in vs),
                            " | ".join(sorted(vs, key=lambda x: -vals[x])[:10])])
        print(f"\nwrote {a.out}")


if __name__ == "__main__":
    main()
