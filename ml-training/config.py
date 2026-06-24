from dataclasses import dataclass, field
from typing import List


@dataclass
class DataConfig:
    database: str = "DASH_AUTOMATED_INTELLIGENCE_DB"
    schema: str = "RAW"
    warehouse: str = "HOL_WH"
    orders_table: str = "ORDERS"
    order_items_table: str = "ORDER_ITEMS"
    model_registry_schema: str = "MODELS"

    @property
    def orders_fqn(self) -> str:
        return f"{self.database}.{self.schema}.{self.orders_table}"

    @property
    def order_items_fqn(self) -> str:
        return f"{self.database}.{self.schema}.{self.order_items_table}"


@dataclass
class TrainingConfig:
    n_estimators: int = 1000
    max_depth: int = 20
    learning_rate: float = 0.03
    min_child_weight: int = 1
    subsample: float = 0.8
    colsample_bytree: float = 0.8
    gamma: float = 0.1
    reg_alpha: float = 0.1
    reg_lambda: float = 1.0
    random_state: int = 42
    eval_metric: str = "logloss"
    early_stopping_rounds: int = 50
    test_size: float = 0.2
    feature_columns: List[str] = field(default_factory=lambda: [
        "CUSTOMER_ID_ENCODED",
        "PRODUCT_ID_ENCODED",
        "TOTAL_PAST_ORDERS",
        "TOTAL_SPENT",
        "AVG_ITEM_SPEND",
        "UNIQUE_PRODUCTS_BOUGHT",
        "DAYS_SINCE_LAST_ORDER",
        "PRODUCT_POPULARITY",
        "PRODUCT_PRICE",
        "PRODUCT_VOLUME",
        "PRODUCT_PRICE_VARIANCE",
    ])
    label_column: str = "PURCHASED"

    @classmethod
    def light(cls) -> "TrainingConfig":
        return cls(n_estimators=100, max_depth=6, early_stopping_rounds=10)

    def to_xgb_params(self) -> dict:
        return {
            "n_estimators": self.n_estimators,
            "max_depth": self.max_depth,
            "learning_rate": self.learning_rate,
            "min_child_weight": self.min_child_weight,
            "subsample": self.subsample,
            "colsample_bytree": self.colsample_bytree,
            "gamma": self.gamma,
            "reg_alpha": self.reg_alpha,
            "reg_lambda": self.reg_lambda,
            "random_state": self.random_state,
            "eval_metric": self.eval_metric,
        }
