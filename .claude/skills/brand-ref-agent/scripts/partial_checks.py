"""Step 2 (workflow Step 5): duplicate / partial / catalog checks on a final-refs tab.

Dry run by default: prints findings per type and writes a full CSV. Nothing is written to the
sheet unless --apply is given, and then only for the --types you list, and only into blank
PartialRefFlag cells.

usage:
  python partial_checks.py --tab "Jacob&co. final refs" [--catalog "Sheet4:M"] [--out findings.csv]
  python partial_checks.py --tab "..." --apply --types normalized_duplicate,last_separator --style sentences
"""
import argparse
import csv
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
import sheets_client as sc  # noqa: E402

SEP = re.compile(r"[.\-/ ]")
APPLICABLE = {"normalized_duplicate", "prefix", "last_separator", "embedded", "front_truncation",
              "short_full_form", "catalog_exact", "catalog_short_full", "final_base_of_catalog",
              "catalog_base_of_final"}
REPORT_ONLY = {"many_prefix", "hamming1"}


def base_through_last_sep(s):
    m = list(SEP.finditer(s))
    if not m:
        return None, s
    i = m[-1].end()
    return s[:i], s[i:]


def flag_text(kind, other, style):
    if style == "sentences":
        return {
            "normalized_duplicate": f"Duplicate of {other}",
            "prefix": f"Partial - full ref present: {other}",
            "last_separator": f"Partial - full ref present: {other}",
            "embedded": f"Partial - full ref present: {other}",
            "front_truncation": f"Partial - full ref present: {other}",
            "short_full_form": f"Partial - full ref present: {other}",
            "catalog_exact": f"Already in catalog (Sheet4: '{other}')",
            "catalog_short_full": f"Already in catalog (Sheet4: '{other}')",
            "final_base_of_catalog": f"Partial - full ref in catalog (Sheet4: '{other}')",
            "catalog_base_of_final": f"Base ref {other} already present in catalog (Sheet4) as partial",
        }[kind]
    return {
        "normalized_duplicate": "Duplicate",
        "prefix": "Partial",
        "last_separator": "Partial",
        "embedded": "Partial",
        "front_truncation": "Partial",
        "short_full_form": "Partial",
        "catalog_exact": f"Already in catalog (Sheet4: '{other}')",
        "catalog_short_full": f"Already in catalog (Sheet4: '{other}')",
        "final_base_of_catalog": "Partial",
        "catalog_base_of_final": f"Base ref {other} already present in catalog (Sheet4) as partial",
    }[kind]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True, help="final refs tab")
    ap.add_argument("--catalog", help="Sheet4 column, e.g. Sheet4:M  (tab:COLUMN_LETTER)")
    ap.add_argument("--include-flagged", action="store_true", help="also treat already-flagged refs as candidates (regression check)")
    ap.add_argument("--min-len", type=int, default=4, help="ignore refs shorter than this (normalized)")
    ap.add_argument("--examples", type=int, default=8)
    ap.add_argument("--out", help="CSV path for all findings")
    ap.add_argument("--apply", action="store_true", help="write flags (needs --types)")
    ap.add_argument("--types", default="", help="comma list of finding types to apply")
    ap.add_argument("--style", choices=["tags", "sentences"], help="flag wording (required with --apply)")
    ap.add_argument("--add-flag-col", action="store_true", help="with --apply: insert PartialRefFlag if missing")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    c_ref = sc.find_col(headers, "Referencenumbers", "ReferenceNumber", "FinalRef")
    c_flag = sc.find_col(headers, "PartialRefFlag", required=False)
    c_rnid = sc.find_col(headers, "ReferenceNumberId", required=False)
    data = list(enumerate(rows[1:], start=2))

    refs = []
    for rn, r in data:
        raw = r[c_ref].strip()
        if not raw:
            continue
        flag = r[c_flag].strip() if c_flag is not None else ""
        has_id = c_rnid is not None and not sc.is_null(r[c_rnid])
        refs.append({"row": rn, "raw": raw, "norm": sc.norm_ref(raw), "flag": flag, "has_id": has_id})

    print(f"tab: {a.tab} | refs: {len(refs)} | key column: {headers[c_ref]!r} | "
          f"flag column: {'col ' + sc.col_letter(c_flag) if c_flag is not None else 'MISSING'}")
    print("existing flag values:", Counter(x["flag"] for x in refs if x["flag"]).most_common(10))

    clean = [x for x in refs if (a.include_flagged or not x["flag"]) and len(x["norm"]) >= a.min_len]
    print(f"refs compared ({'all' if a.include_flagged else 'unflagged only'}): {len(clean)}")
    findings = []  # dict(kind, row, ref, other, note)

    def add(kind, x, other, note=""):
        findings.append({"kind": kind, "row": x["row"], "ref": x["raw"], "other": other, "note": note})

    # normalized duplicates
    groups = defaultdict(list)
    for x in clean:
        groups[x["norm"]].append(x)
    dup_rows = set()
    for k, g in groups.items():
        if len(g) > 1:
            g.sort(key=lambda x: (-len(SEP.findall(x["raw"])), x["raw"]))
            keep = g[0]
            for x in g[1:]:
                add("normalized_duplicate", x, keep["raw"])
                dup_rows.add(x["row"])

    uniq = {k: g[0] for k, g in groups.items()}
    norms = sorted(uniq)
    prefix_counts = Counter()
    for a_n in norms:
        xa = uniq[a_n]
        if xa["row"] in dup_rows:
            continue
        longer = [b for b in norms if b != a_n and b.startswith(a_n)]
        for b in longer:
            prefix_counts[a_n] += 1
        if longer:
            kind = "many_prefix" if len(longer) >= 3 else "prefix"
            add(kind, xa, uniq[min(longer, key=len)]["raw"], f"prefix of {len(longer)} ref(s)")

        # last-separator (placeholder final segment)
        base, last = base_through_last_sep(xa["raw"])
        if base and len(SEP.findall(base)) >= 3 and len(sc.norm_ref(last)) <= 2:
            for b in norms:
                if b == a_n:
                    continue
                xb = uniq[b]
                bb, bl = base_through_last_sep(xb["raw"])
                if bb and bb.upper() == base.upper() and len(sc.norm_ref(bl)) > len(sc.norm_ref(last)) \
                        and not b.startswith(a_n):
                    add("last_separator", xa, xb["raw"], f"same base '{base}', last '{last}' vs '{bl}'")
                    break

        if len(a_n) >= 5:
            for b in norms:
                if b == a_n or len(b) <= len(a_n):
                    continue
                if b.endswith(a_n):
                    diff = b[: len(b) - len(a_n)]
                    kind = "short_full_form" if len(diff) <= 3 and diff.isalpha() else "front_truncation"
                    add(kind, xa, uniq[b]["raw"], f"extra leading '{diff}'")
                    break
            for b in norms:
                if b == a_n or len(b) <= len(a_n):
                    continue
                i = b.find(a_n)
                if 0 < i and not b.endswith(a_n):
                    add("embedded", xa, uniq[b]["raw"], f"found inside at position {i}")
                    break

    # hamming-1 (report only)
    by_len = defaultdict(list)
    for n in norms:
        by_len[len(n)].append(n)
    seen = set()
    skipped_h1 = 0
    for L, lst in by_len.items():
        for i, n1 in enumerate(lst):
            for n2 in lst[i + 1:]:
                if sum(c1 != c2 for c1, c2 in zip(n1, n2)) == 1 and (n1, n2) not in seen:
                    seen.add((n1, n2))
                    x1, x2 = uniq[n1], uniq[n2]
                    if x1["has_id"] and x2["has_id"]:
                        skipped_h1 += 1
                        continue
                    note = f"RNId: {'set' if x1['has_id'] else 'NULL'} / {'set' if x2['has_id'] else 'NULL'}"
                    add("hamming1", x1, x2["raw"], note)

    print(f"hamming1: {skipped_h1} pairs where BOTH refs have a ReferenceNumberId were skipped (both confirmed)")

    # catalog cross-check
    if a.catalog:
        ctab, cletter = a.catalog.split(":")
        cvals = sc.get_values(ctab, f"{cletter}1:{cletter}")
        cat = [r[0].strip() for r in cvals[1:] if r and r[0].strip()]
        print(f"catalog column {a.catalog}: {len(cat)} refs (header {cvals[0][0] if cvals and cvals[0] else '?'!r})")
        catn = {sc.norm_ref(c): c for c in cat}
        for x in clean:
            n = x["norm"]
            if n in catn:
                add("catalog_exact", x, catn[n])
                continue
            hit = next((c for cn, c in catn.items() if cn.endswith(n) and 0 < len(cn) - len(n) <= 3 and cn[:len(cn) - len(n)].isalpha()), None) \
                or next((c for cn, c in catn.items() if n.endswith(cn) and 0 < len(n) - len(cn) <= 3 and n[:len(n) - len(cn)].isalpha()), None)
            if hit:
                add("catalog_short_full", x, hit)
                continue
            pre = next((c for cn, c in catn.items() if cn.startswith(n) and cn != n), None)
            if pre:
                add("final_base_of_catalog", x, pre)
                continue
            base_of = next((c for cn, c in catn.items() if n.startswith(cn) and cn != n and len(cn) >= a.min_len), None)
            if base_of:
                add("catalog_base_of_final", x, base_of)

    # report
    by_kind = defaultdict(list)
    for f in findings:
        by_kind[f["kind"]].append(f)
    print("\n=== findings ===")
    for kind in ["normalized_duplicate", "prefix", "many_prefix", "last_separator", "front_truncation",
                 "short_full_form", "embedded", "hamming1", "catalog_exact", "catalog_short_full",
                 "final_base_of_catalog", "catalog_base_of_final"]:
        lst = by_kind.get(kind, [])
        tag = " (report only)" if kind in REPORT_ONLY else ""
        print(f"\n{kind}{tag}: {len(lst)}")
        for f in lst[: a.examples]:
            print(f"   row {f['row']}: {f['ref']!r} -> {f['other']!r}  {f['note']}")
    if a.out:
        with open(a.out, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=["kind", "row", "ref", "other", "note"])
            w.writeheader()
            w.writerows(findings)
        print(f"\nall findings -> {a.out}")

    if not a.apply:
        print("\ndry run - nothing written. Review, then re-run with --apply --types ... --style ...")
        return

    types = {t.strip() for t in a.types.split(",") if t.strip()}
    bad = types - APPLICABLE
    if not types or bad or not a.style:
        print(f"--apply needs --types from {sorted(APPLICABLE)} (got {sorted(types)}; invalid: {sorted(bad)}) and --style")
        sys.exit(1)
    if c_flag is None:
        if not a.add_flag_col:
            print("PartialRefFlag column is missing; re-run with --add-flag-col to insert it after the ref column.")
            sys.exit(1)
        c_flag = c_ref + 1
        sc.insert_column(a.tab, c_flag, write=True)
        sc.write_cells(a.tab, [(f"{sc.col_letter(c_flag)}1", "PartialRefFlag")], write=True, label="header")
        sc.set_text_format(a.tab, c_flag, write=True)

    chosen = {}
    for f in findings:
        if f["kind"] in types and f["ref"] not in chosen:
            chosen[f["ref"]] = flag_text(f["kind"], f["other"], a.style)
    writes = [(ref, c_flag, txt) for ref, txt in chosen.items()]
    print(f"\napplying {len(writes)} flags for types {sorted(types)} (blank cells only)")
    sc.safe_batch_write(a.tab, writes, key_header=headers[c_ref], write=True, label="flags")


if __name__ == "__main__":
    main()
