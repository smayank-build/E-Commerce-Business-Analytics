# Power BI Dashboard Guide

## Star Schema Design

```
                    ┌─────────────┐
                    │  fact_sales │
                    │─────────────│
              ┌────▶│ order_id    │◀────┐
              │     │ customer_id │     │
              │     │ product_id  │     │
              │     │ seller_id   │     │
              │     │ revenue     │     │
              │     │ order_date  │     │
              │     └─────────────┘     │
              │                         │
    ┌─────────┴──┐              ┌───────┴─────┐
    │ dim_customer│              │ dim_product │
    └────────────┘              └─────────────┘
         │                            │
    ┌────┴──────┐              ┌──────┴──────┐
    │ dim_seller│              │  dim_date   │
    └───────────┘              └─────────────┘
```

## DAX Measures to Create

### Revenue KPIs
```dax
Total Revenue = SUM(fact_sales[revenue])

MoM Revenue Growth =
VAR CurrentMonth = [Total Revenue]
VAR PrevMonth = CALCULATE([Total Revenue], DATEADD(dim_date[date], -1, MONTH))
RETURN DIVIDE(CurrentMonth - PrevMonth, PrevMonth, 0)

YTD Revenue = TOTALYTD([Total Revenue], dim_date[date])
```

### Customer KPIs
```dax
Avg Order Value = DIVIDE([Total Revenue], DISTINCTCOUNT(fact_sales[order_id]))

Customer Retention Rate =
DIVIDE(
    CALCULATE(DISTINCTCOUNT(fact_sales[customer_id]),
              FILTER(fact_sales, fact_sales[order_count] > 1)),
    DISTINCTCOUNT(fact_sales[customer_id])
)
```

### Delivery KPIs
```dax
Late Delivery Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_sales), fact_sales[is_late] = 1),
    COUNTROWS(fact_sales)
)
```

## Dashboard Pages to Build

1. **Executive Summary** — Total Revenue, Orders, AOV, Late Rate KPI cards + MoM trend line
<img width="1375" height="776" alt="Screenshot 2026-06-03 172501" src="https://github.com/user-attachments/assets/12c54559-834c-4b5a-b1bc-259b93049e40" />

2. **Revenue Analysis** — Monthly trend, Pareto chart by category, Revenue by state map
<img width="1379" height="774" alt="Screenshot 2026-06-03 172610" src="https://github.com/user-attachments/assets/37d73ece-b776-49c2-9731-6c3626d397a7" />

3. **Customer Intelligence** — RFM segment donut, Champion vs At-Risk bar chart
<img width="1371" height="772" alt="Screenshot 2026-06-03 172624" src="https://github.com/user-attachments/assets/45c0e799-d1c4-4c7e-8dee-4fcaa3e25e56" />

4. **Delivery Performance** — Delivery time by state map, Late rate trend, Stage breakdown
<img width="1376" height="773" alt="Screenshot 2026-06-03 172636" src="https://github.com/user-attachments/assets/5d771072-b9e0-48f1-bfd0-ca6fd2b9a89d" />

5. **Seller Scorecard** — Top/Bottom performers table, Rating vs Revenue scatter
<img width="1376" height="776" alt="Screenshot 2026-06-03 172650" src="https://github.com/user-attachments/assets/f5c8e617-c4b0-49a6-9add-6c870e506e54" />


## Drill-Through Setup
- Right-click any category bar → Drill Through → Category Detail page
- Shows: monthly trend, top sellers, avg rating, delivery performance for that category


[def]: image.png
