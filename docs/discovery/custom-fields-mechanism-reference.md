# Custom Fields (UDF) Mechanism — Table Reference

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`). Written up as a standing reference — Custom Fields configured on CW forms (e.g. `ShipmentForm > Basic Registration > Custom Fields`) are **not** plain columns; they're stored in a generic key/value structure shared across the whole system. Once this mechanism is understood, any custom field on any form can be queried the same way, without needing a schema lookup each time.

Source data: `tmp/Query_GEN_tables_202608282349.csv`, `tmp/Query_all_gen_tables_202608290113.csv` (columns for all 4 tables) — gitignored, not tracked. Discovered via CW's field-inspector macro (`Ctrl+right-click` on a field) returning `Table/Field Name: [calculated property]` for two Shipment custom fields ("Product Line", "Network Partner"), which was the signal this isn't a normal column.

## How a Custom Field shows up in the UI

Field-inspector signature for any Custom Field on this control:
- `DataSource Type: Enterprise.Freight.Forwarding.Business.PhaseSecuritySupportableCustomBusinessObject`
- `Binding Member: __<FIELD NAME>__prop__ZString`
- `List Type: Enterprise.ZArchitecture.Core.CodeDescriptionPairList`
- `Table/Field Name: [calculated property]`

That `[calculated property]` is the tell — there's no static column, so a schema-columns query on the visible form's business object won't find it. The actual value lives in `GenCustomAddOnValue`, keyed by field name (not by a column).

## The four tables

| Table | Prefix | Role |
|---|---|---|
| `GenCustomColumnDefinition` | `XC_` | **Field declaration** — what custom field exists for a given parent context (`XC_ParentTableCode`/`XC_ParentID`, presumably the Process/Workflow Template that defines it), its name (`XC_Name`), type, display order (`XC_DisplaySequence`), and which rule governs it (`XC_XR`) |
| `GenCustomAddOnRule` | `XR_` | **Rule logic** — `XR_Code`/`XR_Description`, `XR_RuleType`, and `XR_SourceCode` (xml) — almost certainly the script/expression driving things like the dropdown options (the `CodeDescriptionPairList` seen in the field inspector) or validation |
| **`GenCustomAddOnValue`** | `XV_` | **The value store** — this is the only table needed to *read* a custom field's current value. See below. |
| `GenCustomAddOnRuleAck` | `XK_` | **Warning-acknowledgment log** — separate concern, tracks when a user dismissed a rule-generated warning on a record (`XK_ParentTableCode`/`XK_ParentID`, `XK_RuleID`, `XK_Warning` xml, `XK_IsCancelled`). Not involved in normal value retrieval. |

### `GenCustomAddOnValue` columns (the one that matters for reading values)

| Column | Type | Notes |
|---|---|---|
| `XV_PK` | uniqueidentifier | Primary key |
| `XV_ParentTableCode` | varchar | Short code for which entity type this value belongs to — `JS` = JobShipment, `JJ` = JobCartage, `JE` = JobDeclaration (others likely exist for other forms) |
| `XV_ParentID` | uniqueidentifier | The specific record's **own** PK (e.g. `JobShipment.JS_PK` directly — NOT `JobHeader.JH_PK`, see the correction below). See `docs/discovery/glbbranch-table-reference.md` point 5 for the job-number-uniqueness caveat that applies here too. |
| `XV_Name` | varchar | The field's on-screen label, exactly as displayed (title case, with spaces — e.g. `'Product Line'`, `'Network Partner'`) |
| `XV_Data` | nvarchar | The stored value as text |
| `XV_DataAsDecimal` | decimal | Typed numeric version, populated when relevant |
| `XV_Type` | varchar | Value type code |
| `XV_XR_Rule` | uniqueidentifier | FK → `GenCustomAddOnRule.XR_PK` — which rule was in effect. **Confirmed NOT part of the uniqueness key** — informational only (see below) |
| `XV_IsRuleEnabled` | bit | Whether the governing rule was enabled when this value was set |
| `XV_SystemCreateTimeUtc`, `XV_SystemCreateUser`, `XV_SystemLastEditTimeUtc`, `XV_SystemLastEditUser`, `XV_AutoVersion` | — | Standard audit columns |

## Confirmed: the real key is `(ParentID, ParentTableCode, Name, Type)` — genuinely unique

Checked directly against `sys.indexes` (2026-08-29): `NR_UX__XV_ParentID_XV_ParentTableCode_XV_Name_XV_Type` is a real **unique index** on exactly those four columns. `XV_XR_Rule` has its own index (`FK_RX__XV_XR_Rule`) but it is **not unique** and **not part of** this composite key — confirming a given record can have at most one row per field name, regardless of which rule was involved. Also confirmed empirically: `GROUP BY XV_ParentID HAVING COUNT(*) > 1` for `XV_Name = 'Product Line'` returned zero rows.

**Practical implication:** it's always safe to query a specific field's value with a plain equality join on `(ParentID, ParentTableCode, Name)` — no need to involve `XV_XR_Rule` or worry about picking the "wrong" duplicate.

## ⚠️ Correction (2026-08-29): `JobHeader.JH_PK` is NOT the same as `JobShipment.JS_PK`

An earlier version of this doc assumed `JobHeader` and `JobShipment` share the same PK value (the pattern that holds for `OrgHeader`/`OrgMiscServ`). **That assumption is wrong for Job tables**, discovered by directly testing a known-real GUID:

```sql
SELECT 'JobShipment' AS TableName, JS_PK AS PKValue FROM JobShipment WHERE JS_PK = 'FC75F81D-42B4-427A-BE3B-000137592144'
UNION ALL
SELECT 'JobHeader' AS TableName, JH_PK AS PKValue FROM JobHeader WHERE JH_PK = 'FC75F81D-42B4-427A-BE3B-000137592144';
-- returned only the JobShipment row — JobHeader has NO row with that PK
```

The real relationship is a **generic polymorphic pointer on `JobHeader` itself**: `JobHeader.JH_ParentID` + `JobHeader.JH_ParentTableCode` identify which subtype table+row this Job actually is — confirmed directly:
```sql
SELECT JH_PK, JH_JobNum, JH_ParentTableCode, JH_ParentID
FROM JobHeader
WHERE JH_ParentTableCode = 'JS' AND JH_ParentID = 'FC75F81D-42B4-427A-BE3B-000137592144';
-- returned JH_PK = 4F445ABD-0AF9-401A-82E0-4881C4366A0F, JH_JobNum = S00011599
```
So: `JobHeader.JH_ParentID = JobShipment.JS_PK` (when `JH_ParentTableCode = 'JS'`) — **not** `JobHeader.JH_PK = JobShipment.JS_PK`. This also explains why no FK constraint was ever found referencing `JobHeader.JH_PK` (a polymorphic pointer can't be a normal single-target FK constraint).

**Practical impact:** `GenCustomAddOnValue.XV_ParentID` for `ParentTableCode = 'JS'` holds the shipment's own `JS_PK` — reachable from `JobHeader` via `JH_ParentID` (not `JH_PK`), or directly if you already have the `JobShipment` row.

## Reusable retrieval pattern

**Single field, starting from a known `JobShipment.JS_PK`:**
```sql
SELECT XV_Data
FROM GenCustomAddOnValue
WHERE XV_ParentTableCode = 'JS' AND XV_ParentID = '<JobShipment.JS_PK>' AND XV_Name = 'Product Line';
```

**Starting from `JobHeader` (the common case for a report keyed by Job Number):**
```sql
SELECT
    JH_JobNum,
    cf.XV_Data AS ProductLine
