from pathlib import Path
import hashlib,json,re,subprocess,tempfile,shutil,runpy,io,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
p=json.loads((HERE/'process.json').read_text(encoding='utf8'))
assert len(p['inputs'])==216 and len(p['trials'])==6
assert p['fixture_sha256']==sha((HERE/'trace.luau').read_bytes())
archive=subprocess.check_output(['git','archive','--format=tar',p['source'],'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
 blobs={t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
assert len(blobs)==216 and set(blobs)==set(p['inputs'])
for path,h in p['inputs'].items():
 assert sha((ROOT/path).read_bytes())==h==sha(blobs[path])
def bundles(meta,fixture_path):
 # Reconstruct every executed bundle, binding all embedded test/shim inputs too.
 with tempfile.TemporaryDirectory() as folder:
  snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
  runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'))
  for row in meta['trials']:
   fixture=fixture_path.read_text(encoding='utf8').replace('__FPS__',str(row['fps'])).replace('__BARRIER__',str(row['barrier']).lower())
   (snap/'roblox_port/tests/activation_trace.luau').write_text(fixture,encoding='utf8',newline='\n')
   assert sha(runner['bundle']('activation_trace.luau').encode())==row['bundle_sha256']
bundles(p,HERE/'trace.luau')
results=[];barrier_samples=[]
for r in p['trials']:
 assert r['exit_code']==0
 name=f'trace-{int(r["barrier"])}-{r["fps"]}.txt';b=(HERE/name).read_bytes();s=b.decode()
 done=re.findall(r'\[ACTIVATION_DONE\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',s)
 assert len(done)==1
 fps,ticks,prepared,moved,checks=map(int,done[0]);assert fps==r['fps'] and ticks==5400 and checks==fps*90
 samples=re.findall(r'\[ACTIVATION_SAMPLE\]\s+\d+\s+(.*)',s)
 assert len(samples)==9 and [int(x.split()[0]) for x in samples]==list(range(600,5401,600))
 if r['barrier']:
  assert prepared==1 and moved==16
  barrier_samples.append(samples)
 results.append(dict(barrier=r['barrier'],fps=fps,prepared_tick=prepared,moved_tick=moved,log_sha256=sha(b)))
assert barrier_samples[0]==barrier_samples[1]==barrier_samples[2]
assert len({r['prepared_tick'] for r in results if not r['barrier']})==3
receipt=dict(source=p['source'],production_inputs=216,fixed_tick_hz=60,simulated_seconds_per_trial=90,
 trials=results,barrier_sample_count=9,barrier_position_samples_match=True,
 production_change=False,full_client_trace=False,station_air_covered=False,native_performance_claim=False,
 scope='Cold RivalDrive/Route component, static safe observer and patrol record, seed914; render-rate calls use actual production Drive.advance budgets')
(HERE/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
if (HERE/'air/process.json').exists():
 a=json.loads((HERE/'air/process.json').read_text(encoding='utf8'))
 assert a['source']==p['source'] and a['inputs']==p['inputs']
 assert a['fixture_sha256']==sha((HERE/'air-trace.luau').read_bytes()) and len(a['trials'])==6
 bundles(a,HERE/'air-trace.luau')
 rows=[];samples=[]
 for r in a['trials']:
  assert r['exit_code']==0
  name=f'trace-{int(r["barrier"])}-{r["fps"]}.txt';b=(HERE/'air'/name).read_bytes();s=b.decode()
  done=re.findall(r'\[AIR_DONE\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',s)
  assert len(done)==1
  fps,ticks,ready,pauses,points=map(int,done[0]);assert fps==r['fps'] and ticks==1800 and pauses==625 and points==5
  if r['barrier']:
   assert ready==1
   samples.append(re.findall(r'\[AIR_SAMPLE\]\s+\d+\s+(.*)',s))
  rows.append(dict(barrier=r['barrier'],fps=fps,route_ready_tick=ready,log_sha256=sha(b)))
 assert len(samples)==3 and len(samples[0])==6 and samples[0]==samples[1]==samples[2]
 assert len({r['route_ready_tick'] for r in rows if not r['barrier']})==3
 result=dict(source=a['source'],trials=rows,prepare_yields=625,full_wasp_actor_trace=False,
  scope='Controlled one-resume-per-render-frame model of StationAir.prepare task.wait callback; blocked doorway route query, not native scheduler proof',production_change=False)
 (HERE/'air/receipt.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps(result,indent=2))
