# Job Volume Trend Analysis — 2026 (Jan–Aug)

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`). For discussion with the business team — this surfaces a volume trend that needs business context to interpret, not something resolvable from the data alone.

Source data: `tmp/Query_count_by_month_2026_202608290137.csv` (all companies combined), `tmp/Query_count_by_month_of_company_2026_202608290138.csv` (per-company breakdown) — both gitignored, not tracked. Counted by `JobHeader.JH_A_JOP` (Job Opening Date), grouped by month and company (`GlbCompany.GC_Code` via `GlbBranch`).

**Caveat: August 2026 is a partial month.** Data pulled 2026-08-29, so August reflects ~29 of 31 days — not directly comparable to the other, complete months.

## Overall trend (all companies combined)

| Month | Job Count |
|---|---|
| Jan | 4,364 |
| Feb | 3,562 |
| Mar | 3,741 |
| Apr | 3,316 |
| May | 3,274 |
| Jun | 3,259 |
| Jul | 3,490 |
| Aug | 2,826 *(partial)* |

At face value: a decline from January through June, a partial recovery in July, then a drop in August (partly explained by the incomplete month). **This headline trend is misleading on its own — see below.**

## Key finding: the overall decline is driven almost entirely by `MVN`, not a broad business slowdown

`MVN` (Marine Connections Vietnam Co., Ltd. — already an open question in `docs/discovery/workflow-audit-checklist.md` Section A2/A3, where it was confirmed active but its priority/status was unconfirmed) fell from **1,518 jobs in January to 132 in August — a ~91% decline**, in a smooth, consistent slide every single month:

| Month | MVN Job Count |
|---|---|
| Jan | 1,518 |
| Feb | 992 |
| Mar | 708 |
| Apr | 326 |
| May | 253 |
| Jun | 196 |
| Jul | 140 |
| Aug | 132 *(partial)* |

In January, MVN alone was **34.8% of the entire database's job volume** — by August it's under 5%. Stripping MVN out of the totals flips the story:

| Month | Total excl. MVN |
|---|---|
| Jan | 2,846 |
| Feb | 2,570 |
| Mar | 3,033 |
| Apr | 2,990 |
| May | 3,021 |
| Jun | 3,063 |
| Jul | 3,350 |
| Aug | 2,694 *(partial)* |

Excluding MVN, volume is **flat-to-growing** across Jan–Jul (a dip in Feb, then steady recovery to a Jul high). The apparent "declining business" in the raw totals is really MVN's individual collapse — the rest of the business is healthy or improving over the same period.

**This needs a business answer, not a data answer:** something happened to MVN's volume starting around February 2026 — client loss, business wind-down, operational disruption, or a migration of MVN's data/activity into a different company code. Worth asking directly rather than guessing further from SQL.

## Other notable patterns

- **`MCN`** also declining, less severely: 438 → 162 (~63% drop over the period), same general shape as MVN — worth checking whether it's related (same root cause) or coincidental.
- **`BKR`** (Ben Line Agencies Korea) is **growing**: 51 → peaked at 205 in June, still elevated at 126 in August.
- **`BCN`** is the single largest steady contributor most months (450–650/month) — no concerning trend, healthy baseline.
- **`BID`**, **`BJP`** show moderate growth with a notable July spike.
- A handful of company codes (`AMY`, `BCA`, `HHK`, `LTW`, `BVN`, `BMM`, `MHK`) have only a handful of jobs total across the whole 8-month window — likely dormant/test/rarely-used entities, not meaningful for trend purposes.

## Questions for the business team

1. What happened with MVN starting around February 2026? Client loss, wind-down, operational issue, or a migration to a different company/branch code?
2. Is MCN's smaller-but-similar decline related to the same cause, or a separate issue?
3. Does this change the priority/status answer for MVN in the existing audit checklist question (Section A2/A3 of `docs/discovery/workflow-audit-checklist.md` — is it still worth prioritizing for UAT backfill, or is it winding down)?
4. Is BKR's growth trend expected/planned, or worth investigating as a possible destination if MVN's volume is migrating elsewhere?

## Related files

- `docs/discovery/workflow-audit-checklist.md` — MVN is an existing open question there (Section A2/A3); this trend data should feed back into that discussion.
- `docs/discovery/glbbranch-table-reference.md`, `docs/discovery/custom-fields-mechanism-reference.md` — schema reference used to build the underlying query (company/branch join, job-number-uniqueness caveat).
