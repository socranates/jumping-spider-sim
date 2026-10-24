"""Verify exact matched native frame models and the cache equivalence cohort."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--baseline',default='attempt3');p.add_argument('--optimized',default='attempt5');p.add_argument('--checks',default='cache-check3');p.add_argument('--check',action='store_true');a=p.parse_args()
target=H/'qualification.json';inputs={};results=[];models=[]
def bind(path):inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
subprocess.run([sys.executable,str(H/'prepare.py'),'--check'],check=True)
for prefix in [a.baseline,a.optimized]:
 receipt=H/(prefix+'-receipt.json');record=json.loads(receipt.read_text(encoding='utf8'));output=H/(prefix+'-output.txt');bind(receipt);bind(output)
 assert record['complete'] and sha(output.read_bytes())==record['output_sha256']
 assert sum(x['kind']=='PASS'for x in record['events'])==1 and not any(x['kind']=='FAIL'for x in record['events'])
 folder=Path(record['model']);manifest=json.loads((folder/'manifest.json').read_text(encoding='utf8'));models.append(manifest)
 assert sha((folder/'manifest.json').read_bytes())==record['manifest_sha256']
 assert sha(Path(manifest['place']).read_bytes())==record['model_sha256']==manifest['place_sha256']
 assert manifest['source_count']==276 and manifest['ordinary_workload'] and not manifest['published']
 assert manifest['diagnostic_sha256']==sha((H/'playback.luau').read_bytes()) and manifest['probe_sha256']==sha((H/'probe.luau').read_bytes())
 assert (folder/'compile.txt').read_text(encoding='utf8').strip()=='compile 276/276'
 assert 'TypeError:' not in (folder/'strict.txt').read_text(encoding='utf8')
 actual={}
 def walk(node,parent=''):
  properties=node.find('Properties');name=properties.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
  source=properties.find("*[@name='Source']")
  if source is not None:actual[path]=sha((source.text or '').replace('\r\n','\n').encode())
  for child in node.findall('Item'):walk(child,path)
 for node in ET.parse(manifest['place']).getroot().findall('Item'):walk(node)
 assert actual==manifest['sources']
 ends={e['value']['sample']:e['value']for e in record['events']if e['kind']=='END'}
 methods=[e['value']for e in record['events']if e['kind']=='METHOD']
 assert set(ends)=={'client-startup','startup-to-menu','home','garden_a1-arrival','garden_a1','pond_a1-arrival','pond_a1'}
 for scene in ['home','garden_a1','pond_a1']:
  row=ends[scene];assert row['frames']>1000 and row['extra']['simulation_seconds']>=29.9 and not row['extra']['ended'] and not row['extra']['loading']
 assert all(ends[s]['frames']>0 for s in ['garden_a1-arrival','pond_a1-arrival'])
 results.append(dict(prefix=prefix,run=record['run'],samples={scene:{k:row[k]for k in ['frames','seconds','worst_ms','over50','render_mean_ms','render_worst_ms']}for scene,row in ends.items()},methods=methods,server_marks=record['server_marks']))
assert set(models[0]['sources'])==set(models[1]['sources'])
diff=[name for name in models[0]['sources']if models[0]['sources'][name]!=models[1]['sources'][name]]
assert diff==['ReplicatedStorage.Shared.World.LookPlan'],diff
assert models[1]['optimized'] and models[1]['extra_game_override']=='Shared/World/LookPlan.luau'
assert models[1]['sources'][diff[0]]==sha((H/'look-plan.luau').read_bytes())
checks=H/(a.checks+'-checks.json');cohort=json.loads(checks.read_text(encoding='utf8'));bind(checks);assert cohort['all_passed'] and len(cohort['suites'])==5
for rel,digest in cohort['inputs'].items():assert sha((ROOT/rel).read_bytes())==digest,rel
for suite in cohort['suites']:
 output=H/suite['output'];bind(output);assert suite['exit_code']==0 and sha(output.read_bytes())==suite['output_sha256']
assert 'SCENERY_CACHE\t2167\tpassed\t0\tfailed\tregions\t267\told_generations\t801\tnew_generations\t267' in (H/(a.checks+'-equivalence-output.txt')).read_text(encoding='utf8')
assert 'SCENERY_PHONE_CACHE\t1602\tpassed\t0\tfailed\tregions\t267\tlow_far_generations\t267\tupgrade_generations\t267' in (H/(a.checks+'-equivalence-output.txt')).read_text(encoding='utf8')
for name in ['probe.luau','playback.luau','look-plan.luau','prepare.py','build.py','check-cache.py','cache-checks.luau','phone-checks.luau','collect.py']:bind(H/name)
result=dict(inputs=inputs,changed_game_sources=diff,regions=267,before_generation_calls=801,after_generation_calls=267,equivalence_checks=2167,phone_checks=1602,runs=results,
 production_activated=False,published=False,startup_gap_fixed=False,goal_complete=False)
if a.check:assert json.loads(target.read_text(encoding='utf8'))==result;print('Matched ordinary frame models and unchanged scenery records verified')
else:assert not target.exists();target.write_bytes((json.dumps(result,indent=2)+'\n').encode());print('Ordinary frame qualification recorded')
