do
local function runFormatChecks()
local Format=__restFormatPrototype
local Progress=require("../src/Shared/Persistence/SaveProgress")
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local Rare=require("../src/Shared/Life/RareDirector")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local initial=assert(Format.fromProposal(anchor,codec,fresh));local initialText=assert(Json.canonical(initial));local originalArchive=assert(Json.canonical(archive))
check(Format.check("main",initial,fresh)==nil and initial.entryKind=="rest" and table.isfrozen(initial) and table.isfrozen(initial.provenance),"continued recovery format was not owned/valid")
check(Format.matchesProposal(initial,anchor,codec,fresh),"continued provenance did not match immutable proposal")
check(initial.provenance.proposal==anchor.id and initial.provenance.archive.manifest==anchor.archive and initial.provenance.historyChecksum~=nil,"continued provenance omitted archive/history")
local initialLogical=codec:decode(anchor.target)
check(Envelope.open(Format.spec("main",fresh),initialLogical).status=="ok","union reader lost original import packet")
local normal=Envelope.make(SaveRest.SPECS.main,template,100,nil)
local normalRead=Envelope.open(Format.spec("main",fresh),normal)
check(normalRead.status=="migrated" and Json.canonical(normalRead.payload)==Json.canonical(template),"union reader changed an ordinary schema2 rest")
local marker=Envelope.make(SaveRest.SPECS.main,{save_retired=true,save_life="ordinary-retired"},100,nil)
check(Envelope.open(Format.spec("main",fresh),marker).payload.save_retired,"union reader lost ordinary retirement")
-- Real checkpoint restore/capture, followed by repeated encoded current/backup
-- saves. The original proposal/history reference never nests prior saves.
local live=newWorld();local okay,problems=Checkpoint.restore(initial.checkpoint,live);assert(okay,table.concat(problems,";"))
local prior=initial;local stored=Envelope.make(Format.spec("main",live),initial,200,nil);local reference=Json.canonical(initial.provenance)
local sizes={};local backend=Memory.new()
for i=1,5 do
 live.life:step(.1,{inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=live.motor.pos},false,false)
 local record=assert(Checkpoint.capture(live,200+i));record.save_life=initial.save_life
 local current,why=Format.advance(prior,record,live);check(current~=nil,"subsequent real checkpoint refused: "..tostring(why))
 local logical=Envelope.make(Format.spec("main",live),current,200+i,stored)
 local encoded=codec:encode(logical);local decoded=codec:decode(encoded)
 check(Envelope.open(Format.spec("main",live),decoded).status=="ok" and decoded.backup~=nil and decoded.backup.backup==nil,"schema3 current/backup round trip lost shape")
 check(Json.canonical(current.provenance)==reference and Format.matchesProposal(current,anchor,codec,live),"successive save changed original provenance")
 check(Envelope.open(__productionRest.SPECS.main,decoded).status=="newer","old reader accepted a continued schema3 save")
 local ok=backend:update("R_format_main",function() return encoded end);local read,value=backend:read("R_format_main");check(ok and read and Json.canonical(value)==Json.canonical(encoded),"continued stored transport changed bytes")
 check(Format.check("main",current,live)==nil and not select(2,Format.check("main",current,live)).gameplayAuthorized,"format validation granted gameplay authority")
 sizes[i]=#assert(Json.canonical(current));stored,prior=logical,current
