---
type: Knowledge Fact
title: EveryWatch SQL knowledge base
description: The original, older version of the EveryWatch DB knowledge base, superseded by EW_DB_Knowledge.md but kept for history.
tags: [knowledge, database, ew-db, schema, sql, legacy]
timestamp: 2026-10-24
---

# EveryWatch SQL knowledge base

- When two sessions disagree, the **newest** rule wins; the older one is noted.
- Always confirm columns against `D:\EW\ew-db` before using them. Items marked (?) are unconfirmed — ask before relying on them.

---

## 1. Databases

- **EveryWatch** (`EveryWatchDDL` in repo) = app DB: watches, refs, models, enrichment (`tblWatch*`, `tblReferenceNumber*`, `tbl_RE_*`).
- **EWMaster / MasterDB** = Catalog DB: `tbl_CAT_*`, `tbl_RAW_*`, `tbl_MAP_*`. Scripts often run from EWMaster → prefix app tables with `EveryWatch.dbo.`.
- Mirror DB: `Mirror.EWMaster.*_m`, `MIRROR.EW.*_m` — filled by `tr_UD_*` triggers on UPDATE/DELETE (history versions, `IdMirror`, `MirrorDate`). A big update writes as many mirror rows.
- **Ids differ between the two DBs** (manufacturer, dial color, case material…).
  - Manufacturer bridge: `EveryWatch.dbo.tblManufacturer.CatalogId` = `tbl_CAT_Manufacturer_d.ManufacturerId`.
  - Dial color / case material: resolve ids to **names** and match on names. A watch or catalog can have several → comma-separated.

## 2. Manufacturer ids

| Brand                                                                    | EveryWatch (app) | EWMaster (catalog)                                                |
| ------------------------------------------------------------------------ | ---------------- | ----------------------------------------------------------------- |
| Rolex                                                                    | 257              | 129                                                               |
| Patek Philippe                                                           | 193              | 114                                                               |
| Audemars Piguet                                                          | 142              | 12 (scripts often use `ManufacturerName LIKE 'Audemars Piguet%'`) |
| Cartier                                                                  | 23               | 26 (?)                                                            |
| IWC                                                                      | 5                |                                                                   |
| Hermès                                                                   | 11               |                                                                   |
| Omega                                                                    | 123              | 108                                                               |
| Mathey-Tissot                                                            | 221              |                                                                   |
| Breguet / Breitling / Longines / TAG Heuer / Tudor / Vacheron Constantin |                  | 19 / 20 / 89 / 141 / 143 / 148                                    |

- "5 brands" list (app): 142, 23, 193, 257, 269 (269 = ?).
- `Manufacturer114_Watch_EnrichmentResults_Scores.sql` uses 114 on app-DB `tblWatch_d` — brand in the app DB unknown (?).

## 3. Watches: draft vs publish (EveryWatch)

- `tblWatch_d` = draft, `tblWatch` = published. Join: `tblWatch.WatchListingDraftId = tblWatch_d.WatchId`.
- Every published watch exists in draft → **never add the draft and publish counts together**.
- **"Watch count"** = draft count from `tblWatch_d` and publish count from `tblWatch`, grouped by `ReferenceNumberId`. Never use `TotalWatchCount` / `WatchCount` columns.
- Published watch = `tblWatch.IsDeleted = 0`. `IsDeleted` can be NULL → handle it.
- Ref "Assigned" = has `ReferenceNumberId`; "Raw" = only `RawReferenceNumber` (never count an assigned watch under raw).
- Tables keyed on the **draft** WatchId: `tbl_RE_DataToFix`, `TblWatchEnrichmentResults`, `tbl_RE_DiscardedWatch`, `tblMediaAsset_d`.
- Watch attributes: `tblWatchToDialColor(_d)` → `tblColor`; `tblWatchToCaseMaterial(_d)` → `tblCaseMaterial` / `TblMaterial`; `TblWatchToBraceletMaterial_D` → `TblMaterial`.
- Auction-house watches: `tblInfoSource.EventTypeId = 1`. Lot status: 2/4 = Sold, 1 = Active, 3 = Unsold.

## 4. Reference numbers & models (EveryWatch)

