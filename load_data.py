"""Load the 84.51 / dunnhumby "Complete Journey" grocery dataset into SQLite.

Get the raw files first (public, CC0 licence):
    git clone --depth 1 https://github.com/bradleyboehmke/completejourney data/completejourney

Then run from the project root:
    python scripts/load_data.py
"""
import os, sqlite3, sys

sys.path.insert(0, os.path.dirname(__file__))
import rreader  # tiny reader for R .rda/.rds files, no R install needed

SRC = 'data/completejourney/data'
DB = 'grocery.db'
FILES = ['transactions.rds', 'products.rda', 'demographics.rda', 'campaigns.rda',
         'campaign_descriptions.rda', 'coupons.rda', 'coupon_redemptions.rda']

con = sqlite3.connect(DB)
for f in FILES:
    obj = rreader.read(os.path.join(SRC, f))
    name, df = list(obj.items())[0] if isinstance(obj, dict) else ('transactions', obj)
    for col in df.columns:  # store timestamps as 'YYYY-MM-DD HH:MM:SS' text
        if str(df[col].dtype).startswith('datetime'):
            s = df[col]
            if getattr(s.dt, 'tz', None) is not None:
                s = s.dt.tz_localize(None)
            df[col] = s.astype(str)
    df.to_sql(name, con, if_exists='replace', index=False)
    print(f'{name:<22} {len(df):>10,} rows')
con.close()
print(f'Saved {DB}')
