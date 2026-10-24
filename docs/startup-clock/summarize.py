"""Validate the completed startup/late-visual cohorts and current CI metadata."""
from pathlib import Path
import ast,datetime,hashlib,json,subprocess,urllib.request
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
sha=lambda b:hashlib.sha256(b).hexdigest()
current={p.relative_to(PORT/'src').as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n')) for p in (PORT/'src').rglob('*.luau')}
checks=json.loads((H/'fix-checks/receipt.json').read_text())
assert checks['passed']==1022 and checks['failed']==0
assert json.loads((PORT/'build-receipt.json').read_text())['evidence_id']==checks['evidence_id']
cohorts=[]
for name in ['full-late1','decor-full2','decor-low1']:
 d=json.loads((H/name/'native.json').read_text());m=json.loads((H/name/'manifest.json').read_text())
 assert d['source_guards']>=2 and d['creator_errors']==0 and m['original_sources']==current
 assert sha(Path(m['place']).read_bytes())==m['place_sha256']
 assert sha((H/name/'native-output.txt').read_bytes())==d['native_output_sha256']
 def event(kind):
  items=[x['value']for x in d['events']if x['kind']==kind];assert len(items)==1;return items[0]
 event('PASS');cleanup=event('CLEANUP')
 assert cleanup['active']==cleanup['scopes']==cleanup['focus_lost']==0 and not cleanup['life_started']
 row=dict(cohort=name,run=d['run'],tier=d['tier'],source_guards=d['source_guards'],creator_errors=0,creator_warnings=d['creator_warnings'],model_sha256=m['place_sha256'],manifest_sha256=sha((H/name/'manifest.json').read_bytes()))
 if m.get('exercise_decor'):
  row.update(exercise=event('DECOR_EXERCISE'),restored=event('DECOR_RESTORED'))
  assert all(row['exercise'].values()) and row['restored']['parts']>0
 else:
  row['marks']={x['name']:x['t']for x in d['marks']}
 cohorts.append(row)
baseline=json.loads((H/'full-deep2/manifest.json').read_text())['original_sources']
changed=sorted(key for key in current if current[key]!=baseline[key])
assert changed==['Client/HutLife.luau','Client/SpiderClient.client.luau','Client/WorldClient.luau','Shared/Habitat/Breakaway.luau']
revision=subprocess.check_output(['git','rev-parse','c8054893'],cwd=ROOT,text=True).strip()
def api(path):
 req=urllib.request.Request('https://api.github.com/repos/socranates/jumping-spider-sim/'+path,headers={'User-Agent':'Windowsill-qualification','Accept':'application/vnd.github+json'})
 with urllib.request.urlopen(req,timeout=30) as response:return json.load(response)
run=api('actions/runs/40084424435');jobs=api('actions/runs/40084424435/jobs')
assert run['head_sha']==revision and run['status']=='completed'and run['conclusion']=='success'
assert len(jobs['jobs'])==1 and jobs['jobs'][0]['conclusion']=='success'
assert all(step['conclusion']=='success'for step in jobs['jobs'][0]['steps'])
tree=ast.parse((PORT/'tests/run.py').read_text())
suite_lists=[n for n in ast.walk(tree)if isinstance(n,ast.List)and len(n.elts)>70 and all(isinstance(e,ast.Constant)and str(e.value).endswith('.luau')for e in n.elts)]
assert len(suite_lists)==1 and len(suite_lists[0].elts)==79
stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
ci=dict(checked_at=stamp,run=run,jobs=jobs,suite_count=79,limits='Completed configured full CI at the exact source/test commit. No Linux assertion count inferred from job metadata.')
(H/'github-ci.json').write_bytes((json.dumps(ci,indent=2)+'\n').encode())
record=dict(checked_at=stamp,evidence_id=checks['evidence_id'],game_source_count=len(current),sources=current,changed_from_deep2=changed,unchanged_game_sources=len(current)-len(changed),windows_passed=1022,linux_ci=dict(run_id=run['id'],revision=revision,suites=79,conclusion='success'),native=cohorts,published=False,
 limits='Selected startup and deliberate optional-visual engine checks. No current private Player/storage, physical-phone, natural-life, all-map clipping or causal FPS qualification. Engine startup gaps remain unresolved; the original failed red cohorts remain failed.')
(H/'qualification.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps({k:record[k]for k in ['evidence_id','windows_passed','linux_ci','native']}))
