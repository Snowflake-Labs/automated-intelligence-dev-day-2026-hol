# Building an End-to-End AI Application on Snowflake: From Data to Intelligence

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Lab Sections](#lab-sections)
  - [Section 1: Setup](#section-1-setup-10-min--manual)
  - [Section 2: Streaming Ingestion](#section-2-streaming-ingestion-10-min--manual)
  - [Section 3: Gen2 Warehouse & MERGE](#section-3-gen2-warehouse--merge-5-min--coco)
  - [Section 4: Dynamic Tables Pipeline](#section-4-dynamic-tables-pipeline-5-min--coco)
  - [Section 5: Iceberg Tables & V3 Features](#section-5-iceberg-tables--v3-features-7-min--coco)
  - [Section 6: Interactive Tables](#section-6-interactive-tables-5-min--coco--manual)
  - [Section 7: Data Quality](#section-7-data-quality-5-min--coco)
  - [Section 8: dbt Analytics](#section-8-dbt-analytics-10-min--coco)
  - [Section 9: CoCo Custom Skill](#section-9-coco-custom-skill-5-min--coco)
  - [Section 10: Snowflake CoWork](#section-10-snowflake-cowork-10-min--coco)
  - [Section 11: Security & Governance](#section-11-security--governance-5-min--snowflake-cowork)
  - [Section 12: Streamlit Dashboard](#section-12-streamlit-dashboard-5-min--coco)
  - [Section 13: Agent Evaluation](#section-13-agent-evaluation-5-min--coco--snowsight)
  - [Section 14: MCP Server](#section-14-mcp-server-5-min--coco)
- [Cleanup](#cleanup)
- [Resources](#resources)

---

## Overview

In this hands-on lab, you'll build a complete AI-powered retail analytics platform entirely within Snowflake — no external infrastructure required. Using Cortex Code as your AI-assisted development environment, you'll work through the full data lifecycle: stream real-time orders via Snowpipe Streaming, MERGE them into production tables with Gen2 Warehouses, transform them through a 3-tier Dynamic Tables pipeline, and serve them with Interactive Tables for low-latency point lookups. You'll build analytical models with dbt, monitor data quality with Data Metric Functions, explore Iceberg V3 features (deletion vectors, row lineage), and create custom CoCo skills for reusable workflows. Tie it all together with Snowflake CoWork — a conversational AI interface where a Cortex Agent orchestrates Cortex Analyst (text-to-SQL via a semantic view with verified queries) and Agentic Search (multi-index Cortex Search across reviews and tickets with persist-to-table analysis) to answer "what happened" and "why" from both structured and unstructured data. Evaluate your agent with ground-truth datasets, implement row-level security that transparently governs who sees what, and expose your agent as a managed MCP server for external AI clients.

### What You'll Learn

- Accelerate development with Cortex Code (AI-assisted SQL, deployment, and data exploration)
- Stream real-time data with Snowpipe Streaming and transform with Dynamic Tables
- Serve low-latency queries with Interactive Tables and Gen2 Warehouses
- Build analytical models with dbt
- Monitor data quality automatically with Data Metric Functions
- Create and query managed Iceberg V3 tables (deletion vectors, row lineage)
- Create custom CoCo skills for reusable team workflows
- Build a Cortex Agent with Cortex Analyst (semantic view + verified queries) and Agentic Search (multi-index Cortex Search)
- Evaluate agent quality with ground-truth datasets and LLM judges
- Expose agents as managed MCP servers for external AI clients
- Implement transparent row-level security with Row Access Policies

```
Snowpipe Streaming (Python SDK)
        |
        v
STAGING tables (append-only landing zone)
        |
        v
Gen2 Warehouse MERGE (dedup + upsert into RAW)
        |
        v
Dynamic Tables (3-tier incremental pipeline)
        |
        v
Interactive Tables (low-latency point lookups)
        |
        v
Cortex Agent + Semantic View (natural language queries)
        |
        v
Row Access Policies (transparent security)
```

---

## Prerequisites

Complete these steps **before** the lab begins.

### 1. Snowflake Account

Create a trial account for this lab at:

**http://signup.snowflake.com/summit2026**

Once your account is provisioned, verify you can log in at:
```
https://<account-identifier>.snowflakecomputing.com
```

### 2. Local Environment

Ensure these are installed on your laptop:

| Tool | Version | Check |
|------|---------|-------|
| Python | 3.8+ | `python3 --version` |
| pip | latest | `pip --version` |
| git | any | `git --version` |

### 3. Install Snowflake CLI + Cortex Code

Run the installer script:

**macOS / Linux:**
```bash
bash install.sh
```

**Windows (PowerShell):**
```powershell
.\install.ps1
```

This installs:
- **Snowflake CLI** (`snow`) — for SQL execution and deployments
- **Cortex Code CLI** (`cortex`) — AI-powered coding assistant for Snowflake

Verify:
```bash
snow --version
cortex --version
```

### 4. Configure Snowflake Connection

```bash
snow connection add
# Enter: account identifier, username, password (provided at lab start)
# Set role: ACCOUNTADMIN
# Set warehouse: HOL_WH
# Set database: DASH_AUTOMATED_INTELLIGENCE_DB
```

### 5. Generate RSA Key Pair (for Streaming)

```bash
# Generate private key (unencrypted PEM)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Upload public key to your Snowflake user
snow sql -q "ALTER USER <your-username> SET RSA_PUBLIC_KEY='$(grep -v -- '-----' rsa_key.pub | tr -d '\n')'"

# Verify
snow sql -q "DESC USER <your-username>" | grep RSA_PUBLIC_KEY_FP
```

Keep `rsa_key.p8` — you'll paste the private key into your streaming profile config in Section 2.

### 6. Clone the Lab Repository

```bash
git clone https://github.com/iamontheinet/automated-intelligence-hol.git
cd automated-intelligence-hol
```

---

## Lab Sections

> **Legend:**  
> MANUAL = Run in terminal or Snowsight (no CoCo)  
> CoCo = Run via Cortex Code prompts

---

### Section 1: Setup (10 min) — MANUAL

Launch Cortex Code and verify your connection:

```bash
cortex
```

Verify connection:
- CoCo should show your active connection, role, and warehouse
- Test with: *"What databases do I have access to?"*

Then run the core infrastructure script:

```bash
snow sql -f setup.sql -c <your-connection>
```

This creates:
- Database `DASH_AUTOMATED_INTELLIGENCE_DB` with schemas (RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, DBT_STAGING, DBT_ANALYTICS)
- Standard warehouse (`HOL_WH`) + Gen2 warehouse
- Raw tables, staging tables, stored procedures
- 5 Dynamic Tables (3-tier pipeline)
- 2 Interactive Tables + Interactive Warehouse
- Data quality monitoring (DMFs + alert)
- Product catalog + 2 Cortex Search Services (product catalog + customer feedback via Agentic Search)
- Semantic View with verified queries for natural language queries
- Seed data loaded from S3 (2M customers, 50M orders, 161M order items, 1200 reviews, 1200 tickets)
- Row Access Policy + WEST_COAST_MANAGER role (RBAC demo)

---

### Section 2: Streaming Ingestion (10 min) — MANUAL

Stream orders into the **STAGING** schema using the Python SDK:

```bash
cd snowpipe-streaming-python
pip install -r requirements.txt

# Copy and configure profile
cp profile.json.template profile.json
```

> **⚠️ IMPORTANT:** Edit `profile.json` and set your `account`, `user`, `private_key` (contents of rsa_key.p8), and `role` before proceeding.

```bash
# Stream 10,000 orders (lands in STAGING.ORDERS_STAGING and STAGING.ORDER_ITEMS_STAGING)
python src/automated_intelligence_streaming.py 10000
```

Verify data landed in staging:
```sql
SELECT COUNT(*) FROM dash_automated_intelligence_db.staging.orders_staging;
SELECT COUNT(*) FROM dash_automated_intelligence_db.staging.order_items_staging;
```

---

### Section 3: Gen2 Warehouse & MERGE (5 min) — CoCo

> **Prompt CoCo:**  
> *"Switch to the Gen2 warehouse, check how many rows are in staging, then merge them into RAW and show me the results"*

CoCo will:
1. Switch to `hol_gen2_wh`
2. Check `staging.orders_staging` and `staging.order_items_staging` row counts
3. Call `staging.merge_staging_to_raw(TRUE)`
4. Display timing: total duration, orders merged, order_items merged

> **Note:** If staging is empty (you skipped Section 2), the merge will report 0 rows — that's expected. The Gen2 warehouse is still demonstrating Optima Indexing on the point lookup below.

Then ask:
> *"Run a point lookup for customer_id 5000 on the Gen2 warehouse"*

CoCo will query `RAW.ORDERS WHERE customer_id = 5000` and return ~25 orders. To see the **partition pruning** (Optima Indexing), open the query profile in Snowsight — you'll see only a fraction of partitions were scanned despite no explicit clustering key.

Also explore: `demos/gen2-warehouse.sql`

---

### Section 4: Dynamic Tables Pipeline (5 min) — CoCo

> **Prompt CoCo:**  
> *"Show me the Dynamic Tables pipeline status — names, target lag, last refresh time, and row counts for each tier"*

CoCo will query the dynamic tables metadata and display the 3-tier pipeline:
- **Tier 1** (1-min lag): `enriched_orders` (50M rows), `enriched_order_items` (161M rows)
- **Tier 2** (DOWNSTREAM): `fact_orders` (161M rows)
- **Tier 3** (DOWNSTREAM): `daily_business_metrics` (365 rows), `product_performance_metrics` (4 rows)

All should show `scheduling_state = ACTIVE`.

Follow up:
> *"Show me a sample of the daily business metrics — top 5 days by revenue"*

Expected: All top-5 days are in December 2025 (holiday peak), each with ~$755M revenue and ~258K orders.

---

### Section 5: Iceberg Tables & V3 Features (7 min) — CoCo

> **Prompt CoCo:**  
> *"Create a managed Iceberg table from RAW.ORDERS with clustering by year and month, then query it to show partition pruning"*

CoCo will:
1. Create schema `ICEBERG`
2. Create a managed Iceberg table (CATALOG='SNOWFLAKE', no external volume needed)
3. Run a filtered query and show partitions scanned vs total

Then explore V3 features:
> *"Create an Iceberg V3 table from RAW.ORDERS (ICEBERG_VERSION=3) with merge-on-read enabled, insert 1000 rows, then update 10 of them to demonstrate deletion vectors"*

CoCo will:
1. Create a V3 Iceberg table with `ICEBERG_VERSION = 3` and `ENABLE_ICEBERG_MERGE_ON_READ = TRUE`
2. Insert sample data
3. Run an UPDATE (uses deletion vectors instead of full file rewrite — no data files are rewritten)

Finally:
> *"Add a new column 'priority' with default value 'STANDARD' to the V3 table and show that existing rows get the default without a backfill"*

This demonstrates V3 default values — schema evolution without rewriting data.

Also explore: `demos/iceberg.sql`

---

### Section 6: Interactive Tables (5 min) — CoCo + Manual

Run point-lookup queries in **Snowsight** to observe sub-second latency:

```sql
USE WAREHOUSE hol_interactive_wh;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- Point lookup by customer ID
SELECT * FROM dash_automated_intelligence_db.interactive.customer_order_analytics
WHERE customer_id = 1;

-- Point lookup by order ID
SELECT * FROM dash_automated_intelligence_db.interactive.order_lookup
WHERE order_id = '<any-order-uuid-from-raw.orders>';
```

Check the query profile — sub-second execution on 50M rows.

**Concurrency load test (the wow moment):**

> **Prompt CoCo:**  
> *"Run the interactive tables load test at interactive/load_test.py"*

This fires 200 concurrent sessions (1000 queries total) against both Interactive and Standard warehouses, then compares P50/P90/P99 latencies. Expected result: **~10x faster P50** on Interactive.

> **Tip:** The first run after setup may show modest gains (~2x) while the Interactive Table cache warms up. Run the load test a **second time** for the full wow moment (~10-12x speedup).

---

### Section 7: Data Quality (5 min) — CoCo

The setup script intentionally injected ~200 NULL values into `orders.total_amount` and `order_items.quantity`, plus ~150 NULLs into `order_items.product_name`. DMFs have already detected the first two — but there's a gap.

> **Prompt CoCo:**  
> *"Check the data quality monitoring results and show me which columns have NULL violations"*

CoCo will show that `TOTAL_AMOUNT` (200 NULLs) and `QUANTITY` (200 NULLs) have violations — but `product_name` NULLs are going **undetected**.

> **Bonus:** *"Show me the alert history for data quality issues"*

CoCo will query `data_quality_alerts` and show the alert that fired during setup.

**Discover the gap:**
> *"Are there any NULL values in order_items.product_name? Is that column being monitored?"*

CoCo will find ~150 NULLs and reveal the DMF is mis-attached to `product_category` instead of `product_name`.

**Fix it:**
> *"Fix the DMF — remove the NULL check from product_category and add it to product_name instead"*

CoCo will run:
```sql
ALTER TABLE order_items DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (product_category);
ALTER TABLE order_items ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (product_name);
```

This demonstrates the real-world workflow: monitor → discover gaps → fix coverage.

Also explore: `demos/data-quality.sql`

---

### Section 8: dbt Analytics (10 min) — CoCo

> **Prompt CoCo:**  
> *"Install dbt dependencies and build all models in the dbt-analytics project"*

CoCo will:
1. Run `dbt deps` to install packages
2. Run `dbt build` to create all models
3. Report pass/fail for 9+ models (staging views + mart tables)

Follow up:
> *"Show me the customer lifetime value segments — how many customers are in each value tier?"*

---

### Section 9: CoCo Custom Skill (5 min) — CoCo

Create a reusable CoCo skill that automates table profiling:

> **Prompt CoCo:**  
> *"Create a custom CoCo skill called 'profile-table' that takes a table name, counts rows, checks for NULL columns, shows distinct value counts, and flags potential data quality issues"*

CoCo will:
1. Create `.cortex/skills/profile-table/SKILL.md` with the skill definition
2. Define when the skill should activate (triggers)
3. Include step-by-step instructions for profiling any table

Test it:
> *"$profile-table DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS"*

This demonstrates how teams package repeatable workflows as shareable CoCo skills.

---

### Section 10: Snowflake CoWork (10 min) — CoCo

> **Prompt CoCo:**  
> *"Run snowflake-cowork/create_agent.sql to create the Business Insights Agent"*

Then test the agent with its sample questions — each demonstrates different tool routing:

| # | Question | Tools Used |
|---|----------|-----------|
| 1 | "Show me monthly revenue trend from June 2025 to April 2026" | Cortex Analyst (text-to-SQL) → chart |
| 2 | "Revenue dropped in February — what caused it and what do reviews say?" | Cortex Analyst + Agentic Search (what→why) |
| 3 | "Find reviews mentioning wrong size with a rating below 3" | Agentic Search (filtered: source_type=review, rating<3) |
| 4 | "Why are customers returning ski boots?" | Agentic Search (reviews + tickets, persist→analyze) |
| 5 | "What is our total revenue and customer count by state?" | Cortex Analyst (text-to-SQL) |
| 6 | "What are the top complaint themes in support tickets from February 2026?" | Agentic Search (filter→persist→AI_AGG theme extraction) |
| 7 | "How many reviews mention sizing issues, and which products are most affected?" | Agentic Search (broad search→count→breakdown) |

This is the **capstone moment** — the agent routes across structured data (text-to-SQL) and unstructured data (Cortex Search) to answer "what happened" and "why."

Also explore: `snowflake-cowork/semantic_view_sql_demo.sql`

---

### Section 11: Security & Governance (5 min) — Snowflake CoWork

The Row Access Policy and WEST_COAST_MANAGER role were already created by `setup.sql`. Now demonstrate the contrast using Snowflake CoWork:

1. Open **Snowflake CoWork** in Snowsight
2. Ask the Business Insights Agent: *"What is our total revenue and customer count by state?"*
3. Note the result (all 10 states visible as ACCOUNTADMIN)
4. Switch role to `WEST_COAST_MANAGER` and ask the same question
5. Only CA, OR, WA appear — the Row Access Policy transparently filters data

Key insight: The same agent, same question — but different results based on who's asking. Row-level security works transparently through AI agents.

Also explore: `demos/security-rbac.sql` (reference queries)

---

### Section 12: Streamlit Dashboard (5 min) — CoCo

> **Prompt CoCo:**  
> *"Deploy the Streamlit dashboard to Snowflake"*

CoCo will run `snow streamlit deploy` from the `streamlit-dashboard/` directory.

Open in Snowsight to see the data pipeline in action — staging ingestion, Gen2 MERGE to production, pipeline health, and product analytics.

---

### Section 13: Agent Evaluation (5 min) — CoCo + Snowsight

The evaluation dataset (7 questions + ground truth) was created by `setup.sql`. Now run the evaluation:

#### Run via Snowsight UI

1. Navigate to **AI & ML → Agents → BUSINESS_INSIGHTS_AGENT → Evaluations** tab
2. Click **New evaluation run**
3. Name it (e.g. `hol-eval-run-1`)
4. Select **Create new dataset** → source table: `DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.AGENT_EVALUATION_DATA`
5. Map columns: `INPUT_QUERY` → query_text, `GROUND_TRUTH` → ground_truth
6. Toggle on **Answer Correctness** and **Logical Consistency**
7. Click **Create** — evaluation starts automatically (~3 min)

#### Interpret Results

After ~3 minutes, view results in the **Evaluations** tab:

- **Answer Correctness** — Did the agent's response match the expected ground truth? Scored 0–1 per question.
- **Logical Consistency** — Were the agent's planning steps, tool calls, and final response internally consistent? (Reference-free — no ground truth needed.)
- **Per-question drill-down** — Select any row to see the full thread: planning → tool invocations → response generation.
- **Trace details** — Inspect which tools were called, what parameters were passed, and what each tool returned.

This is how you validate agent quality before deploying to production — catch regressions, verify tool routing, and ensure response accuracy.

#### Improve Scores (Stretch Exercise)

If any questions score low on **logical consistency**, inspect the trace to see what happened:

1. Click on a low-scoring row → view **Thread details** → check the "Planning" step
2. Look for vague or missing reasoning about tool selection
3. Update the agent's `instructions.orchestration` to be more explicit (e.g., add "Before calling any tool, explicitly state which tool you will use and why")
4. Recreate the agent and re-run the evaluation with a new run name

> **Tip:** Evaluation scores can vary between runs due to LLM non-determinism. Run multiple evaluations and compare averages for reliable signal.

---

### Section 14: MCP Server (5 min) — CoCo

Expose the Business Insights Agent as a managed MCP server so external AI clients can discover and invoke it:

> **Prompt CoCo:**  
> *"Create a Snowflake-managed MCP server that exposes our Business Insights Agent, semantic view, and customer feedback search as tools"*

CoCo will run:

```sql
CREATE MCP SERVER business_insights_mcp
  FROM SPECIFICATION $$
    tools:
      - name: "business-insights-agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_INSIGHTS_AGENT"
        description: "AI agent that answers business questions using structured data and customer feedback"
        title: "Business Insights Agent"

      - name: "revenue-analytics"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.SEMANTIC.BUSINESS_ANALYTICS_SEMANTIC"
        description: "Text-to-SQL for revenue, orders, customers, and product metrics"
        title: "Revenue Analytics"

      - name: "customer-feedback-search"
        type: "CORTEX_SEARCH_SERVICE_QUERY"
        identifier: "DASH_AUTOMATED_INTELLIGENCE_DB.RAW.CUSTOMER_FEEDBACK_SEARCH"
        description: "Search across product reviews and support tickets"
        title: "Customer Feedback Search"
  $$;
```

**Connect from CoCo:**
```bash
cortex mcp add business-insights https://<account_url>/api/v2/databases/DASH_AUTOMATED_INTELLIGENCE_DB/schemas/SEMANTIC/mcp-servers/BUSINESS_INSIGHTS_MCP --type http
```

Now any MCP-compatible client (CoCo, Claude Desktop, custom apps) can discover and call these tools via the standard MCP protocol.

---

## Cleanup

To remove all objects created during the lab, run [`cleanup.sql`](cleanup.sql):

```bash
snow sql -f cleanup.sql -c <your-connection>
```

---

## Resources

- [Snowpipe Streaming SDK](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-about)
- [Interactive Tables](https://docs.snowflake.com/en/user-guide/interactive)
- [Gen2 Warehouses](https://docs.snowflake.com/en/user-guide/warehouses-gen2)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Semantic Views](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Data Metric Functions](https://docs.snowflake.com/en/user-guide/data-quality-intro)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
- [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
