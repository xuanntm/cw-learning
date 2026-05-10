# CargoWise Menu Structure (Quick Learning Note)

## 1. Registry (System Foundation / Master Data)

**Definition:**
Core setup area for all master data, configurations, and system controls.

**Think:**
“System brain / setup center”

**Main Purpose:**

* Organizations (customers, vendors, agents)
* Users & security rights
* Charge codes
* Departments / branches
* Milestones
* Document templates
* EDI setup (eAdaptor, endpoints)
* System configuration

**Simple Rule:**
**If data or rule is reused globally → likely in Registry**

---

## 2. EDI Messaging (Integration Hub)

**Definition:**
Module for system-to-system communication (inbound/outbound data exchange).

**Think:**
“CargoWise talks to external systems here”

**Main Purpose:**

* API / XML / JSON integrations
* eAdaptor Next
* Inbound message processing
* Outbound message sending
* Mapping templates
* Authentication
* Integration logs / troubleshooting

**Examples:**

* CargoWise → Boomi
* CargoWise → Customer API
* Vendor → CargoWise shipment data

**Simple Rule:**
**If data enters or leaves CargoWise automatically → EDI Messaging**

---

## 3. Forwarding (Operational Core)

**Definition:**
Main daily logistics execution module.

**Think:**
“Where shipments actually happen”

**Main Purpose:**

* Shipment creation
* Consol
* Booking
* Documentation
* Milestones/events
* Customs
* Pickup/delivery
* One-File operations
* Branch jobs
* Customer service workflow

**Examples:**

* Air export
* Ocean import
* Cross-trade shipment
* Agency forwarding

**Simple Rule:**
**If moving cargo operationally → Forwarding**

---

## 4. Accounting (High-Level Only)

**Definition:**
Financial control layer for billing, cost, and accounting transactions.

**Think:**
“Money control”

**Main Purpose:**

* AR invoices (customer billing)
* AP invoices (vendor costs)
* Profit share
* Commissions
* Revenue recognition
* General ledger posting
* Financial reporting

**Examples:**

* Bill customer freight
* Pay carrier invoice
* Profit share SG ↔ ID
* Branch P&L

**Simple Rule:**
**If money is billed, paid, or reported → Accounting**

---

# Simple Big Picture

## Registry

**Build the rules**

## EDI Messaging

**Connect systems**

## Forwarding

**Run operations**

## Accounting

**Manage money**

---

# Real Workflow Example

### Step 1: Registry

Set customer, charge codes, milestones

### Step 2: Forwarding

Create shipment, consol, delivery

### Step 3: EDI Messaging

Send shipment updates to client

### Step 4: Accounting

Invoice customer + pay vendor

---

# Memory Shortcut:

### Registry = Setup

### EDI = Integration

### Forwarding = Operations

### Accounting = Finance

---

# Bottom Line:

**CargoWise = Setup (Registry) + Execute (Forwarding) + Connect (EDI) + Bill (Accounting)**

This is the core structure your husband should understand first before deep diving into EDI or technical architecture.