end
check(math.max(table.unpack(sizes))-math.min(table.unpack(sizes))<512,"successive save nested/grew archive history")
check(Json.canonical(initial)==initialText and Json.canonical(archive)==originalArchive,"subsequent saves changed original packet/archive")
-- A direct schema2-shaped checkpoint must not drop the metadata wrapper.
local stripped=Envelope.make(SaveRest.SPECS.main,prior.checkpoint,300,nil)
check(Envelope.open(Format.spec("main",live),stripped).status=="invalid","recovered graph accepted without schema3 provenance")
-- Actual mating/carry-on functions advance the current generation while the
-- original import generation and history remain fixed.
live.life.growth.stage=3;live.life.mating=Mating.new();live.life.mating.stage="hatched";live.life.mating.hatch_day=live.life.clock.day;live.life.mating.brood=3
local hatch=assert(Checkpoint.capture(live,310));hatch.save_life=initial.save_life
local hatching=assert(Format.advance(prior,hatch,live))
check(hatching.entryKind=="hatching" and hatching.provenance.originGeneration==initial.provenance.originGeneration,"hatching changed original entry/generation reference")
local nextGeneration=Mating.carryOn(live.life,live.needs,live.prey.feeding.mealsFinished)
local ledger=Json.copy(assert(__packetPrototype.open(anchor,codec,fresh)).progress.rare);Rare.ensureLife(ledger,live.life)
local nextRecord=assert(Checkpoint.capture(live,311));nextRecord.save_life=initial.save_life
local nextRest=assert(Format.advance(hatching,nextRecord,live))
check(nextRest.entryKind=="rest" and nextGeneration>initial.provenance.originGeneration and Json.canonical(nextRest.provenance)==reference,"next generation rewrote original provenance or remained hatching")
check(select(2,Format.check("main",nextRest,live)).decoded.roots.life.generation==nextGeneration,"next generation was not retained by schema3")
-- Current scene kind is independent of the immutable original scene kind.
live.life.growth.stage=3;live.life.mating=Mating.new();live.life.mating.stage="courted";live.life.mate=Mate.new();live.life.mate.state="pair";live.life.mate.scene=true;live.life.mate.meter=1
local courted=assert(Checkpoint.capture(live,312));courted.save_life=initial.save_life
local mating,matError=Format.advance(nextRest,courted,live)
check(mating~=nil and mating.entryKind=="mating","current mating entry refused: "..tostring(matError))
-- A dead current graph must never enter the ordinary restore, which resets
-- lifeOver. An explicit retirement payload carries the original archive ref.
live.life.lifeOver=true;local ended=assert(Checkpoint.capture(live,313));ended.save_life=initial.save_life
check(Format.advance(nextRest,ended,live)==nil,"ended life was packaged as an active resume")
local retired=assert(Format.retire(nextRest,"new-life-token",live))
check(SaveRest.isRetired(retired) and retired.checkpoint==nil and Json.canonical(retired.provenance)==reference,"retirement lost original archive provenance")
local retiredLogical=Envelope.make(Format.spec("main",live),retired,400,stored)
check(Envelope.open(Format.spec("main",live),codec:decode(codec:encode(retiredLogical))).payload.save_retired,"schema3 retirement transport failed")
check(Format.advance(retired,nextRecord,live)==nil,"retired format was revived by advancing a checkpoint")
-- Known formats are strict: no new/foreign fields, history edits, identity
-- swaps, hidden backups or generation rewind can silently survive validation.
for _,edit in {
 function(p) p.version=2 end,
 function(p) p.extra=true end,
 function(p) p.slot="free" end,
 function(p) p.provenance.owner="other" end,
 function(p) p.provenance.proposal="M1_other_main" end,
 function(p) p.provenance.archive.extra=true end,
 function(p) p.provenance.archive.manifest="broken" end,
 function(p) p.provenance.source.schema=999 end,
 function(p) p.provenance.historyChecksum="0000000000000000" end,
 function(p) p.provenance.originBinding="wrong" end,
 function(p) p.provenance.originGeneration=999 end,
 function(p) p.entryKind="mating" end,
 function(p) p.save_life="foreign-life" end,
 function(p) p.save_retired=true end,
 function(p) p.checkpoint.save_retired=true end,
 function(p) p.provenance.originLife="bad token!" end,
 function(p) p.provenance.source.updatedAt=0/0 end,
} do
 local p=Json.copy(initial);edit(p);check(Format.check("main",p,live)~=nil,"mutated continued rest accepted")
end
local historyEdit=newWorld();assert(Checkpoint.restore(initial.checkpoint,historyEdit));historyEdit.life.recoveryHistory.entryKind="mating"
local edited=assert(Checkpoint.capture(historyEdit,500));edited.save_life=initial.save_life
check(Format.advance(initial,edited,historyEdit)==nil,"historical entry kind was rewritten as current scene state")
for _,edit in {function(p) p.checkpoint=initial.checkpoint end,function(p) p.entryKind="rest" end,function(p) p.save_life="bad!" end,function(p) p.save_retired=false end} do
 local p=Json.copy(retired);edit(p);check(Format.check("main",p,live)~=nil,"malformed retirement accepted")
end
-- Format preparation is cooperative and owns its output; it performs no I/O.
local before=backend.requests;local cpu=0;local function now() cpu+=.00001;return cpu end
local work=Work.new(function() return Format.fromProposal(anchor,codec,fresh) end,{budget=.00001,now=now,maxSeconds=1000,maxResumes=10000})
local suspensions=0;while work.state=="pending" do work:step();suspensions+=1 end
local result=work:take();check(result and result[1] and table.isfrozen(result[1]) and suspensions>1 and backend.requests==before,"cooperative format preparation failed or performed I/O")
for _,slot in {"main","free","easy"} do
 WorldMap.use("test_garden");local w=gardenWorld();w.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 w.life.mode=if slot=="free" then "free" else "main";w.life.rules=if slot=="main" then "standard" else "gentle";w.needs.gentle=slot~="main"
 local old=assert(Checkpoint.capture(w,600));old.save_life="original-"..slot
 WorldMap.use("preserve")
 local sources={progress={loaded=true,value=Envelope.make(Progress.SPEC,{notebook={opened={},eye_seconds=0},finished_main=true,settings={},settings_version=Progress.default().settings_version},100,nil)},main={loaded=true},free={loaded=true},easy={loaded=true}}
 sources[slot].value=Envelope.make(SaveRest.SPECS[slot],old,100,nil)
 local a=assert(__packetArchive.prepare("46001","all-modes",sources))
 local proposal,why=__packetPrototype.prepare("46001",slot,a,Progress.default(),100,template,fresh,codec,"primary",601)
 assert(proposal,why)
 local value,errorText=Format.fromProposal(proposal,codec,fresh);check(value~=nil and value.slot==slot and value.save_life==old.save_life,"slot format preparation failed: "..slot..": "..tostring(errorText))
 check(Format.check(slot,value,fresh)==nil and Format.matchesProposal(value,proposal,codec,fresh),"slot provenance validation failed: "..slot)
 local mark=assert(Format.retire(value,"retired-"..slot,fresh))
 check(Envelope.open(Format.spec(slot,fresh),codec:decode(codec:encode(Envelope.make(Format.spec(slot,fresh),mark,602,nil)))).payload.save_retired,"slot retirement round trip failed: "..slot)
 check(Format.check(if slot=="main" then "free" else "main",value,fresh)~=nil,"slot-scoped format accepted under a different mode")
end
print("RECOVERY_REST_FORMAT passed="..count.." failed=0 suspensions="..suspensions)
end
runFormatChecks()
end
