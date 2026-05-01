import os
import random
import sys
import time
import uuid
from datetime import datetime, timedelta

import pyarrow as pa
import pyarrow.parquet as pq

from config import (
    TOTAL_ORDERS, NUM_CUSTOMERS, NUM_REVIEWS, NUM_TICKETS,
    MONTHLY_CONFIG, STATUS_DISTRIBUTION, SEGMENT_AOV_MULTIPLIER,
    MONTH_DAYS, PRODUCTS, CATEGORY_WEIGHTS_BY_SEASON,
)

SEED = 42
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")
ORDERS_CHUNK_SIZE = 5_000_000
ITEMS_PER_ORDERS_CHUNK = True

ORDERS_SCHEMA = pa.schema([
    ("order_id", pa.string()),
    ("customer_id", pa.int32()),
    ("order_date", pa.string()),
    ("order_status", pa.string()),
    ("total_amount", pa.float64()),
    ("discount_percent", pa.float64()),
    ("shipping_cost", pa.float64()),
])

ITEMS_SCHEMA = pa.schema([
    ("order_item_id", pa.string()),
    ("order_id", pa.string()),
    ("product_id", pa.int32()),
    ("product_name", pa.string()),
    ("product_category", pa.string()),
    ("quantity", pa.int32()),
    ("unit_price", pa.float64()),
    ("line_total", pa.float64()),
])

CUSTOMERS_SCHEMA = pa.schema([
    ("customer_id", pa.int32()),
    ("first_name", pa.string()),
    ("last_name", pa.string()),
    ("email", pa.string()),
    ("phone", pa.string()),
    ("address", pa.string()),
    ("city", pa.string()),
    ("state", pa.string()),
    ("zip_code", pa.string()),
    ("registration_date", pa.string()),
    ("customer_segment", pa.string()),
])


def pick_weighted(choices_weights):
    items = list(choices_weights.keys())
    weights = list(choices_weights.values())
    return random.choices(items, weights=weights, k=1)[0]


def get_products_by_category():
    by_cat = {}
    for p in PRODUCTS:
        by_cat.setdefault(p["category"], []).append(p)
    return by_cat


PRODUCTS_BY_CATEGORY = get_products_by_category()


def generate_customers(num_customers):
    random.seed(SEED)
    first_names = ["John", "Sarah", "Michael", "Emily", "David", "Jessica", "Chris", "Ashley",
                   "Matt", "Amanda", "Ryan", "Lauren", "Kevin", "Nicole", "Brian", "Rachel",
                   "Tyler", "Megan", "Josh", "Katie"]
    last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
                  "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
                  "Thomas", "Taylor", "Moore", "Jackson", "Martin"]
    cities = ["Denver", "Salt Lake City", "Boulder", "Aspen", "Park City", "Jackson",
              "Telluride", "Steamboat Springs", "Vail", "Breckenridge", "Mammoth Lakes",
              "Tahoe City", "Whistler", "Banff", "Portland"]
    states = ["CO", "UT", "WY", "CA", "WA", "OR", "MT", "ID", "NV", "BC"]
    segments = ["Premium", "Standard", "Basic"]

    data = {k: [] for k in CUSTOMERS_SCHEMA.names}

    for i in range(1, num_customers + 1):
        state = random.choice(states)
        segment = random.choice(segments)
        reg_days_ago = random.randint(1, 1825)
        reg_date = (datetime(2026, 6, 4) - timedelta(days=reg_days_ago)).strftime("%Y-%m-%d")

        data["customer_id"].append(i)
        data["first_name"].append(random.choice(first_names))
        data["last_name"].append(random.choice(last_names))
        data["email"].append(f"customer{i}@email.com")
        data["phone"].append(f"555-{random.randint(100,999):03d}-{random.randint(1000,9999):04d}")
        data["address"].append(f"{random.randint(100,9999)} {random.choice(['Main St','Oak Ave','Maple Dr','Cedar Ln','Pine Rd','Elm St','Washington Blvd','Lake View Dr','Mountain Way','Summit Trail'])}")
        data["city"].append(random.choice(cities))
        data["state"].append(state)
        data["zip_code"].append(f"{random.randint(10000,99999)}")
        data["registration_date"].append(reg_date)
        data["customer_segment"].append(segment)

    return data


