---
type: Knowledge Fact
title: Watches — draft vs publish
description: The draft/publish table pattern in the EveryWatch app DB, what a watch count means, the IsDeleted scope, which tables key on the draft WatchId, and the watch attribute link tables.
tags: [knowledge, watches, draft-publish, isdeleted, watch-count]
db: EveryWatch
keywords: [tblWatch, tblWatch_d, draft, publish, published, WatchListingDraftId, IsDeleted, watch count, assigned, raw reference, lot status, auction]
timestamp: 2026-11-04
---

# Watches: draft vs publish (EveryWatch)

- `tblWatch_d` = draft, `tblWatch` = published. Join: `tblWatch.WatchListingDraftId = tblWatch_d.WatchId`.
- **The same pattern holds for every table:** draft data always comes from the `_d` table, published data from the table without `_d` — e.g. `tblMediaAsset_d` / `tblMediaAsset`, `tblWatchToDialColor_d` / `tblWatchToDialColor`, `tblWatchToCaseMaterial_d` / `tblWatchToCaseMaterial`.
- Every published watch exists in draft → **never add the draft and publish counts together**.
- **"Watch count"** = draft count from `tblWatch_d` and publish count from `tblWatch`, grouped by `ReferenceNumberId`. Never use `TotalWatchCount` / `WatchCount` columns.
- Published watch = `tblWatch.IsDeleted = 0`. `IsDeleted` can be NULL → handle it.
- **`IsDeleted` is maintained only in `tblWatch` and `tblWatch_d`** on the EveryWatch (watch) side. Filter `IsDeleted = 0 OR IsDeleted IS NULL` on those two tables only; the other watch-side tables don't maintain the flag, so never filter on it there.
- Ref "Assigned" = has `ReferenceNumberId`; "Raw" = only `RawReferenceNumber` (never count an assigned watch under raw).
- Tables keyed on the **draft** WatchId: `tbl_RE_DataToFix`, `TblWatchEnrichmentResults`, `tbl_RE_DiscardedWatch`, `tblMediaAsset_d`.
- A one-off data-fix `UPDATE` (e.g. setting a flag/score column) only needs to touch the `_d` (draft) table. Publishing (`sp_PublishAllDataNew`) propagates the change to the published table automatically — don't also write a matching `UPDATE` against the publish-side table yourself.
- Watch attributes: `tblWatchToDialColor(_d)` → `tblColor`; `tblWatchToCaseMaterial(_d)` → `tblCaseMaterial` / `TblMaterial`; `TblWatchToBraceletMaterial_D` → `TblMaterial`.
- Auction-house watches: `tblInfoSource.EventTypeId = 1`. Lot status: 2/4 = Sold, 1 = Active, 3 = Unsold. Full `LotStatusId` enum incl. the `5` human-edit guard (sync must never overwrite it) and the undocumented `6`: [conventions.md §6](conventions.md). `EventTypeId` has a crawl-side counterpart `SourceDataType` on `MAC_Sources` — see [conventions.md §7](conventions.md).

## See also

- Staging rule before querying these tables: B8 in [../Rules/10-sql-style.md](../Rules/10-sql-style.md).
- Matching on ids rather than the denormalized text columns: B9, same file.
