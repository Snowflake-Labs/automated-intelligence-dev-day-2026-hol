-- ============================================================================
-- Gen2 Warehouse - Optima Indexing Demo
-- ============================================================================
-- Demonstrates automatic indexing for point lookups on Gen2 warehouses.
-- Optima Indexing is FREE - Snowflake covers build and maintenance costs!
-- 
-- Key Features:
-- - Automatic detection of point lookup patterns
-- - Background index creation and maintenance
-- - 2-10x faster point lookup performance
-- - Zero configuration required
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE_ADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_GEN2_WH;  -- Must use Gen2 warehouse

-- ============================================================================
-- PART 1: Verify Gen2 Warehouse
-- ============================================================================

-- Check warehouse configuration
SHOW WAREHOUSES LIKE 'AUTOMATED_INTELLIGENCE_GEN2_WH';

-- Verify it's Gen2 (RESOURCE_CONSTRAINT = STANDARD_GEN_2)
SELECT 
    "name" AS warehouse_name,
    "type" AS warehouse_type,
    "size" AS warehouse_size,
    "resource_constraint" AS resource_type,
    "generation" AS generation
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" = 'AUTOMATED_INTELLIGENCE_GEN2_WH';

-- ============================================================================
-- PART 2: Point Lookup Queries (Optima will optimize these)
-- ============================================================================

-- Point lookup by order_id (UUID)
-- Optima detects this pattern and builds index automatically
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    order_status
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
WHERE order_id = (SELECT order_id FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS LIMIT 1);

-- Point lookup by customer_id
SELECT 
    customer_id,
    first_name,
    last_name,
    customer_segment,
    state
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
WHERE customer_id = 5000;

-- Multiple point lookups (batch pattern)
SELECT 
    order_id,
    customer_id,
    total_amount
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
WHERE customer_id IN (5000, 5001, 5002, 5003, 5004);

-- ============================================================================
-- PART 3: Check Query Insights for Index Usage
-- ============================================================================

-- View recent query insights (requires ACCOUNTADMIN or monitoring privileges)
-- Note: Query insights may take a few minutes to appear

-- Check if Optima Index was used in recent queries
SELECT 
    query_id,
    query_text,
    warehouse_name,
    start_time,
    total_elapsed_time / 1000 AS elapsed_seconds
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    WAREHOUSE_NAME => 'AUTOMATED_INTELLIGENCE_GEN2_WH',
    RESULT_LIMIT => 20
))
WHERE query_text ILIKE '%WHERE order_id%' OR query_text ILIKE '%WHERE customer_id%'
ORDER BY start_time DESC;

-- ============================================================================
-- PART 4: Performance Comparison
-- ============================================================================

-- Run the same queries on standard warehouse for comparison
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- Standard warehouse point lookup
SELECT 
    customer_id,
    first_name,
    last_name,
    customer_segment
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
WHERE customer_id = 5000;

-- Switch back to Gen2 and run same query
USE WAREHOUSE AUTOMATED_INTELLIGENCE_GEN2_WH;

SELECT 
    customer_id,
    first_name,
    last_name,
    customer_segment
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMERS
WHERE customer_id = 5000;

-- Compare query times in QUERY_HISTORY
SELECT 
    warehouse_name,
    query_text,
    total_elapsed_time / 1000 AS elapsed_seconds,
    bytes_scanned / 1024 / 1024 AS mb_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 20))
WHERE query_text ILIKE '%customer_id = 5000%'
ORDER BY start_time DESC
LIMIT 4;

-- ============================================================================
-- PART 5: Optima Indexing Best Practices
-- ============================================================================

/*
WHEN OPTIMA INDEXING HELPS:
- Point lookups: WHERE id = X
- Small IN lists: WHERE id IN (1, 2, 3)
- Equality filters on high-cardinality columns

WHEN IT DOESN'T HELP:
- Range scans: WHERE date BETWEEN X AND Y
- Full table scans: SELECT * FROM table
- Aggregations: SELECT COUNT(*) FROM table
- Pattern matching: WHERE name LIKE '%foo%'

TIPS:
1. Use Gen2 warehouse for point-lookup heavy workloads
2. No action needed - Optima works automatically
3. Check Performance Explorer in Snowsight for insights
4. Index creation happens in background, no query impact
*/

-- ============================================================================
-- PART 6: Performance Explorer Reference
-- ============================================================================

/*
To view detailed performance insights:
1. Open Snowsight
2. Navigate to: Monitoring → Performance Explorer
3. Filter by warehouse: AUTOMATED_INTELLIGENCE_GEN2_WH
4. Look for "Index Usage" metrics

Or query programmatically:
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_INSIGHT
WHERE warehouse_name = 'AUTOMATED_INTELLIGENCE_GEN2_WH'
  AND insight_type ILIKE '%INDEX%';
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Optima Indexing Demo Complete!' AS status,
       'Check Performance Explorer in Snowsight for detailed insights' AS next_step;
