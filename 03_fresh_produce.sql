-- 03_fresh_produce.sql
-- Question: are households that buy fresh produce early more likely to become regulars,
-- even after accounting for how often they shopped?
-- Same definitions as 02. "Produce early" = any PRODUCE item in the first 28 days.
-- We compare produce vs no-produce households WITHIN the same early-frequency band,
-- so the gap is not just "frequent shoppers buy more of everything".

WITH first_trip AS (
    SELECT household_id, MIN(ts) AS first_ts, MIN(week) AS first_week
    FROM baskets
    GROUP BY household_id
),
early AS (
    SELECT l.household_id,
           MAX(l.department = 'PRODUCE')  AS bought_produce,
           COUNT(DISTINCT l.basket_id)    AS trips_28d
    FROM lines l
    JOIN first_trip f USING (household_id)
    WHERE julianday(l.ts) < julianday(f.first_ts) + 28
    GROUP BY l.household_id
),
late AS (
    SELECT household_id, COUNT(DISTINCT week) AS weeks_active_45_52
    FROM baskets
    WHERE week BETWEEN 45 AND 52
    GROUP BY household_id
)
SELECT CASE WHEN e.trips_28d <= 2 THEN '1-2 trips'
            WHEN e.trips_28d <= 4 THEN '3-4 trips'
            ELSE '5+ trips' END                                       AS early_frequency,
       CASE WHEN e.bought_produce = 1 THEN 'bought produce'
            ELSE 'no produce' END                                     AS produce_group,
       COUNT(*)                                                       AS households,
       ROUND(100.0 * AVG(COALESCE(l.weeks_active_45_52, 0) >= 4), 1)  AS pct_regular_wk45_52
FROM early e
JOIN first_trip f USING (household_id)
LEFT JOIN late l USING (household_id)
WHERE f.first_week <= 40
GROUP BY 1, 2
ORDER BY 1, 2;
