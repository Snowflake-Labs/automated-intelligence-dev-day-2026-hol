-- ============================================================================
-- TEST: Validate HOL setup + Agent creation + Agent interactions
-- ============================================================================
-- Run after setup.sql completes successfully.
-- Creates the Business Insights Agent and tests sample questions.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE WAREHOUSE HOL_WH;

-- ============================================================================
-- STEP 1: Create the Business Insights Agent
-- ============================================================================

USE SCHEMA SEMANTIC;

CREATE OR REPLACE AGENT DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT
  COMMENT = 'Multi-tool business insights agent with Cortex Analyst and Agentic Search'
FROM SPECIFICATION $$
{
  "instructions": {
    "orchestration": "You are a business insights assistant for an outdoor sports equipment company selling skis, snowboards, boots, and accessories. Route questions about revenue, orders, customers, segments, discounts, and business metrics to query_business_data. Route questions about product reviews, customer feedback, ratings, support tickets, complaints, returns, or shipping issues to search_customer_feedback. Route questions about product details, features, pricing, or catalog to search_products. When a user asks WHY something happened (e.g. revenue dropped), combine structured data from query_business_data with unstructured insights from search_customer_feedback to provide a complete answer.",
    "response": "Be concise and data-driven. Always cite specific numbers from query results. When presenting search results, include relevant context like ratings, dates, and categories. Format currency values with $ and two decimal places. When combining multiple tool results, clearly connect the structured findings (what happened) with unstructured findings (why it happened).",
    "sample_questions": [
      {"question": "Show me monthly revenue trend from June 2025 to April 2026"},
      {"question": "Revenue dropped in February — what caused it and what do reviews say?"},
      {"question": "Find reviews mentioning wrong size with a rating below 3"},
      {"question": "Why are customers returning ski boots?"},
      {"question": "What is our total revenue and customer count by state?"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_business_data",
        "description": "Query structured business data using natural language. Covers orders, revenue, customers, segments, products, discounts, shipping, and order status. Use for questions about metrics, trends, aggregations, comparisons, and any quantitative business analysis."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_customer_feedback",
        "description": "Search across customer reviews and support tickets for qualitative insights. IMPORTANT: always use persist_to_table. Use for finding reviews about specific products, quality issues, sizing problems, customer sentiment, support tickets about returns, shipping delays, or any customer complaints."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_products",
        "description": "Search the product catalog for product details, descriptions, features, pricing, and categories. Use for questions about what products are available, product specs, or product comparisons."
      }
    }
  ],
  "tool_resources": {
    "query_business_data": {
      "semantic_view": "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC",
      "execution_environment": {"type": "warehouse", "warehouse": "HOL_WH"}
    },
    "search_customer_feedback": {
      "search_service": "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMER_FEEDBACK_SEARCH",
      "database_schema": "DASH_AUTOMATED_INTELLIGENCE_DB.RAW",
      "is_multi_index": true,
      "columns_and_descriptions": {
        "doc_id": {"description": "Unique document identifier (review_id or ticket_id)", "type": "TEXT", "searchable": false, "filterable": false},
        "title": {"description": "Review title or ticket subject line", "type": "TEXT", "searchable": true, "filterable": false},
        "content": {"description": "Full text of the review or support ticket description", "type": "TEXT", "searchable": true, "filterable": false},
        "source_type": {"description": "Type of document: review or ticket", "type": "TEXT", "searchable": false, "filterable": true},
        "category": {"description": "Ticket category such as Returns, Shipping, Sizing (null for reviews)", "type": "TEXT", "searchable": false, "filterable": true},
        "rating": {"description": "Review star rating 1-5 (null for tickets)", "type": "NUMBER", "searchable": false, "filterable": true},
        "date_field": {"description": "Date when the review was posted or ticket was created", "type": "DATE", "searchable": false, "filterable": true},
        "customer_id": {"description": "Customer identifier", "type": "NUMBER", "searchable": false, "filterable": true}
      },
      "max_results": 1000,
      "execution_environment": {"type": "warehouse", "warehouse": "HOL_WH"},
      "id_column": "DOC_ID",
      "base_table": "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMER_FEEDBACK",
      "base_table_columns": ["doc_id", "title", "content", "source_type", "category", "rating", "date_field", "customer_id"]
    },
    "search_products": {
      "search_service": "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.PRODUCT_SEARCH_SERVICE"
    }
  }
}
$$;

SHOW AGENTS LIKE 'BUSINESS_INSIGHTS_AGENT' IN SCHEMA DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC;

-- ============================================================================
-- STEP 2: Test Agent with sample questions
-- ============================================================================

-- Q1: Cortex Analyst (text-to-SQL, trend visualization)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Show me monthly revenue trend from June 2025 to April 2026"}]}], "stream": false }$$
  )
) AS q1_revenue_trend;

-- Q2: Agentic Search (reviews + tickets about returns)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Why are customers returning ski boots?"}]}], "stream": false }$$
  )
) AS q2_full_response;

-- Q3: Cortex Analyst + Agentic Search (what→why)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Revenue dropped in February — what caused it and what do reviews say?"}]}], "stream": false }$$
  )
) AS q3_full_response;

-- Q4: Agentic Search with filter (rating < 3, source_type = review)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "Find reviews mentioning wrong size with a rating below 3"}]}], "stream": false }$$
  )
) AS q4_full_response;

-- Q5: Cortex Analyst (text-to-SQL)
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT',
    $${ "messages": [{"role": "user", "content": [{"type": "text", "text": "What is our total revenue and customer count by state?"}]}], "stream": false }$$
  )
) AS q5_full_response;
