---
type: Plan
title: Catalog media download SP
description: Plan for the ImageDownloadStatus/ArtworkPhotosId media-download-status columns and sp_SetCatalogMediaImageDownloadStatus on EWMaster.
tags: [plans, janvi, catalog-media, ewmaster]
timestamp: 2026-10-24
name: Catalog media download SP
overview: ImageDownloadStatus + ArtworkPhotosId on tbl_CAT_Media_d and tbl_CAT_Media; sp_PublishAllDataNew media block updated; sp_SetCatalogMediaImageDownloadStatus on EWMaster.
todos:
  - id: alter-cat-media-d
    content: tbl_CAT_Media_d columns + tr_UD_tbl_CAT_Media_d
    status: pending
  - id: alter-cat-media
    content: tbl_CAT_Media columns
    status: pending
  - id: publish-all-data-media
    content: sp_PublishAllDataNew media UPDATE/INSERT (~4602-4640)
    status: pending
  - id: implement-sp
    content: sp_SetCatalogMediaImageDownloadStatus
    status: pending
  - id: verify-cases
    content: Test draft SP + published tbl_CAT_Media after publish
    status: pending
isProject: false
---

# Catalog media image download status SP (EWMaster)

See full plan: `catalog_media_download_sp_2d985851.plan.md`.

## ew-db deliverables

| File | Change |
|------|--------|
| `MasterDB/dbo/table/tbl_CAT_Media_d.sql` | Columns + mirror trigger lists |
| `MasterDB/dbo/table/tbl_CAT_Media.sql` | Same columns on published table |
| `MasterDB/dbo/stored procedures/sp_PublishAllDataNew.sql` | Media UPDATE + INSERT include new columns |
| `MasterDB/dbo/stored procedures/sp_SetCatalogMediaImageDownloadStatus.sql` | Sets status on **draft** only |

Status values: `1` active RAW, `2` deleted RAW, `3` not in RAW. Match: `Photo = URL` exact.
