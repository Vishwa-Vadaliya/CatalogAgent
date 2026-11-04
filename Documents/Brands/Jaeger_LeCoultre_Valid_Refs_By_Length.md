---
type: Document
title: Jaeger-LeCoultre: valid refs by length and type
description: Breakdown of Jaeger-LeCoultre clean reference values by format type and length, with confidence bands and supporting evidence.
tags: [documents, jaeger-lecoultre, reference-validation, confidence]
timestamp: 2026-10-24
---

# Jaeger-LeCoultre: valid refs by length and type

Generated 2026-10-21 from the tab `Jaeger-LeCoultre final refs` (workbook RawRefsToAssign).

Scope: the refs kept clean (blank `PartialRefFlag`): **2484 of 3683 refs** on the tab. The other 1199 are flagged and excluded (already in the catalog, duplicate spellings, partials, invalid). Watches = how many watch rows in the sheet carry the ref.

## How to read the confidence

- **Confidence is my judgement of a whole format group, not a measured probability.** A ref is rated high only when its format is confirmed on outside sources and/or our catalog. Individual refs inside a group were mostly **not** checked one by one (see section 3).
- **Linked** = the row has a ReferenceNumberId, so the database had already matched it to a catalog reference. That is a strong prior that the ref is real. Refs found only through the raw column have no link.
- Bands: High about 85-90%, Medium-high about 75-80%, Medium about 60-65%, Low-medium about 40-45%, Low about 30%.

## 1. Summary by format type

| Type | Refs | Watches | Linked | Examples | Confidence |
|---|---:|---:|---:|---|---|
| Q + 7 digits | 717 | 15077 | 89% | `Q1768470`, `Q3732420` | High (~90%) |
| Dotted 3.1.2 | 402 | 5191 | 68% | `271.8.61`, `180.1.99` | Medium-high (~80%) |
| Plain number 2-5 digits | 400 | 1971 | 100% | `2285`, `3151` | Low-medium (~45%) |
| Dotted 3-part, other shape | 325 | 1542 | 53% | `165.7.3`, `141.010.1` | Medium (~60%) |
| Q + 6 digits + letter | 131 | 2243 | 77% | `Q151842A`, `Q151812A` | High (~85%) |
| Long dotted 3.3.3 | 119 | 411 | 61% | `250.840.862`, `180.140.990` | Medium (~60%) |
| Dotted 2-part, 4 digits.2 digits | 117 | 816 | 72% | `9041.42`, `1670.42` | Medium (~65%) |
| E-code | 101 | 2411 | 78% | `E855`, `E859` | Medium-high (~75%) |
| Dotted 3.1.2 with .S | 57 | 581 | 84% | `140.8.80.S`, `140.2.98.S` | Medium-high (~80%) |
| Q + 3 digits + letter + 3 digits | 42 | 1132 | 98% | `Q178T471`, `Q192T470` | High (~85%) |
| Dotted with a letter segment | 36 | 242 | 56% | `150.T.42`, `151.T.67.S` | Medium (~65%) |
| Dotted 2-part, other | 35 | 154 | 100% | `875.21`, `200.701` | Low-medium (~40%) |
| Q-code, other letter pattern | 2 | 2 | 0% | `Q16634E7`, `Q177T47V` | Medium-high (~80%) |

Why each type was kept:

