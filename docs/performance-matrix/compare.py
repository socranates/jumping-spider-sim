"""Compare complete, identically instrumented native full/low cohorts.
Read saved native evidence; never infer a broad FPS gain from one pair.
"""
from pathlib import Path
import argparse,hashlib,json,math
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--cohort',type=Path,default=H/'pair1');p.add_argument('--builds',type=Path,default=H/'pair1-builds.json');p.add_argument('--require-matched',action='store_true');p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.cohort=a.cohort.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest()
prepared=json.loads(a.builds.read_text())
models={(x['variant'],x['tier']):x for x in prepared['models']}
records={};inputs={}
for key,model in models.items():
 folder=a.cohort/(key[0]+'-'+key[1]);path=folder/'native.json'
 raw=path.read_bytes();r=json.loads(raw);inputs[str(path.relative_to(H))]=sha(raw)
 assert r['passed']and r['complete_fixture_scope']and r['methods_instrumented']
 assert r['source_guards']>=2 and r['creator_errors']==0
 assert r['model_sha256']==model['sha256']and r['manifest_sha256']==model['manifest_sha256']
 assert sha((folder/'native-output.txt').read_bytes())==r['native_output_sha256']
 assert (r['variant'],r['tier'])==key and len(r['scenes'])==len(r['cameras'])==9
 assert r['actors'][0]['frog_on_screen']and r['actors'][0]['damselflies']>0
 records[key]=r
def close(a,b,tolerance=.01):
 if isinstance(a,list):
  assert len(a)==len(b)
  return all(close(x,y,tolerance)for x,y in zip(a,b))
 return abs(a-b)<=tolerance
rows=[];camera_mismatches=[]
for tier in ['full','low']:
 before,after=records[('before',tier)],records[('after',tier)]
 for field in ['frog_here','frog_on_screen','damselflies']:assert before['actors'][0][field]==after['actors'][0][field],(tier,'pond actors',field)
 assert close(before['actors'][0]['frog_distance'],after['actors'][0]['frog_distance'])
 assert [r['sample']for r in before['samples']]==[r['sample']for r in after['samples']]
 for bscene,ascene,bcam,acam in zip(before['scenes'],after['scenes'],before['cameras'],after['cameras']):
  assert bscene['scene']==ascene['scene']==bcam['scene']==acam['scene']
  b,aa=bscene['state'],ascene['state']
  for field in ['region','mode','viewport','clock','detail','live','cat_enabled']:assert b[field]==aa[field],(tier,bscene['scene'],field)
  for field in ['position','rain','wind']:assert close(b[field],aa[field]),(tier,bscene['scene'],field,b[field],aa[field])
  for field in ['yaw','elevation','position','look','fov']:
   if not close(bcam[field],acam[field]):
    camera_mismatches.append(dict(tier=tier,scene=bcam['scene'],field=field,before=bcam[field],after=acam[field],tolerance=.01))
 for b,aa in zip(before['samples'][1:],after['samples'][1:]):
  name=b['sample'];assert name==aa['sample']
  if name!='three_region_walk':
   assert b['extra']['simulation_seconds']>=20 and aa['extra']['simulation_seconds']>=20
  else:
   assert all(b['extra']['visited'].get(k)and aa['extra']['visited'].get(k)for k in ['garden_a1','garden_a2','garden_a3'])
  def methods(record):
   return {e['value']['name']:e['value']for e in record['events']if e['kind']=='METHOD'and e['value']['sample']==name}
  row=dict(tier=tier,scene=name,
   before={k:b[k]for k in ['mean_ms','p95_ms','worst_ms','frames','over50','render_mean_ms','heap_growth_kb']},
   after={k:aa[k]for k in ['mean_ms','p95_ms','worst_ms','frames','over50','render_mean_ms','heap_growth_kb']},
   before_methods=methods(before),after_methods=methods(after),
   mean_change_percent=(aa['mean_ms']/b['mean_ms']-1)*100)
  assert all(math.isfinite(x)for x in [row['mean_change_percent'],b['mean_ms'],aa['mean_ms']])
  rows.append(row)
record=dict(inputs=inputs,preparation_sha256=sha(a.builds.read_bytes()),rows=rows,source_difference=prepared['changed_between_variants'],
 conditions_matched=not camera_mismatches,camera_mismatches=camera_mismatches,pairs=2,native_runs=4,workload_samples=36,
 limits='One pair per tier on one local Studio laptop. Camera qualification is reported separately at the unchanged .01 tolerance. Asynchronous actor phases, GC and machine load are not lockstep. Endpoint attachment is not continuous support proof. No production FPS, causal/general gain, long-memory or physical-phone claim.')
assert not a.out.exists(),'Keep prior comparison evidence'
a.out.write_bytes((json.dumps(record,indent=2)+'\n').encode())
table=['# Paired native workload observations','',record['limits'],'',
 f"Actual camera conditions matched within .01: {record['conditions_matched']}. See JSON camera_mismatches for all deviations.",'',
 '| Tier | Scene | Before mean ms | After mean ms | Change | Before p95 | After p95 |',
 '|---|---|---:|---:|---:|---:|---:|']
for row in rows:
 b,aa=row['before'],row['after']
 table.append(f"| {row['tier']} | {row['scene']} | {b['mean_ms']:.2f} | {aa['mean_ms']:.2f} | {row['mean_change_percent']:+.1f}% | {b['p95_ms']:.2f} | {aa['p95_ms']:.2f} |")
a.out.with_suffix('.md').write_bytes(('\n'.join(table)+'\n').encode())
print(json.dumps(dict(native_runs=4,samples=36,conditions_matched=record['conditions_matched'],camera_mismatches=len(camera_mismatches),output=str(a.out))))
if a.require_matched:assert record['conditions_matched'],'Retained result does not qualify: camera conditions differ'
