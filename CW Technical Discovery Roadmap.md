# CargoWise Technical Discovery Roadmap (Senior Software Engineer → CW Integration Architect)

## Purpose:

**Fastest path for a senior software engineer (architecture focus) to support CargoWise EDI Messaging / eAdaptor / Integration with minimal business-process learning**

---

# Progress Legend

* [ ] Not Started
* [/] In Progress
* [x] Completed
* [!] Blocked

---

# Overall Target (4 Weeks)

## End Goal:

### By Week 4, capable to:

* Troubleshoot eAdaptor inbound/outbound issues
* Understand CW integration architecture
* Design CW → Boomi → Client flow
* Validate XML payloads
* Review authentication/security
* Build technical governance documentation

---

# WEEK 1 — SYSTEM FOUNDATION (Understand CargoWise as a Platform)

## Objective:

### Learn system structure, core entities, and where integration happens.

---

## Day 1 — CargoWise System Overview

* [ ] Understand CargoWise One-File Concept
* [ ] Learn difference:

  * Shipment
  * Consol
  * Job
  * Organization
  * Milestone/Event
  * Invoice
* [ ] Review CargoWise menu structure:

  * Registry
  * EDI Messaging
  * Forwarding
  * Accounting (high-level only)
* [ ] Document “What are core system objects?”

### Deliverable:

**CW Technical Object Map v1**

---

## Day 2 — Registry Discovery

* [ ] Access Registry
* [ ] Review:

  * Organizations
  * Branches
  * User security
  * System configuration
  * eAdaptor settings
* [ ] Identify where endpoint/security configs are stored
* [ ] Screenshot or document major technical menus

### Deliverable:

**Registry Navigation Guide**

---

## Day 3 — Security Basics

* [ ] Learn:

  * User authentication
  * Basic Auth
  * IP whitelist
  * Environment separation (UAT / PROD)
* [ ] Identify common causes of:

  * 401 Unauthorized
  * Access denied
  * Endpoint rejection
* [ ] Document security dependencies

### Deliverable:

**CW Security & Access Checklist**

---

## Day 4–5 — Database Awareness (Read-only)

* [ ] Access Reporting DB / SQL environment (if available)
* [ ] Identify major technical tables:

  * Shipment
  * Milestone
  * Organization
  * Message logs
* [ ] Learn relationship basics
* [ ] Document “Where integration data lives”

### Deliverable:

**CW Data Architecture Basics**

---

# WEEK 2 — EDI MESSAGING & eAdaptor NEXT

## Objective:

### Master inbound/outbound messaging flow

---

## Day 6 — EDI Messaging Architecture

* [ ] Understand:

  * Inbound
  * Outbound
  * Queue
  * XML processing
* [ ] Locate:

  * Message templates
  * Trigger points
  * Endpoint configs
* [ ] Document complete flow

### Deliverable:

**EDI Messaging Architecture Diagram**

---

## Day 7 — Inbound Discovery

* [ ] Identify:

  * Endpoint URL
  * Authentication method
  * Accepted XML format
  * Validation process
* [ ] Test inbound with sample XML
* [ ] Track logs/errors

### Deliverable:

**Inbound Troubleshooting Checklist**

---

## Day 8 — Outbound Discovery

* [ ] Identify:

  * Trigger events
  * XML generation logic
  * Queue/retry process
  * Delivery endpoint
* [ ] Review existing outbound setup

### Deliverable:

**Outbound Trigger Matrix**

---

## Day 9–10 — Error Handling

* [ ] Investigate:

  * 401
  * 403
  * XML validation failure
  * Queue stuck
  * Timeout
* [ ] Build troubleshooting decision tree

### Deliverable:

**EDI Error Resolution Guide v1**

---

# WEEK 3 — INTEGRATION ARCHITECTURE (CW + Boomi + Client)

## Objective:

### Transition from system learner → integration architect

---

## Day 11 — Middleware Design

