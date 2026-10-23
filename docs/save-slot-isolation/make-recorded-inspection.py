"""Private historical inspection path; never enable cross-world restore."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
paths=['roblox_port/src/Shared/World/WorldMap.luau','roblox_port/src/Shared/Persistence/Checkpoint.luau']
originals={p:(ROOT/p).read_bytes() for p in paths}
world=originals[paths[0]].decode();marker='return table.freeze(WorldMap)';assert world.count(marker)==1
world=world.replace(marker,(HERE/'map-view-prototype.luau').read_text()+'\n'+marker)
text=originals[paths[1]].decode()
def replace(old,new):
 global text
 assert text.count(old)==1,old
 text=text.replace(old,new)
replace('local function checkWorld(roots: { [string]: any }, problems: { string }, legacyCompact: boolean?)',
 'local function checkWorld(roots: { [string]: any }, problems: { string }, legacyCompact: boolean?, sourceMap: any?)')
replace('else WorldMap.region(id)) else nil','else (sourceMap or WorldMap).region(id)) else nil')
start=text.index('function Checkpoint.check(record: any, world: World)')
end=text.index('-- Puts the world back as the record has it',start)
body=text[start:end]
body=body.replace('function Checkpoint.check(record: any, world: World)','local function checkRecord(record: any, world: World, sourceMap: any?)')
body=body.replace('local elsewhere = otherWorld(record)','local elsewhere = sourceMap == nil and otherWorld(record)')
body=body.replace('else WorldMap.region(map.region)','else (sourceMap or WorldMap).region(map.region)')
body=body.replace('local moved = Checkpoint.worldMoved(record)','local moved = sourceMap == nil and Checkpoint.worldMoved(record)')
body=body.replace('not WorldMap.inBounds(pos, region.id)','not (sourceMap or WorldMap).inBounds(pos, region.id)')
body=body.replace('WorldMap.retreat(p.retreat_id)','(sourceMap or WorldMap).retreat(p.retreat_id)')
body=body.replace('checkWorld(roots,problems,true)','checkWorld(roots,problems,true,sourceMap)').replace('checkWorld(roots,problems)','checkWorld(roots,problems,false,sourceMap)')
body+='''function Checkpoint.check(record: any, world: World): ({ string }, ObjectRecord.Decoded?)
 return checkRecord(record,world,nil)
end

-- Inspection only: a private decoded graph validated in its recorded geometry.
-- It cannot be passed to the ordinary prepared-rest commit closure by this API.
-- An archive/projection/durable transition is still required before recovery.
function Checkpoint.inspectRecorded(record: any, world: World): ({ string }, ObjectRecord.Decoded?)
 if type(record)~="table" then return {"not a checkpoint"},nil end
 local map,problems=mapRecord(record)
 if #problems>0 then return problems,nil end
 local view,why=WorldMap.recordedView(map.world,map.seed,map.revision,Work.pulse())
 if not view then return {why or "unsupported recorded map"},nil end
 return checkRecord(record,world,view)
end

'''
text=text[:start]+body+text[end:]
(HERE/'recorded-map-candidate.luau').write_text(world,encoding='utf8',newline='\n')
(HERE/'recorded-checkpoint-candidate.luau').write_text(text,encoding='utf8',newline='\n')
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
manifest=dict(source=source,originals={p:sha(v) for p,v in originals.items()},candidates={
 paths[0]:sha(world.encode()),paths[1]:sha(text.encode())},production_changed=False,restore_enabled=False,migration_implemented=False)
(HERE/'recorded-inspection-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print('Private recorded-map inspection candidate generated; gameplay untouched.')
