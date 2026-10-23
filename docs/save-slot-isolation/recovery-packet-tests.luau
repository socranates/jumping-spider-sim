do
local Compression=require("../src/Server/RestCompression")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local passedPacket=0
local function packetCheck(ok,why) assert(ok,why);passedPacket+=1 end
local memo,texts={},{};local sequence=0
local codec=Compression.new({
 serialize=function(value) local text=assert(Json.canonical(value));memo[text]=Json.copy(value);return text end,
 compress=function(text) sequence+=1;local id="opaque-"..sequence;texts[id]=text;return id end,
 expandedSize=function(id) return if texts[id] then #texts[id] else nil end,
 decompress=function(id) return assert(texts[id],"corrupt opaque fixture") end,
 parse=function(text) return Json.copy(assert(memo[text],"unknown fixture text")) end,
})
local fresh=newWorld();local template=assert(Checkpoint.capture(fresh,123))
local global=Progress.default();global.notebook.opened={"earlier_page"};global.settings={SoundMuted=false}
local incoming=Progress.default();incoming.notebook.opened={"later_page"};incoming.settings={MasterVolume=.7}
local prior=Envelope.make(SaveRest.SPECS.main,Json.copy(source),80,nil)
local rest=Envelope.make(SaveRest.SPECS.main,Json.copy(source),90,prior)
local rawProgress=Envelope.make(Progress.SPEC,global,100,nil)
local function makeArchive(r,p)
 return assert(__packetArchive.prepare("46001","packet-observation",{progress={loaded=true,value=p or rawProgress},main={loaded=true,value=r or rest},free={loaded=true},easy={loaded=true}}))
end
local archive=makeArchive();local original=assert(Json.canonical(archive))
local anchor,why=__packetPrototype.prepare("46001","main",archive,incoming,110,template,fresh,codec,"primary",200)
packetCheck(anchor~=nil,"packet preparation failed: "..tostring(why))
local p=assert(__packetPrototype.open(anchor,codec,fresh));local logical=codec:decode(anchor.target)
packetCheck(logical.schema==3 and anchor.target.schema==2 and anchor.target.innerSchema==3,"new envelope/transport schema differs")
packetCheck(p.progressTime==110 and p.progress.notebook.opened[2]=="later_page" and p.progress.settings.MasterVolume==.7,"packet lost prepared choice time/progress")
packetCheck(p.owner=="46001" and p.slot=="main" and p.archive.manifest==archive.index.checksum and p.archive.selected==archive.entries.main.checksum,"packet scope/archive binding differs")
packetCheck(p.checkpoint.world_map.world=="preserve" and p.binding.serial==p.progress.rare.serial,"packet checkpoint/global rare binding differs")
packetCheck(logical.backup==nil and archive.entries.main.raw.backup~=nil and Json.canonical(archive)==original,"packet duplicated/damaged original backup")
packetCheck(table.isfrozen(anchor) and table.isfrozen(anchor.target),"prepared proposal is not owned/frozen")
local called=0
local old={kind="rest_main",current=2,migrations={},validate=function() called+=1;error("old reader inspected future payload") end}
packetCheck(Envelope.open(old,logical).status=="newer" and called==0,"old reader inspected schema3 payload")
packetCheck(Envelope.open(__productionRest.SPECS.main,logical).status=="newer","production old spec did not refuse schema3")
-- Prepared normal records and retirement markers remain readable by the new
-- spec; their old data is not mistaken for an import packet.
local regular=Envelope.make(SaveRest.SPECS.main,template,100,nil)
local normal=Envelope.open(__packetPrototype.spec("main",fresh),regular)
packetCheck(normal.status=="migrated" and Json.canonical(normal.payload)==Json.canonical(template),"new reader changed ordinary schema2 rest")
local retired=Envelope.make(SaveRest.SPECS.main,{save_retired=true,save_life="retired-token"},100,nil)
local marker=Envelope.open(__packetPrototype.spec("main",fresh),retired)
packetCheck(marker.status=="migrated" and marker.payload.save_retired,"new reader lost a retirement marker")
-- Compression need not reproduce the same opaque bytes on another attempt.
-- The immutable first proposal is the retry source; never overwrite it with a
-- freshly recomputed candidate merely because decoded payloads are equivalent.
local second=assert(__packetPrototype.prepare("46001","main",archive,incoming,110,template,fresh,codec,"primary",200))
packetCheck(anchor.target.data~=second.target.data and Json.canonical(assert(__packetPrototype.open(second,codec,fresh)))==Json.canonical(p),"non-deterministic encoding fixture did not preserve logical identity")
local function seal(a)
 local core={};for k,v in a do if k~="checksum" then core[k]=v end end
 a.checksum=Json.checksum(assert(Json.canonical(core)))
