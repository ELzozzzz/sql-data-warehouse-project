/*
================================================================================
  Data Quality Checks
================================================================================
  Purpose  : Validate the Silver and Gold layers after each pipeline run.
             Each query should return zero rows when data is clean.
             If rows are returned, investigate and resolve before promoting to
             production.
================================================================================
*/

-- ============================================================
-- SILVER LAYER CHECKS
-- ============================================================

PRINT '=== Silver Quality Checks ===';

-- 1. Duplicate customer IDs in Silver customer table
SELECT 'silver.crm_cust_info - duplicate cst_id' AS check_name,
       cst_id, COUNT(*) AS cnt
FROM   silver.crm_cust_info
GROUP  BY cst_id
HAVING COUNT(*) > 1;

-- 2. Null or blank customer keys
SELECT 'silver.crm_cust_info - null/blank cst_key' AS check_name, *
FROM   silver.crm_cust_info
WHERE  cst_key IS NULL OR TRIM(cst_key) = '';

-- 3. Invalid (un-standardised) gender values
SELECT DISTINCT
       'silver.crm_cust_info - unexpected gender value' AS check_name,
       cst_gndr
FROM   silver.crm_cust_info
WHERE  cst_gndr NOT IN ('Male', 'Female', 'n/a');

-- 4. Products with negative cost
SELECT 'silver.crm_prd_info - negative product cost' AS check_name, *
FROM   silver.crm_prd_info
WHERE  prd_cost < 0;

-- 5. Products where start_dt is after end_dt
SELECT 'silver.crm_prd_info - start > end date' AS check_name, *
FROM   silver.crm_prd_info
WHERE  prd_end_dt IS NOT NULL
  AND  prd_start_dt > prd_end_dt;

-- 6. Sales rows with negative or zero order amounts
SELECT 'silver.crm_sales_details - non-positive sales amount' AS check_name, *
FROM   silver.crm_sales_details
WHERE  sls_sales <= 0 OR sls_sales IS NULL;

-- 7. Sales rows where ship_date is before order_date
SELECT 'silver.crm_sales_details - ship before order date' AS check_name, *
FROM   silver.crm_sales_details
WHERE  sls_ship_dt < sls_order_dt;

-- 8. ERP customers with future birth dates
SELECT 'silver.erp_cust_az12 - future birthdate' AS check_name, *
FROM   silver.erp_cust_az12
WHERE  bdate > CAST(GETDATE() AS DATE);

-- 9. Unexpected country values in locations table
SELECT DISTINCT
       'silver.erp_loc_a101 - unexpected country values' AS check_name,
       cntry
FROM   silver.erp_loc_a101
WHERE  cntry NOT IN (
    'United States', 'Australia', 'United Kingdom',
    'Germany', 'France', 'Canada', 'n/a'
);

-- ============================================================
-- GOLD LAYER CHECKS
-- ============================================================

PRINT '=== Gold Quality Checks ===';

-- 10. Orphan sales lines - no matching customer
SELECT 'gold.fact_sales - orphan customer' AS check_name, *
FROM   gold.fact_sales
WHERE  customer_key IS NULL;

-- 11. Orphan sales lines - no matching product
SELECT 'gold.fact_sales - orphan product' AS check_name, *
FROM   gold.fact_sales
WHERE  product_key IS NULL;

-- 12. Orphan sales lines - no matching date
SELECT 'gold.fact_sales - orphan date' AS check_name, *
FROM   gold.fact_sales
WHERE  order_date_key IS NULL;

-- 13. Negative gross profit (may indicate cost data issue)
SELECT 'gold.fact_sales - negative gross profit' AS check_name, *
FROM   gold.fact_sales
WHERE  gross_profit < 0;

-- ============================================================
-- ROW COUNT SUMMARY (informational - always returns rows)
-- ============================================================

PRINT '=== Row Count Summary ===';

SELECT 'bronze.crm_cust_info'    AS layer_table, COUNT(*) AS row_count FROM bronze.crm_cust_info    UNION ALL
SELECT 'bronze.crm_prd_info',                    COUNT(*) FROM bronze.crm_prd_info                   UNION ALL
SELECT 'bronze.crm_sales_details',               COUNT(*) FROM bronze.crm_sales_details               UNION ALL
SELECT 'bronze.erp_cust_az12',                   COUNT(*) FROM bronze.erp_cust_az12                   UNION ALL
SELECT 'bronze.erp_loc_a101',                    COUNT(*) FROM bronze.erp_loc_a101                    UNION ALL
SELECT 'bronze.erp_px_cat_g1v2',                 COUNT(*) FROM bronze.erp_px_cat_g1v2                 UNION ALL
SELECT 'silver.crm_cust_info',                   COUNT(*) FROM silver.crm_cust_info                   UNION ALL
SELECT 'silver.crm_prd_info',                    COUNT(*) FROM silver.crm_prd_info                    UNION ALL
SELECT 'silver.crm_sales_details',               COUNT(*) FROM silver.crm_sales_details               UNION ALL
SELECT 'silver.erp_cust_az12',                   COUNT(*) FROM silver.erp_cust_az12                   UNION ALL
SELECT 'silver.erp_loc_a101',                    COUNT(*) FROM silver.erp_loc_a101                    UNION ALL
SELECT 'silver.erp_px_cat_g1v2',                 COUNT(*) FROM silver.erp_px_cat_g1v2                 UNION ALL
SELECT 'gold.dim_customers',                     COUNT(*) FROM gold.dim_customers                     UNION ALL
SELECT 'gold.dim_products',                      COUNT(*) FROM gold.dim_products                      UNION ALL
SELECT 'gold.dim_date',                          COUNT(*) FROM gold.dim_date                          UNION ALL
SELECT 'gold.fact_sales',                        COUNT(*) FROM gold.fact_sales;
