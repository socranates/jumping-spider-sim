local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Species=require("../src/Shared/Data/Species")
local Surfaces=require("../src/Shared/Data/Surfaces")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Director=require("../src/Shared/Prey/PreyDirector")
local PreyWorld=require("../src/Shared/Prey/PreyWorld")
local Memory=require("../src/Shared/Perception/ObservationMemory")
local Sensor=require("../src/Shared/Perception/Sensor")
local Needs=require("../src/Shared/Life/NeedsModel")
local Life=require("../src/Shared/Life/LifeLoop")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local Json=require("../src/Shared/Persistence/Json")
Map.use("preserve")
local root=Build.world(workspace)
local lo,hi=Map.bounds()
local motor=Motor.new({world=root,surfaces=Surfaces,profile=Species.phidippus_audax_prototype,
 spawn=Vector3.new(-25.5,.31,6),heading=Vector3.xAxis,boundsMin=lo,boundsMax=hi})
local casts=Director.casts(root)
local prey=Director.engine(root,Species.fly_like_prototype,914,4,false,nil,casts)
local memory=Memory.new();local sensor=Sensor.new(memory);sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local needs=Needs.new(true,false);prey.feeding.needs=needs
local life=Life.new(needs);life.clock.day=4;life.clock.hour=12;life.resting=true
life.growth.stage=1;life.growth.fedSinceMoult=1.2;life.growth.exuviae={Vector3.new(-110,-39.1,-1075)}
needs.energy=.57
local garden={}
local host={home=Map.HOME,map=Map,region=Map.region(Map.HOME),regionReady=function() return true end}
local population=PreyWorld.new(prey,host,garden,root,casts);population.tier="full"
for _,id in {"meadow_b4","pond_a3","pond_b2","bin","garden_a3","mown_e15"} do
 population:director(id);population:kinds(id);population:bugs(id);population:ambient(id)
end
local w={motor=motor,prey=prey,memory=memory,sensor=sensor,needs=needs,life=life,garden=garden}
local records={}
for _,id in {"bench_slats","pond_stone","sill_crevice"} do
 local r=assert(Map.retreat(id))
 local pos=(r.min+r.max)*.5
 local up=Vector3.yAxis
 if id=="bench_slats" then pos=Vector3.new(pos.X,pos.Y,r.min.Z+.31);up=Vector3.zAxis end
 motor:place(pos,up,Vector3.xAxis)
 local rec,why=Checkpoint.capture(w,0);assert(rec,why)
 local errors=Checkpoint.check(rec,w);assert(#errors==0,table.concat(errors," | "))
 records[id]=rec
end
print("[COMPACT_FIXTURE]"..assert(Json.canonical(records)))
