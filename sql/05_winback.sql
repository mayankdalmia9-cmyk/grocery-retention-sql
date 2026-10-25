-- 05_winback.sql
-- Question: once a household stops shopping, how fast does the chance of it coming back fall?
-- For every gap between two shopping weeks (or after the last one), count weeks absent.
-- Then: of households already away k weeks, what share return within the NEXT 4 weeks?
-- Only gaps that start in week 36 or earlier, so every gap has 16+ weeks to be observed.

WITH weeks AS (
    SELECT DISTINCT household_id, week FROM baskets
),
gaps AS (
    SELECT household_id,
           week,
           LEAD(week) OVER (PARTITION BY household_id ORDER BY week) AS next_week
    FROM weeks
),
episodes AS (
    SELECT household_id,
           CASE WHEN next_week IS NULL THEN 999          -- never came back in 2017
                ELSE next_week - week - 1 END AS weeks_away
    FROM gaps
    WHERE week <= 36
),
k AS (
    SELECT 1 AS k UNION ALL SELECT 2 UNION ALL SELECT 4
    UNION ALL SELECT 6 UNION ALL SELECT 8 UNION ALL SELECT 12
)
SELECT k.k                                                         AS weeks_already_away,
       SUM(e.weeks_away >= k.k)                                    AS episodes_still_away,
       ROUND(100.0 * SUM(e.weeks_away >= k.k AND e.weeks_away < k.k + 4)
                   / SUM(e.weeks_away >= k.k), 1)                  AS pct_back_within_next_4_weeks
FROM episodes e
CROSS JOIN k
GROUP BY k.k
ORDER BY k.k;
