# Anatomy of a Custom Document (sample 04)

Source: [`../samples/04_cw_custom_document_sample.xlsx`](../samples/04_cw_custom_document_sample.xlsx). It has 28 sections. Judging by its content (Available Date, Storage Date, Goods Available At, Prealert/Arrival Notice Remarks), it is an **Arrival Notice-style** freight document.

## Page layout

```
┌──────────────────────────── PAGE 1 ────────────────────────────┐
│ HFP  1  Company Logo                                           │
│ HFP  2  Document Title with Mode + Departure/Arrival (Short)   │
│ HFP  3  H56 Recipient with Available Date + Storage Date  ★    │
├────────────────────────────────────────────────────────────────┤
│ BDY  7  Document Opening Text by Report Name                   │
│ BDY  8  Shipment Details Section Header                        │
│ BDY  9  Consignor + Consignee Name & Address        [filter]   │
│ BDY 10  H56 Notify Party + Goods Available At  ★               │
│ BDY 11  Release Type + Commodity Type               [SEA only] │
│ BEX 12  Commodity                                   [non-SEA]  │
│ BDY 13  Shipping Line + Goods to be Cleared By                 │
│ BDY 14  H56 Inbond Transit and AMS Details  ★                  │
│ BDY 15  H56 Order Numbers/Reference + Master Bill + House Bill★│
│ BEX 16  Goods Description (Multi Line)                         │
│ BDY 17  Packages + Weight + Volume + Chargeable + Est Delivery │
│ BDY 18  Goods Collected From/Date + Delivered To/Date          │
│ BEX 19  Shipment Routes (Mode/Transport/Load/Disch/ETD/ETA/…)  │
│ BDY 20  SCN + KA + CTO/Berth                  [SEA/RAI & MY]   │
│ BEX 21  Hazardous Category                                     │
│ BEX 22  Container List (Number/Seal/Type/…)       [no MBOL]    │
│ BEX 23  Container List (Number/MBOL/IT Number/…)  [has MBOL]   │
│ BEX 24  Marks and Numbers                                      │
│ BEX 25  Notes - Prealert/Arrival Notice Remarks                │
│ BDY 26  Document Closing Text by Report Name                   │
│ BDY 27  H56 Signoff  ★                                         │
├────────────────────────────────────────────────────────────────┤
│ FAL 28  Default Page Footer for All Documents                  │
└────────────────────────────────────────────────────────────────┘
 PAGE 2+ header instead of HFP:
   HS2 4  Document Title with Mode + Departure/Arrival (Short)
   HS2 5  Recipient with Job Number
   HS2 6  Separator - Blank Row (Solid Background)

 ★ = custom H56 element
```

## Conditional sections (filters)

| Order | Section | Filter | Why |
|---|---|---|---|
| 9 | Consignor + Consignee | `"<Consignor.CompanyNameAndAddress>" != "" \|\| "<Consignee.CompanyNameAndAddress>" != ""` | Hide the block when both parties are empty |
| 11 / 12 | Release Type + Commodity Type / Commodity | `"<JS_TransportMode>" == "SEA"` / `!= "SEA"` | Mode-specific pair. Exactly one of the two shows |
| 20 | SCN + KA + CTO/Berth | `("<TransportMode>" == "SEA" \|\| "<TransportMode>" == "RAI") && "<CompanyCountryCode>" == "MY"` | Malaysia-only port references |
| 22 / 23 | Container List variants | `"<HasContainersNewMBOL>" != "Y"` / `== "Y"` | Mutually exclusive variants |

## Patterns worth reusing

1. **Different header for page 1 and page 2+:** the full header (logo + title + recipient) goes on page 1 (`HFP`). Later pages get a compact title + job number + separator (`HS2`).
2. **Generic "by Report Name" text:** the opening/closing text elements pick their wording by report name, so **one template can serve several menu items**.
3. **Mutually exclusive pairs:** two sections with opposite filters act as an if/else.
4. **Wrap a standard document in custom elements:** 5 of the 28 sections are `H56` custom elements. The rest are standard library elements.
5. **Macro syntax:** `"<FieldName>"` inside double quotes, compared as a string with `==`/`!=`, combined with `&&`/`||` and parentheses. Fields can be dotted (`<Consignor.CompanyNameAndAddress>`) or column-style (`<JS_TransportMode>`, matching the `JobShipment` column prefix).
