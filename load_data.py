"""
load_data.py — Load Olist CSV files into MySQL olist_ecommerce database.
"""

import os
import pandas as pd
import mysql.connector
from mysql.connector import Error

# ── Connection settings ────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "port":     3306,
    "user":     "root",
    "password": "Suhas@1710",
    "database": "olist_ecommerce",
    "allow_local_infile": True,
}

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

# CSV file → table name mapping
FILE_TABLE_MAP = [
    ("olist_customers_dataset.csv",          "customers"),
    ("olist_sellers_dataset.csv",            "sellers"),
    ("olist_products_dataset.csv",           "products"),
    ("product_category_name_translation.csv","product_category_translation"),
    ("olist_orders_dataset.csv",             "orders"),
    ("olist_order_items_dataset.csv",        "order_items"),
    ("olist_order_payments_dataset.csv",     "order_payments"),
    ("olist_order_reviews_dataset.csv",      "order_reviews"),
]

# Columns to keep per table (matches schema exactly)
TABLE_COLUMNS = {
    "customers": [
        "customer_id", "customer_unique_id", "customer_zip_code_prefix",
        "customer_city", "customer_state",
    ],
    "sellers": [
        "seller_id", "seller_zip_code_prefix", "seller_city", "seller_state",
    ],
    "products": [
        "product_id", "product_category_name", "product_name_lenght",
        "product_description_lenght", "product_photos_qty",
        "product_weight_g", "product_length_cm", "product_height_cm",
        "product_width_cm",
    ],
    "product_category_translation": [
        "product_category_name", "product_category_name_english",
    ],
    "orders": [
        "order_id", "customer_id", "order_status",
        "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
    "order_items": [
        "order_id", "order_item_id", "product_id", "seller_id",
        "shipping_limit_date", "price", "freight_value",
    ],
    "order_payments": [
        "order_id", "payment_sequential", "payment_type",
        "payment_installments", "payment_value",
    ],
    "order_reviews": [
        "review_id", "order_id", "review_score", "review_comment_title",
        "review_comment_message", "review_creation_date",
        "review_answer_timestamp",
    ],
}

# Rename CSV columns to DB column names where they differ
COLUMN_RENAMES = {
    "customers": {"customer_zip_code_prefix": "customer_zip_code"},
    "sellers":   {"seller_zip_code_prefix": "seller_zip_code"},
    "products":  {
        "product_name_lenght":        "product_name_length",
        "product_description_lenght": "product_description_length",
    },
}


def load_table(cursor, conn, csv_file, table):
    path = os.path.join(DATA_DIR, csv_file)
    if not os.path.exists(path):
        print(f"  [SKIP] {csv_file} not found — skipping {table}")
        return

    df = pd.read_csv(path, dtype=str, keep_default_na=False)

    # Keep only the columns that exist in the schema
    schema_cols = TABLE_COLUMNS.get(table, [])
    existing = [c for c in schema_cols if c in df.columns]
    df = df[existing].copy()

    # Rename CSV column names to DB column names
    renames = COLUMN_RENAMES.get(table, {})
    df.rename(columns=renames, inplace=True)

    # Replace empty strings with None so MySQL gets NULL
    df.replace("", None, inplace=True)

    if df.empty:
        print(f"  [WARN] {csv_file} is empty — skipping {table}")
        return

    placeholders = ", ".join(["%s"] * len(df.columns))
    cols = ", ".join(df.columns)
    sql = f"INSERT IGNORE INTO {table} ({cols}) VALUES ({placeholders})"

    rows = [tuple(r) for r in df.itertuples(index=False, name=None)]
    cursor.executemany(sql, rows)
    conn.commit()
    print(f"  [OK] {table:<30} {cursor.rowcount:>7} rows inserted  (file: {csv_file})")


def main():
    print("Connecting to MySQL …")
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("Connected.\n")
    except Error as e:
        print(f"Connection failed: {e}")
        return

    print("Loading tables …\n")
    for csv_file, table in FILE_TABLE_MAP:
        try:
            load_table(cursor, conn, csv_file, table)
        except Error as e:
            print(f"  [ERROR] {table}: {e}")

    print("\nVerification — row counts:")
    verification_sql = """
        SELECT 'orders'          AS tbl, COUNT(*) AS row_count FROM orders         UNION ALL
        SELECT 'customers',               COUNT(*)              FROM customers       UNION ALL
        SELECT 'order_items',             COUNT(*)              FROM order_items     UNION ALL
        SELECT 'products',                COUNT(*)              FROM products        UNION ALL
        SELECT 'sellers',                 COUNT(*)              FROM sellers         UNION ALL
        SELECT 'order_payments',          COUNT(*)              FROM order_payments  UNION ALL
        SELECT 'order_reviews',           COUNT(*)              FROM order_reviews
    """
    cursor.execute(verification_sql)
    print(f"\n  {'Table':<25} {'Row Count':>10}")
    print("  " + "-" * 37)
    for tbl, cnt in cursor.fetchall():
        print(f"  {tbl:<25} {cnt:>10,}")

    cursor.close()
    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
