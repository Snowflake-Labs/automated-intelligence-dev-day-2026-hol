-- ============================================================================
-- Cortex AI Functions Demo - AI_FILTER, AI_CLASSIFY, AI_AGG
-- ============================================================================
-- Demonstrates Snowflake's AI-powered SQL functions (GA Jan 2026)
-- These functions enable intelligent data filtering and classification
-- directly within SQL queries using natural language predicates.
-- ============================================================================

USE ROLE AUTOMATED_INTELLIGENCE_ADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: AI_FILTER - Boolean Classification with Natural Language
-- ============================================================================

-- Basic AI_FILTER: Classify text as true/false based on a natural language predicate
SELECT AI_FILTER('Is Snowflake a cloud data platform?') AS simple_test;
-- Returns: TRUE

-- AI_FILTER on Product Reviews: Identify satisfied customers
SELECT 
    review_id,
    product_id,
    rating,
    review_title,
    LEFT(review_text, 80) || '...' AS review_preview,
    AI_FILTER(PROMPT('The reviewer is satisfied with this product: {0}', review_text)) AS is_satisfied
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS
WHERE rating IN (1, 5)  -- Compare extremes
ORDER BY rating
LIMIT 10;

-- AI_FILTER with Support Tickets: Identify urgent issues
SELECT 
    ticket_id,
    priority,
    category,
    subject,
    AI_FILTER(PROMPT('This support ticket describes an urgent problem requiring immediate attention: {0}', description)) AS is_urgent
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS
LIMIT 10;

-- ============================================================================
-- PART 2: AI_FILTER in WHERE Clause - Intelligent Filtering
-- ============================================================================

-- Find reviews where customers mention quality issues (regardless of rating)
SELECT 
    review_id,
    rating,
    review_title,
    LEFT(review_text, 100) || '...' AS review_preview
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS
WHERE AI_FILTER(PROMPT('The reviewer mentions product quality issues or defects: {0}', review_text))
LIMIT 10;

-- Find support tickets about shipping delays
SELECT 
    ticket_id,
    priority,
    category,
    subject,
    status
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS
WHERE AI_FILTER(PROMPT('This ticket is about shipping delays or delivery problems: {0}', description))
LIMIT 10;

-- ============================================================================
-- PART 3: AI_CLASSIFY - Multi-Class Classification
-- ============================================================================

-- Classify order size based on natural language description
SELECT 
    order_id,
    total_amount,
    AI_CLASSIFY(
        PROMPT('Order total: ${0}', total_amount::VARCHAR),
        ARRAY_CONSTRUCT('budget_purchase', 'standard_purchase', 'premium_purchase', 'luxury_purchase')
    ) AS order_classification
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS
LIMIT 10;

-- Classify support ticket sentiment
SELECT 
    ticket_id,
    subject,
    AI_CLASSIFY(
        description,
        ARRAY_CONSTRUCT('frustrated', 'neutral', 'appreciative')
    ) AS customer_sentiment
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.SUPPORT_TICKETS
LIMIT 10;

-- ============================================================================
-- PART 4: AI_FILTER with Dynamic Tables (Advanced Pattern)
-- ============================================================================
-- NOTE: This creates a new Dynamic Table with AI-powered sentiment analysis.
-- Uncomment to create - will incur Cortex AI costs on each refresh.

/*
CREATE OR REPLACE DYNAMIC TABLE DASH_AUTOMATED_INTELLIGENCE_DB.DYNAMIC_TABLES.REVIEWS_WITH_SENTIMENT
TARGET_LAG = '1 hour'
WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
REFRESH_MODE = FULL
AS
SELECT
    r.review_id,
    r.customer_id,
    r.product_id,
    r.review_date,
    r.rating,
    r.review_title,
    r.review_text,
    -- AI-powered sentiment analysis
    AI_FILTER(PROMPT('The reviewer is satisfied: {0}', r.review_text)) AS is_positive,
    AI_FILTER(PROMPT('The reviewer mentions quality issues: {0}', r.review_text)) AS mentions_quality_issues,
    AI_CLASSIFY(
        r.review_text,
        ARRAY_CONSTRUCT('highly_positive', 'positive', 'neutral', 'negative', 'highly_negative')
    ) AS sentiment_category
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS r;
*/

-- ============================================================================
-- PART 5: Performance Considerations
-- ============================================================================

-- AI_FILTER is optimized for:
-- 1. Batch processing (multiple rows in single query)
-- 2. Column-level caching (same column values return cached results)
-- 3. Adaptive routing for cost optimization

-- Best Practices:
-- - Filter NULL values before AI_FILTER to avoid unnecessary processing
-- - Use clear, specific prompts for better accuracy
-- - Consider using LIMIT during development to control costs
-- - For large datasets, consider sampling or pre-filtering

-- Example: Efficient pattern with pre-filtering
SELECT 
    review_id,
    review_title,
    AI_FILTER(PROMPT('Reviewer recommends this product: {0}', review_text)) AS recommends
FROM DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_REVIEWS
WHERE review_text IS NOT NULL 
  AND LENGTH(review_text) > 10  -- Skip very short reviews
  AND rating >= 4  -- Pre-filter to likely positive reviews
LIMIT 20;

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Cortex AI Functions Demo Complete!' AS status;
