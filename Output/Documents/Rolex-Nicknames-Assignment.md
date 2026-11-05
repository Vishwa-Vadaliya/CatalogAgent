---
type: Working Document
title: Rolex nicknames - reference to nickname assignment
description: Every Rolex catalog reference in the DB mapped to the nickname the market actually uses for it, split into reference-level and dial-dependent, for assignment to tbl_CAT_Catalog_d.NicknameId.
tags: [rolex, nickname, catalog, brand-refs]
timestamp: 2026-11-05
---

# Rolex nicknames - reference to nickname assignment

Source sheet: **Rolex nickname** (`1OhYcxSITOt75BVJZVmyx7ijdhGsWpho--TCvYWx5VRg`, `Sheet1`, gid 0) -
9,673 Rolex catalog rows, 1,247 distinct base references, supplied by Vishva from the DB.

## What was written back to the sheet

Columns **A-E were not touched**. Seven columns were added beside them:

| Col | Header | What it holds |
|---|---|---|
| F | `SuggestedNickname` | The nickname the **whole reference** carries - every example of that ref qualifies. Safe to assign from the reference alone. |
| G | `ConditionalNickname` | A nickname only **some** examples of that reference carry. Needs a dial/bezel check before assigning. |
| H | `Condition` | What has to be true for column G (e.g. "white dial", "red Submariner text"). |
| I | `AltNames` | Other names the market uses for the same watch - candidates for synonyms, not for the catalog row. |
| J | `Scope` | `Reference-level` / `Dial-dependent` / `Family / line-wide`. |
| K | `Confidence` | `High` = settled market usage; `Medium` = used but contested or narrower. |
| L | `Status` | `Already set` / `New - assign` / `New - needs dial check` / `No market nickname`. |

## Coverage

| Status | Rows |
|---|---|
| Already set in the DB | 64 |
| **New - assign** (reference-level, ready) | **2,102** |
| **New - needs dial check** (dial-dependent) | **699** |
| No market nickname exists | 6,808 |
| **Total** | **9,673** |

What the DB has today is only **5 distinct nicknames** on 64 rows: Paul Newman (49), Big Red (10),
Ghost (3), Unicorn (1), Crazy Doc (1). This mapping proposes **67 distinct nickname values**, of
which 62 are new.

Distinct nickname values proposed:

Bart Simpson, Batman, Big Crown, Bluesy, Bombe, Bruce Wayne, Bubbleback, Buckley, Bumblebee, CERN,
Celebration, Coke, COMEX, D-Blue, Daytona Beach, Domino's, Double Red Sea-Dweller, Eye of the Tiger,
Fat Lady, Glace Verte, Hulk, Ice Blue, Jean-Claude Killy, John Mayer, Kermit, Le Mans, Leopard,
Lightning Bolt, Maxi Dial, MilSub, Monoblocco, Nipple Dial, Ovettone, OysterQuartz, Padellone,
Palm Motif, Panda, Paul Newman, Pepsi, Polar, Pre-Daytona, Pre-Explorer, President, Rainbow Daytona,
Rainbow Yacht-Master, Red Sea-Dweller, Red Submariner, Rolesium, Root Beer, SARU, Sea-Dweller 4000,
Small Crown, Smurf, Space-Dweller, Sprite, Starbucks, Stella, Stelline, Steve McQueen, Texano,
Thunderbird, Tiffany Dial, Tridor, Triple Six, Wimbledon, Z-Blue, Zenith Daytona.

## The mapping

### A. Reference-level

