"""Record WHAT was changed, and WHY, whenever a final ref differs from the original ref.

Step 2 writes standardised / normalised refs (trimmed, de-spaced, re-cased, re-separated,
extracted from a longer string, generalised ...). The final value is fine, but the original must
never be lost: every changed row gets a note saying what the original was, what changed, and why.

    python ref_change_note.py --tab "<brand>" --orig-col RawReferenceNumber --final-col FinalRef \
           --note-col FinalRefChange [--reason-col FinalRefReason] [--write]

Dry run by default. A blank note means the final value is identical to the original (nothing to
explain). Mechanical changes (whitespace, case, separators, lookalike characters, unicode) are
described automatically. Any other change (extracted from text, generalised, alias mapped, typo
fixed ...) needs a human reason: pass it in --reason-col, or the row is listed and NOT written.

Note format (one line, `|`-separated so it can be filtered and split):

    Original: "<original>" | Changed: <what>; <what> | Why: <reason>

When several different originals collapse into one final ref (a dedup), the tab that holds the
merged row writes:  Originals (3): "a" ; "b" ; "c" | Changed: ...
"""
import argparse
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sheets_client as sc  # noqa: E402

ZERO_WIDTH = "​‌‍⁠﻿"
LOOKALIKE = {"O": "0", "o": "0", "I": "1", "l": "1", "|": "1", "S": "5", "B": "8"}
SEPS = set(".-/\\_ ,;:()")


def _alnum(s):
    return re.sub(r"[^A-Za-z0-9]", "", s)


def describe_change(original, final):
    """Return (changes, mechanical).

    changes    list of short strings, in the order they were applied
    mechanical True when every change is one of the safe, automatic kinds
               (whitespace / unicode / case / separator). False when judgement was involved
               (text removed or added, characters swapped, scientific notation decoded ...).
    Both empty / True when the two values are identical.
    """
    o, f = str(original), str(final)
    if o == f:
        return [], True
    changes, mechanical = [], True
    cur = o

    # 1. unicode oddities: non-breaking space, zero-width, compatibility forms
    if any(ch in cur for ch in ZERO_WIDTH):
        cur = "".join(ch for ch in cur if ch not in ZERO_WIDTH)
        changes.append("removed invisible zero-width characters")
    if " " in cur or " " in cur or " " in cur:
        cur = re.sub("[   ]", " ", cur)
        changes.append("replaced non-breaking space with a normal space")
    nf = unicodedata.normalize("NFKC", cur)
    if nf != cur:
        cur = nf
        changes.append("unicode-normalised (NFKC: look-alike or full-width characters)")

    # 2. leading / trailing whitespace
    if cur != cur.strip():
        lead, trail = len(cur) - len(cur.lstrip()), len(cur) - len(cur.rstrip())
        cur = cur.strip()
        bits = []
        if lead:
            bits.append(f"{lead} leading")
        if trail:
            bits.append(f"{trail} trailing")
        changes.append("trimmed " + " and ".join(bits) + " whitespace")

    # 3. internal whitespace
    if cur != f and re.search(r"\s", cur):
        if re.sub(r"\s+", "", cur) == f:
            cur = re.sub(r"\s+", "", cur)
            changes.append("removed internal spaces")
        elif re.sub(r"\s+", " ", cur) == f:
            cur = re.sub(r"\s+", " ", cur)
            changes.append("collapsed repeated spaces")

    # 4. case only
    if cur != f and cur.upper() == f:
        cur = f
        changes.append("changed to upper case")
    elif cur != f and cur.lower() == f:
        cur = f
        changes.append("changed to lower case")

    # 5. separators only: same letters and digits in the same order, different punctuation
    if cur != f and _alnum(cur) == _alnum(f):
        a = "".join(ch for ch in cur if not ch.isalnum())
        b = "".join(ch for ch in f if not ch.isalnum())
        if not b:
            changes.append(f"removed all separators ({_describe_seps(a)})")
        elif not a:
            changes.append(f"inserted separators ({_describe_seps(b)})")
        elif _describe_seps(a) == _describe_seps(b):
            changes.append(f"separator positions changed ({_describe_seps(a)}): "
                           f"{len(a)} separator(s) became {len(b)}")
        else:
            changes.append(f"separators changed from {_describe_seps(a)} to {_describe_seps(b)}")
        cur = f
    elif cur != f and _alnum(cur).upper() == _alnum(f).upper():
        changes.append("case and separators standardised")
        cur = f

    if cur == f:
        return changes, mechanical

    # ---- from here on a human judgement was involved -------------------------------
    mechanical = False
    ca, fa = _alnum(cur), _alnum(f)

    # scientific notation decoded (e.g. 1.36E+05 -> 136350 can not be recovered from text alone)
    if re.fullmatch(r"\d+(\.\d+)?[eE][+-]?\d+", cur.strip()):
        changes.append("decoded from scientific notation")
        return changes, mechanical

    # a lookalike character swapped (O <-> 0, I/l <-> 1 ...)
    if len(ca) == len(fa):
        diffs = [(x, y) for x, y in zip(ca, fa) if x != y]
        if diffs and all(LOOKALIKE.get(x) == y or LOOKALIKE.get(y) == x for x, y in diffs):
            changes.append("replaced look-alike character(s): "
                           + ", ".join(f'"{x}" -> "{y}"' for x, y in diffs))
            return changes, mechanical

    # the final is the original with text removed from the front and/or back
    up_c, up_f = ca.upper(), fa.upper()
    if up_f and up_f in up_c and up_f != up_c:
        i = up_c.index(up_f)
        # quote the removed text exactly as written in the original, punctuation included
        pos = [k for k, ch in enumerate(cur) if ch.isalnum() and ch.isascii()]
        start, end = pos[i], pos[i + len(fa) - 1] + 1
        pre, post = cur[:start].strip(), cur[end:].strip()
        if pre and post:
            changes.append(f'removed leading text "{pre}" and trailing text "{post}"')
        elif pre:
            changes.append(f'removed leading text "{pre}"')
        elif post:
            changes.append(f'removed trailing text "{post}"')
        core = cur[start:end]
        if core != f:  # what is left still differs from the final in case or separators
            sub, _ = describe_change(core, f)
            changes.extend(sub or ["case or separators standardised"])
        return changes, mechanical

    # the original is contained in the final: something was added
    if up_c and up_c in up_f and up_c != up_f:
        i = up_f.index(up_c)
        pre, post = fa[:i], fa[i + len(ca):]
        if pre:
            changes.append(f'added leading text "{pre}"')
        if post:
            changes.append(f'added trailing text "{post}"')
        return changes, mechanical

    # a different value altogether (alias mapped, typo corrected, base ref chosen ...)
    changes.append("value replaced by a different reference")
    return changes, mechanical


