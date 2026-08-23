# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **not a software project** — there is no build, lint, or test tooling, and no source code to compile or run. It is a personal technical-learning and documentation repository for CargoWise (CW) EDI Messaging / eAdaptor Next integration work, tracking a structured learning roadmap toward becoming a "CargoWise Integration Architect" / technical Product Owner. Content is primarily Markdown notes, a PlantUML diagram, and (currently empty) placeholder files/folders for XML samples, Postman collections, and config templates.

Because there's no code, tasks here are almost always: writing/editing Markdown documentation, filling in placeholder templates, authoring or updating PlantUML diagrams, or organizing the checklist files. There are no commands to build, lint, or test — don't invent any.

## Repository structure

- `CW Technical Discovery Roadmap.md` and `eAdaptor.md` — the two master roadmap/checklist documents (business-PO-oriented and senior-engineer-oriented tracks respectively) driving the whole learning plan. Checkboxes (`[ ]`/`[/]`/`[x]`/`[!]`) track phase/day progress — update these in place as work completes rather than creating new tracking files.
- `structure.md` — the intended target folder layout for this repo; keep new files consistent with it.
- `docs/config/` — environment and integration configuration notes (e.g. `uat-environment-overview.md` for UAT connectivity details, `endpoint-catalog.md`, `field-mapping.md`, `integration-config-template.md`). Several are still empty placeholders awaiting discovery work.
- `docs/discovery/` — investigation notes for the current UAT/PROD environment (auth methods, prod eAdaptor inventory, prod-vs-UAT gaps, integration ownership, schema library, open `Q&A.md` questions). Many are placeholders to be filled in as discovery progresses.
- `docs/integration-design/` — architecture docs and diagrams for the CW ↔ eAdaptor Next ↔ Boomi ↔ Client flow. Diagram standard (per its `README.md`): source diagrams are PlantUML (`.puml`) under `diagrams/`, exported to PNG/SVG under `exports/`; diagrams must never contain real credentials or unredacted endpoints.
- `docs/governance/` — intended for security/change-control rules (currently empty).
- `docs_for_thanh/foundations/` — CargoWise concept explainers (One-File concept, quick concept, menu structure, core system objects, EDI menu notes) written for a specific learner; these are foundational reference material, not roadmap tracking.
- `samples/xml/` and `samples/postman/` — intended locations for sample XML payloads and a Postman collection template; currently empty.
- `.env.example` — documents the shape of local environment variables (`CW_UAT_BASE_URL`, `CW_UAT_USERNAME`, `CW_UAT_PASSWORD`, `BOOMI_ENDPOINT`) used for UAT/Boomi testing. The real `.env` and `tmp/` (which holds scratch credentials/notes in `work_history.log`) are gitignored — never copy real credentials, IPs, or tokens from `.env` or `tmp/` into any tracked file.

## Working conventions

- Redact/omit real credentials, IPs, tokens, and unwhitelisted endpoint URLs from anything committed — `docs/integration-design/README.md` states this standard explicitly for diagrams, and it applies repo-wide given the `.env`/`tmp/` gitignore setup.
- When updating roadmap progress, edit the existing checklist items in `CW Technical Discovery Roadmap.md` / `eAdaptor.md` in place (flip `[ ]` → `[x]`/`[/]`/`[!]`, fill in "Deliverable" sections) rather than duplicating tracking elsewhere.
- New diagrams belong in `docs/integration-design/diagrams/` as `.puml` sources, with rendered output in `docs/integration-design/exports/`.