| Nickname | References in our catalog | Rows | Also known as | Scope | Conf |
|---|---|---|---|---|---|
| **President** | `118135`, `118138`, `118139`, `118205`, `118205F`, `118206`, `118208`, `118209`, `118235`, `118235F`, `118238`, `118239`, `118296`, `118338`, `118339`, `118346`, `118348`, `118366`, `118388`, `118389`, `118395BR`, `118398`, `118398BR`, `118399BR`, `128155RBR`, `128158RBR`, `128159RBR`, `128235`, `12 … | 1352 | — | Family / line-wide | High |
| **President** | `1802`, `1803`, `1803/6`, `1803/8`, `18038`, `18039`, `18039BIC`, `1804`, `1806`, `1807`, `1811`, `1811/8` | 162 | — | Family / line-wide + dial variant | High |
| **Thunderbird** | `116261`, `116263`, `116264`, `1625`, `1625/4`, `1625/8`, `16250`, `16253`, `16263`, `16264`, `6202`, `6309` | 100 | Turn-O-Graph | Family / line-wide | High |
| **Bubbleback** | `2940`, `3065`, `3116`, `3131`, `3133`, `3372`, `3458`, `3599`, `4467`, `5011`, `5015`, `5028`, `5050`, `6050` | 89 | Ovettone (oversized); Bombe | Family / line-wide | Medium |
| **Ovettone** | `6084`, `6085`, `6098` | 45 | Oversized Bubbleback | Family / line-wide | Medium |
| **Zenith Daytona** | `16518`, `16519`, `16520`, `16523`, `16528` | 43 | El Primero; Patrizzi / Floating Dial / Inverted Six (dial variants) | Family / line-wide | High |
| **President** | `18946`, `18948`, `18956`, `18956BR`, `18958BR` | 42 | — | Family / line-wide + dial variant | Medium |
| **OysterQuartz** | `19018`, `19019`, `19028`, `19048`, `19058` | 31 | President | Family / line-wide | High |
| **Jean-Claude Killy** | `4767`, `4768`, `6036`, `6236` | 27 | Dato-Compax | Reference-level | High |
| **OysterQuartz** | `17000`, `17013`, `17014` | 25 | — | Family / line-wide | High |
| **Pre-Daytona** | `6034`, `6234`, `6238`, `6238/0` | 18 | — | Family / line-wide | Medium |
| **Root Beer** | `1675/3`, `1675/8`, `16753`, `16758` | 17 | Rootbeer; Tiger Eye (nipple dial) | Reference-level | High |
| **Monoblocco** | `3484`, `3525` | 17 | Prisoner of War; POW | Reference-level | High |
| **Rolesium** | `116622`, `126622`, `16622`, `168622`, `169622`, `268622` | 12 | — | Family / line-wide | High |
| **Pre-Explorer** | `6150`, `6298`, `6350` | 11 | — | Family / line-wide | Medium |
| **Pepsi** | `116719BLRO`, `126710BLRO`, `126719BLRO`, `16700BLRO`, `16710BLRO` | 10 | — | Reference-level | High |
| **SARU** | `116748SARU`, `116758SARU`, `116759SARU`, `116759Saru`, `126755SARU` | 9 | Rainbow GMT | Reference-level | Medium |
| **Bluesy** | `116613LB`, `126613LB`, `16613LB` | 8 | — | Reference-level | High |
| **Rainbow Daytona** | `116595RBOW`, `116598RBOW`, `116599RBOW`, `126598RBOW` | 7 | — | Reference-level | High |
| **Ice Blue** | `116506`, `126506` | 7 | Platinum Daytona; Platona | Reference-level | Medium |
| **Bombe** | `6090` | 7 | Bombay; Ovettone | Family / line-wide | Medium |
| **Padellone** | `8171` | 6 | Frying Pan | Reference-level | High |
| **Texano** | `5100` | 5 | Beta 21 | Reference-level | Medium |
| **Leopard** | `116578SACO`, `116588SACO`, `116598SACO` | 4 | — | Reference-level | Medium |
| **Batman** | `116710BLNR`, `126710BLNR` | 3 | Batgirl (Jubilee bracelet) | Reference-level | High |
| **Root Beer** | `126711CHNR`, `126715CHNR`, `126715chnr` | 3 | Rootbeer | Reference-level | High |
| **Glace Verte** | `116400GV`, `116400V` | 3 | GV | Reference-level + dial variant | High |
| **Sprite** | `126720VTNR`, `126729vtnr` | 3 | Destro; Lefty | Reference-level | High |
| **Big Crown** | `5510`, `6538` | 3 | James Bond | Reference-level | High |
| **Smurf** | `116619LB`, `126619LB` | 3 | — | Reference-level | High |
| **Panda** | `116500LN`, `126500LN` | 2 | — | Reference-level | High |
| **Hulk** | `116610LV` | 2 | — | Reference-level | High |
| **Red Sea-Dweller** | `126600` | 2 | SD43; Single Red | Reference-level | High |
| **Bruce Wayne** | `126710GRNR`, `126710grnr` | 2 | — | Reference-level | High |
| **Small Crown** | `5508`, `5508/0` | 2 | James Bond | Reference-level | High |
| **COMEX** | `5514`, `5514/0` | 2 | — | Reference-level | High |
| **Lightning Bolt** | `6541` | 2 | Honeycomb | Reference-level | Medium |
| **Rainbow Yacht-Master** | `116695SATS` | 2 | — | Reference-level | Medium |
| **Eye of the Tiger** | `116588TBR` | 2 | — | Reference-level | Medium |
| **Fat Lady** | `16760` | 2 | Sophia Loren; Coke | Reference-level | High |
| **John Mayer** | `116508` | 1 | Christmas Dial | Reference-level | High |
| **Sea-Dweller 4000** | `116600` | 1 | SD4K | Reference-level | Medium |
| **Steve McQueen** | `1655` | 1 | Freccione; Orange Hand | Reference-level | High |
| **Starbucks** | `126610LV` | 1 | Cermit; Kermit 2.0 | Reference-level | High |
| **Bumblebee** | `126713GRNR` | 1 | — | Reference-level | Medium |
| **Le Mans** | `126529LN` | 1 | 100th Anniversary Le Mans | Reference-level | High |
| **Triple Six** | `16660` | 1 | — | Reference-level | High |
| **MilSub** | `5517` | 1 | Military Submariner | Reference-level | High |
| **Kermit** | `16610LV` | 1 | Flat Four / Fat Four (bezel font variant); 50th Anniversary | Reference-level | High |
| **Pepsi** | `6542/0` | 1 | Bakelite; Pussy Galore | Reference-level | High |

### B. Dial-dependent

| Nickname | References | Rows | Applies when | Conf |
|---|---|---|---|---|
| **Wimbledon** | `116234`, `116334`, `126233`, `126333`, `126334` | 196 | slate dial with Roman numerals | High |
| **Buckley** | `1600`, `1600/3`, `16000`, `1601`, `16013`, `16014`, `16018`, `1603`, `16030` | 175 | painted Roman-numeral dial | Medium |
| **Stella** | `1802`, `1803`, `1803/6`, `1803/8`, `18038`, `18039`, `18039BIC`, `1804`, `1806`, `1807`, `1811`, `1811/8` | 162 | Stella = glossy lacquered coloured dial | High |
| **Paul Newman** | `6241`, `6263`, `6263/0`, `6264`, `6265` | 68 | exotic 'Paul Newman' dial only | High |
| **Domino's** | `14000`, `14000M`, `14010`, `14010M`, `5500`, `5500/0` | 55 | co-branded Domino's Pizza logo dial | Medium |
| **Palm Motif** | `126234` | 50 | olive-green palm-motif dial | Medium |
| **Tridor** | `18946`, `18948`, `18956`, `18956BR`, `18958BR` | 42 | three-colour gold (Tridor) bracelet/dial | Medium |
| **Paul Newman** | `6239`, `6240`, `6240/0`, `6262`, `6262/0` | 41 | exotic / art-deco 'Paul Newman' dial only | High |
| **Daytona Beach** | `116519` | 40 | coloured mother-of-pearl dial (pink / green / yellow / blue) | Medium |
| **John Mayer** | `116508` | 15 | green dial (-0013 suffix) | High |
| **Celebration** | `126000` | 15 | bubbles / 'Celebration' motif dial | Medium |
| **Polar** | `16570`, `216570`, `226570` | 13 | white dial (also sold with black dial) | High |
| **Pepsi** | `1675`, `1675/0`, `16750` | 13 | red/blue bezel insert (also came with black bezel) | High |
| **Nipple Dial** | `16803`, `16808` | 10 | gold/two-tone dial with raised gold surrounds | Medium |
| **Tiffany Dial** | `124300` | 8 | turquoise-blue dial; aubergine dial is the Grape | Medium |
| **D-Blue** | `116660`, `126660`, `136660` | 8 | blue-to-black gradient 'D-Blue' dial (also sold with plain black dial) | High |
| **Stelline** | `6062` | 8 | star-marker dial | High |
| **Bart Simpson / Maxi Dial** | `5512`, `5512/0`, `5513`, `5513/0` | 6 | Bart Simpson = early gilt coronet; Maxi = oversized lume plots; Meters-First = depth order on dial | Medium |
| **Root Beer** | `16713` | 6 | brown/gold bezel insert | Medium |
| **Pepsi / Coke** | `16710` | 6 | Pepsi = red/blue bezel, Coke = red/black bezel; also came all-black (LN) | High |
| **Panda** | `116500LN`, `126500LN` | 5 | white dial with black sub-dials (-0001 suffix) | High |
| **Red Submariner** | `1680`, `1680/8` | 5 | red 'Submariner' text on the dial | High |
| **Double Red Sea-Dweller** | `1665`, `1665/0` | 4 | two lines of red text = DRSD; one line = Single Red; white text = Great White | High |
| **Polar** | `16550` | 4 | white dial; cream/ivory examples are the Cream Dial, early ones the Rail Dial | High |
| **Pepsi** | `16700` | 4 | red/blue bezel insert | High |
| **Z-Blue** | `116400GV`, `116400V` | 3 | Z-Blue = electric-blue dial | High |
| **CERN** | `1019`, `1019/0` | 3 | CERN-issued example | Medium |
| **Space-Dweller** | `1016`, `1016/0` | 2 | 'Space-Dweller' dial; other 1016 dial variants are Exclamation, Underline, Frog Foot | Medium |


## Why two columns instead of one

`tbl_CAT_Catalog_d.NicknameId` is a single int FK, and per
[Documents/Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md](../../Documents/Enrichment/Catalog-Enrichment-PaulNewman-Tiffany-Variations.md)
a nickname on a catalog row becomes `EXISTS(nickNameId)` in the generated EWQL when the rule carries
`Nickname = 1`. So:

- **Column F (reference-level)** can be stamped onto the existing catalog row. The nickname adds a
  name, it does not split the reference into variants.
- **Column G (dial-dependent)** must not be stamped onto the base row. Paul Newman is the worked
  example: the variant needs **its own catalog row plus a variant enrichment rule**. Assigning
  "Polar" to every `16570` would wrongly claim the black-dial examples too.

The 699 dial-dependent rows are therefore a **second phase**, and each one needs the dial colour (or
bezel insert, or bracelet) read off the catalog row before it is assigned.

## Open decisions

1. **"President" on the whole Day-Date line (1,556 rows).** It is the real market name for the
   model, but it is line-wide, not a single-reference name - it would sit on every Day-Date catalog
   row. Same question for Bubbleback (89), Thunderbird (100), OysterQuartz (56), Ovettone (45),
   Zenith Daytona (43), Rolesium (12). Keep them, or restrict nicknames to watch-specific names only?
2. **Two names, one row.** 16610LV is Kermit *and* Flat Four; 126710BLNR is Batman on Oyster and
   Batgirl on Jubilee; 16760 is Fat Lady *and* Coke. Column F holds the primary, column I the rest -
   the alternates want to become app-side synonyms (`tblNickName.ParentId`), not catalog values.
3. **Medium-confidence names** (Bumblebee, Eye of the Tiger, Leopard, SARU, Texano, Bombe, CERN,
   Lightning Bolt, Ice Blue, Domino's, Tridor, Celebration, Tiffany Dial) - assign, or hold for
   review?
4. **Names already in the DB that this mapping does not reproduce:** Ghost, Unicorn, Crazy Doc.
   They are on 5 rows and were left untouched; they look like one-off auction names rather than
   market nicknames.

## References not matched

Two rows carry `modelname = NULL` (`3156`, `9172/8`), and `16578` sits under GMT-Master though it
reads like a Day-Date reference. `126710VTNR` is in the catalog but the green/black GMT is the
left-handed `126720VTNR`; worth checking that row. None of these were assigned a nickname.

## Sources

Market usage was taken from the published nickname guides - Bob's Watches, Loupe, Man of Many,
Superlative Watch Co, Watchguys, Diamond Club Miami - plus reference-specific checks for
`126710GRNR` (Bruce Wayne), `126713GRNR` (Bumblebee) and `116508-0013` (John Mayer, confirmed
against WristCheck and Wind Vintage listings).


---

# Image verification (round 2)

Column **E** now holds a catalog image URL for all 9,673 rows. Every row where a nickname had been
proposed was checked against its image: **928 images downloaded** (925 succeeded, 3 dead links),
rendered into **105 labelled contact sheets** and reviewed row by row.

Three more columns were added:

| Col | Header | Values |
|---|---|---|
| M | `ImageCheck` | `Confirmed by image` / `Corrected by image` / `Rejected by image` / `Needs review` / `Needs full-size image` / `Not image-checked - line-wide name` / `No nickname proposed` |
| N | `FinalNickname` | What to actually assign. Empty where the image rejected the proposal. |
| O | `ImageNote` | Why - the dial, bezel or bracelet detail the decision rests on. |

## Result

| ImageCheck | Rows |
|---|---|
| Confirmed by image | 283 |
| Corrected by image | 10 |
| Rejected by image | 554 |
| Needs review (image inconclusive or odd row) | 33 |
| Needs full-size image (Paul Newman dial calls) | 45 |
| Not image-checked - line-wide name | 1,937 |
| No nickname proposed | 6,808 |

**290 rows are image-confirmed and ready to assign.** Together with the 1,937 line-wide rows, 2,227
rows now carry a `FinalNickname`.

## What the images changed

The image pass cut the dial-dependent proposals hard. The reference alone was far too generous:

| Nickname | Proposed from the ref | Confirmed by image |
|---|---|---|
| Wimbledon | 196 | **8** |
| Buckley | 174 | **21** |
| Domino's | 55 | **2** |
| Palm Motif | 50 | **4** |
| Daytona Beach | 40 | **9** |
| Polar | 17 | **9** |
| Stella | 162 | 0 (all 162 rows sit on Day-Date refs already carrying President; no lacquered Stella dial seen) |

Corrections the images forced:

- **Root Beer is bezel-dependent, not reference-level.** `1675/3`, `1675/8`, `16753` and `16758`
  were all sold with black bezels too. 8 of the 19 proposed rows were rejected for exactly that.
- **Bluesy is dial-dependent.** Two `16613LB` rows have slate and champagne dials, not blue.
- **Batman vs Batgirl is visible.** `126710BLNR-0002` is on Jubilee - Batgirl; `-0003` is on Oyster -
  Batman.
- **Leopard belongs only to `116598SACO`.** The `116578SACO` / `116588SACO` rows have orange
  sapphire bezels and plain dials.
- **Coke, not Pepsi,** on four `16710` rows with red-and-black bezels; two more are all-black and
  take no nickname.
- **Great White,** not Double Red, on the `1665` with white dial text.
- **Z-Blue** on `116400GV-0002`; **Tiffany Dial** and **Celebration** swapped between two rows.
- **`116500LN` has yellow, purple and orange dials** in the catalog. Those are not Rolex dials -
  worth checking those three rows.

## Left for a human

- **45 Paul Newman rows** (`6239`, `6240`, `6241`, `6262`, `6263`, `6264`, `6265`): the art-deco
  sub-dial markers that define an exotic dial cannot be judged at catalog-thumbnail size. Needs the
  full-resolution image. The **49 rows already carrying Paul Newman** were checked and all look
  correct.
- **33 rows marked `Needs review`** - stone dials (malachite, tiger-eye, carnelian), a Mickey Mouse
  dial, aftermarket diamond bezels, a blacked-out Milgauss, a `5514/0` with no COMEX logo, and the
  nine `3484` rows whose model name says Monoblocco but whose case does not look like the `3525`.
- **CERN (`1019`) and Bart Simpson / Maxi (`5512`, `5513`)** cannot be settled from a product image
  at all - CERN needs provenance, the others need macro detail. Left unassigned.


---

# Round 3 — the line-wide names

Round 2 skipped every `Scope = Family / line-wide` row on a blanket rule ("an image cannot confirm a
line-wide name"). That was true for some of them and wrong for others. This round fixes the part
that was wrong, and verifies the rest against EveryWatch's own listing corpus instead.

## Image-checked (264 rows, 19 more contact sheets)

| Name | Rows | Verdict |
|---|---|---|
| **Thunderbird** | 99 | 97 confirmed — the rotating Turn-O-Graph bezel is visible on every one. 3 rows on ref `6202` flagged: it is a Turn-O-Graph, but it pre-dates the Datejust that got the Thunderbird name. |
| **Bubbleback** | 88 | 82 confirmed — the domed bubble case is visible. **7 rows on ref `4467` corrected to Ovettone** (oversized case, date window, and EveryWatch listings call it Ovettone). |
| **OysterQuartz** | 56 | All 56 confirmed — the integrated angular case and bracelet are unmistakable. |
| **Rolesium** | 12 | All 12 confirmed — steel case, platinum bezel. |
| **Bombé** | 7 | All 7 confirmed — the flared bombé lugs are visible. |

## Verified against EveryWatch listings (`watch` index, stage)

`watchTitle` is searchable (the `description` field's custom analyser is blocked at the gateway), so
each name was checked against how sellers and auction houses actually title Rolex listings:

| Term | Rolex listings | References they attach it to |
|---|---|---|
| Thunderbird | 2,979 (all brands) | `1625`, `16264`, `116261` + model "Datejust Turn-O-Graph" |
| Rolesium | 1,315 | `116622`, `126622`, `168622`, `169622`, `268622` |
| OysterQuartz | 6,114 | `17000`, `17013`, `17014`, `19018` |
| Bubbleback | 1,450 | `2940`, `3130`, `3131`, `3133`, `3372`, `5011`, `5028`, `5050`, `6050`, `6084`, `6085` |
| Ovettone | 363 | **`6105`, `6305`, `6104`, `6075`, `6352`, `4467`, `5030`, `6030`** — and `6084`/`6085` |
| Zenith (Daytona) | — | `16518`, `16520`, `16523`, `16528` |

Every one corroborated the assignment **except Ovettone**, which is the round's other finding.

## Ovettone is on the wrong references

I had put Ovettone on `6084` / `6085` / `6098` only. EveryWatch's listings are dominated by
**`6105` and `6305`**, with `6104`, `6075`, `6352`, `4467`, `5030` and `6030` also present, and
`6084` / `6085` a minority. `6098` does not appear at all.

In our catalog `6105` (11 rows) and `6305` (9 rows) currently sit under model "Datejust" with **no
nickname**. They should almost certainly carry Ovettone. That is a scope change, not a correction to
an existing row, so it is left for sign-off rather than written in.

## Still not verified

| Name | Rows | Why |
|---|---|---|
| President | 1,556 | The image cannot confirm it — but see below. |
| Zenith Daytona | 43 | The movement is inside the watch. Listings corroborate the refs. |
| Pre-Daytona / Pre-Explorer | 29 | An era judgement, not a visible feature. |
| Ovettone | 45 | On the refs above — pending the scope decision. |

**One thing worth raising about President:** the name comes from the President *bracelet*. A Day-Date
on a leather strap is not on one. That **is** visible in an image, so President is partly checkable
after all — it would mean ~1,556 more images and roughly 105 more contact sheets. Market usage is
loose (most sellers call any Day-Date a President), so this is a policy question before it is a
data question.


---

# Round 4 — reconciled against `Data/data.py`

`Data/data.py` holds `nicknameArray`: 145 reference-to-nickname entries, **34 of them Rolex**
(28 distinct nicknames), plus 3 Rolex nicknames with no reference at all (Great White, Big Red,
Double Red - all already covered on `1665` and `6263`/`6265`).

A new column **P `DataPyCheck`** records how each row relates to that list.

## The partial-reference trap

`data.py` references are bases, not full catalog references, and a plain "starts with" match is
wrong. The concrete collision in our data:

| data.py ref | Nickname | Would wrongly capture | Why that is wrong |
|---|---|---|---|
| **`1655`** | Freccione / Steve McQueen | **`16550`** (4 rows), `16559SACO` (1 row) | `16550` is a different Explorer II generation - the Polar/Rail Dial one, not the orange-hand `1655` |

Those 5 rows now carry an explicit **DO NOT inherit** warning in column P.

By contrast `6542` → `6542/0` and `6238` → `6238/0` **are** the same watch: the `/0` suffix is case
material, not a different reference. Rule of thumb: a `/` suffix extends the same reference; extra
digits make a different one.

Two `data.py` refs are not in our catalog at all: `6542` (we hold `6542/0`) and `5036` (a Killy ref
we do not hold).

## What data.py changed

| Ref | Was | Now | Evidence |
|---|---|---|---|
| **`126619LB`** | Smurf *(flagged)* | **Cookie Monster** | My image check caught the black dial; Smurf is the blue-dial `116619LB`. Sotheby's lots it as "Submariner Cookie Monster reference 126619LB". |
| **`116598TBR`** | *(nothing)* | **Eye of the Tiger** | The name covers three off-catalogue refs - `116588TBR`, `116598TBR`, `116589TBR`. We hold two of them. |
| **`6105`** (11 rows) | *(nothing)* | **Ovettone** | Triple-confirmed: data.py, 363 EveryWatch listings, and auction houses ("Ovettone = large Ovetto", 36mm Big Bubble Back). |
| **`3130`** (2 rows) | *(nothing)* | **Ovetto** | From data.py. Ovetto = the *small* bubbleback; the sibling `3131` is the ref explicitly documented, so confirm `3130` before publishing. |

## What data.py flagged as wrong in my work

| Ref | Issue |
|---|---|
| **`6098`** (10 rows) | I assigned Ovettone from reasoning alone. It appears in **no** source checked - not data.py, not EveryWatch listings, not the auction sources. Now `Needs review`. |
| **`6305`** (9 rows) | EveryWatch listings use Ovettone heavily for it, but data.py lists only `6105`. Adding a nickname to rows that had none is a scope change → `Needs sign-off`. |

## Where data.py and I agree but name it differently

Not conflicts - alias choices. All now merged into column I (`AltNames`):

| Ref | Mine | data.py |
|---|---|---|
| `3525` | Monoblocco | **Barilotto** - both correct; Barilotto = barrel case, Monoblocco = one-piece case. Auction houses use each. POW is a third. |
| `1655` | Steve McQueen | Freccione *(data.py has both)* |
| `6538` | Big Crown | James Bond |
| `5517` | MilSub | Militare |
| `16520` | Zenith Daytona | Zenith |
| `116598RBOW` | Rainbow Daytona | Rainbow |
| `6542/0` | Pepsi | Bakelite |

## Nicknames checked and found correct

`4767` / `6036` / `6236` Jean-Claude Killy (the family is **five** refs - `4767`, `4768`, `5036`,
`6036`, `6236`; my `4768` and data.py's `5036` are both valid, the two lists were just partial),
`116598SACO` Leopard, `8171` Padellone, `6062` Stelline, `5100` Texano, `16760` Fat Lady,
`116610LV` Hulk, `16610LV` Kermit, `126610LV` Starbucks, `116619LB` Smurf, `116613LB`/`126613LB`
Bluesy, `126710BLRO` Pepsi, `126711CHNR`/`126715CHNR` Root Beer, `126720VTNR` Sprite,
`116710BLNR` Batman, `6238` Pre-Daytona.

**One disagreement stands:** data.py calls `126710BLNR` "Batman". My image check shows `-0002` is on
a **Jubilee** bracelet (Batgirl) and `-0003` on an **Oyster** (Batman). data.py has no suffix, so it
cannot make that distinction - which is exactly the partial-reference problem. I kept the per-row
split and noted data.py's value in `AltNames`.


---

# Round 5 — trust levels and multiple names per reference

## Column Q `TrustLevel` — the filter

| TrustLevel | Rows | Refs | Nicknames | Meaning |
|---|---|---|---|---|
| `1 - ASSIGN` | 567 | 156 | 64 | Verified against the catalog image, and/or EveryWatch listings, and/or `data.py` + published sources. |
| `2 - ASSIGN (single source)` | 2 | 1 | 1 | Ovetto on `3130` - `data.py` only. |
| `3 - DECIDE FIRST` | 1,663 | 133 | 5 | Line-wide names, never verified. Policy call needed. |
| `4 - OPEN` | 102 | - | - | Unresolved. |
| `5 - IGNORE` | 7,339 | - | - | Rejected by image, or no market nickname exists. |

## Can one reference have several nicknames?

Three different cases, and they are not the same problem.

**1. Same ref, different nicknames on different catalog rows - the dial suffix separates them.**
`116400GV` (-0001 Glace Verte / -0002 Z-Blue), `124300` and `126000` (Tiffany Dial / Celebration),
`126710BLNR` (-0002 Batgirl on Jubilee / -0003 Batman on Oyster). Each row still carries one name.

**2. Same ref string, different nicknames, nothing in the ref to tell them apart.**
`1665` (Double Red / Great White), `6239` (Paul Newman / Crazy Doc), `6263` (Paul Newman / Big Red),
`6265` (Paul Newman / Big Red / Unicorn). The dial decides, not the reference - so no
"ref → nickname" rule can resolve these.

**3. One watch, several names in circulation at once.** These are now merged into `FinalNickname`,
semicolon-separated, **primary name first** - 304 of the 569 assignable rows carry more than one.

## What was merged, and what deliberately was not

Merged (same watch, interchangeable names): Monoblocco; Barilotto; Prisoner of War; POW ·
Thunderbird; Turn-O-Graph · Bubbleback; Bubble Back · Jean-Claude Killy; Dato-Compax ·
Root Beer; Rootbeer · SARU; Rainbow GMT · Steve McQueen; Freccione; Orange Hand ·
MilSub; Militare; Military Submariner · Big Crown / Small Crown; James Bond ·
Fat Lady; Sophia Loren; Coke · Pepsi; Bakelite; Pussy Galore *(ref `6542/0` only)* ·
Starbucks; Cermit; Kermit 2.0 · D-Blue; James Cameron · Ice Blue; Platona · Padellone; Frying Pan ·
Texano; Beta 21 · Sprite; Destro; Lefty · Glace Verte; GV · Celebration; Candy; Bubbles ·
Rainbow Daytona; Rainbow · Red Sea-Dweller; SD43 · Sea-Dweller 4000; SD4K ·
Double Red Sea-Dweller; DRSD · Red Submariner; Red Sub · Bombe; Bombay · Lightning Bolt; Honeycomb ·
John Mayer; Christmas Dial · Le Mans; 100th Anniversary Le Mans.

**Not merged, on purpose** - these name a *different* watch or dial on the same reference, so folding
them in would be wrong:

| Reference | Primary | Left in `AltNames` | Why |
|---|---|---|---|
| `6263` / `6265` | Paul Newman | Big Red, Oyster Sotto | different dials on the same ref |
| `16550` | Polar | Rail Dial, Cream Dial | different dials |
| `124300` | Tiffany Dial | Grape | the aubergine dial is a different watch |
| `1600`-series | Buckley | Linen, Wide Boy, Sigma | different dials |
| `126234` | Palm Motif | Wimbledon | different dial |
| `6241` | Paul Newman | John Player Special | different configuration |
| `16610LV` | Kermit | Flat Four / Fat Four | a bezel sub-variant, not a synonym |
| `1680` | Red Submariner | Nipple Dial | that name belongs to the gold `1680/8` |
| `126600` | Red Sea-Dweller | Single Red | Single Red is a `1665` name |
| `14000` | Domino's | 3-6-9 Explorer dial | a description, not a name |
| `126619LB` | Cookie Monster | SEGA, BMW, Sonic | real but far rarer usage |

## Loading note

`tbl_CAT_Catalog_d.NicknameId` is a single `int` FK, so a catalog row can hold only one of these.
Take the **first** name in `FinalNickname` as the value for the catalog row; the rest are synonym
candidates for `tblNickName.ParentId` on the app side.


---

# Round 6 — closing the "assigned without looking" gap

An audit of the assignable rows found **15 that had been set from sources (data.py, EveryWatch
listings, web research) without the catalog image ever being opened**. Those, plus 54 `4 - OPEN`
rows worth a look, were fetched (69 images, 67 downloaded) and reviewed.

## The 15 that were assigned on sources alone - all now image-checked

| Ref | Rows | Nickname | What the image shows |
|---|---|---|---|
| `6105` | 11 | Ovettone | the oversized Oyster/Datejust case - **confirmed** |
| `3130` | 2 | Ovetto | small domed bubbleback with sub-seconds - **confirmed** (moves from TrustLevel 2 to 1) |
| `116598TBR` | 1 | Eye of the Tiger | gold Daytona, diamond bezel, tiger-stripe pave dial - **confirmed** |
| `126619LB-0003` | 1 | Cookie Monster | black dial, blue bezel - **confirmed** (and confirms it is not the blue-dial Smurf) |

All four held up. But they should not have been in the assignable set before this check.

## Open rows the images resolved

| Ref | Rows | Was | Now |
|---|---|---|---|
| `6305` | 9 | Needs sign-off | **Ovettone** - the same oversized case family as `6105`, red date wheel; EveryWatch listings agree |
| `6202` | 3 | Needs review | **Turn-O-Graph** - the rotating graduated bezel is clearly there, but Thunderbird belongs to the later Datejust, so the generic name is correct here |
| `6098` | 10 | Needs review | **Rejected** - front-on images show a flat Oyster case, not the oversized Ovettone profile, and no source checked backs `6098` |
| `3484` | 9 | Needs review | **Rejected** - non-Oyster snap-back chronographs with stepped lugs, not the one-piece Monoblocco case of the `3525`. **The catalog model name for `3484` ("Oyster Chronograph Antimagnetique Monoblocco") looks wrong** and is worth a separate fix. |

## Result

| TrustLevel | Rows |
|---|---|
| `1 - ASSIGN` | **581** (159 refs) |
| `3 - DECIDE FIRST` | 1,663 |
| `4 - OPEN` | 71 |
| `5 - IGNORE` | 7,358 |

**Every row in the assignable set has now had its catalog image looked at - 0 remaining.**
TrustLevel 2 is empty; `3130` was promoted to 1.

## Files

| What | Where |
|---|---|
| Full row-level map (9,673 rows) | `Output/Data/RolexNicknames/Rolex_Nickname_Reference_Map.csv` |
| Sheet as it was before the write | `Output/Data/RolexNicknames/Sheet1_before_20261105_135210.csv` |
| **Image-verified result, all 9,673 rows** | `Output/Data/RolexNicknames/Rolex_Nickname_ImageVerified.csv` |
