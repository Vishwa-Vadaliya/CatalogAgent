---
type: Plan
title: Reference production status kept up to date daily
description: Plan to keep tbl_CAT_Catalog_d.RefProductionStatusID in line with the manufacturer crawl every day (MAX map IsSeenInLastRun per catalog), replacing the one-time fix.
tags: [plans, janvi, production-status, catalog, retail-price, ewmaster]
timestamp: 2026-10-28
name: Reference production status continuous
overview: New SP sp_Sync_RefProductionStatus_FromMapping, called in the daily retail chain right after the map SP has refreshed IsSeenInLastRun. Sets In Production when any active map row of the catalog is seen, else Out of Production; writes a TransactionID so sp_PublishAllDataNew publishes it.
todos:
  - id: profile
    content: Owner runs Queries/Janvi/RetailPrice/RefProductionStatus_BrandAnalysis.sql; decide which current statuses (NULL, 3) are in scope
    status: pending
  - id: sp
    content: Write sp_Sync_RefProductionStatus_FromMapping (with @DryRun) and the call in the insert SP
    status: done
  - id: deploy
    content: Owner runs the deploy order in section 10, then the status dry run
    status: pending
---

# Reference production status kept up to date daily

## 1. Requirement (owner, 2026-10-28)

A reference is **In Production** if at least one manufacturer source still lists it in the last crawl. Otherwise it is **Out of Production**. Today this was set once by hand. It must now stay correct every day.

## 2. How it was done once (one-time fix)

- Script: `D:\New folder\Queries\Janvi\Other_regular_stuff\Catalog_ProdStatus_vs_MapMaxIsSeenInLastRun_Fix.sql` (plus `Catalog_MapCountry_MaxIsSeenInLastRun_ProdStatus2.sql`).
- Group `tbl_MAP_RawCatalog_CatalogCountry` (IsDeleted = 0) by `CatalogId`, then take `MAX(IsSeenInLastRun)`.
- MAX = 1 → In Production (1). Owner: all other mapped catalogs are already Out of Production (2).
- That script **updated only 2 → 1**. The case "In Production but MAX = 0" was only reported.
- It created a transaction with `usp_CreateTransaction 2` and set `tbl_CAT_Catalog_d.TransactionID` so the publish copies the change.

## 3. Decisions

| # | Question | Decision |
|---|---|---|
| P1 | Direction | Both ways: MAX = 1 → 1; MAX = 0 and now 1 → 2 |
| P2 | Crawler outage guard | None: flip immediately, the same as the retail Seen flag. If a crawler gap flips a status, the next good run flips it back. |
| P3 | Statuses in scope (NULL, 3 Phasing Out) | **Open**: decide after the profile query (step 4) |
| P4 | Only deleted map rows (listing removed) | Out of Production (2) |
| P5 | Catalog with no map row (new catalogs and variations often have no status) | Proposed by the owner, pending the brand analysis: if the brand is in the map table, set Out of Production automatically on each run; if not, check manually or leave untouched |
| P6 | `DiscontinuedDate` | Not part of this step (later) |

## 4. Profile first

Run `Queries/Janvi/RetailPrice/RefProductionStatus_BrandAnalysis.sql`. It shows:
- Current status × map state (Active / DeletedOnly / NoMap) × MAX seen.
- Per brand: mapped catalogs, current status counts, and how many the rule would change (2→1, 1→2, status 3, NULL).
- Brands that have a status but no map row.

## 5. Where it runs (proposal)

New SP **`dbo.sp_Sync_RefProductionStatus_FromMapping`** (@UserId, @DryRun), called from `sp_update_CatalogRetailPrice_FromMapping` in the post-insert steps, after `sp_Sync_PriceLastSeenDate_isSeenInLastRun`.

Why there:
- `sp_map_rawCatalog_catalogCountry` runs at the start of the same SP and refreshes map `IsSeenInLastRun` and `IsDeleted` from RAW. The status SP reads the map right after, so it is always based on today's crawl.
- One daily chain, one place to look. It is the same pattern as the PLS sync: its own SP, a dry run, and changed rows only.
- `sp_PublishAllDataNew` (STEP 4) publishes a catalog when `tbl_CAT_Catalog_d.TransactionID` is greater than the published one. So the SP creates one `tblTransaction` (type 2) and sets it only on the changed catalogs. `sp_PublishAllDataNew` then publishes them, as it does for the retail rows.

Not chosen:
- Inside the map SP: it would mix a catalog update into the mapping SP.
- A separate job: it could run before the map is refreshed.

## 6. SP logic (draft)

