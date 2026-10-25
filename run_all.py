"""Run every SQL file in order and save each file's final result to results/<name>.csv.

    python scripts/run_all.py
"""
import glob, os, sqlite3
import pandas as pd

pd.set_option('display.width', 200)
con = sqlite3.connect('grocery.db')
os.makedirs('results', exist_ok=True)

for path in sorted(glob.glob('sql/*.sql')):
    text = open(path).read()
    # drop comment lines, then split into statements; the last one is the result query
    body = '\n'.join(l for l in text.splitlines() if not l.strip().startswith('--'))
    stmts = [s.strip() for s in body.split(';') if s.strip()]
    for s in stmts[:-1]:
        con.execute(s)
    con.commit()
    df = pd.read_sql(stmts[-1], con)
    name = os.path.splitext(os.path.basename(path))[0]
    df.to_csv(f'results/{name}.csv', index=False)
    print(f'\n=== {name} ===')
    print(df.to_string(index=False))

# Summary for 06: lift across bands, weighted by number of targeted households
lift = pd.read_csv('results/06_campaign_lift.csv')
summary = (lift.assign(w_pts=lift.lift_pct_points * lift.targeted_households,
                       w_usd=lift.lift_usd_per_household * lift.targeted_households)
               .groupby('campaign_id')[['w_pts', 'w_usd', 'targeted_households']].sum())
summary['weighted_lift_pct_points'] = (summary.w_pts / summary.targeted_households).round(1)
summary['weighted_lift_usd_per_household'] = (summary.w_usd / summary.targeted_households).round(1)
summary = summary[['targeted_households', 'weighted_lift_pct_points', 'weighted_lift_usd_per_household']]
summary.to_csv('results/06b_campaign_lift_summary.csv')
print('\n=== 06b_campaign_lift_summary ===')
print(summary.to_string())
