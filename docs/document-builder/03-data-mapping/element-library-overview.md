# Element Library Overview

Source: [`../samples/03_available_fields.xlsx`](../samples/03_available_fields.xlsx). It has 1,812 elements with the columns `Category | Type | Name`.

These "available fields" are **pre-built sections** (blocks that each render one or more fields), not single data fields. You build a template by stacking them (see [`../01-concepts/document-customization-workflow.md`](../01-concepts/document-customization-workflow.md)).

## Element types

| Type | Count | Meaning *(inferred)* | Placed in zone |
|---|---|---|---|
| `GEN` | 1,314 | Generic fixed-size block | `HFP`, `HS2`, `BDY`, `FAL` |
| `BEX` | 495 | Body **ex**panding block: lists, repeating rows, multi-line text | `BEX` |
| `PFT` | 1 | Unknown, possibly a page-footer total (`Current Branch Bank Account Details + Disbursements Total`) | ? |

## Categories (top 20)

| Category | Count | Typical use |
|---|---|---|
| Freight Job Info/Refs | 571 | Parties, references, packages, goods, routes, order manager |
| Invoice | 211 | AR invoice bodies, totals, country-specific invoice settings |
| Warehouse | 199 | WMS docs: packing lists, receipts, pick/pack footers |
| Landscape | 131 | Landscape variants of headers, manifests and container lists |
| Headings | 122 | Logos, document titles, recipient blocks |
| Transaction | 115 | Accounting transaction docs |
| Containers | 62 | Container lists and counts |
| Organisations | 46 | Org/address blocks |
| Warehouse Invoice | 25 | |
| Notes | 25 | Note/remarks blocks by note type |
| Opening/Closing/Signoff | 20 | Opening/closing text by report name, signoffs |
| Rating(s) / Quotations | 35 | Pricing pages (two spellings in the data) |
| Netting | 16 | |
| Other | 15 | Separators, misc |
| Header / Footer | 15 / 6 | Page headers/footers |
| Warehouse Cartage Advice | 13 | |
| ISF | 13 | US Importer Security Filing |
| Transport Legs | 12 | |
| Warehouse PickingSlip | 10 | |
| US Recon Declaration | 9 | |

## Naming conventions

- **`H56 ...`** = our custom elements (252 of them). Examples: `H56 Signoff`, `H56 Remarks`, `H56 Invoice Document Title`, `H56 Container List (Number/Seal/Type) with Container Fee (TH)`, plus country-specific ones (`THA`, `KH`, `TH`, `BID`).
- **`A + B + C`** in a name = the element renders those fields together in one block, e.g. `Packages + Payment Type + Load and Discharge Ports`.
- **`(…)` in list names** = the columns of a repeating list, e.g. `Container List (Number/Seal/Type/Weight/Volume/Packs)`.
- **`(Landscape)`** suffix = a variant for landscape page orientation.

## How to find the right element

1. Filter by **Category** for the area (headings, parties, containers, notes …).
2. Filter by **Type**: use `BEX` if the content repeats (containers, routes, lines, notes), otherwise `GEN`.
3. Read the name: it lists the fields the block shows.
4. Check for an existing `H56` variant before asking for a new custom element.