1. `#MapCatalog`: per CatalogId, `HasActive` and `MaxSeenActive` (active rows only).
2. `#Target`: active catalogs (`StatusID = 1`) with a map row where `RuleStatus` (1 if HasActive and MaxSeen = 1, else 2) differs from the current status, limited to the statuses decided in P3.
3. Dry run: return `#Target` (catalog, brand, current → new) and counts per brand and change.
4. Real run: if `#Target` is empty, return. Otherwise insert one `tblTransaction` and run one UPDATE that sets `RefProductionStatusID` and `TransactionID`, rechecking the current status in the WHERE. Use `XACT_ABORT` with TRY/CATCH, like the PLS sync SP.

## 7. Side effects to check

- Catalog `TransactionID` changes. Check whether the enrichment resync (`usp_CatToEnrichmentResync`, Catalog → Enrichment) picks these catalogs up, which is expected.
- Is `RefProductionStatusID` also set by hand in the admin app or by enrichment? If so, the daily SP will overwrite manual values for mapped catalogs.
- First run: all current mismatches change at once (count from the profile).

## 8. Brand analysis results (2026-10-28)

Source: `RefProductionStatus_BrandAnalysis.sql`, Sheet3 of the "28-10 retail fix run" sheet.

- **Active catalogs:** 115,391 (In 11,100 / Out 68,500 / Phasing 96 / NULL 35,695).
- **Brands in the map table:** 43, with 84,459 catalogs. Mapped catalogs: 21,888, of which 21,248 already match the rule.
- **First-run changes** for mapped catalogs: 2→1: 69, 1→2: 206, NULL→1: 225, NULL→2: 140. Total 640.
- **Whole-brand Out to check before going live:**
  - MeisterSinger: 129 of 129 unseen; the brand never had a status.
  - Favre Leuba: 28 of 36 In → Out.
  - Gevril: all 1,251 Out; 1 of 13 sources active. It is already Out, so nothing changes.
- **Unmapped catalogs of mapped brands:** 62,571. 56,616 are already Out, 7 In (all Audemars Piguet variations with a parent), 0 have public verified retail, and 5,948 are NULL.
  - NULL by brand: JLC 2,746, Cartier 2,184, Patek 528, H. Moser 198, MeisterSinger 107, Roger Dubuis 91, Rolex 49, AP 45.
  - 5,113 of the NULLs were created in the last 90 days.
  - 358 NULLs have a parent; 300 of those parents have a status (Patek 284). No parent is mapped.
- **Brands not in the map table:** 197 brands, 30,932 catalogs, 95 % NULL.
  - Parmigiani is the only one with statuses (In 70 / Out 1,384 / Phasing 96, set by hand).
  - 26 of these brands have rows in `tbl_sourceManufacturer_mapping` but no map rows, for example Glashütte Original, Nomos, Junghans, FP Journe and Richard Mille.
- **DiscontinuedDate:** 63 catalogs have a DiscontinuedDate but are In, and all 63 are seen in the crawl. Later phase.

## 9. Owner decisions after the brand analysis (2026-10-29)

- **Scope = reliable brands only.** A brand is in scope when at least one of its sources is marked **Reconfigured** in the Master Collection sheet (tabs "Manufacturer Important" and "Manufacturer Others"). Sources of that brand that are not reconfigured do not matter: the brand is in scope.
- **In-scope brand:** mapped catalogs follow the MAX seen rule (1 / 2). Unmapped catalogs → Out of Production (2), filled daily.
- **Out-of-scope brand:** every catalog gets **NULL** (no status), because the map data is not reliable. Example: MeisterSinger stays NULL.
- **No parent/child inheritance.** The status belongs to the reference number itself.
- **Favre Leuba:** the flip to Out is correct (almost all unseen).
- Supersedes P3 and P5 in section 3.

### Master Collection sheet (read 2026-10-29)

Sheet `1PV7a6GqQemUivpCZnCxEB-CBEdKdt2R_xuWgiK-Ac5M`, tabs "Manufacturer (Important Ones)" (SourceId per country, column Reconfigured) and "Manufacturer (Others)" (one SourceId per brand).

- **Reconfigured (at least one source TRUE):**
  - From Important: Rolex, Omega, Cartier, Patek Philippe, Tag Heuer, Breitling, Jaeger-LeCoultre, IWC, Hublot, Audemars Piguet (+ AP Chronicles 15297), Vacheron Constantin, A. Lange & Söhne, Baume & Mercier, Panerai, Longines, Tudor, Piaget, Zenith, Blancpain, Grand Seiko, Chopard, Oris, Hamilton, Tissot, Mido, Montblanc, Ebel, Maurice Lacroix, Norqain, Bell & Ross, Seiko, Revue Thommen, F.P. Journe, Richard Mille, Laurent Ferrier, Parmigiani Fleurier (15983).
  - From Others: Glycine, Doxa, Ball, Speake-Marin, Urwerk, Eberhard, Romain Jerome, Junghans, Nomos, Eterna, Marvin, Reconvilier, Roger Dubuis, H. Moser (17168).
