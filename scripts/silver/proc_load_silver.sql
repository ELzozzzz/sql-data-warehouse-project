/*
================================================================================
  Stored Procedure: Load Silver Layer
================================================================================
  Purpose  : Transform and load data from Bronze into Silver.
             Transformations include:
               - Deduplication (keep most-recent row per business key)
               - Date conversion (YYYYMMDD INT  →  DATE)
               - Null / unknown standardisation
               - Derived column calculation (cat_id from prd_key prefix)
               - Business-rule enforcement (negative sales correction)
  Run order: 4 – run after ddl_silver.sql
================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time  DATETIME2 = SYSDATETIME();
    DECLARE @batch_start DATETIME2;
    DECLARE @rows_loaded INT;

    PRINT '========================================================';
    PRINT 'Starting Silver Layer Load  –  ' + CONVERT(NVARCHAR, @start_time, 120);
    PRINT '========================================================';

    -- --------------------------------------------------------
    -- CRM: Customer Info
    -- Deduplicate on cst_id; keep the row with the latest cst_create_date.
    -- Standardise marital_status and gender codes.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.crm_cust_info ...';

    TRUNCATE TABLE silver.crm_cust_info;

    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        cst_id,
        TRIM(cst_key)                                                       AS cst_key,
        TRIM(cst_firstname)                                                  AS cst_firstname,
        TRIM(cst_lastname)                                                   AS cst_lastname,
        CASE TRIM(UPPER(cst_marital_status))
            WHEN 'M' THEN 'Married'
            WHEN 'S' THEN 'Single'
            ELSE 'n/a'
        END                                                                  AS cst_marital_status,
        CASE TRIM(UPPER(cst_gndr))
            WHEN 'M' THEN 'Male'
            WHEN 'F' THEN 'Female'
            ELSE 'n/a'
        END                                                                  AS cst_gndr,
        cst_create_date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY cst_id
                   ORDER BY cst_create_date DESC
               ) AS rn
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE rn = 1;

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- CRM: Product Info
    -- Derive cat_id as the substring before the first '-' in prd_key.
    -- Normalise prd_line codes.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.crm_prd_info ...';

    TRUNCATE TABLE silver.crm_prd_info;

    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm, prd_cost,
        prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        SUBSTRING(prd_key, 1, CHARINDEX('-', prd_key) - 1)                     AS cat_id,
        SUBSTRING(prd_key, CHARINDEX('-', prd_key) + 1, LEN(prd_key))         AS prd_key,
        TRIM(prd_nm)                                                            AS prd_nm,
        ISNULL(prd_cost, 0)                                                     AS prd_cost,
        CASE TRIM(UPPER(prd_line))
            WHEN 'M'  THEN 'Mountain'
            WHEN 'R'  THEN 'Road'
            WHEN 'S'  THEN 'Other Sales'
            WHEN 'T'  THEN 'Touring'
            ELSE prd_line
        END                                                                     AS prd_line,
        CAST(prd_start_dt AS DATE)                                              AS prd_start_dt,
        CAST(
            LEAD(prd_start_dt) OVER (
                PARTITION BY prd_id ORDER BY prd_start_dt
            ) AS DATE
        )                                                                       AS prd_end_dt
    FROM bronze.crm_prd_info
    WHERE prd_id IS NOT NULL
      AND CHARINDEX('-', prd_key) > 0;  -- guard against malformed keys

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- CRM: Sales Details
    -- Convert date integers to DATE; correct negative sales amounts.
    -- Filter out rows with invalid order numbers.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.crm_sales_details ...';

    TRUNCATE TABLE silver.crm_sales_details;

    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price, sls_discount
    )
    SELECT
        TRIM(sls_ord_num)                                               AS sls_ord_num,
        TRIM(sls_prd_key)                                               AS sls_prd_key,
        sls_cust_id,
        -- Convert YYYYMMDD INT to DATE; NULL for out-of-range values
        CASE
            WHEN sls_order_dt BETWEEN 19000101 AND 99991231
                THEN CONVERT(DATE, CAST(sls_order_dt AS CHAR(8)), 112)
            ELSE NULL
        END                                                             AS sls_order_dt,
        CASE
            WHEN sls_ship_dt BETWEEN 19000101 AND 99991231
                THEN CONVERT(DATE, CAST(sls_ship_dt AS CHAR(8)), 112)
            ELSE NULL
        END                                                             AS sls_ship_dt,
        CASE
            WHEN sls_due_dt BETWEEN 19000101 AND 99991231
                THEN CONVERT(DATE, CAST(sls_due_dt AS CHAR(8)), 112)
            ELSE NULL
        END                                                             AS sls_due_dt,
        -- If sales is negative or zero, recalculate from price × quantity
        CASE
            WHEN sls_sales <= 0 OR sls_sales IS NULL
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END                                                             AS sls_sales,
        sls_quantity,
        ABS(sls_price)                                                  AS sls_price,
        ISNULL(sls_discount, 0)                                         AS sls_discount
    FROM bronze.crm_sales_details
    WHERE TRIM(sls_ord_num) IS NOT NULL
      AND TRIM(sls_ord_num) <> '';

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Customer Demographics (AZ12)
    -- Strip 'NAS' prefix from cid; cap future birth dates to NULL.
    -- Standardise gender.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.erp_cust_az12 ...';

    TRUNCATE TABLE silver.erp_cust_az12;

    INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE
            WHEN UPPER(cid) LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
            ELSE cid
        END                                          AS cid,
        CASE
            WHEN bdate > CAST(GETDATE() AS DATE) THEN NULL
            ELSE bdate
        END                                          AS bdate,
        CASE TRIM(UPPER(gen))
            WHEN 'M'      THEN 'Male'
            WHEN 'MALE'   THEN 'Male'
            WHEN 'F'      THEN 'Female'
            WHEN 'FEMALE' THEN 'Female'
            ELSE 'n/a'
        END                                          AS gen
    FROM bronze.erp_cust_az12;

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Locations (A101)
    -- Standardise country names.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.erp_loc_a101 ...';

    TRUNCATE TABLE silver.erp_loc_a101;

    INSERT INTO silver.erp_loc_a101 (cid, cntry)
    SELECT
        cid,
        CASE TRIM(UPPER(cntry))
            WHEN 'US'  THEN 'United States'
            WHEN 'USA' THEN 'United States'
            WHEN 'DE'  THEN 'Germany'
            WHEN 'GB'  THEN 'United Kingdom'
            WHEN 'AU'  THEN 'Australia'
            WHEN 'FR'  THEN 'France'
            WHEN 'CA'  THEN 'Canada'
            WHEN ''    THEN 'n/a'
            ELSE TRIM(cntry)
        END AS cntry
    FROM bronze.erp_loc_a101;

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Product Categories (PX_CAT_G1V2)
    -- No complex transforms needed; trim whitespace.
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading silver.erp_px_cat_g1v2 ...';

    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT
        TRIM(id)          AS id,
        TRIM(cat)         AS cat,
        TRIM(subcat)      AS subcat,
        TRIM(maintenance) AS maintenance
    FROM bronze.erp_px_cat_g1v2;

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    PRINT '========================================================';
    PRINT 'Silver Layer Load Complete  –  Total duration: ' +
          CAST(DATEDIFF(SECOND, @start_time, SYSDATETIME()) AS NVARCHAR) + ' s';
    PRINT '========================================================';
END;
GO