- `tblReferenceNumber`: ReferenceNumberId, ReferenceNumber, ModelId, ManufacturerId, ParentId (self), IsActive/IsPending/IsDeleted, IsAutoCreated, IsModelVerified, CleanName (trigger `onReferenceNumberClean`), CatalogId.
  - Flags are not mutually exclusive (1/1/0 = active+pending, 1/0/1 occur).
  - Ref cleanup: include active and pending, no `IsDeleted` filter (only `tblWatch`/`tblWatch_d` use it); whole table, no min watch-count filter unless asked.
- `tblModel`: ModelId, ModelName, ManufacturerId, ParentId, flags, CleanName, CatalogId.
- `tblAttributeMergeQueue`: OldAttributeId, NewAttributeId, MoveToSynonym, MergedDate. AttributeTypeId 2 = Model, 3 = ReferenceNumber. Enqueued by `usp_mergeMaster`.
- `tblReferenceNumberMSRP(_d)` = app copy of retail prices (synced by `ResyncCatalogRetailPriceToEW`). EWMaster is the source of truth.
- **Synonym**: "if ref/model A is synonym of B then when A comes we will show B on website". Kept for matching/search, not displayed.
- **Parent/child**: the child is still shown (kind of correct); its ideal value is the parent. Rolex 126710BLRO-0001 → 126710BLRO → 126710; Patek 5711/1A-010 → 5711/1A → 5711/1 → 5711.
- **Merge** = make the wrong/duplicate value a synonym of the correct one. Sheet label is "Merge" (not "Synonym").
- **Correct vs Synonym**: corrected ref already in the table → Synonym; otherwise → Correct.

## 5. Clean name & structure functions

- `fn_extractnumberandalphabet` / `fn_ExtractNumbersAndAlphabets` = letters + digits, lowercased ("Complete Clean Name"). Same clean name = duplicate.
  - Scalar UDF with a WHILE loop → slow in join predicates. Precompute cleaned keys into indexed temp tables first.
- `fn_ConvertToRefStructure` / `fn_ConvertToStructure` (EWMaster): digit → X, letter → A, punctuation kept (`116500LN` → `XXXXXXAA`). Don't write an inline TRANSLATE. Don't index RefStruct.
- `fn_CleanReferenceNumber`: AP official refs '-' → '.'.
- Rolex official raw refs: strip leading `m`/`M` (`m52508-0007` → `52508-0007`). Tudor catalog refs may have an optional leading M.

## 6. Catalog (EWMaster)

- `tbl_CAT_Catalog_d` (draft) / `tbl_CAT_Catalog` (published, via `DraftID`): CatalogId, ReferenceNumber (text — no ref master table in EWMaster), ManufacturerId (nullable → LEFT JOIN), ModelId (→ `tbl_CAT_Model_d`), StatusID, EntityType ('Watch' / 'PartialReference'), ParentCatalogId, RefProductionStatusID, IsDiscontinued, DiscontinuedDate, FromYear/ToYear, SourceLink, CatalogDescription, RuleId, EnrichmentRefName.
- Draft `_d` tables: `StatusID = 1` = active, 3 = deleted. Published `tbl_CAT_*` tables generally have no StatusId → don't filter them on it.
- Hierarchy: `ParentCatalogId` (≤ ~4 levels), e.g. PartialReference 25836 → 25836OR → 25836OR.OO.1084OR.01. For hierarchy/model-consistency checks use `StatusID != 3` (valid children can be status 2).
- Catalog match filter: `StatusID = 1 AND EntityType = 'Watch'`.
- `RefProductionStatusID` (→ `tbl_CAT_Reference_ProductionStatus_d`): 1 = In Production, 2 = Out of Production, 3 = Phasing Out.
- `Tbl_cat_catalogCoreRules`: RuleId, NumberOfField, TransactionId, one bit per field (Manufacturer, ReferenceNumber, CaseMaterial, DialColor, BezelColor, BraceletStyle, DialStyle, IndicesEmbellishment, IndicesStyle, DialMaterial, CaseSize, BraceletMaterial, Model, Edition, DialStamp, DialFinish, Calibre, Nickname).
- Enrichment rules: `tbl_CAT_EnrichmentRule_d`, `tbl_CAT_ReferenceStructure_d` (leaf structure = `fn_ConvertToStructure(ReferenceNumber)`).
- Dial lookups: `tbl_CAT_DialColor`, `DialMaterial`, `DialFinishing`, `DialEmbelishment`, `DialStamp`, `SubDialColor`/`SubDialMaterial`, `tbl_CAT_IndicesStyle`.
- Input lists can contain duplicate manufacturer/ref pairs → dedupe/aggregate before joining.
- `GROUP BY` on all temp-table columns collapses duplicate physical rows → aggregate deliberately.

