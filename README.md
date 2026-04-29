# Building an End-to-End AI Application on Snowflake: From Data to Intelligence

**Duration:** ~87 minutes  
**Tools:** Cortex Code Desktop + Snowsight

---

## Overview

In this hands-on lab, you'll build a complete AI-powered retail analytics platform entirely within Snowflake — no external infrastructure required. Using Cortex Code as your AI-assisted development environment, you'll work through the full data lifecycle: stream real-time orders via Snowpipe Streaming, MERGE them into production tables with Gen2 Warehouses, transform them through a 3-tier Dynamic Tables pipeline, and serve them with Interactive Tables for low-latency point lookups. You'll build batch analytical models (customer lifetime value, segmentation, product affinity) with dbt, monitor data quality with Data Metric Functions, explore Iceberg V3 features (deletion vectors, row lineage), and classify unstructured data with AI SQL functions. Tie it all together with Snowflake Intelligence — a conversational AI interface powered by Agent Search (multi-index Cortex Search) that orchestrates Cortex Analyst and Cortex Search to answer "what happened" and "why" from both structured and unstructured data. Finish with row-level security that transparently governs who sees what — even when querying through an AI agent.

### What You'll Learn

- Accelerate development with Cortex Code (AI-assisted SQL, deployment, and data exploration)
- Stream real-time data with Snowpipe Streaming and transform with Dynamic Tables
- Serve low-latency queries with Interactive Tables and Gen2 Warehouses
- Build analytical models (CLV, segmentation, cohorts) with dbt
- Monitor data quality automatically with Data Metric Functions
- Create and query managed Iceberg V3 tables (deletion vectors, row lineage)
- Classify and filter data with AI SQL functions (AI_CLASSIFY, AI_FILTER)
- Build conversational AI with Snowflake Intelligence and Agent Search (multi-index Cortex Search)
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
> COCO = Run via Cortex Code prompts

---

### Section 0: CoCo Setup (5 min) — MANUAL

Launch Cortex Code and verify your connection:

```bash
cortex
```

Verify connection:
- CoCo should show your active connection, role, and warehouse
- Test with: *"What databases do I have access to?"*

---

### Section 1: Infrastructure Setup (10 min) — MANUAL

Run the core infrastructure script in Snowsight or terminal:

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
- Product catalog + 3 Cortex Search Services (product, reviews, tickets)
- Semantic View for natural language queries
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

### Section 3: Gen2 Warehouse & MERGE (5 min) — COCO

> **Prompt CoCo:**  
> *"Merge the staging data into RAW using the Gen2 warehouse and show me the timing results"*

CoCo will:
1. Switch to the Gen2 warehouse
2. Call `staging.merge_staging_to_raw(TRUE)`
3. Display timing: total duration, orders merged, order_items merged

Then ask:
> *"Run a point lookup for customer_id 5000 and show me the partition pruning from the query profile"*

This demonstrates Optima Indexing — automatic partition pruning with zero configuration.

Also explore: `gen2-warehouse/optima_indexing_demo.sql`

---

### Section 4: Dynamic Tables Pipeline (5 min) — COCO

> **Prompt CoCo:**  
> *"Show me the Dynamic Tables pipeline status — names, target lag, last refresh time, and row counts for each tier"*

CoCo will query `INFORMATION_SCHEMA` and display the 3-tier pipeline:
- **Tier 1** (1-min lag): `enriched_orders`, `enriched_order_items`
- **Tier 2** (DOWNSTREAM): `fact_orders`
- **Tier 3** (DOWNSTREAM): `daily_business_metrics`, `product_performance_metrics`

Follow up:
> *"Show me a sample of the daily business metrics — top 5 days by revenue"*

---

### Section 5: Iceberg Tables & V3 Features (7 min) — COCO

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

Also explore: `iceberg/partitioned_writes_demo.sql`

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

### Section 7: Data Quality (5 min) — COCO

> **Prompt CoCo:**  
> *"Check the data quality monitoring results — are there any NULL violations in the orders or order_items tables?"*

CoCo will query `vw_dq_monitoring_results` and summarize findings.

Follow up:
> *"Show me the alert history for data quality issues"*

Also explore: `data-quality/data_quality_expectations_demo.sql`

---

### Section 8: dbt Analytics (10 min) — COCO

> **Prompt CoCo:**  
> *"Install dbt dependencies and build all models in the dbt-analytics project"*

CoCo will:
1. Run `dbt deps` to install packages
2. Run `dbt build` to create all models
3. Report pass/fail for 9+ models (staging views + mart tables)

Follow up:
> *"Show me the customer lifetime value segments — how many customers are in each value tier?"*

---

### Section 9: AI SQL Functions (5 min) — COCO

> **Prompt CoCo:**  
> *"Run sentiment analysis on the product reviews using AI_CLASSIFY — show me 5 reviews with their predicted sentiment"*

CoCo will write and execute AI function SQL against `product_reviews`.

Also try:
> *"Use AI_FILTER to find product catalog items suitable for beginners"*

See: `ai-sql-demo/ai_filter_demo.sql`

