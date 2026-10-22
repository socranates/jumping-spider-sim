local Map=require("../src/Shared/World/WorldMap")
local Worlds=require("../src/Shared/World/Worlds")
local pass=0
local function check(ok,why) assert(ok,why);pass+=1 end
Map.use("preserve")
local live=Map.regions();local sill=Map.region("sill");local liveLo,liveHi=Map.bounds()
local function unchanged()
 return Map.world()=="preserve" and Map.regions()==live and Map.region("sill")==sill and Map.region("bed_a")==nil
  and Map.bounds()==liveLo and select(2,Map.bounds())==liveHi
end
local old=assert(Map.recordedView("test_garden",Map.SEED,"world-3"))
local current=assert(Map.recordedView("preserve",Map.SEED,"preserve-3"))
check(old.region("bed_a")~=nil and current.region("bed_a")==nil,"explicit maps crossed")
check(old.region("garden_c3")==nil and current.region("garden_c3")~=nil,"destination map missing")
check(old.region("sill")~=sill and current.region("sill")~=sill,"view leaks live region tables")
check(unchanged(),"creating views changed the live map")
local bed=old.region("bed_a")
check(old.at(bed.spawn.pos)==bed and old.inBounds(bed.spawn.pos,"bed_a"),"view lookups disagree")
check(old.retreat("bed_a_stone")==bed.retreats[1],"internal retreat alias lost")
for _,item in {old,old.regions(),bed,bed.bounds,bed.spawn,bed.retreats,bed.retreats[1],bed.neighbors,bed.neighbors[1]} do
 check(table.isfrozen(item) and not pcall(function() item.prototypeMutation=true end),"mutable owned map structure")
end
Map.use("test_garden")
local oldLive=Map.region("bed_a")
check(oldLive~=bed and oldLive.neighbors~=bed.neighbors and oldLive.neighbors[1]~=bed.neighbors[1],"nested original shared")
Map.use("preserve")
-- Distinct trusted seeds may be read, but no module cache retains them.
for _,seed in {0,1,Map.SEED,4294967295} do
 local view=assert(Map.recordedView("test_garden",seed,"world-3"))
 check(view.region("bed_a").seed==Map.seed(seed,"bed_a") and view.seed==seed,"seed silently defaulted")
 check(unchanged(),"seeded authoring changed active map")
end
for _,args in {{"made_up",Map.SEED,"world-3"},{"",Map.SEED,"preserve-3"},{"test_garden",-1,"world-3"},
 {"test_garden",1.5,"world-3"},{"test_garden",math.huge,"world-3"},{"test_garden",0/0,"world-3"},
 {"test_garden",4294967296,"world-3"},{"test_garden","123","world-3"},{"test_garden",Map.SEED,"world-2"},
 {"preserve",Map.SEED,"future"}} do
 local view,why=Map.recordedView(table.unpack(args))
 check(view==nil and type(why)=="string" and unchanged(),"unsupported identity accepted or changed live map")
end
local yielded=0
local worker=coroutine.create(function()
 return Map.recordedView("test_garden",Map.SEED,"world-3",function()
  yielded+=1;if yielded%40==0 then coroutine.yield() end
 end)
end)
while coroutine.status(worker)~="dead" do
 local ok,value=coroutine.resume(worker);assert(ok,value)
 check(unchanged(),"suspended worker switched active map")
 check(current.region("garden_c3").id=="garden_c3" and old.region("bed_a").id=="bed_a","interleaved readers changed")
 if coroutine.status(worker)=="dead" then check(value.region("bed_a")~=nil,"worker result lost") end
end
check(yielded>40,"fixture did not suspend")
check(not pcall(function() Map.recordedView("test_garden",Map.SEED,"world-3",function() error("cancelled") end) end)
 and unchanged(),"cancelled preparation changed live map")
print("MAP_VIEW_PROTOTYPE passed="..pass.." failed=0")
