do
local Build=require("../src/Shared/World/WorldBuild")
local Region=require("../src/Shared/World/Region")
local PreyWorld=require("../src/Shared/Prey/PreyWorld")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local MemoryBackend=require("../src/Shared/Persistence/MemoryBackend")
local Mating=require("../src/Shared/Life/Mating")
local Mate=require("../src/Shared/Predator/Mate")
local passedDestination=0
local function destinationCheck(ok,why) assert(ok,why);passedDestination+=1 end
WorldMap.use("preserve")
local root=Instance.new("Folder");root.Name="RecoveryFreshPreserve";root.Parent=workspace
local ready={}
local function add(id)
 Build.region(assert(WorldMap.region(id)),root);ready[id]=true
end
for _,id in {"sill","garden_c3","meadow_b4","pond_b1"} do add(id) end
local casts=PreyDirector.casts(root);local lo,hi=WorldMap.bounds()
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Layout.SPAWN,heading=Layout.SPAWN_HEADING,boundsMin=lo,boundsMax=hi})
motor:place(Vector3.new(-25.5,.31,6),Vector3.yAxis,Vector3.xAxis)
local prey=PreyDirector.engine(root,Species.fly_like_prototype,914,4,true,nil,casts)
local memory=ObservationMemory.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local needs=NeedsModel.new(true,false);needs:useGameRules();prey.feeding.needs=needs;prey.feeding:useGameRules()
local life=LifeLoop.new(needs);life:useGameRules();life.growth:useGameRules()
local fresh={motor=motor,prey=prey,sensor=sensor,memory=memory,needs=needs,life=life,garden={}}
local adapter={map=WorldMap,home=WorldMap.HOME,region=WorldMap.region(WorldMap.HOME),regionReady=function(self,id) return ready[id]==true end}
local manager=PreyWorld.new(prey,adapter,fresh.garden,root,casts)
local outside=0
for _,id in {"garden_c3","meadow_b4","pond_b1"} do
 for _,director in manager:directors(id) do outside+=#director.flies end
 manager:bugs(id);manager:ambient(id)