def generate_orders_and_items_chunked(customer_segments, parquet_dir):
    random.seed(SEED + 1)

    months = list(MONTHLY_CONFIG.keys())
    total_generated = 0
    chunk_idx = 0

    orders_buf = {k: [] for k in ORDERS_SCHEMA.names}
    items_buf = {k: [] for k in ITEMS_SCHEMA.names}
    orders_in_buf = 0
    total_items = 0

    for month_key in months:
        cfg = MONTHLY_CONFIG[month_key]
        month_order_count = int(TOTAL_ORDERS * cfg["volume_pct"])
        year, month_num = month_key.split("-")
        year, month_num = int(year), int(month_num)
        start_day, end_day = MONTH_DAYS[month_key]

        season = cfg["season"]
        status_dist = STATUS_DISTRIBUTION.get("crash" if season == "crash" else "normal")
        seg_weights = cfg["segment_weights"]
        discount_lo, discount_hi = cfg["discount_range"]
        items_lo, items_hi = cfg["items_range"]
        cat_weights = CATEGORY_WEIGHTS_BY_SEASON[season]
        categories = list(cat_weights.keys())
        weights = list(cat_weights.values())

        for _ in range(month_order_count):
            oid = str(uuid.uuid4())

            seg_roll = random.random()
            if seg_roll < seg_weights[0]:
                segment = "Premium"
            elif seg_roll < seg_weights[0] + seg_weights[1]:
                segment = "Standard"
            else:
                segment = "Basic"

            customer_id = random.choice(customer_segments[segment])
            day = random.randint(start_day, end_day)
            hour = random.randint(0, 23)
            minute = random.randint(0, 59)
            second = random.randint(0, 59)
            order_date = datetime(year, month_num, day, hour, minute, second)

            order_status = pick_weighted(status_dist)

            base_amount = random.uniform(50, 800)
            aov_mult = SEGMENT_AOV_MULTIPLIER[segment]
            if season == "peak":
                aov_mult *= random.uniform(1.1, 1.4)
            elif season == "clearance":
                aov_mult *= random.uniform(0.6, 0.85)
            total_amount = round(base_amount * aov_mult, 2)

            if segment == "Premium":
                discount = round(random.uniform(max(0, discount_lo - 3), discount_hi - 2), 2)
            elif segment == "Basic":
                discount = round(random.uniform(discount_lo + 2, min(50, discount_hi + 5)), 2)
            else:
                discount = round(random.uniform(discount_lo, discount_hi), 2)
            if random.random() > 0.6:
                discount = 0.0

            shipping = round(random.uniform(5, 35), 2)

            orders_buf["order_id"].append(oid)
            orders_buf["customer_id"].append(customer_id)
            orders_buf["order_date"].append(order_date.strftime("%Y-%m-%d %H:%M:%S"))
            orders_buf["order_status"].append(order_status)
            orders_buf["total_amount"].append(total_amount)
            orders_buf["discount_percent"].append(discount)
            orders_buf["shipping_cost"].append(shipping)

            if segment == "Premium":
                num_items = random.randint(items_lo, items_hi + 1)
            elif segment == "Basic":
                num_items = random.randint(max(1, items_lo - 1), items_hi)
            else:
                num_items = random.randint(items_lo, items_hi)

            chosen_categories = random.choices(categories, weights=weights, k=num_items)
            for cat in chosen_categories:
                product = random.choice(PRODUCTS_BY_CATEGORY[cat])
                quantity = 1
                if segment == "Premium" and random.random() < 0.15:
                    quantity = random.randint(2, 3)
                elif segment == "Basic" and random.random() < 0.05:
                    quantity = 2
                price_variance = random.uniform(0.9, 1.1)
                unit_price = round(product["price"] * price_variance, 2)
                line_total = round(unit_price * quantity, 2)

                items_buf["order_item_id"].append(str(uuid.uuid4()))
                items_buf["order_id"].append(oid)
                items_buf["product_id"].append(product["id"])
                items_buf["product_name"].append(product["name"])
                items_buf["product_category"].append(product["category"])
                items_buf["quantity"].append(quantity)
                items_buf["unit_price"].append(unit_price)
                items_buf["line_total"].append(line_total)
                total_items += 1

            orders_in_buf += 1
            total_generated += 1

            if orders_in_buf >= ORDERS_CHUNK_SIZE:
                chunk_idx += 1
                flush_chunk(parquet_dir, chunk_idx, orders_buf, items_buf)
                orders_buf = {k: [] for k in ORDERS_SCHEMA.names}
                items_buf = {k: [] for k in ITEMS_SCHEMA.names}
                orders_in_buf = 0
                print(f"    Chunk {chunk_idx}: {total_generated:,} orders, {total_items:,} items so far")

    if orders_in_buf > 0:
        chunk_idx += 1
        flush_chunk(parquet_dir, chunk_idx, orders_buf, items_buf)
        print(f"    Chunk {chunk_idx}: {total_generated:,} orders, {total_items:,} items (final)")

    return total_generated, total_items


