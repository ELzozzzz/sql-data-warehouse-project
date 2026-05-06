# Architecture Overview

## Medallion Architecture

This project implements the **Bronze → Silver → Gold** medallion architecture pattern for building a scalable, maintainable SQL data warehouse.

```
┌──────────────────────────────────────────────────────────┐
│                     Source Systems                        │
│          CRM System            ERP System                 │
│   (customers, products,   (demographics, locations,       │
│       sales orders)          product categories)          │
└──────────────────────────────────────────────────────────┘
                          │ CSV Extract
                          ▼
┌──────────────────────────────────────────────────────────┐
│                   BRONZE LAYER                            │
│              Raw / As-Is Ingestion                        │
│  ┌──────────────────┐   ┌──────────────────────────────┐ │
│  │  CRM Tables      │   │  ERP Tables                  │ │
│  │  crm_cust_info   │   │  erp_cust_az12               │ │
│  │  crm_prd_info    │   │  erp_loc_a101                │ │
│  │  crm_sales_detail│   │  erp_px_cat_g1v2             │ │
│  └──────────────────┘   └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                          │ Cleanse & Conform
                          ▼
┌──────────────────────────────────────────────────────────┐
│                   SILVER LAYER                            │
│          Cleansed, Standardised, Conformed                │
│  ┌──────────────────┐   ┌──────────────────────────────┐ │
│  │  CRM Tables      │   │  ERP Tables                  │ │
│  │  crm_cust_info   │   │  erp_cust_az12               │ │
│  │  crm_prd_info    │   │  erp_loc_a101                │ │
│  │  crm_sales_detail│   │  erp_px_cat_g1v2             │ │
│  └──────────────────┘   └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                          │ Integrate & Model
                          ▼
┌──────────────────────────────────────────────────────────┐
│                    GOLD LAYER                             │
│            Star Schema – Business-Ready Views             │
│                                                           │
│   dim_customers   dim_products   dim_date                 │
│         └──────────────┴────────────┘                    │
│                         │                                 │
│                    fact_sales                             │
└──────────────────────────────────────────────────────────┘
                          │ Consume
                          ▼
              BI Tools / Ad-hoc Analytics
        (Power BI, Tableau, Excel, SSRS, etc.)
```

---

## Layer Responsibilities

### Bronze – Raw Ingestion
| Characteristic | Detail |
|---|---|
| **Goal** | Land data exactly as received; no transformations |
| **Storage** | Staging tables (full truncate-and-reload on each run) |
| **Schema** | Source column names preserved; types widened where necessary |
| **Load script** | `scripts/bronze/proc_load_bronze.sql` |
| **When to use** | Debugging / re-processing; answering "what did the source send?" |

### Silver – Cleansed & Conformed
| Characteristic | Detail |
|---|---|
| **Goal** | Single source of truth per entity; business rules applied |
| **Transformations** | Deduplication, date conversion, NULL handling, code standardisation, business-rule corrections |
| **Schema** | Audit columns added (`dwh_create_date`) |
| **Load script** | `scripts/silver/proc_load_silver.sql` |
| **When to use** | Data quality investigations; building new Gold objects |

### Gold – Business-Ready Star Schema
| Characteristic | Detail |
|---|---|
| **Goal** | Optimised for analytical queries and BI consumption |
| **Implementation** | SQL views over Silver (no physical copy; always fresh) |
| **Schema** | Star schema: `fact_sales` + `dim_customers`, `dim_products`, `dim_date` |
| **Script** | `scripts/gold/ddl_gold.sql` |
| **When to use** | All reporting, dashboards, and end-user analytics |

---

## ETL Pipeline Execution Order

```
1. scripts/bronze/ddl_bronze.sql        -- Create Bronze tables
2. scripts/bronze/proc_load_bronze.sql  -- Load raw CSVs into Bronze
3. scripts/silver/ddl_silver.sql        -- Create Silver tables
4. scripts/silver/proc_load_silver.sql  -- Cleanse & load into Silver
5. scripts/gold/ddl_gold.sql            -- Create Gold views (star schema)
6. tests/quality_checks.sql             -- Validate results
```

---

## Data Sources

### CRM System
| File | Description |
|---|---|
| `source_crm/cust_info.csv` | Customer master data – names, gender, marital status |
| `source_crm/prd_info.csv` | Product catalogue – names, costs, product lines |
| `source_crm/sales_details.csv` | Sales transactions – orders, quantities, prices |

### ERP System
| File | Description |
|---|---|
| `source_erp/CUST_AZ12.csv` | Customer demographics – birth dates, gender codes |
| `source_erp/LOC_A101.csv` | Customer country / location data |
| `source_erp/PX_CAT_G1V2.csv` | Product category and subcategory hierarchy |

---

## Design Decisions

1. **Views for Gold layer** – Gold objects are views rather than physical tables. This avoids a redundant copy of data and means any fix in Silver is immediately reflected in Gold without a reload step.

2. **Surrogate keys via ROW_NUMBER** – The dimension views generate surrogate keys using `ROW_NUMBER()`. For a production system these could be moved to identity columns in materialised tables.

3. **Gender resolution hierarchy** – When both CRM and ERP carry a gender value, CRM is treated as authoritative. The ERP value is used only as a fallback.

4. **Date dimension from spine** – `gold.dim_date` is generated dynamically from the distinct sales dates, keeping the implementation self-contained without a pre-populated calendar table.

5. **Idempotent scripts** – All DDL scripts use `IF OBJECT_ID ... DROP` patterns so they can be re-run safely without manual cleanup.
