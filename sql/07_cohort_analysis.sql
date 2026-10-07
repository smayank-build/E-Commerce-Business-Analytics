-- ============================================================
-- FILE: 07_cohort_analysis.sql
-- PURPOSE: Customer cohort retention analysis
-- Techniques: CTEs (chained 4-level), DATE_FORMAT, Window Functions
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── COHORT RETENTION TABLE ─────────────────────────────────
-- Step 1: Find each customer's first purchase month (cohort)
WITH first_purchase AS (
    SELECT
        c.customer_unique_id                            AS customer_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp,
                        '%Y-%m'))                       AS cohort_month
    FROM orders     o
    JOIN customers  c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- Step 2: Get all orders with their month
all_orders AS (
    SELECT
        c.customer_unique_id                            AS customer_id,
        DATE_FORMAT(o.order_purchase_timestamp,
                    '%Y-%m')                            AS order_month
    FROM orders     o
    JOIN customers  c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

-- Step 3: Join to get cohort_month and calculate month number
cohort_data AS (
    SELECT
        f.cohort_month,
        a.order_month,
        a.customer_id,
        -- Month index: 0 = first purchase, 1 = returned after 1 month, etc.
        PERIOD_DIFF(
            REPLACE(a.order_month, '-', ''),
            REPLACE(f.cohort_month, '-', '')
        ) AS month_index
    FROM all_orders     a
    JOIN first_purchase f ON a.customer_id = f.customer_id
),

-- Step 4: Count unique customers per cohort per month_index
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id)                     AS cohort_customers
    FROM cohort_data
    WHERE month_index = 0
    GROUP BY cohort_month
)

-- Final: Retention Rate Table
SELECT
    cd.cohort_month,
    cs.cohort_customers,
    cd.month_index,
    COUNT(DISTINCT cd.customer_id)                      AS active_customers,
    ROUND(COUNT(DISTINCT cd.customer_id) * 100.0
          / cs.cohort_customers, 2)                     AS retention_rate_pct
FROM cohort_data    cd
JOIN cohort_size    cs ON cd.cohort_month = cs.cohort_month
WHERE cd.month_index <= 6   -- show first 6 months of retention
GROUP BY cd.cohort_month, cs.cohort_customers, cd.month_index
ORDER BY cd.cohort_month, cd.month_index;


-- ── AVERAGE RETENTION BY MONTH INDEX ──────────────────────
-- Quick summary: What % of customers return in month 1, 2, 3...
WITH first_purchase AS (
    SELECT c.customer_unique_id AS customer_id,
           MIN(DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m')) AS cohort_month
    FROM orders o JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
all_orders AS (
    SELECT c.customer_unique_id AS customer_id,
           DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS order_month
    FROM orders o JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
cohort_data AS (
    SELECT f.cohort_month, a.customer_id,
           PERIOD_DIFF(
               REPLACE(a.order_month, '-', ''),
               REPLACE(f.cohort_month, '-', '')
           ) AS month_index
    FROM all_orders a JOIN first_purchase f ON a.customer_id = f.customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
    FROM cohort_data WHERE month_index = 0
    GROUP BY cohort_month
),
monthly_retention AS (
    SELECT
        cd.month_index,
        cd.cohort_month,
        COUNT(DISTINCT cd.customer_id) * 100.0 / cs.cohort_customers AS retention_pct
    FROM cohort_data    cd
    JOIN cohort_size    cs ON cd.cohort_month = cs.cohort_month
    WHERE cd.month_index BETWEEN 1 AND 6
    GROUP BY cd.month_index, cd.cohort_month, cs.cohort_customers
)
SELECT
    month_index,
    ROUND(AVG(retention_pct), 2)                        AS avg_retention_pct
FROM monthly_retention
GROUP BY month_index
ORDER BY month_index;
