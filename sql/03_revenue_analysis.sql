-- ============================================================
-- FILE: 03_revenue_analysis.sql
-- PURPOSE: Revenue trends, Pareto analysis, MoM growth
-- Techniques: CTEs, Window Functions (SUM OVER, LAG), RANK
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── 1. MONTHLY REVENUE TREND WITH MoM GROWTH ──────────────
-- Technique: CTE + LAG window function
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        ROUND(SUM(p.payment_value), 2)                   AS revenue,
        COUNT(DISTINCT o.order_id)                       AS orders
    FROM orders         o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT
    month,
    revenue,
    orders,
    LAG(revenue) OVER (ORDER BY month)  AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100,
    2)                                  AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-- ── 2. PARETO ANALYSIS — 80/20 RULE ON CATEGORIES ─────────
-- Technique: CTE + Cumulative SUM window function + CASE WHEN
WITH category_revenue AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 p.product_category_name, 'Unknown')    AS category,
        ROUND(SUM(oi.price), 2)                         AS revenue
    FROM order_items    oi
    JOIN products       p  ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
                           ON p.product_category_name = t.product_category_name
    GROUP BY category
),
ranked AS (
    SELECT
        category,
        revenue,
        RANK() OVER (ORDER BY revenue DESC)             AS revenue_rank,
        ROUND(
            SUM(revenue) OVER (ORDER BY revenue DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            / SUM(revenue) OVER () * 100,
        2)                                              AS cumulative_pct
    FROM category_revenue
)
SELECT
    revenue_rank,
    category,
    revenue,
    cumulative_pct,
    CASE WHEN cumulative_pct <= 80 THEN 'TOP 80%' ELSE 'TAIL 20%' END AS pareto_segment
FROM ranked
ORDER BY revenue_rank
LIMIT 30;

-- ── 3. QUARTERLY REVENUE BREAKDOWN ────────────────────────
SELECT
    YEAR(o.order_purchase_timestamp)                    AS year,
    QUARTER(o.order_purchase_timestamp)                 AS quarter,
    ROUND(SUM(p.payment_value), 2)                      AS revenue,
    COUNT(DISTINCT o.order_id)                          AS orders,
    ROUND(SUM(p.payment_value) /
          COUNT(DISTINCT o.order_id), 2)                AS avg_order_value
FROM orders         o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY year, quarter
ORDER BY year, quarter;

-- ── 4. REVENUE BY STATE — TOP 10 ──────────────────────────
SELECT
    c.customer_state                            AS state,
    COUNT(DISTINCT o.order_id)                  AS orders,
    ROUND(SUM(p.payment_value), 2)              AS revenue,
    ROUND(AVG(p.payment_value), 2)              AS avg_order_value,
    DENSE_RANK() OVER (ORDER BY SUM(p.payment_value) DESC) AS revenue_rank
FROM orders         o
JOIN customers      c ON o.customer_id  = c.customer_id
JOIN order_payments p ON o.order_id     = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY state
ORDER BY revenue DESC
LIMIT 10;

-- ── 5. WEEKEND vs WEEKDAY ORDER PATTERNS ──────────────────
SELECT
    CASE WHEN DAYOFWEEK(order_purchase_timestamp) IN (1,7)
         THEN 'Weekend' ELSE 'Weekday' END              AS day_type,
    COUNT(*)                                            AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct
FROM orders
GROUP BY day_type;

-- ── 6. HOURLY ORDER DISTRIBUTION (PEAK HOURS) ─────────────
SELECT
    HOUR(order_purchase_timestamp)  AS hour_of_day,
    COUNT(*)                        AS order_count
FROM orders
GROUP BY hour_of_day
ORDER BY order_count DESC
LIMIT 5;
