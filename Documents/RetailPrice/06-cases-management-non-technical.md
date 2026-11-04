---
type: Document
title: Retail Prices in the Catalog: What Cases We Have and Why
description: Management document: every retail price case by production status with reasons, three date points and open points. No counts.
tags: [documents, retail-price, catalog]
timestamp: 2026-10-28
Status: Draft for review
Audience: Management / non-technical
Related: 07-cases-technical.md, 08-cases-combined.md
---

# Retail Prices in the Catalog: What Cases We Have and Why

## The short version

- For every watch reference in every country where we have a price, the catalog keeps one **latest price**. When the price changed over time, older prices stay behind it as a **price history**.
- Prices come from three kinds of source: the **manufacturer's own website** (verified, public), **other sources** such as info-source sites (non-verified, public), and **prices given to us directly by a manufacturer** (private).
- Every price can carry a **"last seen" date**: the last day we know the watch was available at that price. Whether a price has this date depends mostly on whether the watch is still in production and where the price came from.
- Some cases look odd at first (for example, a price with no last-seen date, or a last-seen date that is earlier than the day we stored the price). Each one has a reason, explained below.

## Words used in this document

| Term | Plain meaning                                                                                                       |
|---|---------------------------------------------------------------------------------------------------------------------|
| **Reference** | One watch Reference number, for example a specific Rolex model.                                                     |
| **Retail price** | The official price a manufacturer asks for a watch before any discount.                                             |
| **Verified price** | Price taken from the manufacturer's own website, or given by the manufacturer.                                      |
| **Non-verified price** | Price from another source (info-source sites and similar).                                                          |
| **Public / private** | Public prices are shown to everyone. Private prices were given to us directly by a manufacturer.                    |
| **Production status** | Whether the reference is *In Production*, *Out of Production* or *Phasing Out*. Some references have no status yet. |
| **Still listed ("seen in last run")** | The watch was still on the website the last time we collected data.                                                 |
| **Last-seen date** | The last day we know the watch was on website or watch had the price.                                               |
| **Price history** | Several prices for the same reference and country over time.                                                        |

## Where the prices come from

| Kind of price | Source | Shown publicly                        | Still-listed flag | Last-seen date |
|---|---|---------------------------------------|---|---|
| **Verified, public** | Manufacturer's website (collected automatically), or added by hand by a trusted person | Yes                                   | Yes if still on the website, no if it was removed | Only when the price was removed from the website, or a date is known |
| **Non-verified, public** | Other sources (not the manufacturer) | Yes, if verified prices not available | Always set to "still listed" | Only when we know a discontinued date for the reference |
| **Private** | Given directly by the manufacturer | No                                    | Always set to "still listed" and "verified" | Only when we know when the watch stopped |

## The cases we have today

### Watches that are In Production

| Case | What it means |
|---|---|
| **Verified, on the website now, no last-seen date** | The normal case and the largest group. The price is on the manufacturer's website today, so there is no end date. Many of these also have older prices behind them, and those older prices have last-seen dates. |
| **Verified, price removed from the website, has a last-seen date** | We saw the reference on the website before, the price is gone now, so we record the last day it was seen. |
| **Verified, available in some countries but not others** | Prices are kept per country. The reference counts as in production if at least one country or source still lists it. A country that no longer shows the price is marked "not listed" and always gets a last-seen date. |
| **Non-verified, other sources** | Price comes from a source other than the manufacturer. It is always treated as still listed and has no last-seen date. |
| **Private** | Given by the manufacturer. Always treated as verified and still listed, with no last-seen date because the watch is in production. |

### Watches that are Out of Production

| Case | What it means                                                                                                                                                    |
|---|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Verified, no longer on any website, has a last-seen date** | The reference is not on any manufacturer website any more. The price is marked "not listed" and has a last-seen date.                                            |
| **Non-verified, has a last-seen date** | The reference is not on the manufacturer's website, but we have a price from another source. The date comes from the reference's discontinued date.              |
| **Non-verified, no last-seen date** | Price from another source; we have no discontinued date for this reference and no crawled data from the manufacturer.                                            |
| **Private, has a last-seen date** | Manufacturer-given price. Only a few of these are ever found by our collection (crawled data), which is where the date comes from.                               |
| **Private, no last-seen date** | Manufacturer-given price. We do not collect these references at all, or we have no discontinued date.|

### Watches with no production status

| Case | What it means |
|---|---|
| **Verified prices** | Reasons are below. |
| **Non-verified, has a last-seen date** | We took the date from the reference's discontinued date. |
| **Non-verified, no last-seen date** | We do not know a discontinued date for the reference. |
| **Private** | Given by the manufacturer. |

**Why some watches have no production status.** Many brands have no data collected from the manufacturer's website, but we still hold verified or non-verified prices for them. Verified prices can also be added by an external person, and we don't know the production status. Two brands, **Richard Mille and F.P. Journe**, have only non-verified prices from other sources. The two brands have many variations of one reference, and we do not yet know which variation is in production and which is out.

### Watches that are Phasing Out

This status exists only for **Parmigiani**, where the manufacturer itself told us the status.

| Case | What it means |
|---|---|
| Non-verified, has a last-seen date | Some prices have the date. |
| Non-verified, no last-seen date | Others do not. |
| Private | Always treated as "verified" and "still listed". |

## Three points management should know

### 1. Some prices were stored later than their last-seen date (about 3,000 to 4,000 non-verified prices)

For non-verified prices we take the last-seen date from the reference's discontinued date. For a price from a non-manufacturer source, the "created" date is the day **we collected it**, which can be long after the source first showed that price. So the discontinued date can be **earlier** than the day we stored the price. This is a data-timing effect, not an error in the price itself.

The same happened with the price history from WatchBase: we collected it later but the source showed the price in an earlier year. **That was fixed.** We read the prices and their dates from the website's chart by hand and loaded them into the catalog. **For the other sources nothing was fixed**: the created date is the day we collected the price, and the last-seen date comes from the discontinued date.

### 2. How we decide a reference's discontinued date

We take the date from **WatchBase** and **WatchCharts**. If both have a date for the reference, we compare the two and **keep the later one**. WatchCharts has many dates, but **it also shows 2026 dates for references that are still in production**, so its dates need care.

### 3. How price history and last-seen dates work together

When a reference has several prices over time, the older price's last-seen date is the day the next price was created. So in history, **older prices have a last-seen date, but the latest price often does not**. The latest price has none either because we have no date to add, or because the watch is in production and the price is still on the website.

## Open points

| # | Point | Why it matters                                                                           |
|---|---|------------------------------------------------------------------------------------------|
| 1 | Private prices of Out of Production watches have no last-seen date. | The discontinued date could be used to fill it, but we don't have discontinued date data |
| 2 | Many non-verified prices have no last-seen date because we have no discontinued date for the reference. | A source of discontinued dates for these references would close the gap.                 |
| 3 | Some references have no production status. | These cannot be told apart as current or discontinued.                                   |
| 4 | Non-verified prices whose last-seen date is earlier than their created date were not fixed outside WatchBase. | The dates look wrong in a quick check.                                                   |
| 5 | WatchCharts shows 2026 dates for in-production references. | The discontinued date can be wrong when it comes from WatchCharts only.                  |
