/*
================================================================================
  DDL Script: Bronze Layer (Raw / Staging Tables)
================================================================================
  Purpose  : Create the Bronze schema and its raw staging tables.
             Data is loaded as-is from source systems (CRM and ERP) with no
             transformations. Every column retains the original source name
             and data type (or a safe widened equivalent).
  Run order: 1 – run before proc_load_bronze.sql
================================================================================
*/

-- ============================================================
-- Schema
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

-- ============================================================
-- CRM Source Tables
-- ============================================================

-- Drop and recreate to allow idempotent reruns
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO
CREATE TABLE bronze.crm_cust_info (
    cst_id            INT,
    cst_key           NVARCHAR(50),
    cst_firstname     NVARCHAR(50),
    cst_lastname      NVARCHAR(50),
    cst_marital_status NVARCHAR(50),
    cst_gndr          NVARCHAR(50),
    cst_create_date   DATE
);
GO

IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO
CREATE TABLE bronze.crm_prd_info (
    prd_id        INT,
    prd_key       NVARCHAR(50),
    prd_nm        NVARCHAR(100),
    prd_cost      DECIMAL(10, 2),
    prd_line      NVARCHAR(50),
    prd_start_dt  DATE,
    prd_end_dt    DATE
);
GO

IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num   NVARCHAR(50),
    sls_prd_key   NVARCHAR(50),
    sls_cust_id   INT,
    sls_order_dt  INT,           -- stored as YYYYMMDD integer in source
    sls_ship_dt   INT,
    sls_due_dt    INT,
    sls_sales     DECIMAL(12, 2),
    sls_quantity  INT,
    sls_price     DECIMAL(10, 2),
    sls_discount  DECIMAL(5, 2)
);
GO

-- ============================================================
-- ERP Source Tables
-- ============================================================

IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO
CREATE TABLE bronze.erp_cust_az12 (
    cid   NVARCHAR(50),
    bdate DATE,
    gen   NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO
CREATE TABLE bronze.erp_loc_a101 (
    cid   NVARCHAR(50),
    cntry NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO
CREATE TABLE bronze.erp_px_cat_g1v2 (
    id          NVARCHAR(50),
    cat         NVARCHAR(100),
    subcat      NVARCHAR(100),
    maintenance NVARCHAR(50)
);
GO
