-- 04_category_width.sql
-- Question: do households that shop across more departments spend more per trip and per year?
-- Width = number of distinct departments bought from in 2017 (PRODUCE, MEAT, DELI, ...).
-- This is the "wallet share" idea: selling more WIDTH of products to the same customer.

WITH hh AS (
    SELECT household_id,
           COUNT(DISTINCT department)  AS departments,
           SUM(sales_value)            AS annual_spend,
           COUNT(DISTINCT basket_id)   AS trips
    FROM lines
    WHERE department IS NOT NULL
    GROUP BY household_id
)
SELECT CASE WHEN departments <= 5  THEN '01-05 departments'
            WHEN departments <= 8  THEN '06-08 departments'
            WHEN departments <= 11 THEN '09-11 departments'
            ELSE '12+ departments' END            AS width_band,
       COUNT(*)                                   AS households,
       ROUND(AVG(annual_spend), 0)                AS avg_annual_spend_usd,
       ROUND(AVG(trips), 0)                       AS avg_trips,
       ROUND(SUM(annual_spend) / SUM(trips), 1)   AS avg_basket_usd
FROM hh
GROUP BY 1
ORDER BY 1;
