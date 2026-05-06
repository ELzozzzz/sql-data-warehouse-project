# Data Dictionary

This document describes every table and view in the data warehouse, grouped by layer.

---

## Bronze Layer

### `bronze.crm_cust_info`
Raw customer data extracted from the CRM system.

| Column | Type | Description |
|---|---|---|
| `cst_id` | INT | Source customer identifier |
| `cst_key` | NVARCHAR(50) | Customer business key (used for cross-system joins) |
| `cst_firstname` | NVARCHAR(50) | Customer first name |
| `cst_lastname` | NVARCHAR(50) | Customer last name |
| `cst_marital_status` | NVARCHAR(50) | Raw marital status code (`M`, `S`, or other) |
| `cst_gndr` | NVARCHAR(50) | Raw gender code (`M`, `F`, or other) |
| `cst_create_date` | DATE | Date the customer record was created in the CRM |

---

### `bronze.crm_prd_info`
Raw product catalogue extracted from the CRM system.

| Column | Type | Description |
|---|---|---|
| `prd_id` | INT | Source product identifier |
| `prd_key` | NVARCHAR(50) | Product composite key containing category prefix and product code |
| `prd_nm` | NVARCHAR(100) | Product name |
| `prd_cost` | DECIMAL(10,2) | Standard product cost |
| `prd_line` | NVARCHAR(50) | Product line code (`M`=Mountain, `R`=Road, `T`=Touring, `S`=Other Sales) |
| `prd_start_dt` | DATE | Date this product version became effective |
| `prd_end_dt` | DATE | Date this product version was superseded (NULL = current) |

---

### `bronze.crm_sales_details`
Raw sales order transactions extracted from the CRM system.

| Column | Type | Description |
|---|---|---|
| `sls_ord_num` | NVARCHAR(50) | Sales order number |
| `sls_prd_key` | NVARCHAR(50) | Product key (joins to `crm_prd_info.prd_key`) |
| `sls_cust_id` | INT | Customer identifier (joins to `crm_cust_info.cst_id`) |
| `sls_order_dt` | INT | Order date as YYYYMMDD integer |
| `sls_ship_dt` | INT | Shipment date as YYYYMMDD integer |
| `sls_due_dt` | INT | Due date as YYYYMMDD integer |
| `sls_sales` | DECIMAL(12,2) | Total sales amount for the order line |
| `sls_quantity` | INT | Quantity ordered |
| `sls_price` | DECIMAL(10,2) | Unit price |
| `sls_discount` | DECIMAL(5,2) | Discount amount applied |

---

### `bronze.erp_cust_az12`
Raw customer demographics from the ERP system.

| Column | Type | Description |
|---|---|---|
| `cid` | NVARCHAR(50) | Customer identifier (may be prefixed with `NAS`) |
| `bdate` | DATE | Customer birth date |
| `gen` | NVARCHAR(50) | Gender code (`M`, `Male`, `F`, `Female`, or other) |

---

### `bronze.erp_loc_a101`
Raw customer country/location data from the ERP system.

| Column | Type | Description |
|---|---|---|
| `cid` | NVARCHAR(50) | Customer identifier |
| `cntry` | NVARCHAR(50) | Country code or name as received from ERP |

---

### `bronze.erp_px_cat_g1v2`
Raw product category hierarchy from the ERP system.

| Column | Type | Description |
|---|---|---|
| `id` | NVARCHAR(50) | Category identifier (matches prefix in `crm_prd_info.prd_key`) |
| `cat` | NVARCHAR(100) | Top-level category (e.g., Bikes, Accessories) |
| `subcat` | NVARCHAR(100) | Sub-category (e.g., Mountain Bikes, Helmets) |
| `maintenance` | NVARCHAR(50) | Whether the product requires maintenance (`Yes` / `No`) |

---

## Silver Layer

Silver tables mirror Bronze but with cleansed values and audit columns added.

### `silver.crm_cust_info`
Deduplicated, standardised customer master data.

| Column | Type | Notes vs Bronze |
|---|---|---|
| `cst_id` | INT | NOT NULL |
| `cst_key` | NVARCHAR(50) | Trimmed |
| `cst_firstname` | NVARCHAR(50) | Trimmed |
| `cst_lastname` | NVARCHAR(50) | Trimmed |
| `cst_marital_status` | NVARCHAR(20) | Decoded: `M`→`Married`, `S`→`Single`, else `n/a` |
| `cst_gndr` | NVARCHAR(20) | Decoded: `M`→`Male`, `F`→`Female`, else `n/a` |
| `cst_create_date` | DATE | |
| `dwh_create_date` | DATETIME2 | Load timestamp (default: `SYSDATETIME()`) |

---

### `silver.crm_prd_info`
Enriched product catalogue with derived category identifier and normalised line codes.

| Column | Type | Notes vs Bronze |
|---|---|---|
| `prd_id` | INT | NOT NULL |
| `cat_id` | NVARCHAR(50) | Extracted from prd_key prefix (used to join ERP categories) |
| `prd_key` | NVARCHAR(50) | Suffix part of the original composite key |
| `prd_nm` | NVARCHAR(100) | Trimmed |
| `prd_cost` | DECIMAL(10,2) | NULL replaced with 0 |
| `prd_line` | NVARCHAR(50) | Decoded: `M`→`Mountain`, `R`→`Road`, `T`→`Touring`, `S`→`Other Sales` |
| `prd_start_dt` | DATE | |
| `prd_end_dt` | DATE | Calculated via LEAD (NULL = current version) |
| `dwh_create_date` | DATETIME2 | Load timestamp |

