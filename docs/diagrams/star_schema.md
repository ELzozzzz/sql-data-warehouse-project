# Star Schema Diagram

## Entity-Relationship Overview

The Gold layer implements a **star schema** with one fact table surrounded by three dimension tables.

```
                    ┌─────────────────────────┐
                    │      dim_date           │
                    ├─────────────────────────┤
                    │ PK  date_key (INT)       │
                    │     full_date            │
                    │     year                 │
                    │     month_number         │
                    │     month_name           │
                    │     quarter              │
                    │     quarter_label        │
                    │     day_of_year          │
                    │     day_of_week          │
                    │     day_name             │
                    │     is_weekend           │
                    └────────────┬────────────┘
                                 │
                                 │ order_date_key
                                 │
┌─────────────────────────┐     │     ┌─────────────────────────────┐
│     dim_customers        │     │     │       dim_products           │
├─────────────────────────┤     │     ├─────────────────────────────┤
│ PK  customer_key (INT)  │     │     │ PK  product_key (INT)        │
│     customer_id         │     │     │     product_id               │
│     customer_number     │     │     │     product_number           │
│     first_name          ├─────┼─────┤     product_name             │
│     last_name           │     │     │     standard_cost            │
│     full_name           │     │     │     product_line             │
│     country             │     │     │     product_start_date       │
│     marital_status      │     │     │     category                 │
│     gender              │     │     │     subcategory              │
│     birthdate           │     │     │     maintenance_required     │
│     age                 │     │     └──────────────┬──────────────┘
│     customer_since      │     │                    │
└───────────┬─────────────┘     │                    │
            │                   │                    │ product_key
            │ customer_key      │                    │
            │                   ▼                    │
            │         ┌──────────────────────────────┴──┐
            └────────►│          fact_sales              │
                       ├─────────────────────────────────┤
                       │ FK  order_date_key               │
                       │ FK  product_key                  │
                       │ FK  customer_key                 │
                       │     order_number  (degenerate)   │
                       │     ship_date                    │
                       │     due_date                     │
                       │ ─── Measures ──────────────────  │
                       │     quantity                     │
                       │     unit_price                   │
                       │     discount_amount              │
                       │     sales_amount                 │
                       │     gross_profit                 │
                       └─────────────────────────────────┘
```

## Grain

One row per **sales order line** (a single product on a single sales order).

## Relationships

| Fact Column | Dimension | Join Column |
|---|---|---|
| `order_date_key` | `dim_date` | `date_key` |
| `product_key` | `dim_products` | `product_key` |
| `customer_key` | `dim_customers` | `customer_key` |

## Sample Analytical Queries

### Total Sales by Year and Category
```sql
SELECT
    d.year,
    p.category,
    SUM(f.sales_amount)  AS total_sales,
    SUM(f.gross_profit)  AS total_profit
FROM gold.fact_sales      f
JOIN gold.dim_date        d ON f.order_date_key = d.date_key
JOIN gold.dim_products    p ON f.product_key    = p.product_key
GROUP BY d.year, p.category
ORDER BY d.year, total_sales DESC;
```

### Top 10 Customers by Revenue
```sql
SELECT TOP 10
    c.full_name,
    c.country,
    COUNT(DISTINCT f.order_number) AS orders,
    SUM(f.quantity)                AS units,
    SUM(f.sales_amount)            AS revenue
FROM gold.fact_sales     f
JOIN gold.dim_customers  c ON f.customer_key = c.customer_key
GROUP BY c.full_name, c.country
ORDER BY revenue DESC;
```

### Monthly Sales Trend
```sql
SELECT
    d.year,
    d.month_number,
    d.month_name,
    SUM(f.sales_amount) AS monthly_sales
FROM gold.fact_sales f
JOIN gold.dim_date   d ON f.order_date_key = d.date_key
GROUP BY d.year, d.month_number, d.month_name
ORDER BY d.year, d.month_number;
```