- **Not reconfigured (all sources FALSE):** Frederique Constant, Dubois Et Fils, Gevril, Maen, Mathey Tissot, **Favre-Leuba**, Royal Oak Club, Armin Strom, Armand Nicolet, MeisterSinger, Rotary, Angelus, Bulgari, Roamer, U-Boat, Rado, Wittnauer, Hanhart, Andersen Genève.
- Single FALSE sources inside reconfigured brands: Breitling CN 14814, Vacheron CA 14911, Tudor CN 15378.
- Sheet issues: SourceId 14064 is listed for both Bulgari and Roamer.

### Final scope rule (owner, 2026-10-29)

- A brand gets a reference production status **only if** it has at least one Reconfigured source **and** active rows in the map table. Every other brand: NULL.
- The sheet's Reconfigured column wins: Favre-Leuba is not Reconfigured → NULL.
- F.P. Journe and Richard Mille have no map rows → NULL for now (fine).
- AP Chronicles is not an official website, so its `CatSourceName` is not "Official" and the map SP already ignores it.
- Bulgari / Roamer (duplicate SourceId 14064 in the sheet): both out of scope, fine.
- **Parmigiani is the exception: never touched.** Its statuses were set by hand from manufacturer data.
- To check: why Nomos, Junghans (and similar Reconfigured brands with catalogs) have no map rows → `Queries/Janvi/RetailPrice/RefProductionStatus_NoMapSource_Diagnostic.sql`.

### Why Reconfigured brands have no map rows (diagnostic run, Sheet4, 2026-10-29)

- **Cause: `tbl_sourceManufacturer_mapping.CatCountryLocationId` is NULL** (gate 5 of `sp_map_rawCatalog_catalogCountry`). Source is active, Official, manufacturer set, RAW rows with references, and most references match one catalog.
- Affected Reconfigured sources (RAW rows / match one catalog / seen): Nomos 14189 (307 / 254 / 158), Junghans 14187 (311 / 283 / 28), Ball 14075 (507 / 200 / 443), Glycine 14068 (462 / 412 / 407), Doxa 14070 (325 / 187 / 316), Eberhard 14171 (289 / 210 / 10), Marvin 14192 (373 / 292 / 89), Speake-Marin 14081 (94, 26 with ref / 26 / 35), Eterna 14191 (23 / 23 / **0**, last update 2025-12-23), Romain Jerome 14180 (104 / 98 / 81), Urwerk 14166 (28 / 16 / 26), Reconvilier 14196 (20 / 20 / 16).
- Also gate 5 but excluded by decision: Parmigiani 15983 (never touch), F.P. Journe 14224, Richard Mille 14178 (fine without map rows; also many ambiguous matches).
- Not on the sheet but same cause: Glashütte Original 14053 (325 / 311 / 269).
- Revue Thommen (14082, 15403–15406): no manufacturer and no CatSourceName in source mapping, and RAW rows have no ReferenceNo.
- Already mapped and fine: H. Moser, Roger Dubuis, Laurent Ferrier. Mapped but not Reconfigured (→ NULL): Rado, Bulgari, MeisterSinger.
- Side effect of a fix: setting the country makes the next daily run insert map rows **and retail prices** for these brands.

### Owner proposal: map official sources without a location (2026-10-29)

- Do not set a country for brands that have none. Instead, `sp_map_rawCatalog_catalogCountry` maps every **Official** source even when `CatCountryLocationId` is NULL (map `CountryId` = NULL). The retail price flow keeps requiring a country.
- Impact check (code read, ew-db MasterDB):
  - **Table:** `tbl_MAP_RawCatalog_CatalogCountry.CountryId` is `bigint NOT NULL` → must become NULL. The FK to Country allows NULL. `UQ_MAP_RCC_CatalogId_CountryId_Active` treats NULLs as equal → at most one active no-country row per catalog (same rule as per country).
  - **Map SP:** drop `sm.CatCountryLocationId IS NOT NULL` in `#IdsMirrorRef` and `RawCore`. The insert duplicate check `ex2.CountryId = d.CountryId` is false for NULL → a second raw row for the same catalog would hit the unique index and abort the whole daily chain → change to a NULL-safe compare. The ambiguous queue already uses `ISNULL(CountryId, -1)` and its CountryId is nullable.
  - **Retail insert** (`sp_update_CatalogRetailPrice_FromMapping` / `sp_Insert_…`): `#Filtered` has `WHERE ar.CountryId IS NOT NULL`, so no retail row is ever inserted without a country. But `#ActiveMapPairs` would include no-country pairs and, having no retail, run the full mirror history for them every day → add `AND map.CountryId IS NOT NULL` there.
  - **`sp_UpdateMap_PriceLastSeen`:** joins retail on `rp.CountryId = map.CountryId` → no match for NULL → PLS stays NULL. No change.
  - **`sp_Sync_PriceLastSeenDate_isSeenInLastRun`:** only retail rows with a country → no-country map rows ignored. No change.

