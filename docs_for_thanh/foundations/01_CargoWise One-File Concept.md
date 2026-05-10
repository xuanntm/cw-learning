# CargoWise One-File Concept (Core Operating Principle)

**CargoWise One-File** means **one global operational shipment file is created once and shared across all relevant branches/countries/entities involved in the shipment lifecycle**, instead of each office creating separate disconnected files.

---

## Simple Definition

**One shipment = One master operational file = Multiple countries can work on the same shipment record**

This is one of CargoWise’s biggest strengths for global forwarding and agency operations.

---

## Core Idea

When Origin creates a shipment/job file:

* Shipment data is entered once
* All linked branches (Origin / Destination / Third Country / Agent) access the same operational file
* Each branch can perform its own operational tasks
* Each billing branch can create **its own billing file** under the same shipment
* Milestones, documents, visibility, and shipment history remain globally connected

---

## Example (Ben Line Scenario)

### Shipment:

**Shanghai (China) → Singapore → Jakarta (Indonesia)**

### Process:

### China Office:

* Creates shipment
* Books carrier
* Manages origin documents

### Singapore Office:

* Oversees controlling customer / regional account
* Monitors milestones
* May manage profit share

### Indonesia Office:

* Handles destination customs / delivery
* Issues destination billing

---

## Result:

### ONE operational file globally:

**Shipment #S000123**

### But multiple billing jobs:

* China Billing Job
* Singapore Billing Job
* Indonesia Billing Job

Each office sees:

* Same shipment details
* Shared milestones
* Shared documents (depending rights)
* Their own financial transaction visibility

---

## Key Structure

| Layer                        | Purpose                             |
| ---------------------------- | ----------------------------------- |
| Shipment File (One-File)     | Global operational truth            |
| Consol / House / Declaration | Operational modules                 |
| Billing File per Branch      | Local AR/AP and financial ownership |
| Milestones                   | Shared tracking                     |
| Documents                    | Shared or permission-based          |

---

## Important Business Logic

## 1. One Controlling Customer per Job

* Global business owner
* Often linked to global account
* Can have multiple local debtors

## 2. Multiple Sale Reps by Country

* Same Controlling Customer
* Different billing branch auto-detects local Sales Rep

### Example:

* SG billing tab → SG Sales Rep
* ID billing tab → ID Sales Rep

---

## 3. Separate Financial Ownership

Even though shipment is one-file:

* Revenue belongs locally
* Cost belongs locally
* Profit share can happen across branches

---

# Benefits

## Operational

* No duplicate data entry
* Better milestone continuity
* Reduced email handover
* Better visibility across countries

## Governance

* Standardized data
* Shared master data
* Better KPI reporting
* One source of truth

## Commercial

* Supports global account management
* Enables trade lane visibility
* Supports cross-country collaboration

---

# Common Misunderstanding

## Wrong Thinking:

“Each country should create its own job”

## Correct Thinking:

“Create once globally, let each country work within the same file”

---

# Common Challenges

| Challenge                        | Risk                    |
| -------------------------------- | ----------------------- |
| Poor branch role setup           | Wrong billing ownership |
| Weak controlling customer setup  | Bad sales reporting     |
| Multiple duplicate organizations | Data fragmentation      |
| User rights misconfiguration     | Limited visibility      |
| Country bypassing one-file       | Duplicate jobs          |

---

# Best Practice for Your Team

## For Product / Governance:

* Enforce one-file policy
* Standardize controlling customer logic
* Standardize branch roles
* Standardize sale rep by country
* Audit duplicate shipment creation
* Build KPI: One-file adoption %

---

# Real-World Analogy

### CargoWise One-File = Google Doc

Everyone works in the same document, but each team edits their own section.

### Traditional Non-One-File = Separate Excel Files

Each office creates its own file → duplication, mismatch, reconciliation nightmare

---

# In Your LCS Context

This concept is critical because:

* FS + TCL multiple countries
* Global accounts
* Profit share
* Boomi integrations
* Power BI reporting
* Cost optimization

If One-File discipline is weak:
**Data quality, billing accuracy, and reporting trust all collapse.**

---

# Executive Summary

**CargoWise One-File = One global shipment truth + local operational execution + local financial control**

### Formula:

**One Shipment File + Multi-Branch Collaboration + Branch Billing = CargoWise One-File**

---

## Quick Governance KPI Suggestion:

**One-File Adoption Rate = (Valid single-file cross-country shipments / Total eligible cross-country shipments) %**

Target:
**>95%**

---

# Bottom Line:

**CargoWise is not just a forwarding system — it is a global shared operational platform.
One-File is the foundation that makes global standardization possible.**
