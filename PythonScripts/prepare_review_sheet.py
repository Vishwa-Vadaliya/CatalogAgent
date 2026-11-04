"""Prepare a per-brand copy of the image match review template.

Run right after copying the template (see Knowledge/Image_Match_Review_Workflow.md). It
  1. renames the brand-named tabs to neutral names,
  2. adds the `Enrichment Overview` tab if it is missing,
  3. clears the pasted data and typed numbers (headers, formulas, formatting and the
     difference-reason labels stay),
  4. sets the FINAL SUMMARY title to the brand.

Usage: python -I prepare_review_sheet.py <service_account_key.json> <sheet_id> <Brand>
       python -I prepare_review_sheet.py <service_account_key.json> <template_id> "<Brand>" --template

The sheet must be shared with the service account as Editor. The template itself is only touched
with the explicit --template flag (it then also renames the file to "... - TEMPLATE").
"""
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build

TEMPLATE_ID = "1it3jlCafeNQMyQwqI1Sodfijdt9pf8kgGTcUGtgV9hc"
RENAMES = {
    "Summary for jaeger": "Overview Data",
    "Jaeguer-le": "Extra Review 1",
    "Jaeger-leCoultre": "Extra Review 2",
}
OVERVIEW_TAB = "Enrichment Overview"
OVERVIEW_HEADERS = [
    "WatchType", "TotalWatches", "WithEnrichment", "WithoutEnrichment",
    "WithoutEnr_WithReferenceNumber", "WithoutEnr_NullReferenceNumber",
    "NullRef_WithRawReference", "NullRef_WithoutRawReference", "NullRef_UniqueRawReferences",
]
CLEAR = [
    "'ManufacturerWide'!A2:AB",
    "'Multiple ENR'!A2:AB",
    "'Extra Review 1'!A2:AB",
    "'Extra Review 2'!A2:AB",
    "'Overview Data'!A2:Q",
    "'Enrichment Overview'!A2:I",
    "'Summary Table for Manufacturer Wide'!I3:I32",
    "'FINAL SUMMARY'!B7:J7",
    "'FINAL SUMMARY'!F8",
    "'FINAL SUMMARY'!G12:I16",
    "'FINAL SUMMARY'!J16",
    "'FINAL SUMMARY'!B28:K41",
    "'FINAL SUMMARY'!B47:B48",
    "'FINAL SUMMARY'!B89:H104",
    "'FINAL SUMMARY'!B108:H116",
]

key, sheet_id, brand = sys.argv[1], sys.argv[2], sys.argv[3]
is_template = "--template" in sys.argv[4:]
if (sheet_id == TEMPLATE_ID) != is_template:
    sys.exit("refusing: the template needs --template, and --template is only for the template")

creds = service_account.Credentials.from_service_account_file(
    key, scopes=["https://www.googleapis.com/auth/spreadsheets"])
svc = build("sheets", "v4", credentials=creds)

meta = svc.spreadsheets().get(
    spreadsheetId=sheet_id, fields="sheets.properties(sheetId,title,index)").execute()
tabs = {s["properties"]["title"]: s["properties"] for s in meta["sheets"]}

requests = []
for old, new in RENAMES.items():
    if old in tabs:
        requests.append({"updateSheetProperties": {
            "properties": {"sheetId": tabs[old]["sheetId"], "title": new}, "fields": "title"}})
if OVERVIEW_TAB not in tabs:
    requests.append({"addSheet": {"properties": {
        "title": OVERVIEW_TAB, "index": tabs["FINAL SUMMARY"]["index"] + 1}}})
if requests:
    res = svc.spreadsheets().batchUpdate(
        spreadsheetId=sheet_id, body={"requests": requests}).execute()
    print("structure:", len(requests), "changes")
    for r in res.get("replies", []):
        if "addSheet" in r:
            new_id = r["addSheet"]["properties"]["sheetId"]
            svc.spreadsheets().values().update(
                spreadsheetId=sheet_id, range=f"'{OVERVIEW_TAB}'!A1", valueInputOption="RAW",
                body={"values": [OVERVIEW_HEADERS]}).execute()
            svc.spreadsheets().batchUpdate(spreadsheetId=sheet_id, body={"requests": [{
                "repeatCell": {
                    "range": {"sheetId": new_id, "startRowIndex": 0, "endRowIndex": 1},
                    "cell": {"userEnteredFormat": {"textFormat": {"bold": True}}},
                    "fields": "userEnteredFormat.textFormat.bold"}}]}).execute()

done = svc.spreadsheets().values().batchClear(
    spreadsheetId=sheet_id, body={"ranges": CLEAR}).execute()
print("cleared:", len(done.get("clearedRanges", [])), "ranges")

svc.spreadsheets().values().update(
    spreadsheetId=sheet_id, range="'FINAL SUMMARY'!B2", valueInputOption="RAW",
    body={"values": [[f"{brand}: Enrichment Summary"]]}).execute()
print("title set for", brand)

if is_template:
    svc.spreadsheets().batchUpdate(spreadsheetId=sheet_id, body={"requests": [{
        "updateSpreadsheetProperties": {
            "properties": {"title": "ManufacturerWideImageMatch - TEMPLATE"},
            "fields": "title"}}]}).execute()
    print("template file renamed")
