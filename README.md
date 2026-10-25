# Grocery Retention & Lifecycle Analysis in SQL

**Question:** In a grocery business, what turns a first-time shopper into a weekly regular, how fast do lapsed shoppers slip away, and do marketing campaigns actually change behaviour?

**Data:** 84.51° / dunnhumby *The Complete Journey*: 1.47M item-level grocery transactions from 2,469 US households across 2017 (155,848 shopping trips, $4.6M in sales), plus products, demographics, 27 marketing campaigns and coupon redemptions. Public, CC0 licence.

**Tools:** SQL (SQLite: CTEs, window functions `LAG`/`LEAD`/`NTILE`), Python (pandas) for loading and charts.

---

## Key findings

| # | Finding | Number | What it means for a grocery growth team |
|---|---|---|---|
| 1 | **The first 28 days decide the habit.** | Households with **3+ trips** in their first 28 days were **2.3× as likely** to be year-end regulars (**74% vs 33%**). | Onboarding should push the 2nd and 3rd order fast, not just the 1st. |
| 2 | **Newer households are far less sticky.** | Month-1 retention: **63%** for households first seen Feb–Nov vs **89%** for the established January base. | Measure new-customer cohorts separately; the blended number hides the problem. |
| 3 | **Fresh produce goes with stickiness.** | At the same early trip frequency, households that bought produce early were **6–12 points** more likely to be regulars. | Worth testing produce-led first-order offers (a hypothesis, not proof). |
| 4 | **The return window closes fast.** | Chance of returning within the next 4 weeks: **86%** after 1 week away, **64%** after 4, **46%** after 8. | Trigger win-back around weeks 2–4 of inactivity, before the odds halve. |
| 5 | **Width = wallet share.** | Households shopping **12+ departments** spent **$3,304/yr** vs **$537** for 6–8 departments, and **$31.6 vs $21.0** per trip. | Cross-category nudges are a lever for basket size (also needs testing). |
| 6 | **Naive campaign measurement is wrong.** | Targeted households spent ~3× more *before* the campaigns, so a raw comparison shows ~no lift. Matched by pre-campaign spend, the 3 big campaigns lifted spend by **+19 to +26 points** (**$29–59 per targeted household**). Lift was smallest among top spenders. | Always use a holdout group; target mid/low spenders rather than discounting loyalists. |

## How each finding was measured

| File | What it does |
|---|---|
| `sql/00_setup.sql` | Builds `baskets` (one row per trip) and `lines` (one row per item + department). |
| `sql/01_cohort_retention.sql` | Monthly cohorts by first-trip month; % of each cohort active N months later. |
| `sql/02_habit_first_28_days.sql` | Trips in first 28 days vs being a "regular" (active 4+ of weeks 45–52). |
| `sql/03_fresh_produce.sql` | Produce vs no-produce households, compared within the same early-frequency band. |
| `sql/04_category_width.sql` | Departments shopped vs annual spend, trips and basket size. |
| `sql/05_winback.sql` | For households already away k weeks, % back within the next 4 weeks. |
| `sql/06_campaign_lift.sql` | Matched difference-in-differences: targeted vs untargeted households in the same pre-spend quintile. |

All results are saved as CSVs in `results/`.

## Limitations (read results honestly)

- **Not true new customers.** The panel starts on 1 Jan 2017, so most households are existing shoppers. Feb–Dec cohorts (479 households) are the closest proxy for new or returning customers.
- **Correlation, not causation** for findings 1, 3 and 5. Frequent shoppers naturally buy more categories. These are hypotheses to A/B test.
- **Campaign targeting wasn't random.** Matching on pre-spend removes the biggest bias but not all of it. Campaign cost isn't in the data, so ROI can't be computed.
- **US supermarket data**, not Indian quick commerce. Patterns (habit formation, lapse decay, targeting bias) transfer; exact levels won't.

## Run it yourself

```bash
git clone --depth 1 https://github.com/bradleyboehmke/completejourney data/completejourney
python scripts/load_data.py   # builds grocery.db (no R needed)
python scripts/run_all.py     # runs every SQL file, writes results/*.csv
```

Source: [completejourney R package](https://github.com/bradleyboehmke/completejourney), originally from 84.51° (Kroger's data science company).
