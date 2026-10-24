"""Derive a source-fingerprinted ordinary startup performance fixture."""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent;N=H.parent/'normal-startup'
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
builder=(N/'build-legacy.py').read_text(encoding='utf8')
builder=builder.replace("H=Path(__file__).resolve().parent;ROOT=H.parents[1]","H=Path(__file__).resolve().parent;N=H.parent/'normal-startup';ROOT=H.parents[1]")
builder=builder.replace("H/('check.py' if a.before else 'check-legacy.py')","N/('check.py' if a.before else 'check-legacy.py')")
builder=builder.replace("(H/'legacy-playback.luau')","(H/'playback.luau')")
builder=builder.replace("(H/'legacy-storage.luau')","(N/'diagnostic-storage.luau')")
builder=builder.replace("expected['Server/NormalStartupLegacySeed.luau']=(H/'legacy-seed.luau').read_bytes()",'''expected['Client/StartupPerfProbe.luau']=(H/'probe.luau').read_bytes()
client=expected['Client/SpiderClient.client.luau'].decode('utf8')
assert client.startswith('--!strict\\n')
client=client.replace('--!strict\\n','--!strict\\nrequire(script.Parent.StartupPerfProbe).begin()\\n',1)
anchors={
 'local M = {':'require(script.Parent.StartupPerfProbe).mark("module-table")\\nlocal M = {',
 'M.lock = M.LockOn.new()':'require(script.Parent.StartupPerfProbe).mark("module-table-complete")\\nM.lock = M.LockOn.new()',
 'World = require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer),':'World = require(script.Parent.StartupPerfProbe).call("world-client",function()return require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer)end),',
 'local rig = SpiderRig.new(Workspace, M.World.root, appearance, detail)':'local rig = require(script.Parent.StartupPerfProbe).call("spider-rig",function()return SpiderRig.new(Workspace, M.World.root, appearance, detail)end)',
 'M.World:streamLooks(Workspace, detail)':'require(script.Parent.StartupPerfProbe).mark("looks-begin");M.World:streamLooks(Workspace, detail);require(script.Parent.StartupPerfProbe).mark("looks-end");require(script.Parent.StartupPerfProbe).watchLooks(M.World.looks)',
 'local flyBodies = FlyBodies.new(Workspace, detail)':'require(script.Parent.StartupPerfProbe).mark("animal-bodies-begin")\\nlocal flyBodies = FlyBodies.new(Workspace, detail)',
 'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)':'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)\\nrequire(script.Parent.StartupPerfProbe).mark("animal-bodies-end")',
 'local accumulator = 0':'require(script.Parent.StartupPerfProbe).mark("client-ready-to-render")\\nlocal accumulator = 0'}
for old,new in anchors.items():assert client.count(old)==1,old;client=client.replace(old,new)
expected['Client/SpiderClient.client.luau']=client.encode()''')
builder=builder.replace("source_count=len(expected);",'''# Timing-only server marks: no scheduling or world/saving behavior changes.
for rel,anchors in {
 'Server/Main.server.luau':{
  'local Habitat =':('main-modules-begin',None),
  'Players.CharacterAutoLoads = false':('main-modules-end',None),
  'local decorOk, decor, replaced = pcall(Scenery.decor, if litOk and sun.ok then sun.direction else nil, worldId)':('decor-begin','decor-end'),
  'local hidden: { [string]: boolean } = {}':('hidden-plan-begin',None),
  'WorldBuild.world(Workspace, WorldMap.SEED, hidden)':('physical-world-begin','physical-world-end')},
 'Server/Persistence.server.luau':{
  'local dataStore,available=loadStore()':('storage-begin','storage-end'),
  ' catalog,problem=Templates.new(root,function():boolean return not closing end)':('templates-begin','templates-end'),
  'if worldId==Worlds.PRESERVE then composition=Composition.new(config);service=composition.service;require(script.Parent.NormalStartupDiagnosticStorage).observe(composition)':('composition-begin',None)}
}.items():
 code=expected[rel].decode()
 for anchor,(before,after)in anchors.items():
  assert code.count(anchor)==1,anchor
  def marker(name):return 'print("[ORDINARY_SERVER_MARK]",game:GetService("HttpService"):JSONEncode({name="'+name+'",at=workspace:GetServerTimeNow(),clock=os.clock(),heap_kb=gcinfo()}))'
  code=code.replace(anchor,marker(before)+'\\n'+anchor+('\\n'+marker(after)if after else ''))
 expected[rel]=code.encode()
source_count=len(expected);''')
builder=builder.replace("'LegacyStartupDiagnostic':True","'OrdinaryPerf':True")
builder=builder.replace("project['name']='WindowsillNormalStartupDiagnostic'","project['name']='WindowsillOrdinaryFrameDiagnostic'")
builder=builder.replace('out=a.out.resolve()','out=a.out.resolve();assert not a.before and not a.unavailable')
builder=builder.replace("p.add_argument('--types'", "p.add_argument('--optimized',action='store_true');p.add_argument('--types'")
builder=builder.replace("if a.ordinary_ui:\n", "if a.optimized:expected['Shared/World/LookPlan.luau']=(H/'look-plan.luau').read_bytes()\nif a.ordinary_ui:\n",1)
builder=builder.replace('legacy_seeded=True','legacy_seeded=False,ordinary_workload=True,early_client_measurement=True,optimized=a.optimized,extra_game_override=("Shared/World/LookPlan.luau" if a.optimized else None)')
builder=builder.replace('unbound memory_only normal_startup_enabled','unbound memory_only ordinary_workload measured_startup')
builder=builder.replace("diagnostic_sha256=sha((H/'playback.luau').read_bytes())","diagnostic_sha256=sha((H/'playback.luau').read_bytes()),probe_sha256=sha((H/'probe.luau').read_bytes())")
path=H/'build.py';data=builder.encode()
if a.check:assert path.read_bytes()==data;print('Ordinary frame builder derivation matches')
else:path.write_bytes(data);print('Ordinary frame builder created')
original=(H.parents[1]/'roblox_port/src/Shared/World/LookPlan.luau').read_text(encoding='utf8')
old='\tlocal all = Region.decor(region)'
assert original.count(old)==1
updated=original.replace(old,'''\t-- All detail levels are read-only views of one seeded decoration list.
\t-- Generating again for low/far wastes CPU and keeps duplicate record tables.
\tlocal fullKey = region.id .. "/" .. tostring(region.seed) .. "/full"
\tlocal all = recordsCache[fullKey]
\tif all == nil and tier == "low" and level ~= "full" then
\t\t-- The phone tier retains only its base records. Far low views use those
\t\t-- same records; full detail is generated later only if actually requested.
\t\tlocal lowKey = region.id .. "/" .. tostring(region.seed) .. "/low"
\t\tall = recordsCache[lowKey]
\t\tif all == nil then
\t\t\tall = {}
\t\t\tfor _, d in Region.decor(region) do if not d.full then table.insert(all, d) end end
\t\t\trecordsCache[lowKey] = all
\t\tend
\telseif all == nil then
\t\tall = Region.decor(region); recordsCache[fullKey] = all
\tend''')
path=H/'look-plan.luau';data=updated.encode()
if a.check:assert path.read_bytes()==data;print('Shared scenery generation derivation matches')
else:path.write_bytes(data);print('Shared scenery generation created')
