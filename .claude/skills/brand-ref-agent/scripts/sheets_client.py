"""Shared Google Sheets helpers for the brand-ref-agent scripts."""
import re
import time
import warnings

warnings.filterwarnings("ignore", category=FutureWarning)

from google.auth import default as _google_default  # noqa: E402
from google.auth.exceptions import DefaultCredentialsError  # noqa: E402
from googleapiclient.discovery import build  # noqa: E402

SPREADSHEET_ID = "1NhfXvAq1aOmpC_auLH_QkNFiIS5VPEvVaa_BfUz8bgg"
SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]
CHUNK = 500
NULLS = {"", "null", "none", "n/a"}

_service = None

_CREDS_HELP = (
    "No Google credentials found. Set GOOGLE_APPLICATION_CREDENTIALS once (PowerShell), "
    "then open a new terminal:\n"
    "    [Environment]::SetEnvironmentVariable('GOOGLE_APPLICATION_CREDENTIALS', "
    "'C:\\Users\\user\\.secrets\\ew-sheets-sa.json', 'User')"
)


def credentials(scopes=None):
    """Application Default Credentials — the key path comes from the environment, never from code."""
    try:
        creds, _ = _google_default(scopes=scopes or SCOPES)
    except DefaultCredentialsError as exc:
        raise SystemExit(f"{_CREDS_HELP}\n\nUnderlying error: {exc}") from exc
    return creds


def service():
    global _service
    if _service is None:
        _service = build("sheets", "v4", credentials=credentials(), cache_discovery=False)
    return _service


def col_letter(idx):
    s, n = "", idx + 1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def col_index(letter):
    n = 0
    for ch in letter.upper():
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def q(tab):
    return "'" + tab.replace("'", "''") + "'"


def is_null(v):
    return str(v).strip().lower() in NULLS


def norm_header(h):
    return re.sub(r"[^a-z0-9]", "", str(h).lower())


def norm_ref(s):
    return re.sub(r"[^A-Z0-9]", "", str(s).upper())


def get_values(tab, rng="A1:ZZ", render="FORMATTED_VALUE"):
    return service().spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=f"{q(tab)}!{rng}",
        valueRenderOption=render).execute().get("values", [])


def cell_text(v):
    """Text for a stored cell value. Whole numbers lose the '.0'; a number shown as 1.66E+04 comes back as 16634."""
    if isinstance(v, bool):
        return str(v).upper()
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def read_tab(tab, render="UNFORMATTED_VALUE"):
    """Return (headers, rows) as text. rows[0] is the header row; every row is padded to the same width.

    Default is the STORED value, not the displayed one: a number with a scientific or rounded number
    format (e.g. 136350 shown as 1.36E+05) is read as its real digits. Pass render="FORMATTED_VALUE" for
    the displayed text, or "FORMULA" for formulas.
    """
    rows = get_values(tab, render=render)
    if not rows:
        return [], []
    width = max(len(r) for r in rows)
    rows = [[cell_text(c) for c in r] + [""] * (width - len(r)) for r in rows]
    return rows[0], rows


def find_col(headers, *names, occurrence=1, required=True):
    targets = {norm_header(n) for n in names}
    hits = [i for i, h in enumerate(headers) if norm_header(h) in targets]
    if len(hits) >= occurrence:
        return hits[occurrence - 1]
    if required:
        raise KeyError(f"none of {names} (occurrence {occurrence}) found in headers: {headers}")
    return None


def list_tabs():
    meta = service().spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID, fields="sheets(properties(sheetId,title))").execute()
    return {s["properties"]["title"]: s["properties"]["sheetId"] for s in meta["sheets"]}


def sheet_meta(tab):
    meta = service().spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID,
        fields="sheets(properties(sheetId,title,gridProperties),basicFilter)").execute()
    for s in meta["sheets"]:
        if s["properties"]["title"] == tab:
            return s
    raise KeyError(f"tab not found: {tab!r}")


