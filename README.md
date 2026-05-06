# SQL Data Warehouse Project

A production-ready **SQL Server data warehouse** built as a data engineering portfolio project, demonstrating the full medallion architecture pipeline from raw source ingestion to analytical star schema.

---

## 🏗️ Architecture

This project uses the **Bronze → Silver → Gold** medallion architecture pattern.

```
Source Systems (CRM + ERP)
        │
        ▼  BULK INSERT
  ┌─────────────┐
  │   BRONZE    │  Raw / as-is staging tables
  └──────┬──────┘
         │  Cleanse & conform
         ▼
  ┌─────────────┐
  │   SILVER    │  Deduplicated, standardised, business-rule-applied tables
  └──────┬──────┘
         │  Integrate & model
         ▼
  ┌─────────────┐
  │    GOLD     │  Star schema views (dim_customers, dim_products, dim_date, fact_sales)
  └─────────────┘
         │  Consume
         ▼
  BI Tools / Analytics
```

See [`docs/architecture.md`](docs/architecture.md) for the full layer breakdown.

---

## 📁 Repository Structure

```
sql-data-warehouse-project/
│
├── datasets/                        # Sample source data (CSV)
│   ├── source_crm/
│   │   ├── cust_info.csv            # CRM: customer master
│   │   ├── prd_info.csv             # CRM: product catalogue
│   │   └── sales_details.csv        # CRM: sales transactions
│   └── source_erp/
│       ├── CUST_AZ12.csv            # ERP: customer demographics
│       ├── LOC_A101.csv             # ERP: customer locations
│       └── PX_CAT_G1V2.csv         # ERP: product categories
│
├── docs/                            # Documentation
│   ├── architecture.md              # Medallion architecture overview
│   ├── data_dictionary.md           # Column-level descriptions for all tables/views
│   └── diagrams/
│       └── star_schema.md           # Star schema diagram + sample queries
│
├── scripts/                         # SQL ETL scripts
│   ├── bronze/
│   │   ├── ddl_bronze.sql           # Create Bronze staging tables
│   │   └── proc_load_bronze.sql     # Load CSVs into Bronze (BULK INSERT)
│   ├── silver/
│   │   ├── ddl_silver.sql           # Create Silver cleansed tables
│   │   └── proc_load_silver.sql     # Transform & load Bronze → Silver
│   └── gold/
│       └── ddl_gold.sql             # Create Gold star schema views
│
├── tests/
│   └── quality_checks.sql           # Data quality validation queries
│
├── LICENSE
└── README.md
```

---

## ⭐ Star Schema (Gold Layer)

```
dim_customers ──┐
dim_products  ──┼──► fact_sales
dim_date      ──┘
```

| Object | Type | Description |
|---|---|---|
| `gold.dim_customers` | View | Conformed customer dimension (CRM + ERP combined) |
| `gold.dim_products` | View | Current product dimension with category hierarchy |
| `gold.dim_date` | View | Calendar dimension derived from sales date range |
| `gold.fact_sales` | View | Order-line grain; measures: sales_amount, gross_profit |

---

## 🚀 Quick Start

### Prerequisites
- **SQL Server 2019+** (or Azure SQL Database)
- Access to the `datasets/` folder from the SQL Server instance

### Step 1 – Create the Database
```sql
CREATE DATABASE DataWarehouse;
USE DataWarehouse;
```

### Step 2 – Build Bronze Layer
```sql
-- Create staging tables
:r scripts/bronze/ddl_bronze.sql

-- Load raw CSVs (update $(DatasetPath) to your absolute datasets/ path)
:setvar DatasetPath "C:\path\to\datasets"
:r scripts/bronze/proc_load_bronze.sql
EXEC bronze.load_bronze;
```

### Step 3 – Build Silver Layer
```sql
-- Create cleansed tables
:r scripts/silver/ddl_silver.sql

-- Cleanse and load
:r scripts/silver/proc_load_silver.sql
EXEC silver.load_silver;
```

### Step 4 – Build Gold Layer (Star Schema)
```sql
:r scripts/gold/ddl_gold.sql
```

### Step 5 – Run Quality Checks
```sql
:r tests/quality_checks.sql
```

---

## 🔄 ETL Transformations (Silver Layer)

| Transformation | Applied To | Detail |
|---|---|---|
| Deduplication | Customers | Keep latest row per `cst_id` using `ROW_NUMBER()` |
| Code decoding | Customers, Products | `M`→`Male`, `F`→`Female`, `M`→`Married`, etc. |
| Date conversion | Sales | YYYYMMDD INT → DATE; out-of-range values → NULL |
| Negative value correction | Sales | Non-positive `sls_sales` recalculated from qty × price |
| Prefix stripping | ERP customers | Remove leading `NAS` from customer IDs |
| Derived columns | Products | `cat_id` extracted from composite product key |
| LEAD-based SCD end date | Products | `prd_end_dt` calculated from next version's start date |
| Country standardisation | Locations | ISO codes decoded to full country names |

---

## 📊 Sample Analytical Queries

**Total sales and profit by product category:**
```sql
SELECT
    p.category,
    SUM(f.sales_amount) AS total_sales,
    SUM(f.gross_profit) AS total_profit
FROM gold.fact_sales   f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales DESC;
```

**Top customers by revenue:**
```sql
SELECT TOP 5
    c.full_name,
    c.country,
    SUM(f.sales_amount) AS revenue
FROM gold.fact_sales    f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.full_name, c.country
ORDER BY revenue DESC;
```

More sample queries are available in [`docs/diagrams/star_schema.md`](docs/diagrams/star_schema.md).

---

## 📖 Documentation

| Document | Description |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Layer responsibilities, design decisions, execution order |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Full column-level description of every table and view |
| [`docs/diagrams/star_schema.md`](docs/diagrams/star_schema.md) | Star schema diagram and sample analytical queries |

---

## 🛡️ Data Quality

The `tests/quality_checks.sql` script validates:
- No duplicate customer IDs in Silver
- No NULL/blank business keys
- No unexpected gender or marital-status codes
- No negative product costs
- Date logical consistency (start ≤ end, ship ≥ order)
- No orphan rows in the Gold fact table
- Full row-count summary across all layers

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