def _describe_seps(s):
    names = {".": "dot", "-": "hyphen", "/": "slash", "\\": "backslash", "_": "underscore",
             " ": "space", ",": "comma", ";": "semicolon", ":": "colon", "(": "(", ")": ")"}
    seen = []
    for ch in s:
        n = names.get(ch, repr(ch))
        if n not in seen:
            seen.append(n)
    return "/".join(seen) if seen else "none"


def build_note(original, final, reason="", originals=None):
    """The note text for one row, or '' when nothing changed.

    Returns (note, needs_reason). needs_reason is True when a judgement change has no reason.
    """
    originals = [o for o in (originals or []) if o is not None]
    if originals and len(set(originals)) > 1:
        head = f"Originals ({len(set(originals))}): " + " ; ".join(f'"{o}"' for o in dict.fromkeys(originals))
        diffs, mech_all = [], True
        for o in dict.fromkeys(originals):
            ch, mech = describe_change(o, final)
            if ch:
                diffs.append(f'"{o}": ' + "; ".join(ch))
                mech_all = mech_all and mech
        if not diffs:
            return "", False
        note = f"{head} | Changed: " + " || ".join(diffs)
        needs = (not mech_all) and not reason.strip()
        if reason.strip():
            note += f" | Why: {reason.strip()}"
        elif mech_all:
            note += " | Why: standardised so that equivalent spellings become one reference"
        return note, needs

    o = originals[0] if originals else original
    changes, mechanical = describe_change(o, final)
    if not changes:
        return "", False
    note = f'Original: "{o}" | Changed: ' + "; ".join(changes)
    if reason.strip():
        note += f" | Why: {reason.strip()}"
        return note, False
    if mechanical:
        note += " | Why: standardised formatting only, the reference itself is the same"
        return note, False
    return note, True


