-- ============================================================================
-- Data Quality Expectations Demo (GA - 2025)
-- ============================================================================
-- Declarative data quality rules that run during DML operations.
-- Similar to dbt tests but enforced at the table level.
--
-- Note: Data Quality Expectations are in preview. Check documentation
-- for current availability and syntax.
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE_ADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Data Metric Functions (DMF) - Available Now
-- ============================================================================

-- DMFs provide built-in and custom data quality checks
-- They can be scheduled to run periodically on tables

-- View available built-in DMFs
SHOW DATA METRIC FUNCTIONS IN ACCOUNT;

-- Example: Check for NULL values in a column
SELECT SNOWFLAKE.CORE.NULL_COUNT(
    SELECT customer_id FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
) AS null_customer_ids;

-- Example: Check for duplicate values
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(
    SELECT order_id FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
) AS duplicate_orders;

-- Example: Check freshness
SELECT SNOWFLAKE.CORE.FRESHNESS(
    SELECT order_date FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
) AS data_freshness_hours;

-- ============================================================================
-- PART 2: Associate DMFs with Tables
-- ============================================================================

-- Attach a NULL check to the customers table
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
ON (customer_id);

-- Attach a duplicate check to orders
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
ON (order_id);

-- Set the schedule at the TABLE level (not per-DMF).
-- SCHEDULE = '60 MINUTES' on ALTER TABLE ... ADD DATA METRIC FUNCTION is deprecated.
-- Use DATA_METRIC_SCHEDULE with TRIGGER_ON_CHANGES or a cron expression instead:
--   ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
--   ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS    SET DATA_METRIC_SCHEDULE = '60 MINUTES';
--   ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS    SET DATA_METRIC_SCHEDULE = 'USING CRON 0 * * * * UTC';

-- View DMFs attached to a table
SHOW DATA METRIC FUNCTIONS ON DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS;

-- ============================================================================
-- PART 3: Custom Data Metric Functions
-- ============================================================================

-- Create a custom DMF for business rules
CREATE OR REPLACE DATA METRIC FUNCTION DASH_AUTOMATED_INTELLIGENCE_DB.RAW.check_order_total_positive(
    tbl TABLE(total_amount NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM tbl WHERE total_amount < 0
$$;

-- Attach custom DMF to orders table
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
ADD DATA METRIC FUNCTION DASH_AUTOMATED_INTELLIGENCE_DB.RAW.check_order_total_positive
ON (total_amount);

-- ============================================================================
-- PART 4: Query DMF Results
-- ============================================================================

-- View DMF execution history
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE TABLE_NAME = 'ORDERS'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- Alternative: Account Usage view
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE
WHERE TABLE_NAME = 'ORDERS'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- ============================================================================
-- PART 5: Data Quality Alerts (Create monitoring table)
-- ============================================================================

-- Create a table to store data quality alerts
CREATE OR REPLACE TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.DATA_QUALITY_ALERTS (
    alert_id INT AUTOINCREMENT,
    check_name VARCHAR,
    table_name VARCHAR,
    column_name VARCHAR,
    check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    issue_count INT,
    severity VARCHAR,
    description VARCHAR
);

-- Insert alerts based on DMF results (manual process for now)
INSERT INTO DASH_AUTOMATED_INTELLIGENCE_DB.RAW.DATA_QUALITY_ALERTS 
    (check_name, table_name, column_name, issue_count, severity, description)
SELECT 
    'NULL_CHECK', 
    'CUSTOMERS', 
    'CUSTOMER_ID', 
    SNOWFLAKE.CORE.NULL_COUNT(SELECT customer_id FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS),
    CASE 
        WHEN SNOWFLAKE.CORE.NULL_COUNT(SELECT customer_id FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS) > 0 
        THEN 'HIGH' ELSE 'OK' 
    END,
    'Primary key should not have NULL values';

-- ============================================================================
-- PART 6: Expectations (GA - Aug 2025)
-- ============================================================================

-- Expectations are GA (Aug 2025) — declarative thresholds on DMF results.
-- When the DMF returns a value that violates the expectation, Snowflake
-- records an expectation violation for alerting and monitoring.

-- Add expectations to existing DMF associations
-- Example: Expect zero NULL customer_ids (primary key)
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
  MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    ADD EXPECTATION zero_nulls (VALUE = 0);

-- Example: Expect order totals are always positive (< 5 violations allowed)
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
  MODIFY DATA METRIC FUNCTION DASH_AUTOMATED_INTELLIGENCE_DB.RAW.check_order_total_positive ON (total_amount)
    ADD EXPECTATION few_negatives (VALUE < 5);

-- Example: Freshness expectation — alert if data not updated in 5 minutes
ALTER TABLE DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (order_date)
    EXPECTATION fresh_5min (VALUE < 300),
    EXPECTATION fresh_30min (VALUE < 1800);

-- Evaluate expectations to check current violation status
SELECT SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    'DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS'
);

-- View expectation violations in monitoring results
SELECT *
FROM TABLE(
  SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME => 'DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS',
    REF_ENTITY_DOMAIN => 'table'
  )
)
WHERE EXPECTATION_NAME IS NOT NULL
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- ============================================================================
-- PART 7: Best Practices
-- ============================================================================

/*
DATA QUALITY STRATEGY:

1. TIER 1 - CRITICAL (Block on failure):
   - Primary keys: NOT NULL, UNIQUE
   - Foreign keys: REFERENCES
   - Required fields: NOT NULL

2. TIER 2 - IMPORTANT (Alert on failure):
   - Business rules: positive amounts, valid ranges
   - Freshness checks: data not stale
   - Completeness: expected row counts

3. TIER 3 - MONITORING (Log only):
   - Duplicate detection
   - Outlier detection
   - Distribution changes

IMPLEMENTATION:
- Use DMFs for scheduled batch checks
- Use column constraints for immediate enforcement
- Use Expectations for pipeline-level rules (when GA)
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Data Quality Demo Complete!' AS status;