def flush_chunk(parquet_dir, chunk_idx, orders_buf, items_buf):
    orders_table = pa.table(orders_buf, schema=ORDERS_SCHEMA)
    items_table = pa.table(items_buf, schema=ITEMS_SCHEMA)

    orders_path = os.path.join(parquet_dir, f"orders_{chunk_idx:03d}.parquet")
    items_path = os.path.join(parquet_dir, f"order_items_{chunk_idx:03d}.parquet")

    pq.write_table(orders_table, orders_path, compression="snappy")
    pq.write_table(items_table, items_path, compression="snappy")


def main():
    random.seed(SEED)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    parquet_dir = os.path.join(OUTPUT_DIR, "parquet")
    os.makedirs(parquet_dir, exist_ok=True)

    print("=" * 60)
    print("HOL Seed Data Generator (50M orders — Parquet)")
    print("=" * 60)

    print(f"\n[1/5] Generating {NUM_CUSTOMERS:,} customers...")
    t0 = time.time()
    cust_data = generate_customers(NUM_CUSTOMERS)
    cust_table = pa.table(cust_data, schema=CUSTOMERS_SCHEMA)
    cust_path = os.path.join(parquet_dir, "customers.parquet")
    pq.write_table(cust_table, cust_path, compression="snappy")
    print(f"  Done: {NUM_CUSTOMERS:,} customers ({time.time()-t0:.1f}s)")
    print(f"  File: {cust_path} ({os.path.getsize(cust_path)/1024/1024:.1f} MB)")

    customer_segments = {"Premium": [], "Standard": [], "Basic": []}
    for i, seg in enumerate(cust_data["customer_segment"]):
        customer_segments[seg].append(cust_data["customer_id"][i])
    del cust_data, cust_table

    print(f"\n[2/5] Generating {TOTAL_ORDERS:,} orders + items (chunked Parquet)...")
    t0 = time.time()
    total_orders, total_items = generate_orders_and_items_chunked(customer_segments, parquet_dir)
    elapsed = time.time() - t0
    print(f"  Done: {total_orders:,} orders, {total_items:,} items ({elapsed:.1f}s)")

    print(f"\n[3/5] Generating {NUM_REVIEWS:,} product reviews (CSV)...")
    t0 = time.time()
    from reviews_generator import generate_reviews
    all_cust_ids = list(range(1, NUM_CUSTOMERS + 1))
    reviews = generate_reviews(all_cust_ids)
    write_csv(os.path.join(OUTPUT_DIR, "product_reviews.csv"), reviews,
              ["review_id", "product_id", "customer_id", "review_date", "rating", "review_title", "review_text", "verified_purchase"])
    print(f"  Done: {len(reviews):,} reviews ({time.time()-t0:.1f}s)")

    print(f"\n[4/5] Generating {NUM_TICKETS:,} support tickets (CSV)...")
    t0 = time.time()
    from tickets_generator import generate_tickets
    tickets = generate_tickets(all_cust_ids)
    write_csv(os.path.join(OUTPUT_DIR, "support_tickets.csv"), tickets,
              ["ticket_id", "customer_id", "ticket_date", "category", "priority", "subject", "description", "resolution", "status"])
    print(f"  Done: {len(tickets):,} tickets ({time.time()-t0:.1f}s)")

    print(f"\n[5/5] Writing product catalog (CSV)...")
    write_csv(os.path.join(OUTPUT_DIR, "product_catalog.csv"), PRODUCTS,
              ["id", "name", "category", "price"],
              rename={"id": "product_id", "name": "product_name", "category": "product_category", "price": "price"})

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Orders:      {total_orders:,}")
    print(f"  Order Items: {total_items:,}")
    print(f"  Customers:   {NUM_CUSTOMERS:,}")
    print(f"  Reviews:     {len(reviews):,}")
    print(f"  Tickets:     {len(tickets):,}")

    parquet_files = [f for f in os.listdir(parquet_dir) if f.endswith('.parquet')]
    total_size = sum(os.path.getsize(os.path.join(parquet_dir, f)) for f in parquet_files)
    print(f"\n  Parquet files: {len(parquet_files)}")
    print(f"  Total size:    {total_size/1024/1024/1024:.2f} GB")
    print(f"\n  Output: {OUTPUT_DIR}")
    print("=" * 60)


def write_csv(path, data, fields, rename=None):
    import csv
    with open(path, "w", newline="", encoding="utf-8") as f:
        if rename:
            writer = csv.DictWriter(f, fieldnames=list(rename.values()), quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            for row in data:
                writer.writerow({rename[k]: row[k] for k in fields})
        else:
            writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore", quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            for row in data:
                writer.writerow(row)
    size_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"    {os.path.basename(path)}: {len(data):,} rows ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
