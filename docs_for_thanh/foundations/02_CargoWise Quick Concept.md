# CargoWise Quick Concept Note (For Fast Understanding)

## 1. Shipment (Main Operational File)

**Definition:**
The primary logistics file representing one movement of goods from origin to destination.

**Think:**
“Main case file for one customer movement”

**Example:**
China → Singapore → Indonesia shipment for customer ABC

**Purpose:**

* Operational control
* Customer visibility
* One-File collaboration
* Master shipment record

---

## 2. Consol (Consolidation File)

**Definition:**
A master transport file grouping multiple shipments moving together on the same carrier journey.

**Think:**
“Big container / flight / vessel plan holding multiple shipments”

**Example:**
20 customer shipments all loaded in one container from Shanghai to Singapore

**Purpose:**

* Container or flight planning
* Carrier booking
* Shared freight cost
* Group shipment control

---

## 3. Job (Branch Execution / Financial Work Unit)

**Definition:**
The branch-specific execution or billing layer under shipment/consol.

**Think:**
“Local office’s working and billing section”

**Example:**

* China origin handling job
* Singapore transshipment job
* Indonesia destination clearance job

**Purpose:**

* Local billing
* Local AP/AR
* Operational ownership by branch

---

## 4. Organization (Party / Company Master Data)

**Definition:**
Any company or party involved in business.

**Think:**
“Who is involved?”

**Examples:**

* Shipper
* Consignee
* Customer
* Vendor
* Carrier
* Network Partner
* Principal

**Purpose:**

* Master data
* Commercial ownership
* Billing party
* Compliance screening

---

## 5. Milestone / Event (Status Tracking)

**Definition:**
Operational progress points during shipment lifecycle.

**Think:**
“What happened and when?”

**Examples:**

* Booking Confirmed
* Cargo Picked Up
* Departed
* Arrived
* Customs Cleared
* Delivered

**Purpose:**

* Tracking
* Customer updates
* KPI measurement
* Integration triggers (Boomi/API)

---

## 6. Invoice (Financial Document)

**Definition:**
Billing document for charges.

**Think:**
“Money in / money out”

**Types:**

* AR Invoice = Customer billed
* AP Invoice = Vendor cost
* Profit Share / Commission

**Purpose:**

* Revenue
* Cost
* Accounting
* Profitability

---

# Simple Relationship Flow

**Organization** = Who
↓
**Shipment** = Main movement
↓
**Consol** = Group transport plan (if multiple shipments together)
↓
**Job** = Local execution & billing
↓
**Milestone/Event** = Status updates
↓
**Invoice** = Financial result

---

# Easy Real-World Example

### Customer ships 10 boxes from China to Indonesia:

### Organization:

ABC Customer, DHL Carrier, Ben Line SG

### Shipment:

ABC’s shipment file

### Consol:

Container with ABC + other customers

### Job:

China export job + Indonesia import job

### Milestone:

Picked up → Loaded → Arrived → Delivered

### Invoice:

Customer billed + vendor paid

---

# Memory Shortcut:

### Shipment = Movement

### Consol = Group Movement

### Job = Work + Billing

### Organization = Party

### Milestone = Status

### Invoice = Money

---

# Bottom Line:

**CargoWise = One operational ecosystem where data, movement, parties, status, and money are connected.**