FROM JobHeader
LEFT JOIN GenCustomAddOnValue cf
    ON cf.XV_ParentID = JH_ParentID
    AND cf.XV_ParentTableCode = JH_ParentTableCode
    AND cf.XV_Name = 'Product Line'
WHERE JH_JobNum = '<job number>';
```

**Multiple fields, pivoted into one row** (safe because of the confirmed unique key):
```sql
SELECT
    JH_JobNum,
    MAX(CASE WHEN cf.XV_Name = 'Product Line' THEN cf.XV_Data END) AS ProductLine,
    MAX(CASE WHEN cf.XV_Name = 'Network Partner' THEN cf.XV_Data END) AS NetworkPartner
FROM JobHeader
LEFT JOIN GenCustomAddOnValue cf
    ON cf.XV_ParentID = JH_ParentID
    AND cf.XV_ParentTableCode = JH_ParentTableCode
WHERE JH_JobNum = '<job number>'
GROUP BY JH_JobNum;
```

## Verification script — run against real, populated shipment data

Uses the corrected relationship, against the same known-good shipment found during this investigation: `JobShipment.JS_PK = 'FC75F81D-42B4-427A-BE3B-000137592144'`, which belongs to `JobHeader.JH_PK = '4F445ABD-0AF9-401A-82E0-4881C4366A0F'` (`JH_JobNum = 'S00011599'`).

```sql
-- Step 1: confirm the JH_ParentID -> JS_PK relationship (NOT JH_PK) for this real shipment
SELECT JH_JobNum, JH_A_JOP AS OpenDate, JH_ParentTableCode, JH_ParentID
FROM JobHeader
WHERE JH_PK = '4F445ABD-0AF9-401A-82E0-4881C4366A0F';
-- expect JH_ParentTableCode = 'JS', JH_ParentID = 'FC75F81D-42B4-427A-BE3B-000137592144'

