# CargoWise Core System Objects (Concise Note)

## Definition:

**Core system objects** are the main data entities CargoWise uses to run logistics operations, connect parties, track activities, and manage financials.

**Think:**
“Everything in CargoWise is built around key objects that relate to each other.”

---

# 1. Organization (Who)

**What it is:**
Master record of any business party.

**Examples:**

* Customer
* Shipper
* Consignee
* Vendor
* Carrier
* Agent
* Principal

**Purpose:**
Who is involved in the business

---

# 2. Shipment (What moves)

**What it is:**
Main operational file for one cargo movement.

**Examples:**

* Air export
* Sea import
* Cross-trade

**Purpose:**
Controls shipment lifecycle

---

# 3. Consol (How goods are grouped)

**What it is:**
Consolidated transport movement for multiple shipments.

**Examples:**

* One container
* One flight booking

**Purpose:**
Carrier / transport planning

---

# 4. Job (Who executes locally)

**What it is:**
Branch-specific operational or billing work unit.

**Examples:**

* Origin handling
* Destination clearance
* Billing branch

**Purpose:**
Execution + local ownership

---

# 5. Milestone / Event (What happened)

**What it is:**
Status checkpoint.

**Examples:**

* Booked
* Departed
* Arrived
* Delivered

**Purpose:**
Tracking + KPI + integration triggers

---

# 6. Document (Proof / Communication)

**What it is:**
Generated or uploaded business documents.

**Examples:**

* HBL / MBL
* Invoice
* Packing list
* Arrival notice

**Purpose:**
Operational + compliance + customer communication

---

# 7. Invoice / Transaction (Money)

**What it is:**
Financial object for AR/AP.

**Examples:**

* Customer invoice
* Vendor invoice
* Profit share

**Purpose:**
Revenue + cost + accounting

---

# 8. Charge Code (Why money exists)

**What it is:**
Financial logic category.

**Examples:**

* Freight
* Documentation fee
* ACOMM
* PS

**Purpose:**
Controls billing structure

---

# 9. User / Security Role (Who can do what)

**What it is:**
System access object.

**Purpose:**
Permissions + governance

---

# Simple Relationship Model

**Organization**
↓
**Shipment**
↓
**Consol**
↓
**Job**
↓
**Milestone / Document**
↓
**Invoice / Transaction**

---

# Easy Analogy:

## CargoWise = ERP for logistics

### Organization = People/Companies

### Shipment = Case

### Consol = Transport plan

### Job = Department task

### Milestone = Status

### Document = Paperwork

### Invoice = Money

---

# Technical View (Important for EDI/Architecture)

These objects become:

* Database tables
* API payloads
* XML messages
* Event triggers
* Power BI entities

---

# For EDI Focus:

Most integrations revolve around:

### Shipment + Organization + Milestone + Invoice

---

# Memory Shortcut:

### Who = Organization

### What = Shipment

### Group = Consol

### Work = Job

### Status = Milestone

### Proof = Document

### Money = Invoice

---

# Bottom Line:

**CargoWise core objects are reusable business entities that form one connected operational ecosystem.**
Understanding these objects = understanding CargoWise architecture.
