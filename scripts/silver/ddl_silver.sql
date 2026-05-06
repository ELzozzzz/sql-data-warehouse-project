/*
================================================================================
  DDL Script: Silver Layer (Cleansed & Conformed Tables)
================================================================================
  Purpose  : Create the Silver schema and its cleansed tables.
             Data is standardised, deduplicated, and enriched with
             surrogate / audit columns ready for Gold consumption.
  Run order: 3 – run after proc_load_bronze.sql
================================================================================
*/

-- ============================================================
-- Schema
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

-- ============================================================
-- CRM: Customer Info
-- ============================================================
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO
CREATE TABLE silver.crm_cust_info (
    cst_id             INT            NOT NULL,
    cst_key            NVARCHAR(50)   NOT NULL,
    cst_firstname      NVARCHAR(50),
    cst_lastname       NVARCHAR(50),
    cst_marital_status NVARCHAR(20),   -- 'Married' | 'Single' | 'n/a'
    cst_gndr           NVARCHAR(20),   -- 'Male' | 'Female' | 'n/a'
    cst_create_date    DATE,
    -- Audit
    dwh_create_date    DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ============================================================
-- CRM: Product Info
-- ============================================================
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO
CREATE TABLE silver.crm_prd_info (
    prd_id           INT            NOT NULL,
    cat_id           NVARCHAR(50),  -- derived from prd_key prefix
    prd_key          NVARCHAR(50)   NOT NULL,
    prd_nm           NVARCHAR(100),
    prd_cost         DECIMAL(10, 2),
    prd_line         NVARCHAR(50),
    prd_start_dt     DATE,
    prd_end_dt       DATE,
    -- Audit
    dwh_create_date  DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ============================================================
-- CRM: Sales Details
-- ============================================================
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO
CREATE TABLE silver.crm_sales_details (
    sls_ord_num      NVARCHAR(50)   NOT NULL,
    sls_prd_key      NVARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE,          -- converted from YYYYMMDD integer
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_sales        DECIMAL(12, 2),
    sls_quantity     INT,
    sls_price        DECIMAL(10, 2),
    sls_discount     DECIMAL(5, 2),
    -- Audit
    dwh_create_date  DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ============================================================
-- ERP: Customer Demographics
-- ============================================================
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO
CREATE TABLE silver.erp_cust_az12 (
    cid              NVARCHAR(50)   NOT NULL,
    bdate            DATE,
    gen              NVARCHAR(20),  -- 'Male' | 'Female' | 'n/a'
    -- Audit
    dwh_create_date  DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ============================================================
-- ERP: Customer Locations
-- ============================================================
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO
CREATE TABLE silver.erp_loc_a101 (
    cid              NVARCHAR(50)   NOT NULL,
    cntry            NVARCHAR(50),
    -- Audit
    dwh_create_date  DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ============================================================
-- ERP: Product Categories
-- ============================================================
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO
CREATE TABLE silver.erp_px_cat_g1v2 (
    id               NVARCHAR(50)   NOT NULL,
    cat              NVARCHAR(100),
    subcat           NVARCHAR(100),
    maintenance      NVARCHAR(50),
    -- Audit
    dwh_create_date  DATETIME2 DEFAULT SYSDATETIME()
);
GO