# ------------------------------------------------------------------------------- CLI
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tab", required=True)
    ap.add_argument("--orig-col", required=True, help="header of the column holding the ORIGINAL ref")
    ap.add_argument("--final-col", required=True, help="header of the column holding the FINAL ref")
    ap.add_argument("--note-col", required=True, help="header of the note column (created if absent)")
    ap.add_argument("--reason-col", help="header of a column where the agent wrote the reason for judgement changes")
    ap.add_argument("--write", action="store_true", help="write the notes (default is a dry run)")
    ap.add_argument("--out", help="CSV of every row that has a note, for review")
    a = ap.parse_args()

    headers, rows = sc.read_tab(a.tab)
    oc, fc = sc.find_col(headers, a.orig_col), sc.find_col(headers, a.final_col)
    rc = sc.find_col(headers, a.reason_col) if a.reason_col else None
    nc = sc.find_col(headers, a.note_col, required=False)
    new_col = nc is None
    if new_col:
        nc = len(headers)

    plan, blocked, mech_n, judg_n, same_n, skipped = [], [], 0, 0, 0, 0
    for rn, r in enumerate(rows[1:], start=2):
        orig, final = r[oc], r[fc]
        if sc.is_null(final) or not str(final).strip():
            plan.append(""); skipped += 1
            continue
        if sc.is_null(orig):
            orig = ""
        reason = r[rc] if rc is not None else ""
        note, needs = build_note(orig, final, reason)
        if not note:
            same_n += 1
        elif needs:
            blocked.append((rn, orig, final, describe_change(orig, final)[0]))
            note = ""
        elif describe_change(orig, final)[1]:
            mech_n += 1
        else:
            judg_n += 1
        plan.append(note)

    print(f"{a.tab}: {len(rows) - 1} rows | unchanged (no note) {same_n} | no final value {skipped}")
    print(f"notes ready: {mech_n} mechanical + {judg_n} judgement-with-reason")
    print(f"BLOCKED (changed but no reason given): {len(blocked)}")
    for rn, o, f, ch in blocked[:25]:
        print(f'  row {rn}: "{o}" -> "{f}"   [{"; ".join(ch)}]')
    if len(blocked) > 25:
        print(f"  ... and {len(blocked) - 25} more")
    shown = [(i + 2, n) for i, n in enumerate(plan) if n][:6]
    print("sample notes:")
    for rn, n in shown:
        print(f"  row {rn}: {n}")
    if a.out:
        import csv
        with open(a.out, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["row", "original", "final", "note"])
            for i, n in enumerate(plan):
                if n:
                    rr = rows[i + 1]
                    w.writerow([i + 2, rr[oc], rr[fc], n])
        print("wrote", a.out)
    if not a.write:
        print("\nDRY RUN - nothing written. Re-run with --write after the user approves."
              + ("\nBlocked rows are NOT written until each has a reason." if blocked else ""))
        return

    # re-read and confirm the source columns did not move before writing
    h2, r2 = sc.read_tab(a.tab)
    if [x[oc] for x in r2] != [x[oc] for x in rows] or [x[fc] for x in r2] != [x[fc] for x in rows]:
        sys.exit("ABORT: the original / final columns changed since the dry run. Re-run the dry run.")
    if not new_col:
        have = [i for i, x in enumerate(r2[1:], start=2) if x[nc].strip() and plan[i - 2] and x[nc] != plan[i - 2]]
        if have:
            sys.exit(f"ABORT: {len(have)} rows already hold a different note (first: row {have[0]}). "
                     "Existing notes are never overwritten automatically.")
    L = sc.col_letter(nc)
    svc = sc.service()
    n = len(rows)
    if new_col:
        sc.set_text_format(a.tab, nc, write=True)
    keep = [[plan[i]] if plan[i] else [r2[i + 1][nc] if not new_col else ""] for i in range(n - 1)]
    svc.spreadsheets().values().update(
        spreadsheetId=sc.SPREADSHEET_ID, range=f"{sc.q(a.tab)}!{L}1:{L}{n}", valueInputOption="RAW",
        body={"values": [[a.note_col]] + keep}).execute()
    print(f"WRITTEN {a.tab}!{L}1:{L}{n}")


if __name__ == "__main__":
    main()
