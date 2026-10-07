# How to Download & Load the Olist Dataset

## Step 1: Download from Kaggle

1. Go to: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
2. Click **Download** (requires free Kaggle account)
3. Extract the ZIP — you'll get 9 CSV files

## Step 2: Load into MySQL

Option A — MySQL Workbench (easiest):
1. Run `sql/01_schema_setup.sql` first
2. Use Table Data Import Wizard for each CSV

Option B — Command line:
```sql
LOAD DATA INFILE '/path/to/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
```

## CSV → Table Mapping

| CSV File | Table Name |
|---|---|
| olist_orders_dataset.csv | orders |
| olist_customers_dataset.csv | customers |
| olist_order_items_dataset.csv | order_items |
| olist_products_dataset.csv | products |
| olist_sellers_dataset.csv | sellers |
| olist_order_payments_dataset.csv | order_payments |
| olist_order_reviews_dataset.csv | order_reviews |
| product_category_name_translation.csv | product_category_translation |

## Step 3: Verify Load
```sql
SELECT COUNT(*) FROM orders;        -- expect ~99k
SELECT COUNT(*) FROM customers;     -- expect ~99k
SELECT COUNT(*) FROM order_items;   -- expect ~112k
```