end
for _,edit in {
 function(a) a.owner="other" end,
 function(a) a.version=2 end,
 function(a) a.target.innerSchema=99 end,
 function(a) a.target.encoding="future" end,
 function(a) a.extra=true end,
} do local a=Json.copy(anchor);edit(a);seal(a);packetCheck(__packetPrototype.open(a,codec,fresh)==nil,"unsupported proposal accepted") end
for _,edit in {
 function(p) p.binding.serial+=1 end,
 function(p) p.progress.extra=true end,
 function(p) p.progress.rare.extra=true end,
 function(p) p.entryKind="mating" end,
 function(p) p.archive.key="A1_other_index" end,
 function(p) p.save_life="foreign-life" end,
 function(p) p.progress.notebook.opened={string.rep("x",__packetPrototype.MAX_PROGRESS_CHARS)} end,
} do
 local payload=Json.copy(p);edit(payload)
 local bad=Json.copy(anchor);bad.target=codec:encode(Envelope.make(__packetPrototype.spec("main",fresh),payload,200,nil));seal(bad)
 packetCheck(__packetPrototype.open(bad,codec,fresh)==nil,"invalid payload accepted behind valid checksums")
end
local broken=Json.copy(rest);broken.checksum="bad"
local backupArchive=makeArchive(broken)
packetCheck(__packetPrototype.prepare("46001","main",backupArchive,incoming,110,template,fresh,codec,"primary",200)==nil,"corrupt primary silently substituted backup")
local recovered=assert(__packetPrototype.prepare("46001","main",backupArchive,incoming,110,template,fresh,codec,"backup",200))
packetCheck(assert(__packetPrototype.open(recovered,codec,fresh)).source.kind=="backup" and Json.canonical(backupArchive.entries.main.raw)==Json.canonical(broken),"explicit backup selection changed source")
packetCheck(__packetPrototype.prepare("other","main",archive,incoming,110,template,fresh,codec,"primary",200)==nil,"foreign archive owner accepted")
packetCheck(__packetPrototype.prepare("46001","free",archive,incoming,110,template,fresh,codec,"primary",200)==nil,"missing source slot defaulted")
local badCodec=Compression.new({serialize=codec.adapter.serialize,compress=function() return string.rep("x",Compression.MAX_STORED_CHARS+1) end,
 expandedSize=codec.adapter.expandedSize,decompress=codec.adapter.decompress,parse=codec.adapter.parse})
packetCheck(__packetPrototype.prepare("46001","main",archive,incoming,110,template,fresh,badCodec,"primary",200)==nil,"oversize compressed candidate accepted")
-- A valid union can exceed the old declared 16K budget without exceeding either
-- page/rare cardinality cap. The proposed packet format has an explicit 32K
-- global budget; it must preserve this data rather than trim either map.
local a,b=Progress.default(),Progress.default();a.rare={serial=1,claimed={},once={}};b.rare={serial=1,claimed={},once={}}
for i=1,200 do table.insert(if i<=100 then a.notebook.opened else b.notebook.opened,string.rep("p",45)..string.format("%03d",i)) end
for i=1,64 do local t=if i<=32 then a.rare else b.rare;t.claimed[string.rep("c",61)..string.format("%03d",i)]=1;t.once[string.rep("o",61)..string.format("%03d",i)]=true end
local wide=makeArchive(nil,Envelope.make(Progress.SPEC,a,100,nil))
local wideAnchor=assert(__packetPrototype.prepare("46001","main",wide,b,110,template,fresh,codec,"primary",200))
local widePacket=assert(__packetPrototype.open(wideAnchor,codec,fresh));local size=#assert(Json.canonical(widePacket.progress))
packetCheck(size>16384 and size<=__packetPrototype.MAX_PROGRESS_CHARS and #widePacket.progress.notebook.opened==200,"wide legal progress was trimmed or budget counterexample missing")
packetCheck(Json.canonical(archive)==original,"packet tests changed the original archive")
local brokenTransport=Json.copy(anchor);brokenTransport.target.data="corrupt-opaque";seal(brokenTransport)
packetCheck(__packetPrototype.open(brokenTransport,codec,fresh)==nil,"corrupt proposal transport fell back/defaulted")
for _,slot in {"main","easy","free"} do
 local problems,d=Checkpoint.inspectRecorded(source,fresh);assert(#problems==0 and d)
 d.roots.life.mode=if slot=="free" then "free" else "main";d.roots.life.rules=if slot=="main" then "standard" else "gentle";d.roots.needs.gentle=slot~="main"
 local record=Json.copy(source);record.world=assert(ObjectRecord.capture(d.roots,Checkpoint.CLASSES,Checkpoint.refs(fresh)));record.life_rules={mode=d.roots.life.mode,rules=d.roots.life.rules}
 local globals=Progress.default();globals.finished_main=true
 local sources={progress={loaded=true,value=Envelope.make(Progress.SPEC,globals,100,nil)},main={loaded=true},free={loaded=true},easy={loaded=true}}
 sources[slot].value=Envelope.make(SaveRest.SPECS[slot],record,90,nil)
 local all=assert(__packetArchive.prepare("46001","slot-"..slot,sources))
 local cell=assert(__packetPrototype.prepare("46001",slot,all,incoming,110,template,fresh,codec,"primary",200))
 local packet=assert(__packetPrototype.open(cell,codec,fresh))
 packetCheck(packet.slot==slot and packet.checkpoint.life_rules.mode==record.life_rules.mode and packet.checkpoint.life_rules.rules==record.life_rules.rules,"mode/slot packet changed during round trip")
 packetCheck(Envelope.open(SaveRest.SPECS[slot],codec:decode(cell.target)).status=="newer","old slot reader did not refuse new format")
end
print("RECOVERY_PACKET passed="..passedPacket.." failed=0 wide_progress_chars="..size)
end
