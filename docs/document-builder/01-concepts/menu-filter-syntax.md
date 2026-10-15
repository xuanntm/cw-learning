# Document Menu Filter Syntax

Source: `Filter` column of [`../samples/01_cw_document_menu_for_shipment.xlsx`](../samples/01_cw_document_menu_for_shipment.xlsx) (467 menu items). The filter decides **whether a menu item appears** for the current shipment, user and company. An empty filter means the item always shows (if `Publish = Y`).

There are **two different syntaxes**.

## Syntax 1: Expression (macro) filters, used by all custom items

```
"<FieldName>" == "VALUE"
"<FieldName>" != "VALUE"
cond1 && cond2          AND
cond1 || cond2          OR
( ... )                 grouping
"<Field>".Contains(",X,")   string method (seen once, system item)
```

| Part | Notes |
|---|---|
| `<FieldName>` | A **macro**: CW swaps in the field's value at runtime. Always wrap it in double quotes so it's compared as a string. |
| Field naming styles | **Column style**: `<JS_ReleaseType>` (JS_ = `JobShipment` column). **Calculated property**: `<TransportMode>`, `<CompanyCode>`, `<UseDocBuilderFreightDocs>`. **Dotted path**: `<CurrentCompany.Country.Code>`, `<ArrivalConsolForDocuments.JK_AgentType>` (JK_ = `JobConsol`). |
| Values | Always string literals, usually CW codes (`SEA`, `FCL`, `OBR`) or `Y`/`N` flags. |
| Precedence | `&&` binds tighter than `\|\|` (C#-style). Add brackets when you mix them. |
| Spacing | Free-form: `"<A>"=="B"` and `"<A>" == "B"` both work. |
| "Hide" trick | Comparing to an impossible value hides an item: `"<CurrentCompany.Country.Code>" == "HideThisDocument"`, `CTY=HideThisMenuItem`. |

## Syntax 2: Legacy `KEY=VALUE` codes (system items only)

A short code name, `=`, and a value. No macros and no operators. **None of our custom items use this.** It is used by 188 system items, with 27 different keys:

| Key | Uses | Example values | Meaning *(inferred)* |
|---|---|---|---|
| `MSGBKRCTY` | 86 | `IMPKR`, `EXPTW`, `IMPUS`, `LEXKR`, `FTZUS` | Customs message type + broker country (`IMP`/`EXP` + country) |
| `CTY` | 45 | `IS`, `ZA`, `NZ`, `GB`, `CN` | Company country |
| `EXPBKRLIC` | 10 | `Y` | Export broker licence enabled |
| `IsNonCondensedDeclaration`, `CTYEGSADH`, `BKR` | 4 each | | Customs feature flags |
| others (21 keys) | 1–3 each | `MOD=SEA`, `CTYMOD=USAIR`, `MYDO=Y`, `ASYCUDA=Y` … | Mode, country+mode, local features |

Use Syntax 1 for anything new.

---

## Statistics: non-system (custom) menu items

**44 custom items.** 24 have a filter and 20 don't (17 of those 20 are published, so every company sees them).

### By field (parameter)

| Field (macro) | Occurrences | Items using it | Purpose |
|---|---|---|---|
| `<CompanyCode>` | 20 | 19 | Limit the item to one company/branch |
| `<JS_HouseBillOfLadingType>` | 12 | 3 | Choose the HBL layout variant |
| `<JS_ReleaseType>` | 6 | 2 | Choose the HBL layout variant |
| `<TransportMode>` | 2 | 1 | Sea only |
| `<CurrentCompany.Country.Code>` | 2 | 1 | CA/US only |
| `<JS_ShipmentType>` | 1 | 1 | Third-party (`3PT`) shipments |

### By field + operator + value

| Field | Op | Value | Count |
|---|---|---|---|
| `<CompanyCode>` | `==` | `BIN` | 8 |
| `<CompanyCode>` | `==` | `BSG` | 3 |
| `<CompanyCode>` | `==` | `BCN`, `LKH` | 2 each |
| `<CompanyCode>` | `==` | `BKR`, `BTW`, `MCN`, `BID`, `SID` | 1 each |
| `<JS_HouseBillOfLadingType>` | `!=` | `MCN` | 5 |
| `<JS_HouseBillOfLadingType>` | `==` | `BLF` | 3 |
| `<JS_HouseBillOfLadingType>` | `!=` | `BLF` | 2 |
| `<JS_HouseBillOfLadingType>` | `==` | `MCN`, `KES` | 1 each |
| `<JS_ReleaseType>` | `==` | `EBL` | 2 |
| `<JS_ReleaseType>` | `==` | `OBR`, `OBO` | 1 each |
| `<JS_ReleaseType>` | `!=` | `SWB`, `OBR` | 1 each |
| `<TransportMode>` | `==` | `SEA`, `FSA` | 1 each |
| `<CurrentCompany.Country.Code>` | `==` | `US`, `CA` | 1 each |
| `<JS_ShipmentType>` | `==` | `3PT` | 1 |

### Operators

| Operator | Count |
|---|---|
| `==` | 34 |
| `!=` | 9 |
| `&&` | 12 |
| `\|\|` | 7 |

### Filter patterns

| Pattern | Items | Example |
|---|---|---|
| Single company | 18 | `"<CompanyCode>"=="BIN"` |
| Company A or B | 1 | `"<CompanyCode>"=="BID"\|\|"<CompanyCode>"=="SID"` |
| Country list | 1 | `"<CurrentCompany.Country.Code>" == "CA"\|\|... == "US"` |
| Shipment attributes | 4 | HBL type / release type / shipment type + mode |
| No filter | 20 | India Customised Docs, Job Sheet, Inland BOL … |

---

## Worked example: the 3 custom Bill Of Lading items

Three items share the menu path `Departure/Bill Of Lading` and their names differ only by dots and spaces (`Bill Of Lading.`, `Bill Of Lading .`, `Bill Of Lading  .`). This trick lets the same label appear several times, with each item pointing to a different template. The filters decide which one shows. Below, H = `<JS_HouseBillOfLadingType>` and R = `<JS_ReleaseType>`:

| Item | Filter (simplified) |
|---|---|
| `Bill Of Lading  .` | H = `MCN` |
| `Bill Of Lading .` | H = `BLF` **and** R = `OBR` |
| `Bill Of Lading.` | (H ∉ {`MCN`, `BLF`}) **or** (H = `BLF` **and** R ∈ {`OBO`, `EBL`}) |

The long filter on `Bill Of Lading.` reduces to that one line once you apply `&&`-before-`||`. Its last clause (`H == KES && R == EBL`) is redundant: the "H not MCN/BLF" clause already covers it.

⚠️ **Possible gap:** when H = `BLF` and R is anything other than `OBR`/`OBO`/`EBL` (e.g. `SWB`), **no custom BL item shows**. Check whether this is intended.

## Tips for writing filters

- Scope custom items to a company with `"<CompanyCode>"=="XXX"`. Most of our items (19/44) do this.
- For if/else variants, make the filters **mutually exclusive and complete**, and check that every combination maps to exactly one item.
- Put brackets around every `||` group. Don't rely on precedence.
- Keep filters short. If one gets long, split the item or simplify the logic, as in the BL example.
