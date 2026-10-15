# Prod vs UAT: Document Menu & Templates

Compared files (in `../samples/`, gitignored):

| | UAT *(assumed: files 01/02)* | PROD (files 05/06) |
|---|---|---|
| Document menu (shipment) | `01_cw_document_menu_for_shipment.xlsx`: 467 items (423 system / 44 custom), 30 columns | `05_prod_document_menu.xlsx`: 467 items (423 system / 44 custom), **19 columns** |
| Templates | `02_templates.xlsx`: 469 (262 system / 207 custom) | `06_prod_templates.xlsx`: 482 (263 system / 219 custom) |

> The Prod menu export stops at `Delivery Restriction Description`. The columns `Description` … `Line Spacing` (Sign By, Shortcut, Draft, Archive, etc.) weren't exported, so they can't be compared.

## Summary

| Area | Identical | Differs / UAT only | Differs / Prod only |
|---|---|---|---|
| Menu items (19 common columns) | 447 | 20 rows | 20 rows |
| Templates (name + system flag) | 454 | 15 | 28 |

**Main finding:** for custom documents, **Prod is ahead of UAT**. 26 custom templates and several menu changes exist **only in Prod**, so they were built or changed in Prod without first going through this UAT. UAT also holds India work that hasn't been promoted (or that Prod has since replaced).

---

## 1. Document menu differences

### Custom items: changed

| Item | UAT | PROD | Note |
|---|---|---|---|
| IN Customs Letter, IN Empty Drop-Off Letter, IN Haz Manifest, IN IGM Cargo Description | no filter (everyone sees them) | filter on **`<LoginCode>`** (3 specific users) | ⚠️ New filter type: restricted **per user login**, not per company |
| Job Sheet | no filter | `"<CompanyCode>"=="LKH"` | Scoped down in Prod |
| Job Sheet (Landscape) | no filter | `CompanyCode` = LKH **or** BTW | Scoped down in Prod |
| Job Sheet (BCN), Job Sheet (MCN) | Publish = **Y** | Publish = **N** | Retired in Prod (still live in UAT) |
| India Import Manifest | XLS, Web Visible = N | **XLSX**, Web Visible = **Y** | Format + web portal visibility changed in Prod |

### Custom items: only in one environment

| Only in UAT | Only in PROD |
|---|---|
| IN Delivery Order CFS, IN Delivery Order Factory | IN Delivery Order *(single item replacing the two)*, LoginCode-filtered |
| Import Advance List ×6 (BMCT, Chennai, GTI, Mundra, NSICT, NSIGT), XLSX | Job Sheet (AMY / BBN / BMY / DMY / SMY): Malaysia branches, one per `CompanyCode` |
| Net Suite Job Sheet (XLSX, no menu path) | Job Sheet V.2 (XLSX, no filter) |
| | TH Container List Discharge, TH List in Report (unpublished, so probably in development) |

Note: `Job Sheet (BBN)` in Prod has **Allow Modification = N**, unlike every other custom item.

### System items (CW version differences)

| Item | UAT | PROD |
|---|---|---|
| Worksheet SAD 509 (`CTY=ZA`) | ✅ | ❌ |
| MPI Application Cover Sheet (`MSGBKRCTY=IMPNZ`) | ❌ | ✅ |
| DocBuilder Advance Payment Request | has a **Restriction Macro** `WorkflowItems.Where("<P9_Description>"=="Advance Payment approval").P9_Status> == "CLS"`, Restriction = `UDF` | no restriction macro, Restriction = `NON` |

System-level differences like these suggest **UAT and Prod run different CW builds** (or UAT was refreshed at a different time). The Advance Payment item shows a **third macro style**: a LINQ-like query over related records (`WorkflowItems.Where(...).P9_Status`). It's used as a *delivery restriction*, not a menu filter.

### Custom-item filter stats

| | UAT | PROD |
|---|---|---|
| Custom items | 44 | 44 |
| Published | 39 | 35 |
| With a filter | 24 | **36** |
| Published **without** a filter (everyone sees them) | 17 | **3** |
| `<CompanyCode>` uses | 20 | 28 |
| `<LoginCode>` uses | 0 | **15** |
| HBL/release-type filters (Bill Of Lading items) | same | same |

Prod is much more tightly scoped. Most custom items there are limited to a company or a user.

## 2. Template differences

### Only in PROD (28)

| Group | Count | Pattern |
|---|---|---|
| Client HBL templates with **`_OBO`** suffix, dated Sept 2026 | 10 | `H56.Customizations.<Client>_HBL_..._09Sept2026_OBO` |
| Client HBL variants by release type (`_EBL`, `_SWB`) | 2 | `..._24April2026_EBL` / `_SWB` |
| Other new client HBL versions / copies | 3 | incl. `- Copy` leftovers |
| India Straight BL Manifest **`_Final`** ×4 | 4 | replace UAT's non-`_Final` names |
| Malaysia job sheets `MY.Job_Sheet_<branch>_v2.0` | 5 | match the new Job Sheet (AMY/BBN/BMY/DMY/SMY) menu items |
| `H56.ContainerListDischarge`, `H56.ListInReport` | 2 | match the TH menu items (unpublished) |
| System: `MPI Application Cover Sheet`, `RefundRequest` | 2 | CW build difference |

### Only in UAT (15)

| Group | Count |
|---|---|
| India Import Advance List `IN.IAL_<port>` | 6 (matching the 6 UAT-only menu items) |
| India Straight BL Manifest (non-`_Final`) | 4 (renamed `_Final` in Prod) |
| `H56.IndiaDeliveryOrderFactory` | 1 (Prod merged it into one "IN Delivery Order") |
| `CN.Job_Sheet_BCN_v3.1_Work_Item` | 1 |
| `Copy test`, `Copy test 2` | 2 (test leftovers) |
| System: `CalculateProcessForTax` | 1 |

### Link to the BL filter gap

The 10 new `_OBO` HBL templates line up with the BL menu logic in [`../01-concepts/menu-filter-syntax.md`](../01-concepts/menu-filter-syntax.md). The `Bill Of Lading.` item explicitly handles `BLF` + release type `OBO`. The menu filters themselves are **identical** in both environments, so the gap noted there (BLF + release types other than OBR/OBO/EBL, e.g. SWB) exists in Prod too.

---

## Risks / follow-ups

- [ ] **Change control:** 26 custom templates and ~15 menu changes exist only in Prod. Confirm whether customising directly in Prod is the agreed process, and whether UAT should be refreshed from Prod.
- [ ] **`<LoginCode>` filters** tie documents to individual staff. They break when people change roles or leave. Consider a company/branch or security-group based filter.
- [ ] **India Import Advance List (6 items):** still in development in UAT, or abandoned? Decide whether to promote or clean up.
- [ ] **Job Sheet (BCN/MCN)** are unpublished in Prod but published in UAT. Align them.
- [ ] **Job Sheet (BBN)**: why is Allow Modification = N?
- [ ] Re-export the Prod menu with **all 30 columns** to finish the comparison.
- [ ] Confirm the CW build/version of each environment (system item differences).
- [ ] Clean up `- Copy`, `Copy test*` templates in both environments.
