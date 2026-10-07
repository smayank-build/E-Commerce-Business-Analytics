-- ============================================================
-- FILE: 01_schema_setup.sql
-- PURPOSE: Create database schema for Olist E-Commerce Analytics
-- Author: Suhas Dhamapurkar
-- ============================================================

CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;

-- ── CUSTOMERS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
    customer_id           VARCHAR(50) PRIMARY KEY,
    customer_unique_id    VARCHAR(50) NOT NULL,
    customer_zip_code     VARCHAR(10),
    customer_city         VARCHAR(100),
    customer_state        CHAR(2)
);

-- ── ORDERS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(30),
    order_purchase_timestamp        DATETIME,
    order_approved_at               DATETIME,
    order_delivered_carrier_date    DATETIME,
    order_delivered_customer_date   DATETIME,
    order_estimated_delivery_date   DATETIME,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ── ORDER ITEMS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- ── PRODUCTS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
    product_id                  VARCHAR(50) PRIMARY KEY,
    product_category_name       VARCHAR(100),
    product_name_length         INT,
    product_description_length  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);

-- ── SELLERS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sellers (
    seller_id           VARCHAR(50) PRIMARY KEY,
    seller_zip_code     VARCHAR(10),
    seller_city         VARCHAR(100),
    seller_state        CHAR(2)
);

-- ── ORDER PAYMENTS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_payments (
    order_id                VARCHAR(50),
    payment_sequential      INT,
    payment_type            VARCHAR(30),
    payment_installments    INT,
    payment_value           DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- ── ORDER REVIEWS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50),
    review_score            TINYINT,
    review_comment_title    VARCHAR(255),
    review_comment_message  TEXT,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME,
    PRIMARY KEY (review_id, order_id)
);

-- ── PRODUCT CATEGORY TRANSLATIONS ─────────────────────────
CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name           VARCHAR(100) PRIMARY KEY,
    product_category_name_english   VARCHAR(100)
);

-- ── INDEXES FOR QUERY OPTIMIZATION ────────────────────────
CREATE INDEX idx_orders_customer    ON orders(customer_id);
CREATE INDEX idx_orders_status      ON orders(order_status);
CREATE INDEX idx_orders_purchase    ON orders(order_purchase_timestamp);
CREATE INDEX idx_items_product      ON order_items(product_id);
CREATE INDEX idx_items_seller       ON order_items(seller_id);
CREATE INDEX idx_payments_order     ON order_payments(order_id);
CREATE INDEX idx_reviews_order      ON order_reviews(order_id);
CREATE INDEX idx_products_category  ON products(product_category_name);

SELECT 'Schema created successfully.' AS status;