def describe_filter(tab):
    """Human-readable summary of the tab's basicFilter (or None if there is no filter)."""
    bf = sheet_meta(tab).get("basicFilter")
    if not bf:
        return None
    out = []
    for spec in bf.get("filterSpecs", []):
        c = spec.get("columnIndex", 0)
        crit = spec.get("filterCriteria", {})
        parts = []
        if crit.get("hiddenValues"):
            hv = crit["hiddenValues"]
            parts.append(f"hidden {len(hv)} values: {hv[:5]}{' ...' if len(hv) > 5 else ''}")
        if crit.get("condition"):
            cond = crit["condition"]
            parts.append(f"condition {cond.get('type')} {[v.get('userEnteredValue') for v in cond.get('values', [])]}")
        if crit.get("visibleBackgroundColor") or crit.get("visibleBackgroundColorStyle"):
            parts.append("background-colour filter")
        out.append(f"col {col_letter(c)}: " + "; ".join(parts or ["(no criteria)"]))
    if bf.get("sortSpecs"):
        out.append("SORT active: " + ", ".join(
            f"col {col_letter(s.get('dimensionIndex', 0))} {s.get('sortOrder')}" for s in bf["sortSpecs"]))
    return out


def visible_row_numbers(tab, nrows):
    """1-based row numbers currently visible (not hidden by filter or by hand), header included."""
    meta = service().spreadsheets().get(
        spreadsheetId=SPREADSHEET_ID, ranges=[f"{q(tab)}!A1:A{max(nrows, 1)}"],
        fields="sheets(properties.title,data.rowMetadata)").execute()
    rm = meta["sheets"][0]["data"][0].get("rowMetadata", [])
    vis = {i + 1 for i, m in enumerate(rm) if not m.get("hiddenByFilter") and not m.get("hiddenByUser")}
    vis |= set(range(len(rm) + 1, nrows + 1))
    return vis


def ref_positions(rows, key_col):
    pos = {}
    for rn, r in enumerate(rows[1:], start=2):
        k = str(r[key_col]).strip() if key_col < len(r) else ""
        if k:
            pos.setdefault(k, []).append(rn)
    return pos


def safe_batch_write(tab, writes, key_header="Referencenumbers", value_input="RAW",
                     write=False, key_occurrence=1, label="write"):
    """Write cells located by key text, never by cached row number.

    writes: iterable of (key_value, col_idx, value). A '{row}' inside a string value is replaced
    with the resolved row number (for row-relative formulas). The key column is re-read right now;
    keys that are missing or appear on more than one row are skipped and reported.
    """
    headers, rows = read_tab(tab)
    kcol = find_col(headers, key_header, occurrence=key_occurrence)
    pos = ref_positions(rows, kcol)
    data, missing, ambiguous = [], [], []
    for key, col, val in writes:
        hits = pos.get(str(key).strip(), [])
        if not hits:
            missing.append(key)
            continue
        if len(hits) > 1:
            ambiguous.append((key, hits))
            continue
        rn = hits[0]
        v = val.replace("{row}", str(rn)) if isinstance(val, str) else val
        data.append({"range": f"{q(tab)}!{col_letter(col)}{rn}", "values": [[v]]})

    print(f"[{label}] planned cells: {len(data)} | key missing: {len(missing)} | key ambiguous: {len(ambiguous)}")
    for d in data[:5]:
        rn = int(re.sub(r"\D", "", d["range"].split("!")[1]))
        print(f"   sample {d['range']}  key={rows[rn - 1][kcol]!r}  value={str(d['values'][0][0])[:90]!r}")
    if missing:
        print(f"   missing keys (first 10): {missing[:10]}")
    if ambiguous:
        print(f"   ambiguous keys (first 10): {ambiguous[:10]}")

    written = 0
    if write and data:
        for i in range(0, len(data), CHUNK):
            service().spreadsheets().values().batchUpdate(
                spreadsheetId=SPREADSHEET_ID,
                body={"valueInputOption": value_input, "data": data[i:i + CHUNK]}).execute(num_retries=5)
            written += len(data[i:i + CHUNK])
            if len(data) > CHUNK:
                time.sleep(1.1)
        print(f"[{label}] WRITTEN {written} cells")
    elif data:
        print(f"[{label}] dry run - nothing written (re-run with --write)")
    return {"planned": len(data), "written": written, "missing": missing, "ambiguous": ambiguous}


