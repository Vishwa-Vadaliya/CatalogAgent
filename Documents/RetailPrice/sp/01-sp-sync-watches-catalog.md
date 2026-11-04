---
type: Document
title: sp_SYNC_SyncWatchesCatalog
description: How sp_SYNC_SyncWatchesCatalog moves crawler data into tbl_RAW_Catalog.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_SYNC_SyncWatchesCatalog.sql (~989 lines)
---

# sp_SYNC_SyncWatchesCatalog

## In plain words

This is where retail price data first enters our database. The crawlers store what they saw on manufacturer sites in their own database. This procedure copies new and changed listings from there into `tbl_RAW_Catalog`. It copies the price, currency and "still listed" flag exactly as the crawler has them; it does no checking or conversion. Whenever it overwrites a RAW row, a trigger keeps the old version in the Mirror, so we keep a history.

It also copies other watch data (descriptions, photos). This document covers only what matters for retail price.

**Status:** in use; job name and schedule (about hourly) **to confirm**.

## Technical detail

**Signature:** `sp_SYNC_SyncWatchesCatalog @SourceIds varchar(max) = NULL`. A comma-separated list of crawler source ids; NULL means all eligible sources.

**Reads:** crawler database `MACrawler_` on a linked server: `Sources`, `Auctions`, `Artworks` (price and seen status), `Watches` (attributes), joined on ArtworkId + SourceId + AuctionId.

**Writes:** `tbl_RAW_Source`, `tbl_RAW_Auction`, `tbl_RAW_Catalog`, `tbl_RAW_Media`, `tblTransaction`, and sync-back tables in the crawler DB (`SYNC_*`).

### Steps (price-relevant)
1. Take the time from the crawler server (`GETDATE()` via OPENQUERY).
2. Insert two `tblTransaction` rows: type 1 (create) and type 2 (update). Their ids are stamped on written rows as `TransactionId`.
3. **Sources.** Read crawler Sources where `SourceDataType = 5`, `Project = 'w'`, `IsPublished = 1`. If none, stop. Insert new ones into `tbl_RAW_Source`.
4. **Auctions.** Read crawler Auctions of those sources changed since last sync (`UpdatedDate > SyncDate OR SyncDate IS NULL`); update or insert `tbl_RAW_Auction`.
5. **Pick the watches to load.** Build temp table `#Watches` (TOP 5000 per run, no ORDER BY) with: `Project = 'w'`, `SourceDataType = 5`, `isRunning = 0` (skip sources being crawled right now), `IsPublished = 1`, crawler `IsSeenInLastRun IN (0, 1)`, optional `@SourceIds`, and changed since last sync (`UpdatedDate > SyncDate OR SyncDate IS NULL`). If empty, stop.
6. **Update existing RAW rows** (matched by SourceId, AuctionId, ArtworkId and the stored crawler `MA_Id`). Every attribute is overwritten. Price-related fields copied as-is: `Price`, `Currency`, `BuyNowPrice`, `ShippingPrice`, `BuyersFee`, `EstimatePriceFrom/To`, `SuspiciousPriceDate`, `PriceFirstSeenDate`, `UpdatedDate`, `SyncDate`, `IsSeenInLastRun`, `LastSeen`, `IsDeleted`, `Availability`, `ReferenceNo`, `ReferenceRaw`. `TransactionId` is set to the update transaction. (The mirror trigger saves the previous version.)
7. **Insert new RAW rows** (no `MA_Id` yet), only if the parent `tbl_RAW_Auction` row exists and the listing is not already in RAW. Same columns; `TransactionId` is the create transaction.
8. Write the new/updated RAW ids back to the crawler's `SYNC_ArtworkSyncBulkUpdate` so the crawler knows what was synced.
9. Rebuild `EWMaster.dbo.TempWatches` as a copy of `#Watches` (looks like debug leftover).
10. Media sync and three crawler-side sync procedures (`sp_SYNC_SyncAuctionByRunId`, `...ArtworksByRunId`, `...MediaByRunId`).

### What it does not do
- It never works out `IsSeenInLastRun`, `IsDeleted` or `Currency`; they come from the crawler.
- It does not convert currency.
- It does not write `IsPriceTaxIncluded`.