end
destinationCheck(outside>0 and next(fresh.garden)~=nil,"fresh authored fixture has no outside life")
local template=assert(Checkpoint.capture(fresh,456));local templateText=assert(Json.canonical(template))
destinationCheck(#Checkpoint.check(template,fresh)==0 and template.player.retreat_id=="sill_crevice","fresh template invalid or outside home retreat")
local portable=assert(__lifePrototype.prepare(source,fresh,"A1_46001"))
local package,why=__destinationPrototype.prepare(portable,template,fresh,"main")
destinationCheck(package~=nil,"destination failed: "..tostring(why))
destinationCheck(package.status=="prepared-only" and package.destinationCommitAuthorized==false and not package.requiresSceneResume,"checkpoint preparation granted commit/scene authority")
local record=package.checkpoint;local p,decodedDestination=Checkpoint.check(record,fresh)
destinationCheck(#p==0 and decodedDestination~=nil and #SaveRest.check("main",record,fresh)==0,"assembled checkpoint failed complete validators")
destinationCheck(#__productionCheckpoint.check(record,fresh)==0 and #__productionRest.check("main",record,fresh)==0,"unmodified production validators refused assembled checkpoint")
destinationCheck(#__productionCheckpoint.check(source,fresh)>0 and __productionCheckpoint.prepare(source,fresh)==nil,"ordinary production Continue protection was loosened")
local r=decodedDestination.roots
destinationCheck(r.life.needs==r.needs and r.prey.feeding.needs==r.needs,"assembled shared reserve identity lost")
destinationCheck(r.life.growth.stage==1 and r.life.growth:canRun() and not r.life.growth:canLock(),"imported instar or unlocks changed")
destinationCheck(r.life.recoveryHistory.archive=="A1_46001" and r.life.recoveryHistory.origin.region=="bed_a","history provenance missing")
destinationCheck(r.garden.bed_a==nil,"old garden entered fresh Preserve populations")
local retainedRegions=0
for id in fresh.garden do destinationCheck(r.garden[id]~=nil,"fresh Preserve population lost: "..id);retainedRegions+=1 end
destinationCheck(retainedRegions>=2,"fresh fixture has too few populated regions")
local function inspectDirectors(roots)
 local function inspect(d)
  destinationCheck(d.feeding==roots.prey.feeding,"regional prey has separate feeding books")
  for _,fly in d.flies do destinationCheck(fly.captureSerial==0 and fly.nutrition==fly.profile.body.nutrition,"fresh prey inherited an old capture/meal") end
 end
 inspect(roots.prey)
 for _,entry in roots.garden do if entry.prey then inspect(entry.prey) end;for _,d in entry.kinds or {} do inspect(d) end end
end
inspectDirectors(r)
destinationCheck(Json.canonical(template)==templateText and Json.canonical(source)==original,"assembly mutated source/template")
-- Current checkpoint restore/capture must preserve the inert provenance and
-- historical book keys; this is a CLI graph round trip, not durable migration.
local ok,errors=Checkpoint.restore(record,fresh)
destinationCheck(ok,"assembled checkpoint did not restore: "..table.concat(errors,";"))
local again=assert(Checkpoint.capture(fresh,457))
destinationCheck(#SaveRest.check("main",again,fresh)==0,"re-captured destination does not validate")
local productionAgain=assert(__productionCheckpoint.capture(fresh,457))
destinationCheck(Json.canonical(productionAgain)==Json.canonical(again) and #__productionRest.check("main",productionAgain,fresh)==0,"production capture changed imported graph/provenance")
local store=MemoryBackend.new();local envelope=Envelope.make(__productionRest.SPECS.main,productionAgain,457,nil)
local stored=store:update("R_isolated_candidate_main",function() return envelope end)
local read,value=store:read("R_isolated_candidate_main");local opened=Envelope.open(__productionRest.SPECS.main,value)
destinationCheck(stored and read and opened.status=="ok" and Json.canonical(opened.payload)==Json.canonical(productionAgain),"isolated envelope/storage-shape round trip failed")
destinationCheck(fresh.life.recoveryHistory.archive=="A1_46001" and fresh.needs.grantedBySource["@archive/A1_46001/fly_1:1"]~=nil,"round trip lost provenance or historical food")
local q=assert(select(2,Checkpoint.check(again,fresh)));inspectDirectors(q.roots)
-- A previously absent authored region creates ordinary new ids while joining
-- the imported feeding model; historical keys remain separate.
add("garden_c4")
local late=manager:directors("garden_c4")
destinationCheck(#late>0,"late streamed region made no prey")
for _,d in late do destinationCheck(d.feeding==fresh.prey.feeding and d.feeding.needs==fresh.needs,"late prey did not join imported books") end
local afterStream=assert(Checkpoint.capture(fresh,458))
destinationCheck(#SaveRest.check("main",afterStream,fresh)==0,"late population made destination invalid")
for _,slot in {"main","easy","free"} do
 local c=Json.copy(portable)
 -- Generate the modes through actual source records, not by patching encoded
 -- portable objects and bypassing the life/record agreement check.
 WorldMap.use("test_garden");local w=gardenWorld();w.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 w.life.mode=if slot=="free" then "free" else "main";w.life.rules=if slot=="main" then "standard" else "gentle";w.needs.gentle=slot~="main"
 w.life.growth.stage=3;w.life.mating=Mating.new();w.life.mating.stage="guarding";w.life.mating.sac_day=4;w.life.mating.guard_day=2
 w.life.mate=Mate.new();w.life.generation=2;w.life.born=3;w.life.mealsBase=4;w.prey.feeding.mealsFinished=7
 local old=assert(Checkpoint.capture(w,123));WorldMap.use("preserve")
 c=assert(__lifePrototype.prepare(old,fresh,"A1_46001"))
 local out=assert(__destinationPrototype.prepare(c,template,fresh,slot))
 destinationCheck(#SaveRest.check(slot,out.checkpoint,fresh)==0,"slot rules or full validation failed: "..slot)
 local d=assert(select(2,Checkpoint.check(out.checkpoint,fresh)));local born,meals=Mating.grace(d.roots.life,d.roots.prey.feeding.mealsFinished)
 destinationCheck(born==3 and meals==3 and d.roots.life.mating.stage=="guarding","grace/brood progress changed during assembly")
 destinationCheck(d.roots.life.mate.region==Mate.new().region and d.roots.life.rival.region~=nil,"actors were not authored for current Preserve")
end
local broken=Json.copy(template)
for _,object in broken.world.objects do if object.c=="PreyDirector" then for _,entry in object.e do if entry[1]=="captures" then entry[2]=1;break end end;break end end
destinationCheck(__destinationPrototype.prepare(portable,broken,fresh,"main")==nil,"played population accepted as fresh template")
destinationCheck(__destinationPrototype.prepare(portable,template,fresh,"free")==nil,"mismatched destination slot accepted")
for _,stage in {"courted","hatched"} do
 WorldMap.use("test_garden");local w=gardenWorld();w.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
 w.life.growth.stage=3;w.life.mating=Mating.new();w.life.mating.stage=stage;w.life.mate=Mate.new()
 if stage=="courted" then w.life.mate.state="pair";w.life.mate.scene=true
 else w.life.mating.hatch_day=8;w.life.mating.hatch_hour=7;w.life.mating.brood=14 end
 local source=assert(Checkpoint.capture(w,123));WorldMap.use("preserve")
 local capsule=assert(__lifePrototype.prepare(source,fresh,"A1_46001"));local out=assert(__destinationPrototype.prepare(capsule,template,fresh,"main"))
 local kind=if stage=="courted" then "mating" else "hatching"
 destinationCheck(out.requiresSceneResume and out.entryKind==kind and not out.destinationCommitAuthorized,"scene/ending recovery was treated as an ordinary playable rest")
 local d=assert(select(2,Checkpoint.check(out.checkpoint,fresh)))
 destinationCheck(d.roots.life.mating.stage==stage and d.roots.life.recoveryHistory.entryKind==kind,"scene stage/provenance lost")
end
do
 local played=Json.copy(template)
 for _,object in played.world.objects do if object.c=="NeedsModel" then for _,e in object.e do if e[1]=="elapsedS" then e[2]=1;break end end;break end end
 destinationCheck(__destinationPrototype.prepare(portable,played,fresh,"main")==nil,"template with elapsed action time accepted as fresh")
end
destinationCheck(Json.canonical(template)==templateText and Json.canonical(source)==original,"later assembly edited source/template")
print("RECOVERY_DESTINATION passed="..passedDestination.." failed=0 outside_flies="..outside.." populated_regions="..retainedRegions)
root:Destroy()
end
