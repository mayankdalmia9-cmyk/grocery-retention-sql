"""Fill dashboard/template.html with the CSVs in results/ -> dashboard/index.html"""
import json, pandas as pd
r = lambda n: json.loads(pd.read_csv(f'results/{n}.csv').to_json(orient='records'))
data = {'habit': r('02_habit_first_28_days'), 'cohort': r('01_cohort_retention'), 'produce': r('03_fresh_produce'),
        'winback': r('05_winback'), 'width': r('04_category_width'), 'lift': r('06_campaign_lift')}
html = open('dashboard/template.html').read().replace('__DATA__', json.dumps(data))
open('dashboard/index.html', 'w').write(html)
print('dashboard/index.html', len(html), 'bytes')
