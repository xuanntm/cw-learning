-- ============================================================
-- JobHeader Relationship Map — outbound + inbound FKs
-- ============================================================
-- Purpose: full dependency map for JobHeader, the master/primary table for
-- any job (Shipment, Consol, Order, etc.) - see docs/discovery/jobheader-
-- table-reference.md for what's already confirmed (JH_GC/JH_GB/JH_GE
-- outbound FKs, the polymorphic JH_ParentID/ParentTableCode subtype link
-- which is NOT a real FK). This maps everything else.

-- ============================================================
-- STEP 1 — outbound: what JobHeader itself has real FK columns pointing to
-- ============================================================
SELECT
    fk.name AS ConstraintName,
    cp.name AS ParentColumn,
    tr.name AS RefTable,
    cr.name AS RefColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = fkc.referenced_column_id
WHERE tp.name = 'JobHeader'
ORDER BY cp.name;

-- ============================================================
-- STEP 2 — inbound: every table with a real FK pointing AT JobHeader.JH_PK
-- (this is the big one - expect many rows, JobHeader is the master record
-- for the whole Job/Shipment/Consol/Order family)
-- ============================================================
SELECT
    fk.name AS ConstraintName,
    tp.name AS ChildTable,
    cp.name AS ChildColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
WHERE tr.name = 'JobHeader'
ORDER BY tp.name;

-- Note: this will NOT include JobShipment (and presumably JobConsol/
-- JobOrderHeader/etc.) - those link via the polymorphic JH_ParentID/
-- JH_ParentTableCode pointer, which cannot be a declared FK constraint,
-- so it's invisible to this query by design. That's expected, not a gap -
-- see docs/discovery/jobheader-table-reference.md and the
-- cw-jobheader-subtype-link-pattern memory for that relationship.
