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
  - [Section 6: Interactive Tables](#section-6-interactive-tables-5-min--manual)
  - [Section 7: Data Quality](#section-7-data-quality-5-min--coco)
  - [Section 8: dbt Analytics](#section-8-dbt-analytics-10-min--coco)
  - [Section 9: Cortex AI Functions](#section-9-cortex-ai-functions-5-min--coco)
  - [Section 10: Snowflake Intelligence](#section-10-snowflake-intelligence-10-min--coco)
  - [Section 11: Security & Governance](#section-11-security--governance-5-min--snowflake-intelligence)
  - [Section 12: Streamlit Dashboard](#section-12-streamlit-dashboard-5-min--coco)
- [Summary](#summary)
- [Cleanup](#cleanup)
- [Resources](#resources)

---

## Overview

In this hands-on lab, you'll build a complete AI-powered retail analytics platform entirely within Snowflake — no external infrastructure required. Using Cortex Code as your AI-assisted development environment, you'll work through the full data lifecycle: stream real-time orders via Snowpipe Streaming, MERGE them into production tables with Gen2 Warehouses, transform them through a 3-tier Dynamic Tables pipeline, and serve them with Interactive Tables for low-latency point lookups. You'll build analytical models with dbt, monitor data quality with Data Metric Functions, explore Iceberg V3 features (deletion vectors, row lineage), and classify unstructured data with Cortex AI functions. Tie it all together with Snowflake Intelligence — a conversational AI interface where a Cortex Agent orchestrates Cortex Analyst (text-to-SQL via a semantic view with verified queries) and Agentic Search (multi-index Cortex Search across reviews and tickets with persist-to-table analysis) to answer "what happened" and "why" from both structured and unstructured data. Finish with row-level security that transparently governs who sees what — even when querying through an AI agent.

### What You'll Learn

- Accelerate development with Cortex Code (AI-assisted SQL, deployment, and data exploration)
- Stream real-time data with Snowpipe Streaming and transform with Dynamic Tables
- Serve low-latency queries with Interactive Tables and Gen2 Warehouses
- Build analytical models with dbt
- Monitor data quality automatically with Data Metric Functions
- Create and query managed Iceberg V3 tables (deletion vectors, row lineage)
- Classify and filter data with Cortex AI functions (AI_CLASSIFY, AI_FILTER)
- Build a Cortex Agent with Cortex Analyst (semantic view + verified queries) and Agentic Search (multi-index Cortex Search)
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

### 1. Snowflake Account (provided)

You will receive login credentials for a pre-provisioned Snowflake account. Verify you can log in at:
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

### 7. Choose Your Environment

| Option | What It Handles | Setup |
|--------|----------------|-------|
| **Cortex Code Desktop** (recommended) | SQL, terminal, AI prompts — everything in one place | Launch `cortex`, open the cloned repo folder |
| **Snowsight Workspaces** (alternative) | SQL files only — open and run directly | Projects → Workspaces → "From Git repository" → paste repo URL → "Public repository" auth → Create |

**Recommended: Cortex Code Desktop.** All lab sections (SQL execution, terminal commands, CoCo prompts) work without switching tools.

**If using Workspaces:** SQL-heavy sections work natively (open file → Run). For Sections 2 (streaming) and 8 (dbt), you'll need a local terminal since those require Python/dbt CLI.

> **Docs:** [Integrate Workspaces with Git](https://docs.snowflake.com/en/user-guide/ui-snowsight/workspaces-git)

### Account Features (pre-enabled)

The following are already enabled on your lab account:
- Gen2 Warehouses
- Interactive Warehouses
- Cortex AI (Agent, Search, Analyst)
- Dynamic Tables
- Snowpipe Streaming

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
- Seed data loaded from S3 (500K customers, 1M orders, 3.2M order items, 1200 reviews, 1200 tickets)
- Row Access Policy + WEST_COAST_MANAGER role (RBAC demo)

---

### Section 2: Streaming Ingestion (10 min) — MANUAL

Stream orders into the **STAGING** schema using the Python SDK:

```bash
cd snowpipe-streaming-python
pip install -r requirements.txt

# Copy and configure profile
cp profile.json.template profile.json
# Edit profile.json: set account, user, private_key, role

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
> *"Merge the staging data into RAW using the Gen2 warehouse and show me the timing results"*

CoCo will:
1. Switch to the Gen2 warehouse
2. Call `staging.merge_staging_to_raw(TRUE)`
3. Display timing: total duration, orders merged, order_items merged

Then ask:
> *"Run a point lookup for customer_id 5000 and show me the partition pruning from the query profile"*

This demonstrates Optima Indexing — automatic partition pruning with zero configuration.

Also explore: `demos/gen2-warehouse.sql`

---

### Section 4: Dynamic Tables Pipeline (5 min) — CoCo

> **Prompt CoCo:**  
> *"Show me the Dynamic Tables pipeline status — names, target lag, last refresh time, and row counts for each tier"*

CoCo will query `INFORMATION_SCHEMA` and display the 3-tier pipeline:
- **Tier 1** (1-min lag): `enriched_orders`, `enriched_order_items`
- **Tier 2** (DOWNSTREAM): `fact_orders`
- **Tier 3** (DOWNSTREAM): `daily_business_metrics`, `product_performance_metrics`

Follow up:
> *"Show me a sample of the daily business metrics — top 5 days by revenue"*

---

### Section 5: Iceberg Tables & V3 Features (7 min) — CoCo

> **Prompt CoCo:**  
> *"Create a managed Iceberg table from RAW.ORDERS with clustering by year and month, then query it to show partition pruning"*

CoCo will:
1. Create schema `ICEBERG`
2. Create a managed Iceberg table (CATALOG='SNOWFLAKE', no external volume needed)
3. Run a filtered query and show partitions scanned vs total

Then explore V3 features:
> *"Create an Iceberg V3 table from RAW.ORDERS (FORMAT_VERSION=3), update 10 rows to demonstrate deletion vectors, then show me the row lineage fields _row_id and _last_updated_sequence_number"*

CoCo will:
1. Create a V3 Iceberg table
2. Run an UPDATE (uses deletion vectors instead of full file rewrite)
3. Query row lineage metadata fields

Finally:
> *"Add a new column 'priority' with default value 'STANDARD' to the V3 table and show that existing rows get the default without a backfill"*

This demonstrates V3 default values — schema evolution without rewriting data.

Also explore: `demos/iceberg.sql`

---

### Section 6: Interactive Tables (5 min) — MANUAL

Run point-lookup queries directly in **Snowsight** to observe raw latency in the query profile:

```sql
USE WAREHOUSE hol_interactive_wh;

-- Point lookup by customer ID (observe latency in query profile)
SELECT * FROM dash_automated_intelligence_db.interactive.customer_order_analytics
WHERE customer_id = 1;

-- Point lookup by order ID
SELECT * FROM dash_automated_intelligence_db.interactive.order_lookup
WHERE order_id = '<any-order-uuid-from-raw.orders>';
```

Check the query profile for fast execution time.

---

### Section 7: Data Quality (5 min) — CoCo

> **Prompt CoCo:**  
> *"Check the data quality monitoring results — are there any NULL violations in the orders or order_items tables?"*

CoCo will query `vw_dq_monitoring_results` and summarize findings.

Follow up:
> *"Show me the alert history for data quality issues"*

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

### Section 9: Cortex AI Functions (5 min) — CoCo

> **Prompt CoCo:**  
> *"Run sentiment analysis on the product reviews using AI_CLASSIFY — show me 5 reviews with their predicted sentiment"*

CoCo will write and execute AI function SQL against `product_reviews`.

Also try:
> *"Use AI_FILTER to find product catalog items suitable for beginners"*

See: `demos/cortex-ai-functions.sql`

---

### Section 10: Snowflake Intelligence (10 min) — CoCo

> **Prompt CoCo:**  
> *"Run snowflake-intelligence/create_agent.sql to create the Business Insights Agent"*

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

Also explore: `snowflake-intelligence/semantic_view_sql_demo.sql`

---

### Section 11: Security & Governance (5 min) — Snowflake Intelligence

The Row Access Policy and WEST_COAST_MANAGER role were already created by `setup.sql`. Now demonstrate the contrast using Snowflake Intelligence:

1. Open **Snowflake Intelligence** in Snowsight
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

Open in Snowsight to see all the data flowing through the system — live ingestion metrics, pipeline health, query performance comparisons.

---

## Summary

| Section | Method | Duration | Focus |
|---------|--------|----------|-------|
| 1. Setup | MANUAL | 10 min | CoCo install + setup.sql |
| 2. Streaming | MANUAL | 10 min | Python SDK → STAGING |
| 3. Gen2 MERGE | CoCo | 5 min | Staging → RAW + Optima |
| 4. Dynamic Tables | CoCo | 5 min | Pipeline status + data |
| 5. Iceberg & V3 | CoCo | 7 min | Managed Iceberg + V3 features |
| 6. Interactive Tables | MANUAL | 5 min | Point lookups in Snowsight |
| 7. Data Quality | CoCo | 5 min | DMF monitoring results |
| 8. dbt Analytics | CoCo | 10 min | Build models |
| 9. Cortex AI | CoCo | 5 min | AI_CLASSIFY, AI_FILTER |
| 10. Intelligence | CoCo | 10 min | Agent creation + NL queries |
| 11. Security | SI | 5 min | RBAC via Snowflake Intelligence |
| 12. Streamlit | CoCo | 5 min | Deploy dashboard |

**Manual: 3 sections** (setup, streaming, interactive)  
**CoCo: 8 sections** (Gen2, DTs, Iceberg, DQ, dbt, Cortex AI, Intelligence, Streamlit)  
**Snowflake Intelligence: 1 section** (Security & Governance)

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
