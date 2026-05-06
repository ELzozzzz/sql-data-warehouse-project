/*
================================================================================
  DDL Script: Gold Layer (Star Schema – Dimension & Fact Views)
================================================================================
  Purpose  : Create the Gold schema and define analytical views that implement
             the star schema.  No data is physically stored here; every object
             is a view over Silver tables so that downstream tools always read
             the latest cleansed data without an additional ETL step.

  Star Schema
  ───────────
      dim_customers  ─┐
      dim_products   ─┼──► fact_sales
      dim_date       ─┘

  Run order: 5 – run after proc_load_silver.sql
================================================================================
*/

-- ============================================================
-- Schema
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- ============================================================
-- dim_customers
-- Combines CRM customer master data with ERP demographics and
-- ERP country information into one conformed customer dimension.
-- ============================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO
CREATE VIEW gold.dim_customers AS
SELECT
    -- Surrogate key (deterministic hash keeps it stable across reloads)
    ROW_NUMBER() OVER (ORDER BY ci.cst_id)          AS customer_key,

    -- Natural / business keys
    ci.cst_id                                        AS customer_id,
    ci.cst_key                                       AS customer_number,

    -- Demographics
    ci.cst_firstname                                 AS first_name,
    ci.cst_lastname                                  AS last_name,
    ci.cst_firstname + ' ' + ci.cst_lastname         AS full_name,
    loc.cntry                                        AS country,
    ci.cst_marital_status                            AS marital_status,

    -- Resolve gender: CRM takes priority; fall back to ERP
    CASE
        WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr
        ELSE ISNULL(ea.gen, 'n/a')
    END                                              AS gender,

    ea.bdate                                         AS birthdate,
    DATEDIFF(YEAR, ea.bdate, GETDATE())              AS age,

    ci.cst_create_date                               AS customer_since
FROM silver.crm_cust_info     ci
LEFT JOIN silver.erp_cust_az12 ea
       ON ci.cst_key = ea.cid
LEFT JOIN silver.erp_loc_a101  loc
       ON ci.cst_key = loc.cid;
GO

-- ============================================================
-- dim_products
-- Combines CRM product catalogue with ERP category hierarchy.
-- Excludes historical/expired product versions (prd_end_dt IS NULL).
-- ============================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY p.prd_id)           AS product_key,

    -- Natural / business keys
    p.prd_id                                         AS product_id,
    p.prd_key                                        AS product_number,
    p.prd_nm                                         AS product_name,

    -- Pricing & classification
    p.prd_cost                                       AS standard_cost,
    p.prd_line                                       AS product_line,
    p.prd_start_dt                                   AS product_start_date,

    -- Category hierarchy from ERP
    c.cat                                            AS category,
    c.subcat                                         AS subcategory,
    c.maintenance                                    AS maintenance_required
FROM silver.crm_prd_info          p
LEFT JOIN silver.erp_px_cat_g1v2  c
       ON p.cat_id = c.id
WHERE p.prd_end_dt IS NULL;  -- current product versions only
GO

-- ============================================================
-- dim_date
-- Calendar dimension covering the full range of sales dates.
-- Generated inline from the sales data so no static table is
-- required and the range always matches the actual data.
-- ============================================================
IF OBJECT_ID('gold.dim_date', 'V') IS NOT NULL
    DROP VIEW gold.dim_date;
GO
CREATE VIEW gold.dim_date AS
WITH date_spine AS (
    -- one row per calendar day between min and max sales order date
    SELECT DISTINCT sls_order_dt AS date_value
    FROM silver.crm_sales_details
    WHERE sls_order_dt IS NOT NULL
)
SELECT
    CAST(FORMAT(date_value, 'yyyyMMdd') AS INT)          AS date_key,
    date_value                                            AS full_date,
    YEAR(date_value)                                      AS year,
    MONTH(date_value)                                     AS month_number,
    DATENAME(MONTH, date_value)                           AS month_name,
    DATEPART(QUARTER, date_value)                         AS quarter,
    'Q' + CAST(DATEPART(QUARTER, date_value) AS VARCHAR(2)) AS quarter_label,
    DATEPART(DAYOFYEAR, date_value)                       AS day_of_year,
    DATEPART(WEEKDAY, date_value)                         AS day_of_week,
    DATENAME(WEEKDAY, date_value)                         AS day_name,
    CASE WHEN DATEPART(WEEKDAY, date_value) IN (1, 7)
         THEN 1 ELSE 0 END                                AS is_weekend
FROM date_spine;
GO

-- ============================================================
-- fact_sales
-- Central fact table joining Silver sales to Gold dimensions.
-- Grain: one row per order line.
-- ============================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT
    -- Dimension foreign keys
    d.date_key                          AS order_date_key,
    p.product_key,
    c.customer_key,

    -- Degenerate dimensions (order attributes not in a separate dim)
    s.sls_ord_num                       AS order_number,
    s.sls_ship_dt                       AS ship_date,
    s.sls_due_dt                        AS due_date,

    -- Measures
    s.sls_quantity                      AS quantity,
    s.sls_price                         AS unit_price,
    s.sls_discount                      AS discount_amount,
    s.sls_sales                         AS sales_amount,

    -- Calculated measures
    s.sls_sales - (p.standard_cost * s.sls_quantity) AS gross_profit
FROM silver.crm_sales_details  s
INNER JOIN gold.dim_date       d ON s.sls_order_dt = d.full_date
INNER JOIN gold.dim_products   p ON s.sls_prd_key  = p.product_number
INNER JOIN gold.dim_customers  c ON s.sls_cust_id  = c.customer_id;
GO