---

### Section 10: Snowflake Intelligence (10 min) — COCO

> **Prompt CoCo:**  
> *"Run snowflake-intelligence/create_agent.sql to create the Business Insights Agent"*

Then test the agent with its sample questions:

> *"Ask the agent: What was our total revenue in December 2025 vs February 2026?"*

> *"Ask the agent: Why are customers returning ski boots?"*

> *"Ask the agent: Revenue dropped in February — what caused it and what do reviews say?"*

> *"Ask the agent: Find reviews mentioning wrong size with a rating below 3"*

This is the **capstone moment** — the agent routes across structured data (text-to-SQL) and unstructured data (Cortex Search) to answer "what happened" and "why."

Also explore: `snowflake-intelligence/semantic_view_sql_demo.sql`

---

### Section 11: Security & Governance (5 min) — COCO

The Row Access Policy and WEST_COAST_MANAGER role were already created by `setup.sql`. Now demonstrate the contrast:

> **Prompt CoCo:**  
> *"Query the customer count by state as ACCOUNTADMIN, then as WEST_COAST_MANAGER — show me the difference"*

CoCo will:
1. Query customers as `ACCOUNTADMIN` (all 10 states)
2. Query customers as `WEST_COAST_MANAGER` (only CA, OR, WA)
3. Show the contrast

Key insight: The West Coast Manager doesn't even know other states exist — filtered at the database level.

Also explore: `security-and-governance/setup_west_coast_manager.sql` (reference queries)

---

### Section 12: Streamlit Dashboard (5 min) — COCO

> **Prompt CoCo:**  
> *"Deploy the Streamlit dashboard to Snowflake"*

CoCo will run `snow streamlit deploy` from the `streamlit-dashboard/` directory.

Open in Snowsight to see all the data flowing through the system — live ingestion metrics, pipeline health, query performance comparisons.

---

## Summary

| Section | Method | Duration | Focus |
|---------|--------|----------|-------|
| 0. CoCo Setup | MANUAL | 5 min | Install + connect |
| 1. Infrastructure | MANUAL | 10 min | Run setup.sql |
| 2. Streaming | MANUAL | 10 min | Python SDK → STAGING |
| 3. Gen2 MERGE | COCO | 5 min | Staging → RAW + Optima |
| 4. Dynamic Tables | COCO | 5 min | Pipeline status + data |
| 5. Iceberg & V3 | COCO | 7 min | Managed Iceberg + V3 features |
| 6. Interactive Tables | MANUAL | 5 min | Point lookups in Snowsight |
| 7. Data Quality | COCO | 5 min | DMF monitoring results |
| 8. dbt Analytics | COCO | 10 min | Build models |
| 9. AI SQL | COCO | 5 min | AI_CLASSIFY, AI_FILTER |
| 10. Intelligence | COCO | 10 min | Agent creation + NL queries |
| 11. Security | COCO | 5 min | RBAC role contrast |
| 12. Streamlit | COCO | 5 min | Deploy dashboard |
| | | **~87 min** | |

**Manual: 4 sections** (setup, streaming, interactive, CoCo install)  
**CoCo: 9 sections** (Gen2, DTs, Iceberg, DQ, dbt, AI SQL, Intelligence, Security, Streamlit)

---

## Cleanup

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS dash_automated_intelligence_db CASCADE;
DROP WAREHOUSE IF EXISTS hol_wh;
DROP WAREHOUSE IF EXISTS hol_gen2_wh;
DROP WAREHOUSE IF EXISTS hol_interactive_wh;
DROP ROLE IF EXISTS automated_intelligence_admin;
DROP ROLE IF EXISTS west_coast_manager;
```

---

## Directory Structure

```
setup.sql                      <- Run first (creates all shared infrastructure)
ai-sql-demo/                   <- AI_FILTER, AI_CLASSIFY demos
data-quality/                  <- Data Metric Functions demo
dbt-analytics/                 <- dbt project (staging + mart models)
gen2-warehouse/                <- Gen2 + Optima Indexing demo
iceberg/                       <- Iceberg partitioned writes demo
interactive/                   <- Interactive Tables validation + load testing
security-and-governance/       <- Row Access Policy (RBAC) demo queries
snowflake-intelligence/        <- Cortex Agent + Semantic View
snowpipe-streaming-python/     <- Python Snowpipe Streaming SDK
sql-features/                  <- SQL feature demos (pipe operator, UNION BY NAME, etc.)
streamlit-dashboard/           <- 7-page Streamlit in Snowflake app
tests/                         <- Validation notebooks
```

---

## Resources

- [Snowpipe Streaming SDK](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-about)
- [Interactive Tables](https://docs.snowflake.com/en/user-guide/interactive)
- [Gen2 Warehouses](https://docs.snowflake.com/en/user-guide/warehouses-gen2)
- [Cortex Agent](https://docs.snowflake.com/en/user-guide/snowflake-intelligence/cortex-agent)
- [Semantic Views](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Data Metric Functions](https://docs.snowflake.com/en/user-guide/data-quality-intro)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
- [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code)
