-- 01_cohort_retention.sql
-- Question: once a household starts shopping, what share is still shopping 1, 2, 3... months later?
-- Cohort  = the calendar month of a household's FIRST trip in 2017.
-- Active  = at least one trip in that month.
-- Note: households first seen in January are mostly long-standing customers (the data starts
-- on 1 Jan), so treat Feb+ cohorts as the closest thing to "new" customers.

WITH first_month AS (
    SELECT household_id, MIN(month) AS cohort_month
    FROM baskets
    GROUP BY household_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS households
    FROM first_month
    GROUP BY cohort_month
),
activity AS (                      -- every (household, month) where the household shopped
    SELECT DISTINCT b.household_id, f.cohort_month, b.month
    FROM baskets b
    JOIN first_month f USING (household_id)
)
SELECT a.cohort_month,
       s.households                                       AS cohort_size,
       a.month - a.cohort_month                           AS months_since_first,
       COUNT(*)                                           AS active_households,
       ROUND(100.0 * COUNT(*) / s.households, 1)          AS retention_pct
FROM activity a
JOIN cohort_size s USING (cohort_month)
GROUP BY a.cohort_month, months_since_first
ORDER BY a.cohort_month, months_since_first;
