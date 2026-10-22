"""Summarize verified desktop measurements; fail closed on missing/mismatched pairs.
Usage: python compare.py BASELINE_JSON CANDIDATE_JSON --out NEW_JSON
"""
from pathlib import Path
import argparse,json
p=argparse.ArgumentParser();p.add_argument('baseline');p.add_argument('candidate');p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out);assert not out.exists(),'choose a new report path'
b,c=[json.loads(Path(name).read_text(encoding='utf-8')) for name in [a.baseline,a.candidate]]
for r in [b,c]:
 assert r['complete'] and r['comparison_config'] and r['source_guard_verified'] and r.get('audit_scenes_complete') and r.get('workload_verified'),'full-length verified run including continuous three-region walk required'
 assert len({x['run'] for x in r['records']})==1,'one trial per input required'
headers=[next(x['value'] for x in r['records'] if x['kind']=='header') for r in [b,c]]
assert headers[0]['role']=='baseline' and headers[1]['role']=='candidate'
for k in ['predator_flags','harness_version','tier','viewport','engine','warm_seconds','sample_seconds','rain','mode','clock']:
 assert headers[0][k]==headers[1][k],('unmatched configuration',k)
scenes={x['kind']:x['value'] for x in b['records'] if x['kind']!='header'}
rows=[]
for x in c['records']:
 if x['kind'] in {'header','continuous_route'} or x['kind'].startswith('trace_'):continue
 left=scenes[x['kind']];right=x['value']
 for v in [left,right]:
  assert v['action_ok'] and v['focus_preserved'] and v['viewport_unchanged']
 diffs=[]
 for edge in ['before','after']:
  for key in ['region','active','actors','predators']:
   if left[edge].get(key)!=right[edge].get(key):diffs.append(edge+'.'+key)
 rows.append({'scene':x['kind'],'baseline_frames':left['frames'],'candidate_frames':right['frames'],
 'mean_delta_ms':right['frames']['mean_ms']-left['frames']['mean_ms'],
 'p95_delta_ms':right['frames']['p95_ms']-left['frames']['p95_ms'],
 'state_differences':diffs,'baseline_callback':left['render_callback'],'candidate_callback':right['render_callback']})
report={'scope':'One paired desktop Studio trial; not a phone or published-player result; repeated trials needed for causal performance claims',
 'baseline_header':headers[0],'candidate_header':headers[1],'rows':rows,'all_actor_states_match':all(not r['state_differences'] for r in rows)}
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'scenes':len(rows),'all_actor_states_match':report['all_actor_states_match'],'scope':report['scope']},indent=2))
