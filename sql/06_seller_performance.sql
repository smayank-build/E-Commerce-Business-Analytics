-- ============================================================
-- FILE: 06_seller_performance.sql
-- PURPOSE: Seller KPI scorecard and ranking
-- Techniques: CTEs, RANK/DENSE_RANK, CASE WHEN, Multi-table JOIN
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

-- ── 1. SELLER SCORECARD (Full KPI View) ───────────────────
WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                     AS total_orders,
        ROUND(SUM(oi.price), 2)                         AS total_revenue,
        ROUND(AVG(oi.price), 2)                         AS avg_order_value,
        ROUND(AVG(r.review_score), 2)                   AS avg_rating,
        SUM(CASE WHEN o.order_status = 'canceled'
                 THEN 1 ELSE 0 END)                     AS canceled_orders,
        ROUND(SUM(CASE WHEN o.order_status = 'canceled'
                       THEN 1 ELSE 0 END) * 100.0
              / COUNT(DISTINCT oi.order_id), 2)         AS cancellation_rate,
        SUM(CASE WHEN o.order_delivered_customer_date
                      > o.order_estimated_delivery_date
                 THEN 1 ELSE 0 END)                     AS late_deliveries
    FROM order_items    oi
    JOIN orders         o  ON oi.order_id  = o.order_id
    JOIN sellers        s  ON oi.seller_id = s.seller_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY oi.seller_id, s.seller_state
)
SELECT
    seller_id,
    seller_state,
    total_orders,
    total_revenue,
    avg_order_value,
    avg_rating,
    cancellation_rate,
    late_deliveries,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC)     AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY avg_rating DESC)        AS rating_rank,
    DENSE_RANK() OVER (ORDER BY cancellation_rate ASC)  AS reliability_rank,
    CASE
        WHEN total_revenue > 50000 AND avg_rating >= 4.0
             AND cancellation_rate < 5             THEN 'Top Performer'
        WHEN total_revenue > 20000 AND avg_rating >= 3.5 THEN 'Good Performer'
        WHEN cancellation_rate > 15 OR avg_rating < 3.0  THEN 'Underperformer'
        ELSE 'Average'
    END                                                 AS performance_tier
FROM seller_metrics
ORDER BY total_revenue DESC
LIMIT 50;

-- ── 2. PERFORMANCE TIER SUMMARY ───────────────────────────
WITH seller_metrics AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id)                     AS total_orders,
        ROUND(SUM(oi.price), 2)                         AS total_revenue,
        ROUND(AVG(r.review_score), 2)                   AS avg_rating,
        ROUND(SUM(CASE WHEN o.order_status = 'canceled'
                       THEN 1 ELSE 0 END) * 100.0
              / COUNT(DISTINCT oi.order_id), 2)         AS cancellation_rate
    FROM order_items    oi
    JOIN orders         o  ON oi.order_id  = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY oi.seller_id
),
tiered AS (
    SELECT *,
        CASE
            WHEN total_revenue > 50000 AND avg_rating >= 4.0
                 AND cancellation_rate < 5             THEN 'Top Performer'
            WHEN total_revenue > 20000 AND avg_rating >= 3.5 THEN 'Good Performer'
            WHEN cancellation_rate > 15 OR avg_rating < 3.0  THEN 'Underperformer'
            ELSE 'Average'
        END                                             AS performance_tier
    FROM seller_metrics
)
SELECT
    performance_tier,
    COUNT(*)                                            AS seller_count,
    ROUND(AVG(cancellation_rate), 2)                    AS avg_cancellation_rate,
    ROUND(AVG(avg_rating), 2)                           AS avg_review_score,
    ROUND(SUM(total_revenue), 2)                        AS total_revenue,
    ROUND(SUM(total_revenue) * 100.0 /
          SUM(SUM(total_revenue)) OVER(), 2)            AS pct_revenue
FROM tiered
GROUP BY performance_tier
ORDER BY total_revenue DESC;

-- ── 3. TOP 10 vs BOTTOM 10 SELLERS COMPARISON ─────────────
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price), 2)                         AS revenue,
        COUNT(DISTINCT oi.order_id)                     AS orders,
        ROUND(AVG(r.review_score), 2)                   AS avg_rating,
        ROUND(SUM(CASE WHEN o.order_status = 'canceled'
                       THEN 1 ELSE 0 END) * 100.0
              / COUNT(DISTINCT oi.order_id), 2)         AS cancellation_rate,
        ROW_NUMBER() OVER (ORDER BY SUM(oi.price) DESC) AS rn_top,
        ROW_NUMBER() OVER (ORDER BY SUM(oi.price) ASC)  AS rn_bottom
    FROM order_items    oi
    JOIN orders         o  ON oi.order_id  = o.order_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY oi.seller_id
    HAVING orders >= 10  -- exclude very small sellers
)
SELECT
    CASE WHEN rn_top   <= 10 THEN 'Top 10'
         WHEN rn_bottom<= 10 THEN 'Bottom 10'
    END                                                 AS seller_group,
    seller_id,
    revenue,
    orders,
    avg_rating,
    cancellation_rate
FROM seller_revenue
WHERE rn_top <= 10 OR rn_bottom <= 10
ORDER BY seller_group, revenue DESC;
