PRODUCTS = [
    {"id": 1001, "name": "Powder Skis", "category": "Skis", "price": 799.99},
    {"id": 1002, "name": "All-Mountain Skis", "category": "Skis", "price": 649.99},
    {"id": 1003, "name": "Freestyle Snowboard", "category": "Snowboards", "price": 549.99},
    {"id": 1004, "name": "Freeride Snowboard", "category": "Snowboards", "price": 699.99},
    {"id": 1005, "name": "Ski Boots", "category": "Boots", "price": 449.99},
    {"id": 1006, "name": "Snowboard Boots", "category": "Boots", "price": 349.99},
    {"id": 1007, "name": "Ski Poles", "category": "Accessories", "price": 79.99},
    {"id": 1008, "name": "Ski Goggles", "category": "Accessories", "price": 149.99},
    {"id": 1009, "name": "Snowboard Bindings", "category": "Accessories", "price": 249.99},
    {"id": 1010, "name": "Ski Helmet", "category": "Accessories", "price": 179.99},
]

PRODUCT_BY_ID = {p["id"]: p for p in PRODUCTS}

MONTHLY_CONFIG = {
    "2025-06": {"volume_pct": 0.040, "season": "off",       "discount_range": (15, 25), "cancel_rate": 0.03, "items_range": (1, 3), "segment_weights": (0.33, 0.34, 0.33)},
    "2025-07": {"volume_pct": 0.040, "season": "off",       "discount_range": (15, 25), "cancel_rate": 0.03, "items_range": (1, 3), "segment_weights": (0.33, 0.34, 0.33)},
    "2025-08": {"volume_pct": 0.050, "season": "off",       "discount_range": (12, 20), "cancel_rate": 0.03, "items_range": (1, 3), "segment_weights": (0.30, 0.35, 0.35)},
    "2025-09": {"volume_pct": 0.070, "season": "preseason", "discount_range": (5, 12),  "cancel_rate": 0.03, "items_range": (2, 4), "segment_weights": (0.45, 0.40, 0.15)},
    "2025-10": {"volume_pct": 0.090, "season": "preseason", "discount_range": (5, 12),  "cancel_rate": 0.03, "items_range": (2, 4), "segment_weights": (0.45, 0.40, 0.15)},
    "2025-11": {"volume_pct": 0.140, "season": "peak",      "discount_range": (2, 8),   "cancel_rate": 0.02, "items_range": (3, 5), "segment_weights": (0.50, 0.35, 0.15)},
    "2025-12": {"volume_pct": 0.160, "season": "peak",      "discount_range": (2, 8),   "cancel_rate": 0.02, "items_range": (3, 6), "segment_weights": (0.50, 0.35, 0.15)},
    "2026-01": {"volume_pct": 0.130, "season": "peak",      "discount_range": (3, 10),  "cancel_rate": 0.04, "items_range": (2, 5), "segment_weights": (0.45, 0.35, 0.20)},
    "2026-02": {"volume_pct": 0.080, "season": "crash",     "discount_range": (10, 18), "cancel_rate": 0.12, "items_range": (1, 3), "segment_weights": (0.20, 0.35, 0.45)},
    "2026-03": {"volume_pct": 0.070, "season": "shoulder",  "discount_range": (10, 15), "cancel_rate": 0.05, "items_range": (1, 3), "segment_weights": (0.30, 0.35, 0.35)},
    "2026-04": {"volume_pct": 0.060, "season": "clearance", "discount_range": (20, 35), "cancel_rate": 0.03, "items_range": (1, 3), "segment_weights": (0.15, 0.30, 0.55)},
    "2026-05": {"volume_pct": 0.060, "season": "clearance", "discount_range": (20, 35), "cancel_rate": 0.03, "items_range": (2, 4), "segment_weights": (0.15, 0.30, 0.55)},
    "2026-06": {"volume_pct": 0.010, "season": "off",       "discount_range": (10, 20), "cancel_rate": 0.03, "items_range": (1, 3), "segment_weights": (0.33, 0.34, 0.33)},
}

CATEGORY_WEIGHTS_BY_SEASON = {
    "peak":      {"Skis": 0.30, "Snowboards": 0.25, "Boots": 0.20, "Accessories": 0.25},
    "preseason": {"Skis": 0.25, "Snowboards": 0.20, "Boots": 0.30, "Accessories": 0.25},
    "crash":     {"Skis": 0.15, "Snowboards": 0.15, "Boots": 0.35, "Accessories": 0.35},
    "shoulder":  {"Skis": 0.20, "Snowboards": 0.20, "Boots": 0.25, "Accessories": 0.35},
    "clearance": {"Skis": 0.20, "Snowboards": 0.20, "Boots": 0.15, "Accessories": 0.45},
    "off":       {"Skis": 0.10, "Snowboards": 0.10, "Boots": 0.10, "Accessories": 0.70},
}

STATUS_DISTRIBUTION = {
    "normal": {"Completed": 0.65, "Shipped": 0.15, "Processing": 0.10, "Pending": 0.07, "Cancelled": 0.03},
    "crash":  {"Completed": 0.50, "Shipped": 0.12, "Processing": 0.08, "Pending": 0.18, "Cancelled": 0.12},
}

SEGMENT_AOV_MULTIPLIER = {"Premium": 1.4, "Standard": 1.0, "Basic": 0.7}

TOTAL_ORDERS = 50_000_000
NUM_CUSTOMERS = 2_000_000
NUM_REVIEWS = 1200
NUM_TICKETS = 1200

MONTH_DAYS = {
    "2025-06": (5, 30), "2025-07": (1, 31), "2025-08": (1, 31),
    "2025-09": (1, 30), "2025-10": (1, 31), "2025-11": (1, 30),
    "2025-12": (1, 31), "2026-01": (1, 31), "2026-02": (1, 28),
    "2026-03": (1, 31), "2026-04": (1, 30), "2026-05": (1, 31),
    "2026-06": (1, 4),
}
