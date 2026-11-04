---
type: Document
title: sp_PublishAllDataNew: the retail price step
description: The retail price step (step 7) of sp_PublishAllDataNew: update, insert and delete into the published table.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Last verified: 2026-10-13
Confidence: Medium
File: MasterDB\dbo\stored procedures\sp_PublishAllDataNew.sql (~4929 lines; retail step around lines 4107-4156)
---

# sp_PublishAllDataNew: the retail price step

## In plain words

Publishing makes catalog changes live. For retail price it copies approved draft prices (`StatusID = 1`) to the live table, and removes live prices that were marked deleted (`StatusID = 3`). Prices marked pending (`StatusID = 2`) are never published. This is where our flow ends.

**Status:** in use.

## Technical detail

**Signature:** `sp_PublishAllDataNew @validate bit = 0 WITH RECOMPILE`. The whole procedure runs in **one transaction**; with `@validate = 1` it rolls back at the end (a trial run), with `0` it commits. Retail price is **step 7 of 10**: (1) setup, (2) pre-delete children, (3) master upsert, (4) catalog insert/update, (5) media, (6) WatchTo, **(7) retail price**, (8) catalog delete, (9) master delete, (10) post-process.

**Source:** `tbl_CAT_CatalogRetailPrice_d`. **Target:** `tbl_CAT_CatalogRetailPrice`. Key: `CatalogRetailPriceID`.

### The three statements
| Action | Rows | Columns |
|---|---|---|
| **UPDATE** | Draft row has `StatusID = 1` **and** its `TransactionID` is greater than the published row's | `CatalogID, Price, CurrencyId, CountryId, CreatedAt, TransactionID, IsPrivate, IsSeenInLastRun, PriceLastSeenDate, IsVerified, IsPriceTaxIncluded` |
| **INSERT** | Draft rows with `StatusID = 1` that have no published row with the same `CatalogRetailPriceID` | same columns plus the id |
| **DELETE** | Published row whose draft has `StatusID = 3` **and** a greater `TransactionID` | n/a |

Nothing filters on `IsPrivate`, `IsVerified`, `IsSeenInLastRun` or `PriceLastSeenDate`; they are copied. There is no catalog-status check in this step.

## Behaviour worth knowing
- A change to a draft row is published only if its `TransactionId` increased. The sync SP stamps a new one; other manual edits that do not change `TransactionId` are not published.
- A published row later set to `StatusID = 2` is neither updated nor deleted: the live row keeps the old values.
