# Product Recommendation Model with GPU Training (Workspaces)
#
# GPU-accelerated ML model training in Snowflake Notebooks in Workspaces.
# Predicts which products a customer is likely to purchase next.
#
# Prerequisites:
# - Run in Snowflake Workspaces with GPU compute pool
# - Data in DASH_AUTOMATED_INTELLIGENCE_DB.RAW.ORDERS and ORDER_ITEMS

import logging
import time

from snowflake.snowpark.context import get_active_session

from config import DataConfig, TrainingConfig
from data_loader import get_data_stats, load_training_data
from evaluator import evaluate, print_report
from registry_manager import save_to_registry
from trainer import train_model

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s — %(message)s")
logger = logging.getLogger(__name__)


def main() -> None:
    pipeline_start = time.time()

    session = get_active_session()
    data_config = DataConfig()
    training_config = TrainingConfig()

    session.use_database(data_config.database)
    session.use_schema(data_config.schema)
    session.use_warehouse(data_config.warehouse)

    # Data volume check
    orders_count, items_count = get_data_stats(session, data_config)
    logger.info(f"Source tables — ORDERS: {orders_count:,} rows, ORDER_ITEMS: {items_count:,} rows")

    # Feature engineering + load
    pdf = load_training_data(session, data_config)

    # Train
    result = train_model(pdf, training_config)

    # Evaluate
    eval_result = evaluate(result, training_config.feature_columns)
    print_report(eval_result, result.training_time, result.used_gpu)

    # Register model
    version = save_to_registry(session, result, eval_result, data_config)

    elapsed = time.time() - pipeline_start
    logger.info(f"Pipeline complete in {elapsed:.1f}s — model version: {version}")


main()
