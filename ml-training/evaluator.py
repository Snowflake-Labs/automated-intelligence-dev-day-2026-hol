import logging
from dataclasses import dataclass
from typing import List

import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    f1_score,
    precision_score,
    recall_score,
)

from trainer import TrainingResult

logger = logging.getLogger(__name__)


@dataclass
class EvaluationResult:
    accuracy: float
    precision: float
    recall: float
    f1: float
    feature_importances: pd.DataFrame
    classification_report_text: str


def evaluate(result: TrainingResult, feature_columns: List[str]) -> EvaluationResult:
    y_pred = result.model.predict(result.X_test)

    accuracy = accuracy_score(result.y_test, y_pred)
    precision = precision_score(result.y_test, y_pred)
    recall = recall_score(result.y_test, y_pred)
    f1 = f1_score(result.y_test, y_pred)

    report_text = classification_report(
        result.y_test, y_pred, target_names=["Not Purchased", "Purchased"]
    )

    importances = pd.DataFrame({
        "feature": feature_columns,
        "importance": result.model.feature_importances_,
    }).sort_values("importance", ascending=False)

    logger.info(f"Evaluation — Accuracy: {accuracy:.4f}, F1: {f1:.4f}")

    return EvaluationResult(
        accuracy=accuracy,
        precision=precision,
        recall=recall,
        f1=f1,
        feature_importances=importances,
        classification_report_text=report_text,
    )


def print_report(eval_result: EvaluationResult, training_time: float, used_gpu: bool) -> None:
    device = "GPU" if used_gpu else "CPU"
    print(f"\n{'=' * 70}")
    print(f"MODEL EVALUATION ({device} Training — {training_time:.2f}s)")
    print(f"{'=' * 70}")
    print(f"\n{eval_result.classification_report_text}")
    print(f"Summary Metrics:")
    print(f"   Accuracy:  {eval_result.accuracy:.4f}")
    print(f"   Precision: {eval_result.precision:.4f}")
    print(f"   Recall:    {eval_result.recall:.4f}")
    print(f"   F1 Score:  {eval_result.f1:.4f}")
    print(f"\nBusiness Impact:")
    print(f"   {eval_result.precision * 100:.1f}% of recommendations will be relevant")
    print(f"   We'll capture {eval_result.recall * 100:.1f}% of products customers want")
    print(f"\nFeature Importance:")
    print(eval_result.feature_importances.to_string(index=False))
    print(f"{'=' * 70}")
