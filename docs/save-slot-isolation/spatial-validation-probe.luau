-- Source-bound corruption probe; never applied to live game/save data.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Species=require("../src/Shared/Data/Species")
local Director=require("../src/Shared/Prey/PreyDirector")
local Needs=require("../src/Shared/Life/NeedsModel")
local Life=require("../src/Shared/Life/LifeLoop")
local Sensor=require("../src/Shared/Perception/Sensor")
local Memory=require("../src/Shared/Perception/ObservationMemory")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local Json=require("../src/Shared/Persistence/Json")
Map.use("test_garden");workspace:ClearAllChildren()
local root=Build.world(workspace)
local home=Director.engine(root,Species.fly_like_prototype,914,4,true)
local needs=Needs.new(true,false);home.feeding.needs=needs
local memory=Memory.new();local sensor=Sensor.new(memory)
sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local w={prey=home,needs=needs,life=Life.new(needs,nil),sensor=sensor,memory=memory,
 motor={pos=Vector3.new(-25.5,.31,6),up=Vector3.yAxis,heading=Vector3.zAxis,gazePitch=0}}
local control=assert(Checkpoint.capture(w,0));assert(#SaveRest.check("main",control)==0,"invalid control")
print("SPATIAL_CONTROL valid=1")
local fly=assert(home.flies[1]);local original=fly.position
for _,item in {{"nan",Vector3.new(0,0/0,0)},{"positive_inf",Vector3.new(math.huge,0,0)},
 {"negative_inf",Vector3.new(0,0,-math.huge)},{"plain_xyz",{X=0,Y=0,Z=0}},{"empty_table",{}}} do
 fly.position=item[2]
 local record=assert(Checkpoint.capture(w,0));assert(Json.canonical(record))
 local problems=SaveRest.check("main",record)
 print("SPATIAL_CASE",item[1],#problems==0 and "ACCEPTED" or "REFUSED",table.concat(problems,";"))
end
fly.position=original
assert(#SaveRest.check("main",assert(Checkpoint.capture(w,0)))==0,"fixture not restored")
print("SPATIAL_CONTROL valid=2")
