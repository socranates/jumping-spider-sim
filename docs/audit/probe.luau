-- Read-only diagnostic on shim worlds. Does not connect to Roblox or a DataStore.
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local LookPlan=require("../src/Shared/World/LookPlan")
local Build=require("../src/Shared/World/WorldBuild")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Director=require("../src/Shared/Prey/PreyDirector")
local PreyWorld=require("../src/Shared/Prey/PreyWorld")
local Memory=require("../src/Shared/Perception/ObservationMemory")
local Sensor=require("../src/Shared/Perception/Sensor")
local Needs=require("../src/Shared/Life/NeedsModel")
local Life=require("../src/Shared/Life/LifeLoop")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
Map.use("preserve")
local root=Build.world(workspace)
local lo,hi=Map.bounds()
local casts=Director.casts(root)
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(-25.5,.31,6),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
local prey=Director.engine(root,Species.fly_like_prototype,914,4,false,nil,casts)
local memory=Memory.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local needs=Needs.new(true,false);prey.feeding.needs=needs
local life=Life.new(needs)
local world={motor=motor,prey=prey,memory=memory,sensor=sensor,needs=needs,life=life,garden={}}
local readyCalls=0
local adapter={home=Map.HOME,map=Map,regionReady=function() readyCalls+=1;return true end}
local ecology=PreyWorld.new(prey,adapter,world.garden,root,casts)
local function measure(label)
 local rec=assert(Checkpoint.capture(world,0))
 local text=assert(Json.canonical(rec))
 local why=SaveRest.check("main",rec)
 print(`AUDIT_SAVE {label} chars={#text} cap={Rules.MAX_REST_CHARS} accepted={#why==0} problem={why[1] or "none"}`)
end
motor:place(Vector3.new(-25.5,.31,6),Vector3.yAxis,Vector3.xAxis)
measure("sill")
local n=0
for _,r in Map.regions() do
 local pieces=Region.pieces(r)
 print(`AUDIT_REGION id={r.id} kind={r.kind} walkable={#pieces} full_records={#LookPlan.records(r,"full")} low_records={#LookPlan.records(r,"low")} retreats={#r.retreats}`)
 ecology:directors(r.id);ecology:bugs(r.id);ecology:ambient(r.id)
 n+=1
 if n==10 or n==30 or n==60 or n%25==0 then measure(`visited_{n}`) end
end
measure(`visited_all_{n}`)
print(`AUDIT_READY calls={readyCalls}`)
-- A real legacy test-garden ecology, checked first in its original world.
Map.use("test_garden")
world.garden={}
local oldRoot=Build.world(workspace)
local oldEcology=PreyWorld.new(prey,adapter,world.garden,oldRoot,casts)
oldEcology:directors("bed_a");oldEcology:bugs("bed_a");oldEcology:ambient("bed_a")
local oldRecord=assert(Checkpoint.capture(world,0))
local oldWhy=SaveRest.check("main",oldRecord)
print(`AUDIT_LEGACY original_accepted={#oldWhy==0} chars={#assert(Json.canonical(oldRecord))} problem={oldWhy[1] or "none"}`)
Map.use("preserve")
local movedWhy=SaveRest.check("main",oldRecord)
print(`AUDIT_LEGACY preserve_accepted={#movedWhy==0} problem={movedWhy[1] or "none"}`)
