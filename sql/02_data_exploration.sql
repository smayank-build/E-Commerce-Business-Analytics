-- ============================================================
-- FILE: 02_data_exploration.sql
-- PURPOSE: Initial data exploration and quality checks
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── 1. DATASET OVERVIEW ────────────────────────────────────
SELECT 'orders'    AS table_name, COUNT(*) AS row_count FROM orders     UNION ALL
SELECT 'customers',               COUNT(*)              FROM customers   UNION ALL
SELECT 'order_items',             COUNT(*)              FROM order_items UNION ALL
SELECT 'products',                COUNT(*)              FROM products    UNION ALL
SELECT 'sellers',                 COUNT(*)              FROM sellers     UNION ALL
SELECT 'order_payments',          COUNT(*)              FROM order_payments UNION ALL
SELECT 'order_reviews',           COUNT(*)              FROM order_reviews;

-- ── 2. DATE RANGE OF DATA ──────────────────────────────────
SELECT
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order,
    DATEDIFF(MAX(order_purchase_timestamp),
             MIN(order_purchase_timestamp)) AS days_of_data
FROM orders;

-- ── 3. ORDER STATUS DISTRIBUTION ──────────────────────────
SELECT
    order_status,
    COUNT(*)                            AS order_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER(), 2)      AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- ── 4. NULL / MISSING VALUE AUDIT ──────────────────────────
SELECT
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_delivery_date,
    SUM(CASE WHEN order_approved_at             IS NULL THEN 1 ELSE 0 END) AS missing_approval_date,
    SUM(CASE WHEN order_delivered_carrier_date  IS NULL THEN 1 ELSE 0 END) AS missing_carrier_date
FROM orders;

-- ── 5. REVENUE OVERVIEW ────────────────────────────────────
SELECT
    ROUND(SUM(payment_value), 2)        AS total_revenue,
    ROUND(AVG(payment_value), 2)        AS avg_order_value,
    ROUND(MIN(payment_value), 2)        AS min_order_value,
    ROUND(MAX(payment_value), 2)        AS max_order_value,
    COUNT(DISTINCT order_id)            AS total_orders
FROM order_payments;

-- ── 6. TOP 10 PRODUCT CATEGORIES BY ORDER COUNT ────────────
SELECT
    COALESCE(t.product_category_name_english,
             p.product_category_name, 'Unknown') AS category,
    COUNT(DISTINCT oi.order_id)                  AS order_count,
    ROUND(SUM(oi.price), 2)                      AS total_revenue
FROM order_items     oi
JOIN products        p  ON oi.product_id  = p.product_id
LEFT JOIN product_category_translation t
                        ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY order_count DESC
LIMIT 10;

-- ── 7. PAYMENT METHOD BREAKDOWN ───────────────────────────
SELECT
    payment_type,
    COUNT(*)                            AS usage_count,
    ROUND(AVG(payment_value), 2)        AS avg_value,
    ROUND(SUM(payment_value), 2)        AS total_value
FROM order_payments
GROUP BY payment_type
ORDER BY usage_count DESC;

-- ── 8. REVIEW SCORE DISTRIBUTION ──────────────────────────
SELECT
    review_score,
    COUNT(*)                            AS review_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER(), 2)      AS pct
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;
