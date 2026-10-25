-- 00_setup.sql
-- Build two helper tables that every later query uses.
--   baskets : one row per shopping trip (household + basket), with its week, month and spend
--   lines   : one row per item bought, joined to its product department (PRODUCE, MEAT, ...)
-- Raw table "transactions" has one row per item scanned (1.47M rows, all of 2017).

DROP TABLE IF EXISTS baskets;
CREATE TABLE baskets AS
SELECT household_id,
       basket_id,
       CAST(week AS INT)                                         AS week,   -- week 1 = 1 Jan 2017
       MIN(transaction_timestamp)                                AS ts,     -- trip time
       CAST(strftime('%m', MIN(transaction_timestamp)) AS INT)  AS month,  -- 1..12
       SUM(sales_value)                                          AS sales,  -- trip spend, USD
       COUNT(*)                                                  AS items
FROM transactions
GROUP BY household_id, basket_id;

CREATE INDEX idx_baskets_hh ON baskets(household_id);

DROP TABLE IF EXISTS lines;
CREATE TABLE lines AS
SELECT t.household_id,
       t.basket_id,
       CAST(t.week AS INT)     AS week,
       t.transaction_timestamp AS ts,
       t.sales_value,
       p.department
FROM transactions t
LEFT JOIN products p USING (product_id);

CREATE INDEX idx_lines_hh ON lines(household_id);

-- Headline numbers
SELECT COUNT(DISTINCT household_id) AS households,
       COUNT(*)                     AS baskets,
       ROUND(SUM(sales), 0)         AS total_sales_usd,
       ROUND(AVG(sales), 2)         AS avg_basket_usd,
       ROUND(AVG(items), 1)         AS avg_items_per_basket
FROM baskets;
