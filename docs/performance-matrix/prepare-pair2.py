"""Prepare a current, cache-only comparator and prove its scene data equivalent.

No normal source/export writes. Four isolated models, no native or FPS claim.
"""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PORT=ROOT/'roblox_port';OUT=Path('C:/Users/natha/claude-xfer')
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
receipt=H/'pair2-builds.json';assert not receipt.exists()
models=[];stages={}
for variant,tier in [('before','full'),('after','full'),('after','low'),('before','low')]:
 stage=OUT/f'Windowsill-matrix-{variant}-{tier}-pair2';assert not stage.exists()
 subprocess.run([sys.executable,str(H/'build.py'),'--out',str(stage),'--variant',variant,'--tier',tier],cwd=ROOT,check=True)
 m=json.loads((stage/'manifest.json').read_text());stages[(variant,tier)]=stage
 models.append(dict(variant=variant,tier=tier,path=m['place'],sha256=m['place_sha256'],manifest_sha256=sha((stage/'manifest.json').read_bytes()),compile=(stage/'compile.txt').read_text().strip(),strict_exit_code=0,native_executed=False))
manifests={key:json.loads((stage/'manifest.json').read_text()) for key,stage in stages.items()}
before=manifests[('before','full')];after=manifests[('after','full')]
different=[k for k in after['sources'] if before['sources'][k]!=after['sources'][k]]
assert different==['ReplicatedStorage.Shared.World.LookPlan']
assert all(m['original_sources']==after['original_sources'] for m in manifests.values())
for variant in ['before','after']:assert manifests[(variant,'full')]['sources']==manifests[(variant,'low')]['sources']
spec=importlib.util.spec_from_file_location('matrix_runner',PORT/'tests/run.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
bundle=runner.bundle('worldmap.luau');body=runner.requires((PORT/'tests/worldmap.luau').read_text())
assert bundle.endswith(body+'\n');bundle=bundle[:-len(body+'\n')]
old=runner.chunk(stages[('before','full')]/'src/Shared/World/LookPlan.luau')
new=runner.chunk(stages[('after','full')]/'src/Shared/World/LookPlan.luau')
bundle+='local __countedRegion=table.clone(__mods.Region)\nlocal __baselineLookPlan='+old.replace('__mods.Region','__countedRegion')+'\nlocal __optimizedLookPlan='+new.replace('__mods.Region','__countedRegion')+'\nlocal __phoneLookPlan='+new.replace('__mods.Region','__countedRegion')+'\n'
for filename in ['cache-checks.luau','phone-checks.luau']:bundle+=(ROOT/'docs/frame-ordinary'/filename).read_text()+'\n'
bundle+='''
local plans=0
for _,world in {"test_garden","preserve"}do
 Map.use(world)
 for _,tier in {"full","low"}do
  local held={}
  for _,region in Map.regions(Map.SEED)do
   local a,na=baseline.plan(region.spawn.pos,tier,region,held,Map)
   local b,nb=optimized.plan(region.spawn.pos,tier,region,held,Map)
   assert(na==nb and same(a,b),"planner/render policy changed: "..world.."/"..tier.."/"..region.id)
   held=a;plans+=1
  end
 end
end
print("CURRENT_PLAN_EQUIVALENCE passed="..plans.." failed=0")
'''
with tempfile.TemporaryDirectory(prefix='pair2-equivalence-') as temp:
 path=Path(temp)/'run.luau';path.write_bytes(bundle.encode())
 r=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True)
 output=(r.stdout+r.stderr).encode();(H/'pair2-equivalence.txt').write_bytes(output)
 print(output.decode()[-2000:],flush=True);assert r.returncode==0
record=dict(source_revision=after['revision'],sources=276,changed_between_variants=different,identical_fixture_sources=True,identical_sources_between_tiers=True,
 comparator='Current planning policy and all current geometry; only shared seeded base-record reuse is disabled in before. Per-level caching remains in both.',
 native_order=['before-full','after-full','after-low','before-low'],models=models,equivalence_bundle_sha256=sha(bundle.encode()),equivalence_output_sha256=sha(output),
 limits='Preparation and CLI record/plan equivalence only. No native execution or causal/general FPS gain follows. All earlier failed or mismatched cohorts remain unchanged.')
receipt.write_bytes((json.dumps(record,indent=2)+'\n').encode());print(json.dumps(record),flush=True)
