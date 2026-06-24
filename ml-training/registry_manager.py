import datetime
import logging
import time

from snowflake.ml.registry import Registry
from snowflake.snowpark import Session

from config import DataConfig
from evaluator import EvaluationResult
from trainer import TrainingResult

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 2


def save_to_registry(
    session: Session,
    training_result: TrainingResult,
    eval_result: EvaluationResult,
    data_config: DataConfig,
    model_name: str = "product_recommendation_xgboost",
) -> str:
    registry = Registry(
        session=session,
        database_name=data_config.database,
        schema_name=data_config.model_registry_schema,
    )

    version_name = f"v_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    sample_input = training_result.X_test.head(5)

    metrics = {
        "accuracy": float(eval_result.accuracy),
        "precision": float(eval_result.precision),
        "recall": float(eval_result.recall),
        "f1_score": float(eval_result.f1),
        "training_samples": int(len(training_result.X_train)),
        "test_samples": int(len(training_result.X_test)),
        "training_time_seconds": float(training_result.training_time),
        "used_gpu": training_result.used_gpu,
    }

    comment = (
        f"XGBoost product recommender. "
        f"Trained on {len(training_result.X_train):,} customer-product pairs. "
        f"F1: {eval_result.f1:.4f}"
    )

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            registry.log_model(
                model=training_result.model,
                model_name=model_name,
                version_name=version_name,
                sample_input_data=sample_input,
                comment=comment,
                metrics=metrics,
            )
            logger.info(f"Model saved: {data_config.database}.{data_config.model_registry_schema}.{model_name} ({version_name})")
            return version_name
        except Exception as e:
            if attempt == MAX_RETRIES:
                logger.error(f"Failed to save model after {MAX_RETRIES} attempts: {e}")
                raise
            wait = RETRY_BACKOFF_BASE ** attempt
            logger.warning(f"Registry save attempt {attempt} failed ({e}), retrying in {wait}s...")
            time.sleep(wait)
