-- ============================================================================
-- MCP Server: Expose Business Insights Agent as a managed MCP endpoint
-- ============================================================================
-- Creates a Snowflake-managed MCP server that exposes the agent, semantic view,
-- and search service as discoverable tools for any MCP-compatible client.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE DASH_AUTOMATED_INTELLIGENCE_DB;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE MCP SERVER business_insights_mcp
  FROM SPECIFICATION $$
    tools:
      - name: "business-insights-agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT"
        description: "AI agent that answers business questions using structured data and customer feedback. Combines text-to-SQL analytics with search across reviews and tickets."
        title: "Business Insights Agent"

      - name: "revenue-analytics"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
        description: "Text-to-SQL for revenue, orders, customers, segments, and product metrics"
        title: "Revenue Analytics"

      - name: "customer-feedback-search"
        type: "CORTEX_SEARCH_SERVICE_QUERY"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMER_FEEDBACK_SEARCH"
        description: "Search across product reviews and support tickets for qualitative insights"
        title: "Customer Feedback Search"
  $$;

SHOW MCP SERVERS IN SCHEMA DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC;

-- ============================================================================
-- Connection URL for MCP clients:
-- https://<account_url>/api/v2/databases/DASH_AUTOMATED_INTELLIGENCE_DB/schemas/SEMANTIC/mcp-servers/BUSINESS_INSIGHTS_MCP
--
-- Connect from CoCo CLI:
--   cortex mcp add business-insights <url> --type http
--
-- Then use naturally:
--   "Search customer feedback for sizing complaints"
--   "What was our revenue last quarter?"
-- ============================================================================
