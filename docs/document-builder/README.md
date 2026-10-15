# CW Document Builder — Learning Notes

Learning track for the CargoWise **Document Builder** (designing/customising documents and forms that CW generates from job data).

## Folder structure

```
docs/document-builder/
├── README.md              ← this file: index + progress checklist
├── 01-concepts/           ← what Document Builder is, key terms, menu paths, how it fits with EDI/eAdaptor
├── 02-templates/          ← one note per template studied/built (purpose, data source, layout, triggers)
├── 03-data-mapping/       ← which CW fields/tables feed which document fields; data source quirks
├── 04-troubleshooting/    ← errors seen, causes, fixes
├── samples/               ← CW exports (menu, templates, element library) — gitignored, local only
├── generated/             ← analysis outputs, e.g. the scope matrix .xlsx — gitignored, local only
└── _temp/                 ← raw uploads & conversation logs (gitignored — never committed)
```

Diagrams (`.puml`) follow the repo standard: source in `docs/integration-design/diagrams/`, renders in `docs/integration-design/exports/`.

## Workflow

1. Drop raw material (sample data, chat/conversation logs, screenshots) into `_temp/`.
2. Distill findings into the numbered folders.
3. Keep real customer data, job numbers, credentials, endpoints out of the notes — `_temp/` and `samples/` are gitignored and never committed.

## Progress checklist

- [x] Understand what Document Builder is and where it lives in the CW menu → [workflow](01-concepts/document-customization-workflow.md)
- [/] Identify the document types it produces (shipment menu reviewed: Customs, Arrival, Departure, Customized Documents …)
- [x] Learn the template structure (sections, zones, element library, filters) → [sample anatomy](02-templates/custom-document-sample-anatomy.md), [element library](03-data-mapping/element-library-overview.md)
- [ ] Trace one existing template end-to-end: data source → fields → rendered output
- [ ] Map document fields to CW tables/views (`03-data-mapping/`)
- [ ] Learn how documents are triggered (manual print, workflow/ProcessTasks, EDI/eDocs)
- [ ] Modify a copy of a template in UAT and verify output
- [ ] Record common errors and fixes (`04-troubleshooting/`)
