---
type: Document
title: Other and Not-in-Use Procedures
description: Retail price SPs that are not in use or whose use is to confirm.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
---

# Other and Not-in-Use Procedures

## In plain words

Besides the six procedures in the main flow, there are older or occasional ones. They are listed here so nobody mistakes them for part of the daily flow.

| SP | Status | What it is |
|---|---|---|
| `sp_Insert_CatalogRetailPrice_FromMapping` | **Not in use (confirmed)** | The earlier "full" version of the update SP. It rebuilds prices from all history on every run. |
| `sp_MAP_RawCatalog_CatalogCountry_OneTime`, `..._OneTime_update` | To confirm (manual) | One-time backfill of the MAP table; also fills `PriceLastSeenDate` and `RawCatalogUpdatedDate` from mirror history. |
| `sp_ProcessUpdatedRetailPrices` | To confirm (looks obsolete) | An older updater based on `tbl_RetailPrice_SP_RunLog`. |
| `sp_Get_RetailPriceDetail` | To confirm | Read-only: returns retail prices for given references or catalogs. |

## sp_Insert_CatalogRetailPrice_FromMapping (not in use)

Same price-change logic as the update SP, with these differences: it reads all RAW and mirror history every run (no watermark, no SyncLog); it has a date gate against `RawCatalogUpdatedDate`; it does not run the map SP; its post steps are commented out. It also has two defects that mean it would not run cleanly today: it creates a permanent table `AllRaw` with `SELECT INTO` (fails on a second run), and its INSERT omits the NOT NULL `IsVerified` column. Kept for reference only.

## sp_MAP_RawCatalog_CatalogCountry_OneTime / _OneTime_update

Parameters `@DryRun bit = 0` (declared but not used) and `@SinceRawCatalogId bigint = NULL`. Same matching rules as the daily map SP, but they additionally compute `PriceLastSeenDate` and `RawCatalogUpdatedDate` at insert time from mirror history, and they treat `IsSeenInLastRun >= 1` as seen (the daily SP uses `= 1`). They do not refresh existing MAP rows and do not copy `IsPriceTaxIncluded`. `_update` is a variant with a two-pass mirror date calculation.

## sp_ProcessUpdatedRetailPrices

No callers exist in any `ew-db` folder. It reads `tbl_RetailPrice_SP_RunLog`, which has no `CREATE TABLE` in the repo. It joins the old `tbl_source_manufacturer_mapping` table, hard-codes user 5, and would fail on the current draft table because it omits `IsVerified`. Confirm with the team, then mark it legacy.

## sp_Get_RetailPriceDetail

Read-only reporting SP. Inputs: `@ReferenceNumbers` (comma list; exact or prefix match), `@CatalogIds`, `@WantLatestOnly bit = 1`, `@CountryName`, `@CurrencyName`, `@IsPrivate`, `@IsVerified`. Reads active catalogs (`StatusID = 1`) with draft prices where `StatusID <> 3`; ranks per (catalog, country) by `IsVerified` desc, `CreatedAt` desc, `TransactionId` desc. Does not return `IsSeenInLastRun` or `PriceLastSeenDate`.
