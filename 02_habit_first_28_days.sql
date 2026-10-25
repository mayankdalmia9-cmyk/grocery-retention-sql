-- 02_habit_first_28_days.sql
-- Question: does how often a household shops in its first 28 days predict whether it is
-- still a regular at year end?
-- Early trips  = baskets within 28 days of the household's first trip.
-- Regular      = shopped in at least 4 of the last 8 full weeks (weeks 45-52).
-- Only households whose first trip was in week 40 or earlier, so everyone has time to show it.

WITH first_trip AS (
    SELECT household_id, MIN(ts) AS first_ts, MIN(week) AS first_week
    FROM baskets
    GROUP BY household_id
),
early AS (
    SELECT b.household_id, COUNT(*) AS trips_28d
    FROM baskets b
    JOIN first_trip f USING (household_id)
    WHERE julianday(b.ts) < julianday(f.first_ts) + 28
    GROUP BY b.household_id
),
late AS (
    SELECT household_id, COUNT(DISTINCT week) AS weeks_active_45_52
    FROM baskets
    WHERE week BETWEEN 45 AND 52
    GROUP BY household_id
),
hh AS (
    SELECT e.household_id,
           e.trips_28d,
           COALESCE(l.weeks_active_45_52, 0) AS late_weeks
    FROM early e
    JOIN first_trip f USING (household_id)
    LEFT JOIN late l USING (household_id)
    WHERE f.first_week <= 40
)
SELECT CASE WHEN trips_28d = 1 THEN '1 trip'
            WHEN trips_28d = 2 THEN '2 trips'
            WHEN trips_28d <= 4 THEN '3-4 trips'
            WHEN trips_28d <= 8 THEN '5-8 trips'
            ELSE '9+ trips' END                         AS trips_in_first_28_days,
       COUNT(*)                                          AS households,
       ROUND(100.0 * AVG(late_weeks >= 1), 1)            AS pct_any_trip_wk45_52,
       ROUND(100.0 * AVG(late_weeks >= 4), 1)            AS pct_regular_wk45_52
FROM hh
GROUP BY 1
ORDER BY MIN(trips_28d);
