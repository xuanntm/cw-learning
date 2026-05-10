# CargoWise UAT + eAdaptor Next Technical Learning Checklist
## Objective:
**Purpose:** Validate current UAT environment, discover eAdaptor Next configuration, test integrations with Postman, and build technical Product Owner capability.

---
# STATUS LEGEND
- [ ] Not Started
- [/] In Progress
- [x] Completed
- [!] Blocked / Need IT Support

---

# PHASE 1 — ACCESS & ENVIRONMENT DISCOVERY
## Goal: Confirm permissions, tools, and technical boundaries

### UAT Access
- [ ] Confirm UAT login credentials
- [ ] Confirm environment URL
- [ ] Confirm role/security profile
- [ ] Confirm admin rights or permission escalation path
- [ ] Confirm if access includes System Settings
- [ ] Confirm if access includes eAdaptor Next
- [ ] Confirm if access includes Workflow/Triggers
- [ ] Confirm if access includes Integration Logs
- [ ] Confirm if access includes Reporting DB
- [ ] Confirm if access includes Organization Registry

### Technical Tools Setup
- [ ] Install Postman
- [ ] Install VS Code
- [ ] Install XML Tools extension
- [ ] Install GitHub Desktop or Git
- [ ] Install DBeaver (optional)
- [ ] Create GitHub learning repository
- [ ] Setup Markdown documentation structure

### IT Team Questions
- [ ] Request UAT eAdaptor endpoint URL
- [ ] Request authentication method (Basic Auth/API Key/Bearer)
- [ ] Request IP whitelist confirmation
- [ ] Request sample XML payload
- [ ] Request XSD/schema
- [ ] Request current integrations list
- [ ] Request log access path

---

# PHASE 2 — CARGOWISE UI CONFIGURATION REVIEW
## Goal: Discover how current UAT is configured before testing externally

### eAdaptor Next Review
- [ ] Locate eAdaptor Next menu
- [ ] Review inbound templates
- [ ] Review outbound templates
- [ ] Review event triggers
- [ ] Review endpoint destinations
- [ ] Review message queues
- [ ] Review retry settings
- [ ] Review authentication setup
- [ ] Review schema validation rules
- [ ] Capture screenshots of all major config

### Existing Integration Mapping
- [ ] Identify Boomi integrations
- [ ] Identify API integrations
- [ ] Identify SFTP/FTP integrations
- [ ] Identify NetSuite/ERP integrations
- [ ] Identify customer/client outbound integrations
- [ ] Identify shipment-related integrations
- [ ] Identify milestone-related integrations
- [ ] Identify invoice-related integrations

---

# PHASE 3 — DOCUMENTATION & GOVERNANCE
## Goal: Build your technical wiki

### Documentation
- [ ] Document UAT environment overview
- [ ] Document all available modules
- [ ] Document current integration architecture
- [ ] Document trigger-event relationships
- [ ] Document XML structure samples
- [ ] Document endpoint URLs (secured/redacted)
- [ ] Document user rights
- [ ] Document security risks
- [ ] Document failure points
- [ ] Document governance ownership

### Repository Structure
- [ ] README.md created
- [ ] Overview folder created
- [ ] XML samples folder created
- [ ] Integration design folder created
- [ ] Error logs folder created
- [ ] Governance folder created

---

# PHASE 4 — POSTMAN CONNECTIVITY TESTING
## Goal: Validate technical integration

### Initial Setup
- [ ] Create Postman workspace
- [ ] Setup environment variables
- [ ] Configure auth credentials
- [ ] Add base URL
- [ ] Add headers
- [ ] Test SSL/certificate

### Connectivity Tests
- [ ] Test endpoint reachability
- [ ] Test valid authentication
- [ ] Test invalid authentication
- [ ] Test valid XML payload
- [ ] Test invalid XML payload
- [ ] Capture response codes
- [ ] Document response messages
- [ ] Document timeout behavior

### Common Error Handling
- [ ] Test 401 Unauthorized
- [ ] Test 403 Forbidden
- [ ] Test 404 Not Found
- [ ] Test 500 Internal Error
- [ ] Check CW logs after failure
- [ ] Check retry mechanism

---

# PHASE 5 — PRACTICAL BUSINESS SCENARIO TESTING
## Goal: Learn through real CargoWise business flows

### Shipment Integration
- [ ] Test shipment outbound
- [ ] Test shipment inbound
- [ ] Validate mandatory fields
- [ ] Validate milestone trigger
- [ ] Validate branch/entity behavior

### Milestone/Event
- [ ] Test event outbound
- [ ] Test event update
- [ ] Validate trigger timing
- [ ] Validate duplicate prevention

### Master Data
- [ ] Test customer creation
- [ ] Test vendor creation
- [ ] Test organization update

### Finance
- [ ] Test AP/AR export
- [ ] Test invoice trigger

---

# PHASE 6 — TECHNICAL ANALYSIS SKILL BUILDING
## Goal: Move from user → technical PO

### XML & Schema
- [ ] Learn XML formatting
- [ ] Learn schema validation
- [ ] Map CW fields to XML
- [ ] Identify optional vs mandatory fields
- [ ] Compare payload versions

### Integration Design
- [ ] Build sequence diagram
- [ ] Build field mapping template
- [ ] Build governance checklist
- [ ] Build troubleshooting guide

---

# PHASE 7 — ADVANCED UPSKILL
## Goal: Become integration lead

### Advanced
- [ ] Learn SOAP vs REST
- [ ] Learn HTTP methods
- [ ] Learn webhooks
- [ ] Learn middleware role (Boomi)
- [ ] Learn security best practices
- [ ] Learn version control
- [ ] Learn deployment governance

---

# WEEKLY REVIEW
## Week 1
- [ ] Access + environment confirmed
- [ ] Tool setup completed
- [ ] eAdaptor config discovered

## Week 2
- [ ] Existing integration documented
- [ ] XML samples reviewed
- [ ] Postman connectivity tested

## Week 3
- [ ] First successful payload
- [ ] Error log analysis
- [ ] Governance documentation

## Week 4+
- [ ] End-to-end integration blueprint
- [ ] Technical confidence growth
- [ ] Solution ownership

---

# BLOCKERS / ISSUES LOG
| Date | Issue | Root Cause | Owner | Status |
|------|------|-------------|------|-------|
|      |      |             |      |       |

---

# LESSONS LEARNED
## Key Findings:
- 
- 
- 

---

# FINAL TARGET
## 90-Day Goal:
- [ ] Understand full eAdaptor Next architecture
- [ ] Independently test integrations
- [ ] Read & validate XML payloads
- [ ] Troubleshoot failures
- [ ] Document governance
- [ ] Design scalable CW integration solutions

---
# PERSONAL DEVELOPMENT GOAL
**From Product Owner → Technical Product Owner → CargoWise Integration Specialist**