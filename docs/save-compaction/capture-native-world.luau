assert(game.PlaceId==0 and game:GetService("RunService"):IsRunning(),"local native capture only")
-- Read-only diagnostic on shim worlds. Does not connect to Roblox or a DataStore.
local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
local Region=require(game.ReplicatedStorage.Shared.World.Region)
local LookPlan=require(game.ReplicatedStorage.Shared.World.LookPlan)
local Build=require(game.ReplicatedStorage.Shared.World.WorldBuild)
local Motor=require(game.ReplicatedStorage.Shared.Movement.SpiderMotor)
local Species=require(game.ReplicatedStorage.Shared.Data.Species)
local Surfaces=require(game.ReplicatedStorage.Shared.Data.Surfaces)
local Director=require(game.ReplicatedStorage.Shared.Prey.PreyDirector)
local PreyWorld=require(game.ReplicatedStorage.Shared.Prey.PreyWorld)
local Memory=require(game.ReplicatedStorage.Shared.Perception.ObservationMemory)
local Sensor=require(game.ReplicatedStorage.Shared.Perception.Sensor)
local Needs=require(game.ReplicatedStorage.Shared.Life.NeedsModel)
local Life=require(game.ReplicatedStorage.Shared.Life.LifeLoop)
local Checkpoint=require(game.ReplicatedStorage.Shared.Persistence.Checkpoint)
local SaveRest=require(game.ReplicatedStorage.Shared.Persistence.SaveRest)
local Rules=require(game.ReplicatedStorage.Shared.Data.SaveRules)
local Json=require(game.ReplicatedStorage.Shared.Persistence.Json)
Map.use("preserve")
local root=workspace:WaitForChild("World")
assert(workspace:GetAttribute("World")=="preserve","native world is not preserve")
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
 if string.find(label,"visited_all_",1,true) then
  task.wait()
  local rec,err=Checkpoint.capture(world,os.time());assert(rec,err)
  local why=SaveRest.check("main",rec);assert(#why==0,why[1])
  task.wait()
  local Envelope=require(game.ReplicatedStorage.Shared.Persistence.SaveEnvelope)
  local Codec=require(game.ServerScriptService.Server.RestCompression)
  local env=Envelope.make(SaveRest.SPECS.main,rec,os.time(),nil,nil)
  task.wait()
  local packed=Codec.engine():encode(env)
  local wire=game:GetService("HttpService"):JSONEncode(packed)
  print("[CHET_NATIVE_CAPTURE]",#assert(Json.canonical(rec)),#wire,"233 native regions; checkpoint valid")
  local chunks=math.ceil(#wire/500)
  for i=1,chunks do print(string.format("[CHET_NATIVE_CAPTURE_DATA] %d %d %s",i,chunks,string.sub(wire,(i-1)*500+1,i*500))) end
 end
end
motor:place(Vector3.new(-25.5,.31,6),Vector3.yAxis,Vector3.xAxis)
measure("sill")
local n=0
for _,r in Map.regions() do
 local pieces=Region.pieces(r)
 ecology:directors(r.id);ecology:bugs(r.id);ecology:ambient(r.id)
 n+=1
 task.wait()
 if n==10 or n==30 or n==60 or n%25==0 then measure(`visited_{n}`) end
end
measure(`visited_all_{n}`)
print(`AUDIT_READY calls={readyCalls}`)
