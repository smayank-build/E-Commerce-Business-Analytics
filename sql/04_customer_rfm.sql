-- ============================================================
-- FILE: 04_customer_rfm.sql
-- PURPOSE: RFM Segmentation — identify high-value customers
-- Techniques: CTEs (chained), NTILE, CASE WHEN, Window Functions
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── STEP 1: CALCULATE RAW RFM METRICS PER CUSTOMER ────────
WITH rfm_base AS (
    SELECT
        c.customer_unique_id                                AS customer_id,
        DATEDIFF(
            (SELECT MAX(order_purchase_timestamp) FROM orders),
            MAX(o.order_purchase_timestamp)
        )                                                   AS recency_days,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        ROUND(SUM(p.payment_value), 2)                      AS monetary
    FROM orders         o
    JOIN customers      c ON o.customer_id = c.customer_id
    JOIN order_payments p ON o.order_id    = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

-- ── STEP 2: SCORE EACH DIMENSION 1-5 USING NTILE ──────────
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- Recency: lower days = better = score 5
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        -- Frequency: higher = better = score 5
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        -- Monetary: higher = better = score 5
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
),

-- ── STEP 3: COMBINE SCORES AND SEGMENT ────────────────────
rfm_segments AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CONCAT(r_score, f_score, m_score)           AS rfm_score,
        r_score + f_score + m_score                 AS total_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2
                THEN 'New Customers'
            WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 2
                THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4
                THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 3
                THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
                THEN 'Lost'
            ELSE 'Needs Attention'
        END                                         AS customer_segment
    FROM rfm_scores
)

-- ── STEP 4: SEGMENT SUMMARY FOR BUSINESS REPORTING ────────
SELECT
    customer_segment,
    COUNT(*)                                        AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_customers,
    ROUND(AVG(monetary), 2)                         AS avg_revenue,
    ROUND(SUM(monetary), 2)                         AS total_revenue,
    ROUND(SUM(monetary) * 100.0 /
          SUM(SUM(monetary)) OVER(), 2)             AS pct_revenue,
    ROUND(AVG(recency_days), 0)                     AS avg_recency_days,
    ROUND(AVG(frequency), 2)                        AS avg_frequency
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- ── BONUS: TOP 20 CHAMPION CUSTOMERS ─────────────────────
WITH rfm_base AS (
    SELECT
        c.customer_unique_id                                AS customer_id,
        DATEDIFF(
            (SELECT MAX(order_purchase_timestamp) FROM orders),
            MAX(o.order_purchase_timestamp)
        )                                                   AS recency_days,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        ROUND(SUM(p.payment_value), 2)                      AS monetary
    FROM orders         o
    JOIN customers      c ON o.customer_id = c.customer_id
    JOIN order_payments p ON o.order_id    = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    CONCAT(r_score, f_score, m_score)               AS rfm_score,
    ROW_NUMBER() OVER (ORDER BY monetary DESC)      AS value_rank
FROM rfm_scores
WHERE r_score >= 4 AND f_score >= 4 AND m_score >= 4
ORDER BY monetary DESC
LIMIT 20;
