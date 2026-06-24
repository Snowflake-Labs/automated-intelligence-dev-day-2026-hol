import logging
import time
from typing import Tuple

import pandas as pd
from snowflake.snowpark import Session

from config import DataConfig

logger = logging.getLogger(__name__)

TRAINING_FEATURES_SQL = """
CREATE OR REPLACE TEMPORARY TABLE training_features AS
WITH customer_history AS (
    SELECT
        o.CUSTOMER_ID,
        COUNT(DISTINCT o.ORDER_ID) as TOTAL_PAST_ORDERS,
        SUM(oi.LINE_TOTAL) as TOTAL_SPENT,
        AVG(oi.LINE_TOTAL) as AVG_ITEM_SPEND,
        COUNT(DISTINCT oi.PRODUCT_ID) as UNIQUE_PRODUCTS_BOUGHT,
        DATEDIFF(day, MAX(o.ORDER_DATE), CURRENT_DATE()) as DAYS_SINCE_LAST_ORDER,
        LISTAGG(DISTINCT oi.PRODUCT_ID, ',') as PURCHASED_PRODUCTS
    FROM {orders_fqn} o
    JOIN {order_items_fqn} oi ON o.ORDER_ID = oi.ORDER_ID
    GROUP BY o.CUSTOMER_ID
),
product_popularity AS (
    SELECT
        PRODUCT_ID,
        COUNT(DISTINCT ORDER_ID) as TIMES_ORDERED,
        AVG(UNIT_PRICE) as AVG_PRICE,
        SUM(QUANTITY) as TOTAL_QUANTITY_SOLD,
        STDDEV(UNIT_PRICE) as PRICE_VARIANCE
    FROM {order_items_fqn}
    GROUP BY PRODUCT_ID
),
customer_products AS (
    SELECT
        o.CUSTOMER_ID,
        oi.PRODUCT_ID,
        COUNT(*) as PURCHASE_COUNT,
        SUM(oi.QUANTITY) as TOTAL_QUANTITY,
        MAX(o.ORDER_DATE) as LAST_PRODUCT_PURCHASE
    FROM {orders_fqn} o
    JOIN {order_items_fqn} oi ON o.ORDER_ID = oi.ORDER_ID
    GROUP BY o.CUSTOMER_ID, oi.PRODUCT_ID
),
positive_examples AS (
    SELECT
        cp.CUSTOMER_ID,
        cp.PRODUCT_ID,
        ch.TOTAL_PAST_ORDERS,
        ch.TOTAL_SPENT,
        ch.AVG_ITEM_SPEND,
        ch.UNIQUE_PRODUCTS_BOUGHT,
        ch.DAYS_SINCE_LAST_ORDER,
        pp.TIMES_ORDERED as PRODUCT_POPULARITY,
        pp.AVG_PRICE as PRODUCT_PRICE,
        pp.TOTAL_QUANTITY_SOLD as PRODUCT_VOLUME,
        COALESCE(pp.PRICE_VARIANCE, 0) as PRODUCT_PRICE_VARIANCE,
        1 as PURCHASED
    FROM customer_products cp
    JOIN customer_history ch ON cp.CUSTOMER_ID = ch.CUSTOMER_ID
    JOIN product_popularity pp ON cp.PRODUCT_ID = pp.PRODUCT_ID
),
negative_examples AS (
    SELECT
        ch.CUSTOMER_ID,
        pp.PRODUCT_ID,
        ch.TOTAL_PAST_ORDERS,
        ch.TOTAL_SPENT,
        ch.AVG_ITEM_SPEND,
        ch.UNIQUE_PRODUCTS_BOUGHT,
        ch.DAYS_SINCE_LAST_ORDER,
        pp.TIMES_ORDERED as PRODUCT_POPULARITY,
        pp.AVG_PRICE as PRODUCT_PRICE,
        pp.TOTAL_QUANTITY_SOLD as PRODUCT_VOLUME,
        COALESCE(pp.PRICE_VARIANCE, 0) as PRODUCT_PRICE_VARIANCE,
        0 as PURCHASED
    FROM customer_history ch
    CROSS JOIN product_popularity pp
    WHERE NOT CONTAINS(ch.PURCHASED_PRODUCTS, pp.PRODUCT_ID)
    SAMPLE (10 ROWS)
)
SELECT * FROM positive_examples
UNION ALL
SELECT * FROM negative_examples
"""


def load_training_data(session: Session, data_config: DataConfig) -> pd.DataFrame:
    logger.info("Building training features in Snowflake...")
    start = time.time()

    sql = TRAINING_FEATURES_SQL.format(
        orders_fqn=data_config.orders_fqn,
        order_items_fqn=data_config.order_items_fqn,
    )
    session.sql(sql).collect()

    row_count = session.sql("SELECT COUNT(*) as cnt FROM training_features").collect()[0]["CNT"]
    logger.info(f"Training features created: {row_count:,} samples")

    pdf = session.sql("SELECT * FROM training_features").to_pandas()
    elapsed = time.time() - start

    if pdf.empty:
        raise ValueError("Training dataset is empty — check that source tables have data")

    logger.info(f"Data loaded into pandas in {elapsed:.2f}s ({len(pdf):,} rows, {len(pdf.columns)} cols)")
    return pdf


def get_data_stats(session: Session, data_config: DataConfig) -> Tuple[int, int]:
    orders_count = session.table(data_config.orders_fqn).count()
    items_count = session.table(data_config.order_items_fqn).count()
    return orders_count, items_count
