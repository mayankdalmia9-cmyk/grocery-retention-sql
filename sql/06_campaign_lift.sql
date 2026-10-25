-- 06_campaign_lift.sql
-- Question: did the three big "Type A" mailer campaigns actually raise spend?
--
-- Trap: the retailer targeted its BEST customers, who spend about 3x more than everyone else.
-- So comparing targeted vs untargeted households directly is unfair.
-- Fix (a matched difference-in-differences):
--   1. For each campaign, measure each household's spend in the campaign window ("during")
--      and in an equally long window just before it ("pre").
--   2. Put households into 5 bands (quintiles) by pre-campaign spend.
--   3. Within each band, compare the % change in spend for targeted vs untargeted households.
--   4. Lift = targeted change minus untargeted change, in percentage points.
-- Households with zero pre-campaign spend are excluded.

WITH camp AS (
    SELECT campaign_id,
           julianday(start_date)                              AS s,
           julianday(end_date)                                AS e,
           julianday(start_date) - (julianday(end_date) - julianday(start_date)) AS pre_s
    FROM campaign_descriptions
    WHERE campaign_id IN ('8', '13', '18')                    -- the three Type A campaigns with ~1,100 targets each
),
spend AS (
    SELECT c.campaign_id,
           b.household_id,
           SUM(CASE WHEN julianday(b.ts) >= c.pre_s AND julianday(b.ts) < c.s  THEN b.sales ELSE 0 END) AS pre,
           SUM(CASE WHEN julianday(b.ts) >= c.s     AND julianday(b.ts) <= c.e THEN b.sales ELSE 0 END) AS dur
    FROM baskets b
    CROSS JOIN camp c
    GROUP BY c.campaign_id, b.household_id
),
flagged AS (
    SELECT s.*,
           (t.household_id IS NOT NULL) AS targeted,
           NTILE(5) OVER (PARTITION BY s.campaign_id ORDER BY s.pre) AS pre_spend_band
    FROM spend s
    LEFT JOIN campaigns t
           ON t.campaign_id = s.campaign_id AND t.household_id = s.household_id
    WHERE s.pre > 0
),
band AS (
    SELECT campaign_id, pre_spend_band, targeted,
           COUNT(*)                          AS households,
           AVG(pre)                          AS avg_pre,
           AVG(dur)                          AS avg_dur,
           100.0 * (AVG(dur) / AVG(pre) - 1) AS pct_change
    FROM flagged
    GROUP BY campaign_id, pre_spend_band, targeted
)
SELECT t.campaign_id,
       t.pre_spend_band                                    AS pre_spend_band_1_low_5_high,
       t.households                                        AS targeted_households,
       u.households                                        AS untargeted_households,
       ROUND(t.avg_pre, 0)                                 AS targeted_avg_pre_usd,
       ROUND(t.pct_change, 1)                              AS targeted_pct_change,
       ROUND(u.pct_change, 1)                              AS untargeted_pct_change,
       ROUND(t.pct_change - u.pct_change, 1)               AS lift_pct_points,
       ROUND((t.avg_dur - t.avg_pre) - (u.avg_dur - u.avg_pre), 1) AS lift_usd_per_household
FROM band t
JOIN band u
  ON u.campaign_id = t.campaign_id AND u.pre_spend_band = t.pre_spend_band AND u.targeted = 0
WHERE t.targeted = 1
ORDER BY CAST(t.campaign_id AS INT), t.pre_spend_band;
