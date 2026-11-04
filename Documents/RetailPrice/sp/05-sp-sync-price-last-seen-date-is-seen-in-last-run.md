---
type: Document
title: sp_Sync_PriceLastSeenDate_isSeenInLastRun
description: How sp_Sync_PriceLastSeenDate_isSeenInLastRun syncs IsSeenInLastRun (date logic commented out; usage to confirm).
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_Sync_PriceLastSeenDate_isSeenInLastRun.sql (~158 lines)
---

# sp_Sync_PriceLastSeenDate_isSeenInLastRun

## In plain words

New retail price rows start with "not seen" (0). This procedure copies the "is the listing still on the manufacturer's site" flag from the MAP table onto the verified public retail price rows of each catalog watch and country, so the retail table reflects the latest crawl.

**Status: in use.** Called by the update SP after `sp_UpdateMap_PriceLastSeen`. The call is commented out temporarily while the owner dry-runs it by hand (owner, 2026-10-28). Updating every history row of the pair with the crawl flag is intended.

## Technical detail

**Parameters:** `@UserId int = 1`, `@DryRun bit = 0`.
**Reads:** MAP, `tbl_CAT_CatalogRetailPrice_d`, `tbl_CAT_Catalog_d`.
**Writes:** `tbl_CAT_CatalogRetailPrice_d.IsSeenInLastRun` and `TransactionId`; `tblTransaction`.

### Steps
1. **Aggregate MAP** per (CatalogId, CountryId) over active rows (`IsDeleted = 0`): `IsSeenInLastRun = 1` if any active row has `IsSeenInLastRun >= 1`, else 0. Because only one active MAP row exists per pair, this is effectively a copy.
2. **Dry run (`@DryRun = 1`):** select the rows that would change (current vs new `IsSeenInLastRun`); write nothing.
3. **Real run:** in one transaction insert a `tblTransaction` row (type 2, `@UserId`), then update the draft retail rows joined to the aggregate where the row is `StatusID = 1`, `IsPrivate = 0`, `IsVerified = 1`, the catalog is `StatusID = 1`, and the flag differs. Set `IsSeenInLastRun` and `TransactionId` (so publish picks the change up).
   - It updates **every** qualifying price row of the pair (the whole history), not only the latest.
   - Pairs with no active MAP row are not touched.

### Current state of the code
In the live database the `PriceLastSeenDate` part is commented out (owner confirmed, 2026-10-28), so the procedure syncs `IsSeenInLastRun` only. It was switched off because the date rule changed: the old rule put one date (the MAP date) on every row of the pair; the new rule is older price = next price's `CreatedAt`, latest price = crawl date. See [10-last-seen-seen-flag-production-status.md](../10-last-seen-seen-flag-production-status.md).

**The ew-db copy is stale:** the file in `MasterDB` (live export of 2026-09-28) still has the date part active. Read the live definition before changing this SP.
