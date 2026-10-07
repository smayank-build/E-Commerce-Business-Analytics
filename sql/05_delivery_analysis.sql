-- ============================================================
-- FILE: 05_delivery_analysis.sql
-- PURPOSE: Supply chain performance & delay root cause analysis
-- Techniques: CTEs, CASE WHEN, DATEDIFF, Window Functions
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── 1. OVERALL DELIVERY PERFORMANCE ───────────────────────
SELECT
    COUNT(*)                                            AS total_delivered,
    ROUND(AVG(DATEDIFF(
        order_delivered_customer_date,
        order_purchase_timestamp)), 1)                  AS avg_delivery_days,
    ROUND(AVG(DATEDIFF(
        order_estimated_delivery_date,
        order_delivered_customer_date)), 1)             AS avg_days_vs_estimate,
    SUM(CASE WHEN order_delivered_customer_date
             > order_estimated_delivery_date
             THEN 1 ELSE 0 END)                         AS late_orders,
    ROUND(SUM(CASE WHEN order_delivered_customer_date
                   > order_estimated_delivery_date
                   THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2)                                AS late_order_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- ── 2. DELIVERY SEGMENTS — ON TIME vs LATE ────────────────
WITH delivery_status AS (
    SELECT
        order_id,
        DATEDIFF(order_delivered_customer_date,
                 order_purchase_timestamp)              AS actual_days,
        DATEDIFF(order_estimated_delivery_date,
                 order_purchase_timestamp)              AS estimated_days,
        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date       THEN 'On Time'
            WHEN DATEDIFF(order_delivered_customer_date,
                          order_estimated_delivery_date) <= 3 THEN 'Slightly Late (1-3d)'
            WHEN DATEDIFF(order_delivered_customer_date,
                          order_estimated_delivery_date) <= 7 THEN 'Late (4-7d)'
            ELSE 'Very Late (7d+)'
        END                                             AS delivery_segment
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT
    delivery_segment,
    COUNT(*)                                            AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct,
    ROUND(AVG(actual_days), 1)                          AS avg_actual_days
FROM delivery_status
GROUP BY delivery_segment
ORDER BY order_count DESC;

-- ── 3. DELIVERY PERFORMANCE BY STATE ──────────────────────
-- Business Question: Which states have worst delivery times?
SELECT
    c.customer_state                                    AS state,
    COUNT(DISTINCT o.order_id)                          AS orders,
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp)), 1)                AS avg_delivery_days,
    SUM(CASE WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date
             THEN 1 ELSE 0 END)                         AS late_orders,
    ROUND(SUM(CASE WHEN o.order_delivered_customer_date
                   > o.order_estimated_delivery_date
                   THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2)                                AS late_rate_pct,
    RANK() OVER (ORDER BY AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp)) DESC)              AS worst_delivery_rank
FROM orders     o
JOIN customers  c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY state
ORDER BY avg_delivery_days DESC
LIMIT 15;

-- ── 4. SUPPLY CHAIN STAGE BREAKDOWN ───────────────────────
-- Where does time get lost: processing, shipping, or last mile?
SELECT
    ROUND(AVG(DATEDIFF(order_approved_at,
              order_purchase_timestamp)), 1)             AS avg_approval_days,
    ROUND(AVG(DATEDIFF(order_delivered_carrier_date,
              order_approved_at)), 1)                    AS avg_warehouse_days,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date,
              order_delivered_carrier_date)), 1)         AS avg_shipping_days,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date,
              order_purchase_timestamp)), 1)             AS avg_total_days
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at             IS NOT NULL
  AND order_delivered_carrier_date  IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- ── 5. CORRELATION: LATE DELIVERY vs REVIEW SCORE ─────────
-- Business Question: Does late delivery hurt ratings?
WITH delivery_flag AS (
    SELECT
        o.order_id,
        CASE WHEN o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
             THEN 'Late' ELSE 'On Time' END             AS delivery_status
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    d.delivery_status,
    ROUND(AVG(r.review_score), 2)                       AS avg_review_score,
    COUNT(*)                                            AS order_count
FROM delivery_flag  d
JOIN order_reviews  r ON d.order_id = r.order_id
GROUP BY d.delivery_status;
