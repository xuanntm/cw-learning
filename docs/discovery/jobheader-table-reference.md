# JobHeader — Table Reference & Report Query

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`). `JobHeader` is the core Job/Shipment master table and will back most future reports — this consolidates everything learned about it across several investigation threads (job-number uniqueness, the subtype-link correction, indexing) plus a tuned, production-ready export query as a working example.

## Key facts

- **PK:** `JH_PK` (uniqueidentifier) — **not** the clustered index (see Indexing below).
- **Natural key:** `JH_JobNum` (e.g. `S00081401`) — **only unique per company**, not globally. See [[cw-job-number-not-globally-unique]] / `docs/discovery/glbbranch-table-reference.md` point 5. Confirmed at the DB level 2026-08-29 via a real unique index: `NR_UX__JH_JobNum_JH_GC` on `(JH_JobNum, JH_GC)`.
- **Company/Branch/Department FKs:** `JH_GC` → `GlbCompany`, `JH_GB` → `GlbBranch`, `JH_GB_TaxBranch` → `GlbBranch`, `JH_GE` → `GlbDepartment`.
- **Business open date:** `JH_A_JOP` (smalldatetime) — the "Job Opening Date" shown in CW UI (`ShipmentForm > Billing > Invoicing > Open Date`).
- **Subtype link — corrected 2026-08-29:** `JobHeader` does **not** share a PK with its Shipment/Consol/Order/etc. subtype table. The real relationship is a generic polymorphic pointer: `JH_ParentTableCode` (e.g. `'JS'` for JobShipment) + `JH_ParentID` (the subtype table's own PK). See [[cw-jobheader-subtype-link-pattern]] and `docs/discovery/custom-fields-mechanism-reference.md` for the full worked correction — this also governs how to read Custom Fields (`GenCustomAddOnValue`) for a job.

## Indexing (checked 2026-08-29, `sys.indexes`)

`JobHeader` has **22 indexes** — a lot for one table, but this is WiseTech's own vendor schema design (supporting many known CW query patterns), not something to change from the read-only reporting side.

- **Clustered index is `(JH_GC, JH_ParentID)`**, not `JH_PK`. Physical row storage is organized by company, then subtype-pointer — `JH_PK` lookups go through a nonclustered index seek + key lookup (still fast for single-row lookups, just two steps instead of one). Queries filtered/grouped by `JH_GC` are naturally well-supported by this table.
- **Well-indexed:** `JH_GB`, `JH_GB_TaxBranch`, `JH_GE`, `JH_GC` (in composite with `JH_ParentID`/`JH_Status`/`JH_ParentTableCode`), `JH_ParentID` alone, `JH_SystemCreateTimeUtc`, `JH_SystemLastEditTimeUtc`, `JH_JobLocalReference`, `JH_ARInvoiceReference`, `JH_TH_NKQuoteNumber`.
- **Not indexed:** `JH_A_JOP` (the business Open Date) has **no index at all** — any `WHERE`/range filter on it forces a full table scan (~104K rows; not alarming at this size, sub-second-to-a-few-seconds, but worth knowing).
- **Indexed alternative confirmed close enough to use:** `JH_SystemCreateTimeUtc` (system record-creation timestamp) is indexed and, checked empirically against `JH_A_JOP` for the full 2026 year-to-date, diverges by at most ~8 jobs in any single month (<0.3%) — safe to filter on this instead of `JH_A_JOP` when a sargable/indexed range filter matters, while still displaying/ordering by `JH_A_JOP` for business accuracy.

## Report query: full-year job export (tuned, 2026-08-29)

Built incrementally across this investigation — company/branch/department context, business Open Date, and a Custom Field (Product Line) pivoted in. Confirmed runtime: **~16 seconds for the full 2026 year-to-date (~40,000 rows)**.

```sql
SELECT
    JH_JobNum,
    GC_Code AS CompanyCode,
    GC_Name AS CompanyName,
    GB_Code AS BranchCode,
    GB_BranchName AS BranchName,
    GE_Code AS DeptCode,
    GE_Desc AS DeptDescription,
    JH_A_JOP AS OpenDate,
    (SELECT TOP 1 XV_Data FROM GenCustomAddOnValue WHERE XV_ParentID = JH_ParentID AND XV_ParentTableCode = JH_ParentTableCode AND XV_Name = 'Product Line') AS ProductLine
FROM JobHeader
LEFT JOIN GlbBranch ON GB_PK = JH_GB
LEFT JOIN GlbCompany ON GC_PK = GB_GC
LEFT JOIN GlbDepartment ON GE_PK = JH_GE
WHERE JH_SystemCreateTimeUtc >= '2026-01-01' AND JH_SystemCreateTimeUtc < '2027-01-01'
ORDER BY GC_Code, JH_A_JOP;
```

**Tuning decisions baked into this query:**
1. **Sargable date range**, not `YEAR(JH_A_JOP) = 2026` — avoids wrapping the column in a function, which would block index usage.
2. **Filters on `JH_SystemCreateTimeUtc` (indexed) instead of `JH_A_JOP` (unindexed)** — confirmed statistically equivalent for monthly bucketing (see Indexing above) — while still **displaying and ordering by `JH_A_JOP`**, the business-correct field, so there's no accuracy trade-off.
3. **Scalar subquery for the Custom Field, not a `JOIN` + `GROUP BY`** — avoids a fan-out (a plain join on `(XV_ParentID, XV_ParentTableCode)` alone pulls in *every* custom field configured for a job, not just the one wanted, multiplying rows before an aggregate collapses them back down). `TOP 1` is defensive; the underlying `(ParentID, ParentTableCode, Name, Type)` unique index means duplicates aren't expected in practice (confirmed empirically for this field).
4. **`ORDER BY GC_Code, JH_A_JOP` kept deliberately**, even though ordering by the indexed `JH_SystemCreateTimeUtc` could theoretically skip an explicit sort step — the row count here (~40K) makes that sort essentially free either way, and grouping the export into clean per-company chronological blocks matters more for the business review this feeds into than a marginal, imperceptible speed gain.
5. **No explicit company filter** — this exports all companies together; add `AND GC_Code = '<code>'` to scope to one company. Remember `JH_JobNum` alone is never a safe filter/identifier without a company qualifier.

## Related files

- `docs/discovery/glbbranch-table-reference.md` — `GlbBranch` reference (point 5: job-number uniqueness; point 6: the subtype-link correction).
- `docs/discovery/custom-fields-mechanism-reference.md` — full Custom Fields (`GenCustomAddOnValue` etc.) mechanism, including the corrected subtype-link join pattern.
- `docs/discovery/job-volume-trend-analysis-2026.md` — the business trend analysis this table's monthly counts fed into (MVN volume collapse finding).
- `docs/discovery/prod-db-schema-analysis.md`, `docs/discovery/org-tables-schema-analysis.md` — broader PROD schema analyses this builds on.