## 7. Retail price (EWMaster)

### Tables

- `tbl_CAT_CatalogRetailPrice_d` (working, history table — one row per price change per CatalogID/CountryId/CurrencyId): CatalogRetailPriceID, CatalogID, Price (money), CurrencyId, CountryId (nullable), CreatedAt, StatusID, TransactionId, IsPrivate, IsVerified, IsSeenInLastRun, PriceLastSeenDate datetime2(3), IsPriceTaxIncluded. No IsActive column.
- `tbl_CAT_CatalogRetailPrice` (published): no StatusID, id not identity, column `isPriceTaxIncluded`.
- Currency `tbl_CAT_Currency_d` (CurrencyId, CurrencyName, CurrencyCode); country `tbl_CAT_Country_d`. Take country/currency **from the retail row**, and **LEFT JOIN** them (unverified prices often have no CountryId).
- Filter currency by **name** (`CurrencyName = 'CHF'`), not code.
- `tbl_RAW_Catalog` (crawler rows: Id, ReferenceNo, Manufacturer, SourceId, Location, Price float, Currency text, IsSeenInLastRun, IsDeleted, CreatedDate, UpdatedDate, TransactionId, URL…). Mirror `Mirror.EWMaster.tbl_RAW_Catalog_m` = older versions; full history = mirror + live row.
- `tbl_MAP_RawCatalog_CatalogCountry`: RawCatalogId, CatalogId, CountryId, IsSeenInLastRun, IsDeleted, PriceLastSeenDate, IsPriceTaxIncluded… Read directly per (CatalogId, CountryId), no MAX/GROUP BY per pair, and no `IsDeleted` filter. Ambiguous matches → `…_Ambiguous`.
- `tbl_sourceManufacturer_mapping`: SourceId → brand, location, expected currency. `CatSourceName` starting 'OFFICIAL' / 'Official Website' = official source. `tbl_RAW_Source` = source label only.
- `tbl_CAT_RawCatalogMapping` (CatalogId, RawReferenceNumber) = manual raw-ref overrides used by the reference guard.
- `tbl_cat_RetailPrice_SyncLog` = watermark for the incremental job (row 3 is a 'Dummy' seed).
- `RawCatalogUpdatedDate` is unused — ignore it.

### Ids

- StatusID 1 = active, 2 = outlier / pending review, 3 = deleted.
- IsPrivate 0 = public, 1 = private. IsVerified 1 = from the manufacturer's official website.
- CurrencyId 14 = CAD (CountryId 39 Canada); 133 = SGD (199 Singapore); 9 = USD, 8 = CHF, 13 = EUR (?); CountryId 214 = Switzerland, 233 = USA (?).
- AP crawl SourceIds 13989, 15096–15105. Rolex raw SourceIds 13987, 15032–15043. Other sources 14112–14135.

### Definitions & conditions

- **Public verified price** = `IsPrivate = 0 AND IsVerified = 1 AND StatusID = 1`. **Private** = `IsPrivate = 1 AND StatusID = 1`.
- **PriceLastSeenDate** = last time the source showed exactly the price we publish.
  - Older price in a series → `CreatedAt` of the next newer price.
  - Latest public price of a (CatalogID, CountryId) → the map's PriceLastSeenDate; if the map has none, leave it (never overwrite with NULL).
  - Non-public-verified fill → scope `IsPrivate = 1 OR IsVerified = 0`; never touch public verified rows there.
  - Compare CreatedAt vs PriceLastSeenDate as `date`. Flag per row (`CreatedAfterLastSeen`) and per pair (`PairHasIssue`).