def sync_preview_column(tab, refs, write=False, backup_dir=None, label="preview sync", key_header=None):
    """Make the preview column follow FinalImageUrl for the given refs.

    Some tabs keep a plain-URL 'FinalImage' column that the preview formula (=image(R)) reads, so a new
    FinalImageUrl does not change the preview until that column holds the same URL. For every ref in
    `refs` the live FinalImageUrl is copied into 'FinalImage' when that cell is a plain value that
    differs. A cell that holds a formula (e.g. =IMAGE(P2)) already follows FinalImageUrl and is left
    alone, and so is a tab with no 'FinalImage' column. Old values are saved to backup_dir (CSV).
    """
    headers, rows = read_tab(tab)
    c_ref = find_col(headers, key_header) if key_header else find_col(headers, "Referencenumbers", "ReferenceNumber")
    c_fin = find_col(headers, "FinalImageUrl", "FinalPrimaryImageUrl", "FinalImageurl")
    c_prev = find_col(headers, "FinalImage", required=False)
    if c_prev is None or c_prev == c_fin:
        print(f"[{label}] no separate 'FinalImage' column on the tab - nothing to sync")
        return {"planned": 0, "written": 0}
    formulas = get_values(tab, render="FORMULA")
    pos = ref_positions(rows, c_ref)
    writes, old, formula_rows = [], [], 0
    for ref in dict.fromkeys(str(r).strip() for r in refs):
        hits = pos.get(ref, [])
        if len(hits) != 1:
            continue
        rn = hits[0]
        url = rows[rn - 1][c_fin].strip()
        cur = rows[rn - 1][c_prev].strip()
        raw = formulas[rn - 1][c_prev] if rn - 1 < len(formulas) and c_prev < len(formulas[rn - 1]) else ""
        if str(raw).startswith("="):
            formula_rows += 1
        elif url.lower().startswith("http") and cur != url:
            writes.append((ref, c_prev, url))
            old.append((ref, cur))
    print(f"[{label}] column {col_letter(c_prev)} ({headers[c_prev]}): {len(writes)} to sync, "
          f"{formula_rows} are formulas (already follow FinalImageUrl)")
    if write and old and backup_dir:
        import csv
        from datetime import datetime
        p = f"{backup_dir}/preview_sync_backup_{datetime.now():%Y%m%d_%H%M%S}.csv"
        with open(p, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["ref", "old_value"])
            w.writerows(old)
        print(f"[{label}] backup of old values -> {p}")
    if not writes:
        return {"planned": 0, "written": 0}
    return safe_batch_write(tab, writes, key_header=headers[c_ref], value_input="RAW", write=write, label=label)


def write_cells(tab, cells, value_input="RAW", write=False, label="cells"):
    """Write fixed A1 cells (e.g. header cells). cells: list of (a1, value)."""
    data = [{"range": f"{q(tab)}!{a1}", "values": [[v]]} for a1, v in cells]
    print(f"[{label}] planned cells: {len(data)} -> {[(a1, v) for a1, v in cells][:12]}")
    if write and data:
        service().spreadsheets().values().batchUpdate(
            spreadsheetId=SPREADSHEET_ID,
            body={"valueInputOption": value_input, "data": data}).execute()
        print(f"[{label}] WRITTEN {len(data)} cells")
    return len(data)


def set_text_format(tab, col_idx, write=False):
    sid = sheet_meta(tab)["properties"]["sheetId"]
    req = {"repeatCell": {
        "range": {"sheetId": sid, "startColumnIndex": col_idx, "endColumnIndex": col_idx + 1},
        "cell": {"userEnteredFormat": {"numberFormat": {"type": "TEXT"}}},
        "fields": "userEnteredFormat.numberFormat"}}
    print(f"[format] TEXT on column {col_letter(col_idx)}{'' if write else ' (dry run)'}")
    if write:
        service().spreadsheets().batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": [req]}).execute()


def insert_column(tab, at_idx, write=False):
    sid = sheet_meta(tab)["properties"]["sheetId"]
    req = {"insertDimension": {"range": {"sheetId": sid, "dimension": "COLUMNS",
                                         "startIndex": at_idx, "endIndex": at_idx + 1},
                               "inheritFromBefore": at_idx > 0}}
    print(f"[structure] insert column at {col_letter(at_idx)}{'' if write else ' (dry run)'}")
    if write:
        service().spreadsheets().batchUpdate(spreadsheetId=SPREADSHEET_ID, body={"requests": [req]}).execute()


def add_sheet(tab, write=False):
    if tab in list_tabs():
        raise ValueError(f"tab already exists: {tab!r}")
    print(f"[structure] add tab {tab!r}{'' if write else ' (dry run)'}")
    if write:
        service().spreadsheets().batchUpdate(
            spreadsheetId=SPREADSHEET_ID,
            body={"requests": [{"addSheet": {"properties": {"title": tab}}}]}).execute()
