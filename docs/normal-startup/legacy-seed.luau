-- Unpublished engine fixture. Only synthetic memory data; never a played save.
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Shared=RS:WaitForChild("Shared")
local function shared(area,name)return require(Shared[area][name])end
local Map=shared("World","WorldMap")
local Build=shared("World","WorldBuild")
local Garden=shared("World","Garden")
local Region=shared("World","Region")
local Director=shared("Prey","PreyDirector")
local Woodlouse=shared("Prey","Woodlouse")
local Species=shared("Data","Species")
local Layout=shared("Habitat","WindowsillLayout")
local Motor=shared("Movement","SpiderMotor")
local Sensor=shared("Perception","Sensor")
local MemoryModel=shared("Perception","ObservationMemory")
local Needs=shared("Life","NeedsModel")
local Life=shared("Life","LifeLoop")
local Feeding=shared("Prey","Feeding")
local Checkpoint=shared("Persistence","Checkpoint")
local Rest=shared("Persistence","SaveRest")
local Envelope=shared("Persistence","SaveEnvelope")
local Progress=shared("Persistence","SaveProgress")
local Json=shared("Persistence","Json")
local Portable=shared("Persistence","RecoveryLifePrototype")
return function(store,codec)
 assert(game:GetService("RunService"):IsStudio() and game.PlaceId==0 and game.GameId==0 and WS:GetAttribute("LegacyStartupDiagnostic")==true)
 assert(WS:WaitForChild("World",90) and Map.world()=="preserve")
 local container=Instance.new("Folder");container.Name="SyntheticStartupLegacy";container.Parent=WS
 local casts,motor;local originals={};local expected={}
 local okay,why=xpcall(function()
  Map.use("test_garden")
  local root=Build.world(container,Map.SEED);casts=Director.casts(root)
  local prey=Director.engine(root,Species.fly_like_prototype,914,4,true,nil,casts)
  local bed=assert(Map.region("bed_a"));local spec=Garden.prey(bed)
  local bedPrey=Director.engine(root,Species.fungus_gnat_prototype,spec.seed,spec.target,false,spec,casts)
  local soil,boxes=nil,{}
  for _,piece in Region.pieces(bed)do
   if piece.id=="bed_a_soil" then soil={min=piece.lo,max=piece.hi} elseif piece.lo.Y<=-89.99 then table.insert(boxes,{min=piece.lo,max=piece.hi})end
  end
  local bugs=Woodlouse.new(Garden.bugs(bed),soil,boxes)
  local memory=MemoryModel.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
  motor=Motor.new({world=root,surfaces=shared("Data","Surfaces"),profile=Species.phidippus_audax_prototype,spawn=Layout.SPAWN,
   heading=Layout.SPAWN_HEADING,boundsMin=Layout.PLAY_BOUNDS_MIN,boundsMax=Layout.PLAY_BOUNDS_MAX})
  motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
  for _,mode in {"main","free","easy"}do
   local needs=Needs.new(true,mode~="main");needs:useGameRules();needs.energy=.5
   local amount=needs:grantEnergy(.25,"legacy_meal_"..mode)
   local feeding=Feeding.new(needs);feeding:useGameRules();feeding.tapToFeed=true
   feeding.taken=amount;feeding.granted=amount;feeding.ledger["legacy_meal_"..mode]=amount;feeding.mealsFinished=1
   prey.feeding=feeding;bedPrey.feeding=feeding
   local life=Life.new(needs,nil);life:useGameRules();life.growth:useGameRules(mode~="main")
   life.mode=if mode=="free" then "free" else "main";life.rules=if mode=="main" then "standard" else "gentle"
   life.elapsed=120;needs.elapsedS=120;life.clock.day=3;life.clock.hour=10;life.growth.stage=1;life.growth.fedSinceMoult=.1;life.grantedSeen=amount
   local old={motor=motor,prey=prey,sensor=sensor,memory=memory,needs=needs,life=life,garden={bed_a={prey=bedPrey,bugs=bugs}}}
   local record=assert(Checkpoint.capture(old,120));record.save_life="startup-legacy-"..mode
   local capsule,problem=Portable.prepare(record,Rest.stubWorld(),"A1_qa_normal_startup");assert(capsule,problem)
   local decoded=assert(Portable.decode(capsule));assert(decoded.life.growth.stage==1 and decoded.needs.grantedTotal==.25)
   local raw=codec:encode(Envelope.make(Rest.SPECS[mode],record,100,nil));assert(raw)
   originals[mode]=assert(Json.canonical(raw));store:poke("R_qa_normal_startup_"..mode,raw)
   expected[mode]={stage=1,food=.25,elapsed=120,day=3,energy=.75,meal="legacy_meal_"..mode}
  end
 end,debug.traceback)
 if casts and casts.probe then casts.probe:Destroy() end
 if motor then motor:destroy() end
 container:Destroy();Map.use("preserve");assert(okay,why)
 local progress=Progress.default();progress.finished_main=true
 store:poke("P_qa_normal_startup",Envelope.make(Progress.SPEC,progress,100,nil))
 return originals,expected
end