- **IsLatest** is derived: newest by `CreatedAt DESC, CatalogRetailPriceID DESC`, partitioned by (CatalogID, CountryId, CurrencyId) for private; (CatalogID, CountryId) in the public fix.
- **IsSeenInLastRun** = still listed on the official site in the last crawl. **NULL ≠ 0** — count only 0 and 1. `= 0` = dropped out of the last run.
- Raw seen-status categories: Never seen / Always seen / Flips – latest seen / Flips – latest not seen / No 0/1 data, plus FirstZeroDate, LastZeroDate, FlipPattern (`0 > 1 > 0`).
- Production status from crawl: `MAX(IsSeenInLastRun)` over active map rows per CatalogId. Status 2 with max 1 → should be 1; status 1 with max 0 → report only.
- Ref in production in month M → latest public price's PriceLastSeenDate ≥ M (fall back to latest private; skip NULL).
- **DiscontinuedDate** (AP out-of-production) = MAX(PriceLastSeenDate) across public verified prices in any currency/country.
- Latest-flag check → active + public + verified with `PriceLastSeenDate IS NULL`.
- Retail analysis → `StatusID = 1`, then per currency and per country (distinct catalogs/refs, verified vs not, private vs public).
- Automation rule: add a raw price only if CreatedAt > catalog's latest price and the price differs (latest 5000; incoming 5000, 5600, 5700 → add 5600, 5700; a later return to 5000 is added again).
- Outliers: compare each row with previous and next price in the same catalog/currency/country (LAG/LEAD), flag PREV/NEXT/BOTH when > 45%. Don't use the first price as a fixed base. The insert SP uses ~50% → StatusID 2.
- A deviation > 30% from the USD median can be genuine → verify on the official site in that currency.
- Precomputed temp values (Median…) → use only for rows in that temp table, NULL otherwise; include all currencies.
- EUR vs USD competing (no country, unverified) → keep EUR, else USD, else manual review (KeepFlag).
- Same-day duplicates → group on date(CreatedAt) + CatalogID + CurrencyId + CountryId, `StatusID = 1`.
- `tbl_RAW_Catalog` "has price" → main table first, mirror only for 0/NULL rows; any non-zero non-null value; no `IN` against the mirror.
- Tax indication lock: once the map's `IsPriceTaxIncluded` is 0/1, a later raw flip or NULL is a crawl problem → abort.

### Jobs (daily order)

map (`sp_map_rawCatalog_catalogCountry`) → insert/update retail (`sp_update_CatalogRetailPrice_FromMapping`) → `sp_UpdateMap_PriceLastSeen` → `sp_Sync_PriceLastSeenDate_isSeenInLastRun` → `sp_PublishAllDataNew @validate = 0`.

- `sp_map_rawCatalog_catalogCountry`: maps raw → (CatalogId, CountryId), updates IsSeenInLastRun/IsDeleted/tax, strips Rolex 'm', parks ambiguous rows. Doesn't write PriceLastSeenDate.
- `sp_update_CatalogRetailPrice_FromMapping`: incremental by TransactionId watermark; gates: currency, reference guard (does **not** strip Rolex 'm' → blocks ~21,400 Rolex raws), same-day dedup, 50% outlier. Advances the watermark even with 0 inserts.
- `sp_Insert_CatalogRetailPrice_FromMapping`: full backfill (`@DryRun`).
- `sp_UpdateMap_PriceLastSeen`: live raw price = published price → raw UpdatedDate; else last mirror snapshot with same price+currency (window by Id, Location). Skips same-date updates.
- `sp_Sync_PriceLastSeenDate_isSeenInLastRun`: now syncs only IsSeenInLastRun (PriceLastSeenDate part commented out); one-time scripts fill dates.
- `ResyncCatalogRetailPriceToEW` (EveryWatchDDL): MERGE into `tblReferenceNumberMSRP_d` → published; `usp_ConvertReferenceNumberMSRPCurrency` fills converted currencies.

## 8. Enrichment (ENR, EveryWatch)