-- Step 2: full pivot — branch, company, and custom fields together, proving the whole chain end to end
SELECT
    JH_JobNum,
    GC_Code AS CompanyCode,
    GC_Name AS CompanyName,
    GB_Code AS BranchCode,
    GB_BranchName AS BranchName,
    JH_A_JOP AS OpenDate,
    MAX(CASE WHEN cf.XV_Name = 'Product Line' THEN cf.XV_Data END) AS ProductLine,
    MAX(CASE WHEN cf.XV_Name = 'Network Partner' THEN cf.XV_Data END) AS NetworkPartner
FROM JobHeader
LEFT JOIN GlbBranch ON GB_PK = JH_GB
LEFT JOIN GlbCompany ON GC_PK = GB_GC
LEFT JOIN GenCustomAddOnValue cf ON cf.XV_ParentID = JH_ParentID AND cf.XV_ParentTableCode = JH_ParentTableCode
WHERE JH_PK = '4F445ABD-0AF9-401A-82E0-4881C4366A0F'
GROUP BY JH_JobNum, GC_Code, GC_Name, GB_Code, GB_BranchName, JH_A_JOP;

-- Step 3: inspect the governing rule for this value (optional — confirms the XR_Rule join works, though not needed for retrieval)
SELECT cf.XV_Name, cf.XV_Data, xr.XR_Code, xr.XR_Description, xr.XR_RuleType, xr.XR_IsActive
FROM GenCustomAddOnValue cf
LEFT JOIN GenCustomAddOnRule xr ON xr.XR_PK = cf.XV_XR_Rule
WHERE cf.XV_ParentID = 'FC75F81D-42B4-427A-BE3B-000137592144'
  AND cf.XV_ParentTableCode = 'JS';
```

Expected: Step 1 confirms the pointer; Step 2 returns the full pivoted row including `ProductLine = 'FS'`; Step 3 shows the rule metadata behind that value.

## Case study: `S00081401` — resolved 2026-08-29

The original conclusion ("this job has no Shipment subtype record in either company") was wrong — it was built on the incorrect `JH_PK = JS_PK` join. Once corrected to use `JH_ParentTableCode`/`JH_ParentID` (per the correction above), the query returned real data. Confirms the corrected join pattern is the right one to use going forward for any Job-subtype lookup, including custom fields.

## Related files

- `docs/discovery/glbbranch-table-reference.md` — `GlbBranch` reference; point 5 covers the `JH_JobNum` non-uniqueness finding that applies to any job-number-based lookup, including this one.
- `docs/discovery/jobheader-table-reference.md` — `JobHeader` consolidated reference (indexing, the subtype-link correction, and the tuned full-year export query that uses this custom-fields mechanism in practice).
- `docs/discovery/org-tables-schema-analysis.md`, `docs/discovery/prod-db-schema-analysis.md` — broader PROD schema analyses this builds on.
