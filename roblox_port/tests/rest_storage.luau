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
local Compression=require("../src/Server/RestCompression")
local Backend=require("../src/Server/DataStoreBackend")
local Session=require("../src/Shared/Persistence/SaveSession")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local fullRecord
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
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
 if string.find(label,"visited_all_",1,true) then
  local rec=assert(Checkpoint.capture(world,0))
  local problems=SaveRest.check("main",rec)
  check(#problems==0,problems[1])
  fullRecord=rec
  print(`REST_STORAGE full_world_chars={#assert(Json.canonical(rec))} regions=233`)
 end
end
motor:place(Vector3.new(-25.5,.31,6),Vector3.yAxis,Vector3.xAxis)
measure("sill")
local n=0
for _,r in Map.regions() do
 local pieces=Region.pieces(r)
 ecology:directors(r.id);ecology:bugs(r.id);ecology:ambient(r.id)
 n+=1
 if n==10 or n==30 or n==60 or n%25==0 then measure(`visited_{n}`) end
end
measure(`visited_all_{n}`)
-- Real session/backend integration; the adapter is a reversible store, not a claim of CLI Zstd support.
local function copy(v)
 if type(v)~="table" then return v end
 local out={};for k,x in v do out[k]=copy(x) end;return out
end
local records,texts={},{}
local seq=0
local codec=Compression.new({
 serialize=function(v) local text=assert(Json.canonical(v));records[text]=v;return text end,
 compress=function(text) seq+=1;local id="frame-"..seq;texts[id]=text;return id end,
 expandedSize=function(id) return if texts[id] then #texts[id] else nil end,
 decompress=function(id) return assert(texts[id]) end,
 parse=function(text) return copy(assert(records[text])) end,
})
local ds={data={}}
function ds:GetAsync(key) return copy(self.data[key]) end
function ds:UpdateAsync(key,fn)
 local value=fn(copy(self.data[key]))
 if value~=nil then self.data[key]=copy(value) end
 return copy(self.data[key])
end
local backend=Backend.new(ds,codec)
local now=100
local function visit(id)
 return Session.new({backend=backend,userId="full-world",sessionId=id,now=function() return now end,
  sleep=function(dt) now+=dt end})
end
local first=visit("first")
check(first:load()=="active","first session did not load")
check(first:setRest("main",fullRecord),"full-world rest rejected by session")
first:flush()
check(ds.data["R_full-world_main"].encoding==Compression.ENCODING,"session did not store compressed rest")
now+=40
local second=visit("second")
check(second:load()=="active","second session did not load")
check(assert(Json.canonical(second.rests.main))==assert(Json.canonical(fullRecord)),"rejoin changed full-world rest")
local secondRecord=assert(Checkpoint.capture(world,1))
check(second:setRest("main",secondRecord),"replacement full-world rest refused")
second:flush()
local stored=ds.data["R_full-world_main"]
check(stored.backup~=nil,"replacement lacks independent backup")
stored.data="damaged-current"
local before=assert(Json.canonical(stored))
now+=40
local recovered=visit("recovered")
check(recovered:load()=="active" and recovered.restProtected.main=="corrupt","damaged current slot was not protected independently")
check(assert(Json.canonical(recovered.rests.main))==assert(Json.canonical(fullRecord)),"valid full-world backup was not offered")
check(not recovered:beginLife("main",1),"damaged compressed slot accepted retirement")
local progress=Json.copy(recovered.progress);progress.notebook.opened={"p1","p2"}
check(recovered:setProgress(progress),"independent notebook update refused")
recovered:step();recovered:flush()
local progressStored=Envelope.open(Progress.SPEC,ds.data["P_full-world"])
check(progressStored.status=="ok" and #progressStored.payload.notebook.opened==2,"damaged compressed slot blocked notebook persistence")
check(assert(Json.canonical(ds.data["R_full-world_main"]))==before,"recovery overwrote damaged stored bytes")
print(`REST_STORAGE passed={passed} failed=0`)
