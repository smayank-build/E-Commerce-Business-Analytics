"""
run_analysis.py — Execute all SQL analysis files and save results to results/.
Also prints key business metrics at the end.
"""

import os
import re
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
}

BASE_DIR    = os.path.dirname(__file__)
RESULTS_DIR = os.path.join(BASE_DIR, "results")
os.makedirs(RESULTS_DIR, exist_ok=True)

# SQL file → output CSV prefix mapping
SQL_FILES = [
    ("sql/02_data_exploration.sql", "02_exploration"),
    ("sql/03_revenue_analysis.sql", "03_revenue"),
    ("sql/04_customer_rfm.sql",     "04_rfm_segments"),
    ("sql/05_delivery_analysis.sql","05_delivery"),
    ("sql/06_seller_performance.sql","06_sellers"),
    ("sql/07_cohort_analysis.sql",  "07_cohort"),
]


def parse_statements(sql_text):
    """Split a SQL file into individual executable statements."""
    # Remove single-line comments
    sql_text = re.sub(r"--[^\n]*", "", sql_text)
    # Remove USE statements (already connected to the DB)
    sql_text = re.sub(r"USE\s+\w+\s*;", "", sql_text, flags=re.IGNORECASE)
    # Split on semicolons
    raw = sql_text.split(";")
    stmts = []
    for s in raw:
        s = s.strip()
        if s and re.search(r"\bSELECT\b", s, re.IGNORECASE):
            stmts.append(s)
    return stmts


def run_file(cursor, sql_path, output_prefix):
    full_path = os.path.join(BASE_DIR, sql_path)
    if not os.path.exists(full_path):
        print(f"  [SKIP] {sql_path} not found")
        return []

    with open(full_path, encoding="utf-8") as f:
        sql_text = f.read()

    statements = parse_statements(sql_text)
    saved_files = []

    for i, stmt in enumerate(statements, start=1):
        try:
            cursor.execute(stmt)
            rows = cursor.fetchall()
            if rows and cursor.description:
                cols = [d[0] for d in cursor.description]
                df   = pd.DataFrame(rows, columns=cols)
                out  = os.path.join(RESULTS_DIR, f"{output_prefix}_q{i}.csv")
                df.to_csv(out, index=False)
                saved_files.append((out, df))
                print(f"    Query {i}: {len(df):>6} rows  -> {os.path.basename(out)}")
            else:
                print(f"    Query {i}: no rows returned")
        except Error as e:
            print(f"    Query {i}: ERROR — {e}")

    return saved_files


def run_single_query(cursor, sql):
    """Run one SELECT and return a DataFrame, or None on error."""
    try:
        cursor.execute(sql)
        rows = cursor.fetchall()
        if rows and cursor.description:
            cols = [d[0] for d in cursor.description]
            return pd.DataFrame(rows, columns=cols)
    except Error as e:
        print(f"  [ERROR] {e}")
    return None


def print_key_answers(cursor):
    print("\n" + "=" * 60)
    print("  KEY BUSINESS ANSWERS")
    print("=" * 60)

    # 1. Total revenue
    df = run_single_query(cursor, """
        SELECT ROUND(SUM(payment_value), 2) AS total_revenue
        FROM order_payments
    """)
    if df is not None:
        print(f"\n1. Total revenue in dataset:  R$ {df['total_revenue'].iloc[0]:,.2f}")

    # 2. Top 3 product categories by revenue
    df = run_single_query(cursor, """
        SELECT
            COALESCE(t.product_category_name_english,
                     p.product_category_name, 'Unknown') AS category,
            ROUND(SUM(oi.price), 2)                      AS revenue
        FROM order_items oi
        JOIN products    p ON oi.product_id = p.product_id
        LEFT JOIN product_category_translation t
               ON p.product_category_name = t.product_category_name
        GROUP BY category
        ORDER BY revenue DESC
        LIMIT 3
    """)
    if df is not None:
        print("\n2. Top 3 categories by revenue:")
        for _, row in df.iterrows():
            print(f"      {row['category']:<35} R$ {row['revenue']:>12,.2f}")

    # 3. Champions RFM count
    df = run_single_query(cursor, """
        WITH rfm_base AS (
            SELECT
                c.customer_unique_id                            AS customer_id,
                DATEDIFF(
                    (SELECT MAX(order_purchase_timestamp) FROM orders),
                    MAX(o.order_purchase_timestamp))            AS recency_days,
                COUNT(DISTINCT o.order_id)                      AS frequency,
                ROUND(SUM(p.payment_value), 2)                  AS monetary
            FROM orders o
            JOIN customers      c ON o.customer_id = c.customer_id
            JOIN order_payments p ON o.order_id    = p.order_id
            WHERE o.order_status = 'delivered'
            GROUP BY c.customer_unique_id
        ),
        rfm_scores AS (
            SELECT *,
                NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
                NTILE(5) OVER (ORDER BY frequency    ASC)   AS f_score,
                NTILE(5) OVER (ORDER BY monetary     ASC)   AS m_score
            FROM rfm_base
        )
        SELECT COUNT(*) AS champions
        FROM rfm_scores
        WHERE r_score >= 4 AND f_score >= 4 AND m_score >= 4
    """)
    if df is not None:
        print(f"\n3. Customers in 'Champions' RFM segment:  {df['champions'].iloc[0]:,}")

    # 4 & 5. Average delivery time + % late orders
    df = run_single_query(cursor, """
        SELECT
            ROUND(AVG(DATEDIFF(
                order_delivered_customer_date,
                order_purchase_timestamp)), 1)              AS avg_delivery_days,
            ROUND(SUM(CASE WHEN order_delivered_customer_date
                           > order_estimated_delivery_date
                           THEN 1 ELSE 0 END) * 100.0
                  / COUNT(*), 2)                            AS late_order_pct
        FROM orders
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NOT NULL
    """)
    if df is not None:
        print(f"\n4. Average delivery time:     {df['avg_delivery_days'].iloc[0]} days")
        print(f"5. Orders delivered late:     {df['late_order_pct'].iloc[0]}%")

    print("\n" + "=" * 60)


def main():
    print("Connecting to MySQL …")
    try:
        conn   = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("Connected.\n")
    except Error as e:
        print(f"Connection failed: {e}")
        return

    all_results = {}
    for sql_path, prefix in SQL_FILES:
        print(f"\nRunning {sql_path} …")
        results = run_file(cursor, sql_path, prefix)
        all_results[prefix] = results

    print_key_answers(cursor)

    cursor.close()
    conn.close()

    print(f"\nAll result CSVs saved to: {RESULTS_DIR}")


if __name__ == "__main__":
    main()