- `tblWatch.ReferenceEnrichmentId` = assigned ENR. `tbl_RE_ReferenceEnrichment` (ReferenceEnrichmentId, ReferenceNumberId, ManufacturerId, EntityStatusId — 2 = published).
- `TblWatchEnrichmentResults` (WatchId = draft id) = watches that **got** an ENR and how: EnrichmentTypeId, ImageMatchScore, MatchConfidence, MatchingWatchDraftId. No ReferenceEnrichmentId column.
- `tbl_RE_DiscardedWatch` (~9.27M rows) = candidates for watches that did **not** get an ENR. Unique index (WatchId, ReferenceEnrichmentType) → start from filtered `tblWatch_d` and seek by WatchId; never scan by type first.
- EnrichmentTypeId (`tbl_RE_ReferenceEnrichmentType`): 1 = Image Similarity, 2 = Longest Reference, 3 = Core Fields, 4 = Longest-Ref Rule + Image, 5 = Manufacturer-Wide Image Match, 6 = User/Manually Assigned, 7 = cross-manufacturer image (?).
- **Multiple ENR** = watch with `ReferenceEnrichmentId IS NULL` + candidate rows in `tbl_RE_DataToFix` (WatchId = draft id, RefEnrichmentId, one row per candidate). **No `IsFixed` filter** (newest rule, 2026-10-13; an older session used `IsFixed = 0`). Variations = distinct candidate ENRs per watch reference.
- Match data for a watch → has ENR: `TblWatchEnrichmentResults` (type flag; type 1 for image similarity). No ENR: `tbl_RE_DiscardedWatch` (type 5 = manufacturer-wide image candidates).
- Draft ref/ENR coverage → `tblWatch_d` with `IsDeleted = 0`; show % of total and % of parent (With Ref / Without Ref).
- "Unique from ref alone" = watch ref = ENR ref AND EnrichmentTypeId = 3; every other enriched watch = "made unique by us".
- ENR = one catalog id; watches in an ENR group must be uniquely identifiable by a minimal field set (dial color + case material, plus differentiators like bracelet).
- ENR workflow: unique watches per brand → finalize ref + model → create ENR → direct match → lower manufacturer-wide image score → image similarity for same ref → assign refs → create rules.

## 9. Stored procedures & functions

- `sp_Get_CatalogDetails @ManufacturerName / @ReferenceNumbers, @TempTableName = '##x'` → all catalog fields into a **global** temp table (local `#` vanishes — dynamic SQL).
- `sp_Create_Catalog`, `sp_Update_Catalog` / `sp_update_catalog` (model name, primary image…; bulk fixes = one `exec` line per catalog), `sp_Delete_Catalog`, `sp_add_model 'Name', ManufacturerId`.
  - Cursor bulk pattern is fine (loop a temp table, write errors to a status column).
  - Create models: `catalogid IS NOT NULL AND catmodel IS NULL AND modelid IS NULL`; assign existing: same but `modelid IS NOT NULL`.
- `sp_PublishAllDataNew` (EWMaster) publishes draft → live; deleting a model still referenced by `tbl_CAT_Catalog.ModelId` fails (FK). Calls `sp_create_EnrichmentRefName_Bulk`. `sp_UT_PublishAllDataNew` = app-side publish.
- `sp_create_EnrichmentRefName(_Bulk)`, `sp_Create_Enrule`, `sp_create_enrichment_rule`, `sp_update_enrichment_rule` — enrichment rules per tier (leaf/P/GP/GGP).
- `sp_get_coreRulesSummary` → RuleId, NumberOfField, comma list of set fields.
- Raw-to-catalog: `sp_Populate_NewRefStaging` → `sp_Approve_StagingRecord` → cursor `sp_Create_Catalog` (official sources only).
- `sp_SYNC_SyncWatchesCatalog` (~hourly) loads crawler data into `tbl_RAW_Catalog`.
- TransactionId SPs (`sp_Create_Transaction` / `usp_CreateTransaction`): see B6 in `Rules/EW_Rules.md`.

## 10. Ref / model cleanup decisions