### Reference key function in the map SP (2026-10-29)

- `sp_map_rawCatalog_catalogCountry` uses the cross-database `EveryWatch.dbo.UDF_ExtractNumbersAndAlphabets` (13 calls). The retail SPs' reference guard uses `EWMaster.dbo.fn_ExtractNumbersAndAlphabets`. Owner: the map SP should use the EWMaster function.
- The two functions are not identical: EveryWatch's version is nvarchar, folds accents, keeps `°` and super/subscript digits, strips `_ [ \ ] ^ \``, and returns the **original input** when nothing is left. EWMaster's is varchar(255), keeps `_ [ \ ] ^ \`` (its `a-zA-z` range), and returns `''`.
- Switching makes the map key and the retail guard key the same. Existing map rows stay; only new matches use the new key.
- Blank reference: owner is fine that those rows are not mapped. The SP does not exclude a blank key today (a blank RAW key can match a catalog whose reference is also blank) → add `CatalogMatchKey <> ''`.

### Proposed maintenance (pending owner approval)

- The sheet stays the human source of truth. The SP cannot read Google Sheets, so the flag must live in the DB.
- Proposal: add `IsReconfigured bit NOT NULL DEFAULT 0` on `tbl_sourceManufacturer_mapping` (per source, the same grain as the sheet). One-time load from the sheet; afterwards whoever marks a source Reconfigured in the sheet also sets the flag (or a small sync script).
- The SP derives brand scope: `ManufacturerId` with any active source where `IsReconfigured = 1`.
- Open:
  - Which map rows count for MAX seen in an in-scope brand: all sources, or only reconfigured ones?
  - Is Parmigiani's manual status (In 70 / Out 1,384 / Phasing 96) cleared to NULL if Parmigiani is not reconfigured?
  - Does a brand that drops out of scope get NULL on the next run?

## 10. Build (2026-10-29)

Files (ew-db `MasterDB` schema/SPs, uncommitted; one-time scripts in CatalogBrain):
- `Queries/Janvi/RetailPrice/RefProductionStatus_01_MapCountryNull_IsReconfigured.sql` (CatalogBrain): map `CountryId` → NULL (FK and filtered unique index dropped and recreated), new `tbl_sourceManufacturer_mapping.IsReconfigured`, filled from the sheet (292 SourceIds).
- `table/tbl_MAP_RawCatalog_CatalogCountry.sql`, `table/tbl_sourceManufacturer_mapping.sql`: DDL updated to match.
- `sp_map_rawCatalog_catalogCountry`: official sources without a location mapped (CountryId NULL); NULL-safe "already mapped" check; key function `dbo.fn_ExtractNumbersAndAlphabets` (13 calls); blank keys not mapped.
- `sp_update_CatalogRetailPrice_FromMapping` (and the `SP_Versions/..._v2_final.sql` copy in CatalogBrain): `#ActiveMapPairs` skips `map.CountryId IS NULL`. The update SP calls the new status SP after the PLS sync.
- New `sp_Sync_RefProductionStatus_FromMapping (@UserId, @DryRun)`. Watches only (`EntityType = 'Watch'`); Parmigiani (ManufacturerId 113) excluded by a list in the SP; seen/mapped counted only from Reconfigured official sources.

Deploy order:
1. Rolex v1 catch-up real run (still pending), so it runs on the current map.
2. Script 01.
3. `sp_map_rawCatalog_catalogCountry`, then `sp_Sync_RefProductionStatus_FromMapping`, then the retail SP (`v2_final`, which now also has the filter and the call). `sp_Insert_CatalogRetailPrice_FromMapping` is not used (owner) and is not changed.
4. `EXEC dbo.sp_map_rawCatalog_catalogCountry;` (adds the no-country map rows), then `EXEC dbo.sp_Sync_RefProductionStatus_FromMapping @DryRun = 1;` and review per brand before the next daily run.