* [ ] Understand Boomi role:

  * Pass-through
  * Mapping
  * Transformation
  * Monitoring
* [ ] Review client endpoint requirements
* [ ] Compare:

  * Direct CW → Client
  * CW → Boomi → Client

### Deliverable:

**Integration Option Comparison**

---

## Day 12–13 — XML Field Mapping

* [ ] Export sample XML
* [ ] Map:

  * Shipment fields
  * Milestones
  * References
* [ ] Identify mandatory vs optional
* [ ] Build mapping template

### Deliverable:

**CW XML Mapping Template**

---

## Day 14–15 — End-to-End Architecture

* [ ] Build:

```txt
CW Trigger → eAdaptor → XML → Boomi → Client API
```

* [ ] Include:

  * Security
  * Logging
  * Retry
  * Monitoring
* [ ] Design governance controls

### Deliverable:

**E2E Solution Architecture Diagram**

---

# WEEK 4 — GOVERNANCE, OPTIMIZATION & HANDOVER

## Objective:

### Become sustainable technical support

---

## Day 16 — Technical Governance

* [ ] Define:

  * Environment control
  * Change control
  * Endpoint ownership
  * Security standards
* [ ] Build governance checklist

### Deliverable:

**CW Integration Governance Framework**

---

## Day 17 — Monitoring

* [ ] Identify:

  * Log sources
  * Error frequency
  * Retry failures
* [ ] Propose dashboard:

  * Inbound success %
  * Outbound success %
  * Failure categories

### Deliverable:

**Monitoring Dashboard Requirement**

---

## Day 18 — Documentation Pack

* [ ] Finalize:

  * Architecture
  * Security
  * XML
  * Troubleshooting
  * Governance
* [ ] Organize for reuse

### Deliverable:

**CW Integration Playbook v1**

---

## Day 19–20 — Knowledge Transfer to You

* [ ] Present findings
* [ ] Review:

  * Security
  * eAdaptor
  * Risks
  * Opportunities
* [ ] Align with your roadmap

### Deliverable:

**Technical Support Readiness Review**

---

# Final Scorecard

| Area              | Status | Notes |
| ----------------- | ------ | ----- |
| CW Core Structure | [ ]    |       |
| Registry          | [ ]    |       |
| Security/Auth     | [ ]    |       |
| Reporting DB      | [ ]    |       |
| EDI Messaging     | [ ]    |       |
| eAdaptor Inbound  | [ ]    |       |
| eAdaptor Outbound | [ ]    |       |
| XML Mapping       | [ ]    |       |
| Boomi Integration | [ ]    |       |
| Governance        | [ ]    |       |
| Troubleshooting   | [ ]    |       |
| Documentation     | [ ]    |       |

---

# Minimum Business Knowledge Rule

## Learn ONLY:

* Shipment lifecycle basics
* Job structure
* Milestones
* Billing visibility (high level)

## Ignore for now:

* Accounting details
* Customs
* CRM
* Operational SOPs
* Local country workflows

---

# Weekly Reporting Format (Update to You)

## Week X Summary:

### Completed:

*
*
*

### Key Findings:

*
*

### Blockers:

*
*

### Next Week Focus:

*
*

---

# Success Definition

## He succeeds if:

### He can answer:

* Where is endpoint config?
* Why inbound 401 happens?
* How outbound triggers?
* What XML is required?
* Where logs are?
* How CW integrates with Boomi?
* What governance is missing?

---

# Final Role Positioning

## Target Role:

### “CargoWise Integration Architect”

### NOT:

### “CargoWise Functional Operator”

---

# Recommended Tools

* CargoWise Registry
* EDI Messaging
* eAdaptor Next
* Reporting DB / SQL
* Postman
* XML Validator
* Boomi

---

# Your Oversight

## You focus:

* Business governance
* Priorities
* Country alignment

## He focuses:

* Technical architecture
* Security
* Integration
* Troubleshooting
* Documentation