- Decide by watch knowledge + web search — **not** by watch count, active/pending flag or smaller id. Watch count ≥ 10 → extra care; never Delete without checking whether it can be merged.
- Keep the **brand-standard format** (brand website): "RM 001" not "rm001"; check spacing (e.g. Franck Muller) before keeping.
- Appearing in search results doesn't prove a ref is correct.
- Merge: spacing/zero-padding (`PAM 24` → `PAM024`), missing prefix (IWC `3714` → `IW3714`), AP `0` vs `O` (`O` correct, `15186OR`), `OO` vs `00`, separators, Richard Mille keyword variants → clean "RM 011".
- Models: shorthand → full (`Perpetual` → Oyster Perpetual), misspelling → correct (`Caltrava` → Calatrava), case size/dial variants aren't models (`Lady-Datejust 26` → Lady-Datejust, `Deepsea D-Blue` → Deepsea), nicknames merge (TV / TV Watch / Television). Descriptions aren't model names. A specific model beats the generic family.
- A shared name can be valid (Piaget "Tank" = valid vintage model).
- Several possible targets → leave unchanged, note "multiple possible target" (only genuine cases).
- Ref pairs: changed core digits = different (182.068 ≠ 182.086); same digits moved = same (PAM 852 = PAM00852). Judge each pair individually.
- **Delete ref** = completely wrong (caliber, movement, case size, random number). Non-standard pattern may be vintage → don't delete on that alone.
- Valid **partial ref** with many children (HH1.210) stays; not a synonym of one full ref.
- Combined string → split only if each part is a valid ref (W1532656 stays; W153 never valid).
- Omega `-68`/`-69`/`-76` = year suffix (145.022-68 → 145.022). Some stored refs are case numbers ("OP 6714 … ideally PAM00287").
- Slug issue: ReferenceNumber exactly equals a model name → assign that ModelId.

## 11. Cartier

- Watches often carry a 4-digit **case number** or serial instead of the W ref → never match the catalog by ReferenceNumber. One case number → many W refs (2384 → W51008Q3, W51027Q4, W51007Q4).
- Cartier refs (catalog `##temp` → EveryWatch) → match `tblReferenceNumber.ReferenceNumber` directly with `ManufacturerId = 23`, no manufacturer-name join.
- `2384/W51007Q4` → corrected ref is the W ref only. 6-digit dealer codes (W, WA, WZ, WAT, WWL, WWM, WP) aren't refs → keep the case number.
- Variation uniqueness: only a different strap **material** makes a new variation.

## 12. Other domain rules

- WatchBase "Produced: YYYY" isn't always the production year — read the sentence where the year reappears. Caliber introduction year ≠ ref year. Auction "Circa YYYY" = that watch only.
- Complication master values: one value per concept; position isn't a separate value; Time / Other / Multifunction / Skeleton / Anti-magnetic aren't complications.
- Field extraction: SubDialCount = 0 when no subdials (not NULL). Bezel color = color only; Oyster ≠ President bracelet.
- rolex.com URLs carry the full ref (`m126000-0001` → 126000-0001).

## 13. Image tables

(The rule for which image to take — primary only — is B5 in `Rules/EW_Rules.md`.)

- **Catalog DB (MasterDB):** `tbl_CAT_Media` / `tbl_CAT_Media_d` (`CatalogId`, `URL`, `S3Url`, `IsPrimary`).
- **EveryWatch DB:**
  - Watch: `tblMediaAsset` / `tblMediaAsset_d` (`WatchId`, `Url`, `Preview960`, `IsPrimary`, `IsDeleted`).
  - Enrichment: `tbl_RE_ReferenceEnrichmentMediaAsset` (`ReferenceEnrichmentId`, `IsPrimary = 1`, `Preview960` / `Original`).
- **Raw images:** `tbl_RAW_Media` (`RawCatalogId = trc.Id`, no `IsDeleted` filter); no `IsPrimary` column.

## 14. `ew-db` project layout (`D:\EW\ew-db`)

- **MasterDB (Catalog DB):** `D:\EW\ew-db\MasterDB\dbo\` — tables in `table\` (`tbl_CAT_*`, `tblUser`, etc.), stored procedures in `stored procedures\` (`sp_*`), functions in `function\` (`fn_*`).
- **EveryWatchDDL (App DB):** `D:\EW\ew-db\EveryWatchDDL\dbo\` — tables in `table\` (`tblWatch`, `tblReferenceNumber*`, `tbl_PAY_*`, `tbl_RE_*`, etc.), routines (SPs) in `routine\` (`usp_*`, `sp_*`), views in `view\` (`vw_*`), triggers in `trigger\` (`tr_*`).
