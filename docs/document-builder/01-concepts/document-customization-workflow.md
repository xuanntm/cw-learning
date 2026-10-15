# Document Customization Workflow (5 steps)

How to customise a CW document with Document Builder. This is distilled from the 4 exports in [`../samples/`](../samples/):

| File | What it is | Rows |
|---|---|---|
| `01_cw_document_menu_for_shipment.xlsx` | **Document menu** config for the Shipment module: every item a user can print/email from a shipment | 467 |
| `02_templates.xlsx` | **Template** registry: system templates + our custom ones | 469 |
| `03_available_fields.xlsx` | **Element library**: the building blocks ("fields"/sections) that can be put on a template | 1,812 |
| `04_cw_custom_document_sample.xlsx` | One **custom template's layout**: the ordered list of sections that make up the document | 28 |

> **Mental model:** a **Document menu item** points to a **Template**. A template is an ordered stack of **Sections**, and each section is one **Element** from the library, placed in a page zone (header/body/footer) with an optional **Filter** macro.

```
Shipment ──► Document menu item ──► Template ──► Sections (ordered) ──► Elements from the library
            (01: name, path,        (02: System    (04: Order, Type,      (03: Category, Type,
             filter, format)         Y/N)           Section, Filter)       Name)
```

---

## Step 1: Select the document menu

The document menu (file 01) controls **what appears** when a user opens Documents on a shipment, and **when**.

Key columns:

| Column | Meaning | Example values |
|---|---|---|
| `Name` | Menu item label shown to the user | `Arrival Notice`, `Job Sheet (BCN)` |
| `Sys.` | `Y` = shipped by WiseTech, `N` = created by us | 423 Y / 44 N |
| `Publish` | Whether the item is active in the menu | `Y`/`N` (`Bill of Lading Test` = N) |
| `Index` | Sort order inside its submenu | `0`, `1`, `2` … |
| `Menu Path` | Submenu the item sits under | `Arrival/Arrival Notice`, `Customized Documents/Job Sheet` |
| `Filter` | Macro expression that must be true for the item to show | `"<CompanyCode>"=="BCN"`, `"<JS_TransportMode>" == "SEA"` |
| `Allow Modification` | Whether the document can be customised | Doc Builder versions = `Y`, legacy = `N` |
| `Def Attach Type` | Output format when attached/emailed | `PDF`, `XLSX`, `XLS` |
| `Dir` | Shipment direction the item applies to *(inferred)* | `ANY`, `ARV` (arrival), `DEP` (departure) |
| `Doc` | Document type/category code *(meaning not confirmed)* | `NCT`, `CNE`, `CNR`, `TRN`, `FES` … |
| `Shortcut` | Keyboard shortcut | `CtrlShiftH`, `CtrlShiftL` |

Observations:
- **Top-level menu paths** for shipments: `Customs` (119), `Arrival` (52), `Departure` (44), `Legacy Documents/*` (~80), `Exporter Documents`, `Declaration Documents`, `Customized Documents/*`, `India Customised Docs/*`.
- **Doc Builder vs legacy:** many documents exist twice, e.g. `Arrival Notice` under `Arrival/Arrival Notice` (Allow Modification = **Y**) and under `Legacy Documents/Arrival/Arrival Notice` with filter `"<UseDocBuilderFreightDocs>" != "Y"` (Allow Modification = **N**). **Only the Doc Builder version can be customised.** The legacy one only shows when the Doc Builder freight docs setting is off.
- **Our custom items** (Sys = N) mostly live under `Customized Documents/...` or `India Customised Docs/...`. They are scoped to one company with a filter such as `"<CompanyCode>"=="BIN"`.
- Filters can get very complex. The custom `Bill Of Lading.` item uses a long expression over `<JS_ReleaseType>` and `<JS_HouseBillOfLadingType>` to choose between several HBL variants.

**Action:** find the menu item you want to change and note its menu path and filter. Check that `Allow Modification = Y`.

## Step 2: Select a suitable template

Templates (file 02) are the layouts behind menu items.

- `System = Y`: standard WiseTech templates (e.g. `Bill Of Lading CargoWise`, `Generic Commercial Invoice`, `ARInvoice`, `Booking Confirmation`). **Don't edit these directly.**
- `System = N`: our customised templates (~200). Naming convention seen:
  - `H56.Customizations.<Client>_HBL_<variant>_<date>`: client-specific House Bills (Blank / Preprinted / NN = non-negotiable / OBL / SWB / T&C)
  - `H56.Customizations.<CC>.<DocName>_<version>`: country-specific docs (e.g. `CN.Job_Sheet_<branch>`, `VN.Manifest_1..5`, `IN.IAL_<port>`)
  - `H56.<DocName>`: shared custom docs (e.g. `H56.HAZManifest`, `H56.IndiaDeliveryOrder`)
  - `... - Copy`, `Copy of ...`, `Copy test`: clones still in progress or leftovers (cleanup candidates)

