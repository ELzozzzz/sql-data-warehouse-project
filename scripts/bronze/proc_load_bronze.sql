/*
================================================================================
  Stored Procedure: Load Bronze Layer
================================================================================
  Purpose  : Bulk-load raw CSV files from the datasets folder into the Bronze
             staging tables using BULK INSERT.  Update the file paths below to
             match your environment before executing.
  Run order: 2 – run after ddl_bronze.sql
================================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time  DATETIME2 = SYSDATETIME();
    DECLARE @batch_start DATETIME2;
    DECLARE @rows_loaded INT;

    PRINT '========================================================';
    PRINT 'Starting Bronze Layer Load  –  ' + CONVERT(NVARCHAR, @start_time, 120);
    PRINT '========================================================';

    -- --------------------------------------------------------
    -- CRM: Customer Info
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.crm_cust_info ...';

    TRUNCATE TABLE bronze.crm_cust_info;

    BULK INSERT bronze.crm_cust_info
    FROM '$(DatasetPath)\source_crm\cust_info.csv'
    WITH (
        FIRSTROW        = 2,         -- skip header row
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- CRM: Product Info
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.crm_prd_info ...';

    TRUNCATE TABLE bronze.crm_prd_info;

    BULK INSERT bronze.crm_prd_info
    FROM '$(DatasetPath)\source_crm\prd_info.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- CRM: Sales Details
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.crm_sales_details ...';

    TRUNCATE TABLE bronze.crm_sales_details;

    BULK INSERT bronze.crm_sales_details
    FROM '$(DatasetPath)\source_crm\sales_details.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Customer AZ12
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.erp_cust_az12 ...';

    TRUNCATE TABLE bronze.erp_cust_az12;

    BULK INSERT bronze.erp_cust_az12
    FROM '$(DatasetPath)\source_erp\CUST_AZ12.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Locations A101
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.erp_loc_a101 ...';

    TRUNCATE TABLE bronze.erp_loc_a101;

    BULK INSERT bronze.erp_loc_a101
    FROM '$(DatasetPath)\source_erp\LOC_A101.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    -- --------------------------------------------------------
    -- ERP: Product Categories PX_CAT_G1V2
    -- --------------------------------------------------------
    SET @batch_start = SYSDATETIME();
    PRINT '>> Loading bronze.erp_px_cat_g1v2 ...';

    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    BULK INSERT bronze.erp_px_cat_g1v2
    FROM '$(DatasetPath)\source_erp\PX_CAT_G1V2.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        TABLOCK
    );

    SET @rows_loaded = @@ROWCOUNT;
    PRINT '   Rows loaded: ' + CAST(@rows_loaded AS NVARCHAR) +
          '   Duration: ' + CAST(DATEDIFF(MILLISECOND, @batch_start, SYSDATETIME()) AS NVARCHAR) + ' ms';

    PRINT '========================================================';
    PRINT 'Bronze Layer Load Complete  –  Total duration: ' +
          CAST(DATEDIFF(SECOND, @start_time, SYSDATETIME()) AS NVARCHAR) + ' s';
    PRINT '========================================================';
END;
GO