- **Q + 7 digits** (High, ~90%): The current JLC reference format. Confirmed on JLC product pages (through dealer copies), Watchbase, Loupe and dealers (Q3858520, Q1238420, Q9038670, Q2661120, Q1338421). The catalog holds 582 refs of this shape.
- **Q + 6 digits + letter** (High, ~85%): A real JLC format. Q151842A (Master Calendar) and Q413812J are confirmed on dealer pages, and the catalog holds 103 refs of this shape.
- **Q + 3 digits + letter + 3 digits** (High, ~85%): A real JLC format. Q178T471, Q178T470 and Q177T47V are confirmed on dealer pages, and the catalog holds 69 refs of this shape.
- **Q-code, other letter pattern** (Medium-high, ~80%): Q refs with letters in the last characters (Q177T47V Valentino Rossi edition, confirmed on three dealer pages; Q16634E7 Master Grand Tourbillon, found on a Wristler page and in the Q16634E.. family). Both were also checked against the sheet images.
- **Dotted 3.1.2 with .S** (Medium-high, ~80%): Legacy JLC catalog number. Dealers and auction houses write it this way (140.8.98.S, 176.8.40.S, 145.8.79.S, 142.8.92.S), and modern Q refs list it as their alternate reference. There is no official decoder and the meaning of the S is unknown.
- **Dotted 3.1.2** (Medium-high, ~80%): Legacy number in the XXX.C.MM format: case code, case material, movement code. The user reports that this structure is found engraved on the caseback; one verified owner post (270.8.62 on a Reverso) and the collectors' wiki (engraved case code xxx-c-mm) agree, so it may be the engraved case code as well as the older reference. Seen on Loupe and auction pages (145.8.79, 140.8.98, 142.8.92). Treated as the same ref as its .S spelling where both exist: the .S form stays clean and the base is flagged.
- **Long dotted 3.3.3** (Medium, ~60%): A longer legacy spelling (for example 140.840.987). The shape fits the legacy scheme, but only a few were seen on dealer pages.
- **Dotted with a letter segment** (Medium, ~65%): Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S). Accepted by pattern; a few were seen on dealer pages.
- **Dotted 3-part, other shape** (Medium, ~60%): Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages). Accepted by pattern.
- **Dotted 2-part, 4 digits.2 digits** (Medium, ~65%): Vintage-style refs. 9107.21 and 6029.21 are seen on dealer pages as the Ref.; the .21 may be a gold code, unconfirmed.
- **Dotted 2-part, other** (Low-medium, ~40%): Two-part dotted values (140.025, 230.8, 11033.71). Many look like truncated forms of longer refs or are unverified. Kept only because they were not flagged.
- **E-code** (Medium-high, ~75%): Real 1960s Memovox and vintage references (E855 and similar on dealer pages). No source I found explains the E prefix.
- **Plain number 2-5 digits** (Low-medium, ~45%): Short vintage-style model numbers (2265 is confirmed as a Memovox Ref.). Others look like years or serials. Kept at your request, mostly because the database had linked them.

## 2. Breakdown by reference length (characters)

| Length | Refs | Watches | Linked | Main types (share of refs) |
|---:|---:|---:|---:|---|
| 2 | 5 | 13 | 100% | Plain number 2-5 digits 100% |
| 3 | 50 | 268 | 100% | Plain number 2-5 digits 100% |
| 4 | 260 | 3290 | 95% | Plain number 2-5 digits 73%; E-code 27% |
| 5 | 170 | 618 | 97% | Plain number 2-5 digits 92%; E-code 7%; Dotted 2-part, other 1% |
| 6 | 20 | 120 | 80% | Dotted 2-part, other 55%; E-code 45% |
| 7 | 168 | 1265 | 69% | Dotted 2-part, 4 digits.2 digits 70%; Dotted 3-part, other shape 17%; Dotted 2-part, other 7% |
| 8 | 1330 | 23821 | 81% | Q + 7 digits 54%; Dotted 3.1.2 30%; Q + 6 digits + letter 10% |
| 9 | 250 | 1233 | 59% | Dotted 3-part, other shape 98%; Dotted with a letter segment 2% |
| 10 | 104 | 721 | 67% | Dotted 3.1.2 with .S 55%; Dotted 3-part, other shape 35%; Dotted with a letter segment 11% |
| 11 | 94 | 276 | 60% | Long dotted 3.3.3 93%; Dotted 3-part, other shape 6%; Dotted with a letter segment 1% |
| 12 | 27 | 132 | 59% | Long dotted 3.3.3 100% |
| 13 | 6 | 16 | 67% | Long dotted 3.3.3 83%; Dotted 3-part, other shape 17% |

### Length 2: 5 refs, 13 watches, 100% linked to the database

- **Plain number 2-5 digits**: 5 refs (100%), e.g. `51`, `72`, `66`. Confidence Low-medium (~45%). Short vintage-style model numbers (2265 is confirmed as a Memovox Ref.).
- Average confidence for this length: **about 45%** (Low-medium 100%).

### Length 3: 50 refs, 268 watches, 100% linked to the database

- **Plain number 2-5 digits**: 50 refs (100%), e.g. `201`, `182`, `195`. Confidence Low-medium (~45%). Short vintage-style model numbers (2265 is confirmed as a Memovox Ref.).
- Average confidence for this length: **about 45%** (Low-medium 100%).

### Length 4: 260 refs, 3290 watches, 95% linked to the database

- **Plain number 2-5 digits**: 189 refs (73%), e.g. `2285`, `3151`, `6001`. Confidence Low-medium (~45%). Short vintage-style model numbers (2265 is confirmed as a Memovox Ref.).
- **E-code**: 71 refs (27%), e.g. `E855`, `E859`, `E903`. Confidence Medium-high (~75%). Real 1960s Memovox and vintage references (E855 and similar on dealer pages).
- Average confidence for this length: **about 53%** (Low-medium 73%, Medium-high 27%).

