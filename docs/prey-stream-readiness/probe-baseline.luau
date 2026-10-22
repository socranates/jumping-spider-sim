-- Current cached-population streaming gate, actual directors under CLI box-world emulation.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Species=require("../src/Shared/Data/Species")
local Director=require("../src/Shared/Prey/PreyDirector")
local PreyWorld=require("../src/Shared/Prey/PreyWorld")
local Sensor=require("../src/Shared/Perception/Sensor")
local Memory=require("../src/Shared/Perception/ObservationMemory")
Map.use("test_garden");workspace:ClearAllChildren()
local root=Build.world(workspace);local ready=true;local bed=assert(Map.region("bed_a"))
local world={home="sill",map=Map,region=bed,regionReady=function(_,id) return id==bed.id and ready end}
local home=Director.engine(root,Species.fly_like_prototype,914,4,true)
local garden={};local pw=PreyWorld.new(home,world,garden,root,{probe=home.probe,cast=home.graph.cast,sweep=home.graph.sweep,overlap=home.graph.overlap})
local sensor=Sensor.new(Memory.new());sensor:configureFrom(Species.phidippus_audax_prototype.perception)
local at=bed.spawn.pos+Vector3.yAxis*.31
local observer={eye=at+Vector3.yAxis*.09,gaze=Vector3.zAxis,up=Vector3.yAxis,heading=Vector3.zAxis}
local camera={CFrame=CFrame.new(at+Vector3.new(0,5,12)),FieldOfView=70,ViewportSize=Vector2.new(1280,720)}
local cast=Sensor.workspaceCast(home.params or (function() local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Include;p.FilterDescendantsInstances={root};return p end)())
local motor={mode="attached",events={},pos=at,preparing=false,moving=false,vel=Vector3.zero,heading=Vector3.zAxis,up=Vector3.yAxis,eyePosition=function() return observer.eye end}
local function tick() pw:before(1/60,at,observer,sensor,cast,camera,12);pw:after(1/60,motor,sensor,cast) end
tick();local entry=assert(garden.bed_a);local d=assert(entry.prey);local before=d.now;local made=pw.made
local pass,fail=0,0
local function check(ok,why) if ok then pass+=1 else fail+=1;print("FAIL PREY_STREAM "..why) end end
ready=false
for _=1,12 do tick() end
check(table.find(pw.active,bed.id)==nil,"missing region is still active")
check(d.now==before,"existing director advanced while geometry unavailable")
check(#pw:flies()==0 and #pw:percepts()==0 and #pw:crawlers()==0,"unavailable ecology remains visible/perceived")
check(garden.bed_a==entry and entry.prey==d and pw.made==made,"unavailability discarded population ownership")
ready=true;tick()
check(garden.bed_a==entry and entry.prey==d and pw.made==made and d.now>before,"complete rearrival did not resume same population")
workspace:ClearAllChildren()
print(string.format("PREY_STREAM: %d passed, %d failed",pass,fail))
if fail>0 then error("prey stream readiness regression",0) end