**Action:** start from the template that is **closest in content and layout** to what you need. Use a system template for a new document type, or an existing `H56.Customizations.*` template when you need a variant of one we already customised.

## Step 3: Clone the selected template

Never modify a system template. Clone it instead, and the copy becomes a `System = N` template you own.

- Cloning gives the name `Copy of <original>` or `<original> - Copy`. **Rename it straight away** using the convention: `H56.Customizations.<Client|CC>.<DocName>_<version or date>`.
- Version by suffix (`_v7`, `_v7.1` … `_v7.6 (OBR)`, or `_28May2025`) and keep the previous version until the new one is live. That is why several versions of the same template sit side by side.

## Step 4: Add, remove or update sections in the template

A template is an **ordered list of sections** (file 04). Each section has:

| Column | Meaning |
|---|---|
| `Order` | Position on the page, top to bottom |
| `Type` | Page **zone** the section is placed in (see below) |
| `Section Name` | The element from the library (file 03) |
| `Filter` | Optional macro: the section only renders when it's true |

**Zone codes** seen in the sample *(meanings inferred from the codes and how they're used)*:

| Code | Zone | Holds element type |
|---|---|---|
| `HFP` | Header, **F**irst **P**age | GEN |
| `HS2` | Header, **S**ubsequent pages (page **2**+) | GEN |
| `BDY` | Body: fixed block | GEN |
| `BEX` | Body: **ex**panding block (lists/repeating rows/multi-line text) | BEX |
| `FAL` | Footer, **A**l**l** pages | GEN |

**Rule of thumb from the data:** element library `Type` = `GEN` (fixed block) goes into `HFP`/`HS2`/`BDY`/`FAL`, and `Type` = `BEX` (repeating/expanding) goes into `BEX`. Every section in the sample follows this rule.

Common edits:
- **Add:** pick an element from the library (file 03). Browse by `Category` (e.g. `Headings`, `Freight Job Info/Refs`, `Containers`, `Notes`, `Opening/Closing/Signoff`, `Footer`), insert it at the right `Order` and in the right zone.
- **Remove:** delete the section row. Nothing else depends on it.
- **Update:** swap an element for a variant (e.g. `Container List (Number/Seal/Type/...)` ↔ the `... MBOL/IT Number ...` one), reorder, or add a **filter** so it only shows in some cases:
  - by mode: `"<JS_TransportMode>" == "SEA"` / `!= "SEA"`
  - by country: `"<CompanyCountryCode>" == "MY"`
  - "show only if it has data": `"<Consignor.CompanyNameAndAddress>" != ""`
  - mutually exclusive variants: two sections with opposite filters (`"<HasContainersNewMBOL>" != "Y"` / `== "Y"`)
- **Custom elements:** when no library element fits, a custom element is built. Ours are prefixed `H56` (252 of the 1,812 elements, e.g. `H56 Signoff`, `H56 Recipient with Available Date + Storage Date`).

See [`../02-templates/custom-document-sample-anatomy.md`](../02-templates/custom-document-sample-anatomy.md) for a full walkthrough of sample 04.

## Step 5: Save and share as a new template (optional)

- Save the template under its final name and version.
- To make it available to users, **add or point a document menu item** (back in Step 1) at it:
  - set the `Menu Path` (usually `Customized Documents/<area>`)
  - set the `Filter` to scope it (e.g. `"<CompanyCode>"=="BSG"`) so other companies/branches don't see it
  - set `Publish = Y`, `Index` for ordering, and `Def Attach Type` (PDF/XLSX)
- **Test in UAT first:** print from a real shipment that matches the filter, then one that doesn't, and check that conditional sections show and hide correctly.
- Retire old versions by un-publishing their menu items (`Publish = N`), not by deleting them straight away.

---

## Open questions

- [ ] Which column or screen links a **menu item to its template**? The menu export (01) has no template-name column.
- [ ] Confirm the zone codes (HFP/HS2/BDY/BEX/FAL) and check whether others exist (e.g. a first-page footer or last-page footer).
- [ ] Meaning of the `Doc` codes (`NCT`, `CNE`, `CNR`, `TRN`, `FES`, `FWI`, …) and `Dir` values.
- [ ] Meaning of `Draft` (`BTH`), `Addr.` (`OFF`), `Archive` (`NO`), `Pack`, `Sign By`.
- [ ] Element type `PFT` (one element: *Current Branch Bank Account Details + Disbursements Total*): probably a "page footer total"? Confirm.
- [ ] How custom `H56 ...` elements are built: in Document Builder itself, or as a separate customisation package?
- [ ] Who approves and publishes new templates (change control)?
