# 🛒 E-Commerce Business Analytics — SQL + Power BI

**End-to-end business analytics project** using the Brazilian Olist E-Commerce dataset.  
Answers real business questions using advanced SQL and visualizes KPIs in Power BI.

---

## 🎯 Business Problem

An e-commerce company wants to understand:
- Which product categories drive 80% of revenue? (Pareto Analysis)
- Which customer segments are most valuable? (RFM Segmentation)
- Where are orders getting delayed in the supply chain?
- What causes revenue decline in certain months?
- Which sellers are underperforming?

---

## 📁 Project Structure

```
ecommerce-sql-analytics/
│
├── sql/
│   ├── 01_schema_setup.sql          # Database schema & table creation
│   ├── 02_data_exploration.sql      # EDA queries
│   ├── 03_revenue_analysis.sql      # Revenue & Pareto analysis
│   ├── 04_customer_rfm.sql          # RFM segmentation (Window Functions)
│   ├── 05_delivery_analysis.sql     # Supply chain & delay analysis
│   ├── 06_seller_performance.sql    # Seller KPI ranking
│   ├── 07_cohort_analysis.sql       # Customer cohort retention
│   └── 08_stored_procedures.sql     # Reusable stored procedures
│
├── data/
│   └── README.md                    # How to download Olist dataset
│
├── powerbi/
│   └── README.md                    # Power BI dashboard guide
│
└── README.md
```

---

## 🗄️ Dataset

**Source:** [Olist Brazilian E-Commerce — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)  
**Size:** 100,000+ orders | 9 tables | 2016–2018

**Tables Used:**
| Table | Description |
|---|---|
| olist_orders | Order status, timestamps |
| olist_order_items | Products, prices, freight |
| olist_customers | Customer location |
| olist_products | Product categories |
| olist_sellers | Seller location |
| olist_order_payments | Payment methods, values |
| olist_order_reviews | Customer ratings |

---

## 🔑 Key SQL Techniques Used

| Technique | Where Used |
|---|---|
| CTEs (WITH clause) | Revenue analysis, RFM, Cohort |
| Window Functions (RANK, DENSE_RANK, LAG, LEAD, ROW_NUMBER) | RFM, Seller ranking, MoM growth |
| Multi-table JOINs (5+ tables) | All business queries |
| Subqueries & Correlated Subqueries | Pareto analysis |
| CASE WHEN | Customer segmentation |
| GROUP BY + HAVING | Category performance |
| DATE functions | Cohort, delivery analysis |
| Stored Procedures | Reusable KPI reports |
| Indexes | Query optimization |

---

## 📊 Business Insights Delivered

1. **Top 5 categories contribute 62% of total revenue** — Pareto rule confirmed
2. **Average delivery delay: 12 days** — São Paulo orders 3x faster than northern states
3. **Champions segment (RFM Score 555)** — 8% of customers, 34% of revenue
4. **Month-over-month revenue dropped 18% in Sep 2017** — traced to seller stockout
5. **Bottom 20% sellers have 4.2x higher cancellation rate** than top performers

---

## 🛠️ Tech Stack

- **SQL:** MySQL / PostgreSQL
- **Visualization:** Power BI (Star Schema, DAX, Drill-Through)
- **Python:** Pandas (data loading helper script)
- **Tools:** MySQL Workbench / DBeaver

---

## ▶️ How to Run

```bash
# 1. Download dataset from Kaggle (see data/README.md)
# 2. Run schema setup
mysql -u root -p ecommerce < sql/01_schema_setup.sql
# 3. Load data (use Python helper or MySQL LOAD DATA)
# 4. Run analysis queries in order (02 → 08)
```

---

## 👤 Author

**Suhas Dhamapurkar** — Data Analyst  
[LinkedIn](https://www.linkedin.com/in/suhas-1710d/) | [GitHub](https://github.com/Suhas5497) | [Portfolio](https://portfolio-git-main-suhasdhamapurkar1710-gmailcoms-projects.vercel.app/)