---

### `silver.crm_sales_details`
Cleansed sales transactions with dates converted and amounts corrected.

| Column | Type | Notes vs Bronze |
|---|---|---|
| `sls_ord_num` | NVARCHAR(50) | NOT NULL, trimmed |
| `sls_prd_key` | NVARCHAR(50) | Trimmed |
| `sls_cust_id` | INT | |
| `sls_order_dt` | DATE | Converted from YYYYMMDD INT; NULL if out-of-range |
| `sls_ship_dt` | DATE | Converted from YYYYMMDD INT |
| `sls_due_dt` | DATE | Converted from YYYYMMDD INT |
| `sls_sales` | DECIMAL(12,2) | Non-positive values replaced with `qty × ABS(price)` |
| `sls_quantity` | INT | |
| `sls_price` | DECIMAL(10,2) | Absolute value applied |
| `sls_discount` | DECIMAL(5,2) | NULL replaced with 0 |
| `dwh_create_date` | DATETIME2 | Load timestamp |

---

### `silver.erp_cust_az12`

| Column | Type | Notes vs Bronze |
|---|---|---|
| `cid` | NVARCHAR(50) | `NAS` prefix stripped if present |
| `bdate` | DATE | Future dates set to NULL |
| `gen` | NVARCHAR(20) | Standardised to `Male` / `Female` / `n/a` |
| `dwh_create_date` | DATETIME2 | Load timestamp |

---

### `silver.erp_loc_a101`

| Column | Type | Notes vs Bronze |
|---|---|---|
| `cid` | NVARCHAR(50) | |
| `cntry` | NVARCHAR(50) | ISO codes decoded to full names (`US`→`United States`, etc.) |
| `dwh_create_date` | DATETIME2 | Load timestamp |

---

### `silver.erp_px_cat_g1v2`

| Column | Type | Notes vs Bronze |
|---|---|---|
| `id` | NVARCHAR(50) | Trimmed |
| `cat` | NVARCHAR(100) | Trimmed |
| `subcat` | NVARCHAR(100) | Trimmed |
| `maintenance` | NVARCHAR(50) | Trimmed |
| `dwh_create_date` | DATETIME2 | Load timestamp |

---

## Gold Layer (Star Schema)

### `gold.dim_customers`

| Column | Type | Description |
|---|---|---|
| `customer_key` | INT | Surrogate key (warehouse-generated) |
| `customer_id` | INT | CRM natural key |
| `customer_number` | NVARCHAR(50) | CRM business key |
| `first_name` | NVARCHAR(50) | |
| `last_name` | NVARCHAR(50) | |
| `full_name` | NVARCHAR(101) | Concatenated first + last |
| `country` | NVARCHAR(50) | From ERP locations |
| `marital_status` | NVARCHAR(20) | |
| `gender` | NVARCHAR(20) | CRM value preferred; ERP as fallback |
| `birthdate` | DATE | From ERP demographics |
| `age` | INT | Calculated: `DATEDIFF(YEAR, birthdate, today)` |
| `customer_since` | DATE | CRM account creation date |

---

### `gold.dim_products`

| Column | Type | Description |
|---|---|---|
| `product_key` | INT | Surrogate key |
| `product_id` | INT | CRM natural key |
| `product_number` | NVARCHAR(50) | CRM product code |
| `product_name` | NVARCHAR(100) | |
| `standard_cost` | DECIMAL(10,2) | Manufacturing / purchase cost |
| `product_line` | NVARCHAR(50) | Decoded line name |
| `product_start_date` | DATE | |
| `category` | NVARCHAR(100) | From ERP category hierarchy |
| `subcategory` | NVARCHAR(100) | From ERP category hierarchy |
| `maintenance_required` | NVARCHAR(50) | From ERP (`Yes`/`No`) |

---

### `gold.dim_date`

| Column | Type | Description |
|---|---|---|
| `date_key` | INT | YYYYMMDD integer key |
| `full_date` | DATE | Calendar date |
| `year` | INT | |
| `month_number` | INT | 1–12 |
| `month_name` | NVARCHAR(20) | Full month name |
| `quarter` | INT | 1–4 |
| `quarter_label` | CHAR(2) | `Q1` – `Q4` |
| `day_of_year` | INT | 1–366 |
| `day_of_week` | INT | 1 (Sunday) – 7 (Saturday) |
| `day_name` | NVARCHAR(20) | Full weekday name |
| `is_weekend` | INT | 1 if Saturday or Sunday, else 0 |

---

### `gold.fact_sales`

| Column | Type | Description |
|---|---|---|
| `order_date_key` | INT | FK → `dim_date.date_key` |
| `product_key` | INT | FK → `dim_products.product_key` |
| `customer_key` | INT | FK → `dim_customers.customer_key` |
| `order_number` | NVARCHAR(50) | Degenerate dimension |
| `ship_date` | DATE | |
| `due_date` | DATE | |
| `quantity` | INT | Units sold |
| `unit_price` | DECIMAL(10,2) | |
| `discount_amount` | DECIMAL(5,2) | |
| `sales_amount` | DECIMAL(12,2) | Total revenue for the line |
| `gross_profit` | DECIMAL(12,2) | `sales_amount − (standard_cost × quantity)` |
