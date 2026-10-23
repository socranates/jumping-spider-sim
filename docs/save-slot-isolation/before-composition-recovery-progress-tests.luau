do
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local RareLedger=require("../src/Shared/Life/RareLedger")
local RareDirector=require("../src/Shared/Life/RareDirector")
local Catalog=require("../src/Shared/Data/RareSightings")
local passedProgress=0
local function progressCheck(ok,why) assert(ok,why);passedProgress+=1 end
local capsule=assert(__lifePrototype.prepare(source,live,"A1_46001"))
local base=Progress.default();base.notebook.opened={"old_page","future_page"};base.notebook.eye_seconds=100
base.finished_main=true;base.appearance="phidippus_audax_female";base.intro_seen=true;base.hut_window=true
base.settings={SoundMuted=false,MasterVolume=.6,Captions="off"};base.rare={serial=9,claimed={older_species=7},once={earlier_unique=true}}
local raw=Envelope.make(Progress.SPEC,base,100,nil,{lock={session="owned",beat=100}})
raw.backup={schema=999,updatedAt=90,payload={opaque="future backup untouched"},checksum="opaque"}
local incoming=Progress.default();incoming.notebook.opened={"new_page","old_page"};incoming.notebook.eye_seconds=200
incoming.appearance="maratus_volans_male";incoming.settings={MasterVolume=.8,FocusToggle=true}
incoming.rare={serial=11,claimed={newer_species=10},once={new_unique=true}}
local originalRaw=assert(Json.canonical(raw));local originalIncoming=assert(Json.canonical(incoming));local originalCapsule=assert(Json.canonical(capsule))
local result,why=__progressPrototype.prepare(raw,incoming,110,capsule,"main")
progressCheck(result~=nil,"global projection failed: "..tostring(why))
local p=result.progress;local bound=assert(__lifePrototype.decode(result.life))
progressCheck(#p.notebook.opened==3 and p.notebook.opened[1]=="old_page" and p.notebook.opened[3]=="new_page" and p.notebook.eye_seconds==200,"notebook union/eye time lost")
progressCheck(p.finished_main and p.intro_seen and p.hut_window,"monotonic discovery/unlock flags lost")
progressCheck(p.appearance==incoming.appearance and p.settings.MasterVolume==.8 and p.settings.SoundMuted==false and p.settings.FocusToggle==true and p.settings.Captions=="off","timestamped appearance/settings merge differs")
progressCheck(p.rare.serial==11 and p.rare.claimed.older_species==7 and p.rare.claimed.newer_species==10 and p.rare.once.earlier_unique and p.rare.once.new_unique,"rare high-water/once history lost")
progressCheck(bound.life.rareSerial==11 and bound.life.rareGeneration==0 and bound.life.rareBorn==bound.life.clock.day,"legacy life was not bound without a new roll")
progressCheck(result.binding.serial==11 and result.source.schema==2 and result.source.updatedAt==100 and not result.destinationCommitAuthorized,"binding/source metadata or authority boundary differs")
progressCheck(#select(1,Progress.sanitize(p))==0 and table.isfrozen(result.progress.settings),"prepared global data invalid or mutable")
progressCheck(Json.canonical(raw)==originalRaw and Json.canonical(incoming)==originalIncoming and Json.canonical(capsule)==originalCapsule,"global projection edited source/current/life")
local twice=assert(__progressPrototype.prepare(raw,incoming,110,capsule,"main"))
progressCheck(Json.canonical(twice)==Json.canonical(result),"retry with identical observations allocated another identity")
local older=assert(__progressPrototype.prepare(raw,incoming,90,capsule,"main"))
progressCheck(older.progress.appearance==base.appearance and older.progress.settings.MasterVolume==.6 and older.progress.settings.FocusToggle==true,"older current preferences overwrote later stored choices")
-- Schema 1's exact supported preferences become settings; duplicate page ids
-- normalize as a set, and explicit false monotonic flags mean absent/false.
local oldSpec={kind="progress",current=1,migrations={},validate=function(p) return {},p end}
local old={notebook={opened={"old_page","old_page"},eye_seconds=30},finished_main=false,appearance="legacy_spider",
 prefs={FocusToggle=true,ReducedMotion=true,SoundMuted=false},intro_seen=false,hut_window=false}
local oldRaw=Envelope.make(oldSpec,old,10,nil);local oldText=Json.canonical(oldRaw)
local migrated=assert(__progressPrototype.prepare(oldRaw,Progress.default(),0,capsule,"main"))
progressCheck(#migrated.progress.notebook.opened==1 and migrated.progress.settings.FocusToggle and migrated.progress.settings.ReducedMotion and migrated.progress.settings.SoundMuted==false,"supported schema1 preferences/pages lost")
progressCheck(migrated.source.schema==1 and migrated.progress.appearance=="legacy_spider" and Json.canonical(oldRaw)==oldText,"schema1 source/appearance changed")
local function rareCapsule(serial,generation,visit)
 local problems,d=Checkpoint.inspectRecorded(source,live);assert(#problems==0 and d)
 local l=d.roots.life;l.clock.day=3;l.clock.hour=21;l.rareSerial=serial;l.rareGeneration=generation;l.rareBorn=1
 l.rareVisit=if visit then {id=Catalog.luna.id,serial=serial,day=3,hour=20.5} else nil
 local r=Json.copy(source);r.world=assert(ObjectRecord.capture(d.roots,Checkpoint.CLASSES,Checkpoint.refs(live)))
 return assert(__lifePrototype.prepare(r,live,"A1_46001"))
end
local olderLife=rareCapsule(7,0,true)
local global=Progress.default();global.rare={serial=20,claimed={[Catalog.luna.id]=20},once={}}
local boundOld=assert(__progressPrototype.prepare(Envelope.make(Progress.SPEC,global,100,nil),Progress.default(),0,olderLife,"main"))
local oldLife=assert(__lifePrototype.decode(boundOld.life));local ledger=Json.copy(boundOld.progress.rare)
progressCheck(oldLife.life.rareSerial==7 and ledger.serial==20 and ledger.claimed[Catalog.luna.id]==20,"rewound rest lowered high-water marks or obtained a new roll")
local visit=RareDirector.step(ledger,oldLife.life,914)
progressCheck(visit~=nil and visit.serial==7 and ledger.serial==20,"recorded visit did not restore as that same animal")
oldLife.life.rareVisit=nil
progressCheck(RareDirector.step(ledger,oldLife.life,914)==nil and ledger.serial==20,"rewound life scheduled an already claimed animal")
local absent=Progress.default()
local evidence=assert(__progressPrototype.prepare(Envelope.make(Progress.SPEC,absent,100,nil),Progress.default(),0,olderLife,"main"))
progressCheck(evidence.progress.rare.serial==7 and evidence.progress.rare.claimed[Catalog.luna.id]==7,"recorded visit did not restore missing claim evidence")
progressCheck(__progressPrototype.prepare(raw,incoming,110,rareCapsule(7,1,false),"main")==nil,"mismatched generation silently allocated another rare life")
-- The ordinary merge truncates an overflowing union; migration must refuse it.
local full=Progress.default();for i=1,200 do table.insert(full.notebook.opened,"page_"..i) end
local extra=Progress.default();extra.notebook.opened={"extra_page"}
progressCheck(#Progress.merge(full,extra,0,1).notebook.opened==200,"page cap counterexample did not reproduce")
progressCheck(__progressPrototype.prepare(Envelope.make(Progress.SPEC,full,0,nil),extra,1,capsule,"main")==nil,"overflowing notebook union silently lost a page")
for _,field in {"claimed","once"} do
 local a,b=Progress.default(),Progress.default();a.rare=RareLedger.new();b.rare=RareLedger.new();a.rare.serial=1;b.rare.serial=1
 for i=1,64 do a.rare[field]["old_"..i]=if field=="once" then true else 1;b.rare[field]["new_"..i]=if field=="once" then true else 1 end
 progressCheck(Progress.merge(a,b,0,1).rare.blocked==true,"rare cap counterexample did not reproduce")
 progressCheck(__progressPrototype.prepare(Envelope.make(Progress.SPEC,a,0,nil),b,1,capsule,"main")==nil,"overflowing rare union silently discarded history")
end
for _,edit in {
 function(r) r.payload.extra=true end,
 function(r) r.payload.notebook.extra=true end,
 function(r) r.payload.settings.UnknownFuture=true end,
 function(r) r.payload.settings.MasterVolume=99 end,
 function(r) r.payload.rare.extra=true end,
 function(r) r.payload.settings_version=999 end,
} do
 local r=Json.copy(raw);edit(r)
 -- Recompute the primary checksum, so these cases exercise mapping refusals,
 -- not a checksum failure masking silent sanitization.
 r=Envelope.make(Progress.SPEC,r.payload,100,nil)
 progressCheck(__progressPrototype.prepare(r,incoming,110,capsule,"main")==nil,"unsupported global data silently normalized away")
end
for _,edit in {
 function(r) r.schema=999 end,
 function(r) r.checksum="bad" end,
 function(r) r.kind="rest_main" end,
} do local r=Json.copy(raw);edit(r);progressCheck(__progressPrototype.prepare(r,incoming,110,capsule,"main")==nil,"unreadable/newer primary fell back or defaulted") end
progressCheck(__progressPrototype.prepare(nil,incoming,110,capsule,"main")==nil,"missing primary defaulted")
progressCheck(__progressPrototype.prepare(raw,incoming,0/0,capsule,"main")==nil,"bad clock accepted")
progressCheck(__progressPrototype.prepare(raw,incoming,110,capsule,"free")==nil,"wrong selected slot accepted")
local clock=0;local function now() clock+=.00001;return clock end
local worker=Work.new(function() return __progressPrototype.prepare(raw,incoming,110,capsule,"main") end,{now=now,budget=.000001,maxSeconds=100,maxResumes=10000})
local suspensions=0
while worker.state=="pending" do
 worker:step();progressCheck(Json.canonical(raw)==originalRaw and Json.canonical(incoming)==originalIncoming,"suspended global preparation edited input")
 if worker.state=="pending" then suspensions+=1 end
end
local prepared=worker:take();progressCheck(prepared and prepared[1] and Json.canonical(prepared[1])==Json.canonical(result) and suspensions>0,"cooperative global result changed or failed")
local cancel=Work.new(function() return __progressPrototype.prepare(raw,incoming,110,capsule,"main") end,{now=now,budget=.000001,maxSeconds=100})
cancel:step();progressCheck(cancel.state=="pending" and cancel:cancel() and cancel:take()==nil,"cancelled global preparation exposed output")
print("RECOVERY_PROGRESS passed="..passedProgress.." failed=0 suspensions="..suspensions)
end