### Length 5: 170 refs, 618 watches, 97% linked to the database

- **Plain number 2-5 digits**: 156 refs (92%), e.g. `20002`, `24000`, `17837`. Confidence Low-medium (~45%). Short vintage-style model numbers (2265 is confirmed as a Memovox Ref.).
- **E-code**: 12 refs (7%), e.g. `E2643`, `E2647`, `E2646`. Confidence Medium-high (~75%). Real 1960s Memovox and vintage references (E855 and similar on dealer pages).
- **Dotted 2-part, other**: 2 refs (1%), e.g. `270.6`, `140.6`. Confidence Low-medium (~40%). Two-part dotted values (140.025, 230.8, 11033.71).
- Average confidence for this length: **about 47%** (Low-medium 93%, Medium-high 7%).

### Length 6: 20 refs, 120 watches, 80% linked to the database

- **Dotted 2-part, other**: 11 refs (55%), e.g. `875.21`, `564.42`, `500.21`. Confidence Low-medium (~40%). Two-part dotted values (140.025, 230.8, 11033.71).
- **E-code**: 9 refs (45%), e.g. `E13001`, `E11005`, `E22059`. Confidence Medium-high (~75%). Real 1960s Memovox and vintage references (E855 and similar on dealer pages).
- Average confidence for this length: **about 56%** (Low-medium 55%, Medium-high 45%).

### Length 7: 168 refs, 1265 watches, 69% linked to the database

- **Dotted 2-part, 4 digits.2 digits**: 117 refs (70%), e.g. `9041.42`, `1670.42`, `1006.01`. Confidence Medium (~65%). Vintage-style refs.
- **Dotted 3-part, other shape**: 29 refs (17%), e.g. `165.7.3`, `155.2.9`, `170.7.8`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- **Dotted 2-part, other**: 12 refs (7%), e.g. `200.701`, `215.019`, `140.118`. Confidence Low-medium (~40%). Two-part dotted values (140.025, 230.8, 11033.71).
- **E-code**: 9 refs (5%), e.g. `E300505`, `E300105`, `E300606`. Confidence Medium-high (~75%). Real 1960s Memovox and vintage references (E855 and similar on dealer pages).
- **Dotted with a letter segment**: 1 refs (1%), e.g. `159.T.3`. Confidence Medium (~65%). Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S).
- Average confidence for this length: **about 63%** (Medium 88%, Low-medium 7%, Medium-high 5%).

### Length 8: 1330 refs, 23821 watches, 81% linked to the database

- **Q + 7 digits**: 717 refs (54%), e.g. `Q1768470`, `Q3732420`, `Q2663420`. Confidence High (~90%). The current JLC reference format.
- **Dotted 3.1.2**: 402 refs (30%), e.g. `271.8.61`, `180.1.99`, `260.3.86`. Confidence Medium-high (~80%). Legacy number in the XXX.C.MM format: case code, case material, movement code.
- **Q + 6 digits + letter**: 131 refs (10%), e.g. `Q151842A`, `Q151812A`, `Q176244G`. Confidence High (~85%). A real JLC format.
- **Q + 3 digits + letter + 3 digits**: 42 refs (3%), e.g. `Q178T471`, `Q192T470`, `Q184T470`. Confidence High (~85%). A real JLC format.
- **Dotted with a letter segment**: 17 refs (1%), e.g. `150.T.42`, `193.J.22`, `231.L.50`. Confidence Medium (~65%). Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S).
- **Dotted 2-part, other**: 10 refs (1%), e.g. `11074.71`, `11033.71`, `16190.22`. Confidence Low-medium (~40%). Two-part dotted values (140.025, 230.8, 11033.71).
- **Dotted 3-part, other shape**: 9 refs (1%), e.g. `161.64.2`, `17.12.24`, `260.51.1`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- **Q-code, other letter pattern**: 2 refs (0%), e.g. `Q16634E7`, `Q177T47V`. Confidence Medium-high (~80%). Q refs with letters in the last characters (Q177T47V Valentino Rossi edition, confirmed on three dealer pages; Q16634E7 Master Grand Tourbillon, found on a Wristler page and in the Q16634E.
- Average confidence for this length: **about 85%** (High 67%, Medium-high 30%, Medium 2%, Low-medium 1%).

### Length 9: 250 refs, 1233 watches, 59% linked to the database

- **Dotted 3-part, other shape**: 244 refs (98%), e.g. `141.010.1`, `140.025.5`, `140.060.1`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- **Dotted with a letter segment**: 6 refs (2%), e.g. `192.H.470`, `191.T4.97`, `160.T.125`. Confidence Medium (~65%). Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S).
- Average confidence for this length: **about 60%** (Medium 100%).

