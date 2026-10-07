-- ============================================================
-- FILE: 08_stored_procedures.sql
-- PURPOSE: Reusable stored procedures for business KPI reports
-- Techniques: Stored Procedures, Parameters, Dynamic SQL
-- Author: Suhas Dhamapurkar
-- ============================================================

USE olist_ecommerce;

DELIMITER $$

-- ── PROCEDURE 1: Monthly Revenue Report ───────────────────
-- Usage: CALL get_monthly_revenue('2017-01', '2017-12');
DROP PROCEDURE IF EXISTS get_monthly_revenue$$
CREATE PROCEDURE get_monthly_revenue(
    IN p_start_month VARCHAR(7),   -- format: 'YYYY-MM'
    IN p_end_month   VARCHAR(7)
)
BEGIN
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')    AS month,
        COUNT(DISTINCT o.order_id)                          AS total_orders,
        ROUND(SUM(p.payment_value), 2)                      AS total_revenue,
        ROUND(AVG(p.payment_value), 2)                      AS avg_order_value,
        COUNT(DISTINCT o.customer_id)                       AS unique_customers
    FROM orders         o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
          BETWEEN p_start_month AND p_end_month
    GROUP BY month
    ORDER BY month;
END$$

-- ── PROCEDURE 2: Category Performance Report ──────────────
-- Usage: CALL get_category_performance(10);
DROP PROCEDURE IF EXISTS get_category_performance$$
CREATE PROCEDURE get_category_performance(
    IN p_top_n INT    -- return top N categories
)
BEGIN
    SELECT
        COALESCE(t.product_category_name_english,
                 p.product_category_name, 'Unknown')        AS category,
        COUNT(DISTINCT oi.order_id)                         AS total_orders,
        ROUND(SUM(oi.price), 2)                             AS total_revenue,
        ROUND(AVG(oi.price), 2)                             AS avg_price,
        ROUND(AVG(r.review_score), 2)                       AS avg_rating
    FROM order_items    oi
    JOIN products       p  ON oi.product_id  = p.product_id
    LEFT JOIN product_category_translation t
                           ON p.product_category_name = t.product_category_name
    LEFT JOIN order_reviews r ON oi.order_id = r.order_id
    GROUP BY category
    ORDER BY total_revenue DESC
    LIMIT p_top_n;
END$$

-- ── PROCEDURE 3: Customer Segment Report ──────────────────
-- Usage: CALL get_customer_segment('Champions');
DROP PROCEDURE IF EXISTS get_customer_segment$$
CREATE PROCEDURE get_customer_segment(
    IN p_segment VARCHAR(50)   -- e.g. 'Champions', 'At Risk', 'Lost'
)
BEGIN
    WITH rfm_base AS (
        SELECT
            c.customer_unique_id                            AS customer_id,
            DATEDIFF(
                (SELECT MAX(order_purchase_timestamp) FROM orders),
                MAX(o.order_purchase_timestamp))            AS recency_days,
            COUNT(DISTINCT o.order_id)                      AS frequency,
            ROUND(SUM(p.payment_value), 2)                  AS monetary
        FROM orders         o
        JOIN customers      c ON o.customer_id = c.customer_id
        JOIN order_payments p ON o.order_id    = p.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    ),
    rfm_scores AS (
        SELECT *,
            NTILE(5) OVER (ORDER BY recency_days DESC)      AS r_score,
            NTILE(5) OVER (ORDER BY frequency ASC)          AS f_score,
            NTILE(5) OVER (ORDER BY monetary ASC)           AS m_score
        FROM rfm_base
    )
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        CONCAT(r_score, f_score, m_score)                   AS rfm_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2              THEN 'New Customers'
            WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 2 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 3              THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
            ELSE 'Needs Attention'
        END                                                 AS customer_segment
    FROM rfm_scores
    HAVING customer_segment = p_segment
    ORDER BY monetary DESC;
END$$

-- ── PROCEDURE 4: Seller Alert — Flag Underperformers ──────
-- Usage: CALL flag_underperforming_sellers(3.5, 10, 5);
DROP PROCEDURE IF EXISTS flag_underperforming_sellers$$
CREATE PROCEDURE flag_underperforming_sellers(
    IN p_min_rating         DECIMAL(3,1),  -- e.g. 3.5
    IN p_max_cancellation   INT,           -- e.g. 10 (percent)
    IN p_min_orders         INT            -- minimum orders to qualify
)
BEGIN
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id)                         AS total_orders,
        ROUND(AVG(r.review_score), 2)                       AS avg_rating,
        ROUND(SUM(CASE WHEN o.order_status = 'canceled'
                       THEN 1 ELSE 0 END) * 100.0
              / COUNT(DISTINCT oi.order_id), 2)             AS cancellation_rate,
        'REVIEW REQUIRED'                                   AS alert_status
    FROM order_items    oi
    JOIN orders         o  ON oi.order_id  = o.order_id
    JOIN sellers        s  ON oi.seller_id = s.seller_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY oi.seller_id, s.seller_state
    HAVING total_orders    >= p_min_orders
       AND (avg_rating      < p_min_rating
        OR  cancellation_rate > p_max_cancellation)
    ORDER BY avg_rating ASC;
END$$

DELIMITER ;

-- ── TEST THE PROCEDURES ────────────────────────────────────
CALL get_monthly_revenue('2017-01', '2017-12');
CALL get_category_performance(10);
CALL get_customer_segment('Champions');
CALL flag_underperforming_sellers(3.5, 10, 5);