### Length 10: 104 refs, 721 watches, 67% linked to the database

- **Dotted 3.1.2 with .S**: 57 refs (55%), e.g. `140.8.80.S`, `140.2.98.S`, `146.3.34.S`. Confidence Medium-high (~80%). Legacy JLC catalog number.
- **Dotted 3-part, other shape**: 36 refs (35%), e.g. `140.111.1N`, `140.8.872B`, `140.840.87`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- **Dotted with a letter segment**: 11 refs (11%), e.g. `151.T.67.S`, `193.C.78.S`, `161.L.61.S`. Confidence Medium (~65%). Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S).
- Average confidence for this length: **about 71%** (Medium-high 55%, Medium 45%).

### Length 11: 94 refs, 276 watches, 60% linked to the database

- **Long dotted 3.3.3**: 87 refs (93%), e.g. `250.840.862`, `180.140.990`, `266.112.005`. Confidence Medium (~60%). A longer legacy spelling (for example 140.840.987).
- **Dotted 3-part, other shape**: 6 refs (6%), e.g. `840.982.84B`, `140.240.80S`, `142.840.29B`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- **Dotted with a letter segment**: 1 refs (1%), e.g. `344.23.L5.S`. Confidence Medium (~65%). Legacy refs with a letter in the middle (192.T.25, 174.8.C1, 151.T.67.S).
- Average confidence for this length: **about 60%** (Medium 100%).

### Length 12: 27 refs, 132 watches, 59% linked to the database

- **Long dotted 3.3.3**: 27 refs (100%), e.g. `142.240.922B`, `270.840.544B`, `140.840.987B`. Confidence Medium (~60%). A longer legacy spelling (for example 140.840.987).
- Average confidence for this length: **about 60%** (Medium 100%).

### Length 13: 6 refs, 16 watches, 67% linked to the database

- **Long dotted 3.3.3**: 5 refs (83%), e.g. `140.840.987SB`, `142.840.927SB`, `266.992.449GT`. Confidence Medium (~60%). A longer legacy spelling (for example 140.840.987).
- **Dotted 3-part, other shape**: 1 refs (17%), e.g. `146.640.956.B`. Confidence Medium (~60%). Dotted refs with a different digit grouping, mostly the 3.3.1 form (for example 140.025.5 and 145.202.5, both seen as Albatross refs on dealer pages).
- Average confidence for this length: **about 60%** (Medium 100%).

## 3. How much was verified

- Overall average confidence across the 2484 clean refs, by the rubric above: **about 72%**. About **79%** of the refs are linked to the database.
- Individually confirmed on the web in this work: `Q3858520`, `Q1238420`, `Q9038670`, `Q2661120`, `Q1338421`, `Q151842A`, `Q413812J`, `Q178T471`, `Q178T470`, `Q177T47V`, `E855`, `2265`, `9107.21`, `6029.21`, and the dotted refs `145.8.79`, `140.8.98`, `176.8.40.S`, `142.8.92`, `142.2.92`, `145.8.31`, `140.2.80`, `145.2.79`, `140.2.93`.
- **Everything else is accepted by pattern:** the format is confirmed on a sample and the ref was not flagged. Pattern confidence is not the same as per-item confirmation.
- Search limits: JLC's own site and several dealers refuse direct access (HTTP 403), so most checks use search results, Loupe pages and dealer pages. 'Not found' means 'not surfaced', not 'does not exist'.

## 4. Weakest groups to review first

- **Plain number 2-5 digits**: 400 refs (Low-medium, ~45%).
- **Dotted 3-part, other shape**: 325 refs (Medium, ~60%).
- **Long dotted 3.3.3**: 119 refs (Medium, ~60%).
- **Dotted 2-part, other**: 35 refs (Low-medium, ~40%).
- On the clean refs, 438 have no model name, 194 no dial colour, 82 no case material and 96 no image, so many of the weak refs also have thin supporting data.

## 5. What is not in this list

- Flagged refs (1199): already in the catalog (452), duplicate spellings, partials, and refs flagged invalid or unconfirmed.
- Groups never written to `FinalRef`: 847 short plain numbers and 260 dotted 9.9 values from Phase B, other joined pairs, digits+letter without a Q form, Q-less codes and unrecognised shapes.
- Plain 6-7 digit numbers with no Q counterpart (likely case serials) and calibre codes (K825).