local Work=require("../src/Shared/Persistence/SaveWork")
local passedInspection=0
local function verify(ok,why) assert(ok,why);passedInspection+=1 end
WorldMap.use("test_garden")
local old= gardenWorld()
old.motor:place(Vector3.new(11,-89.69,-50),Vector3.yAxis,Vector3.zAxis)
old.life.growth:useGameRules(false)
old.life.growth.stage=1;old.life.growth.fedSinceMoult=1.2
local source=assert(Checkpoint.capture(old,123))
local sourceText=assert(Json.canonical(source))
verify(source.world_map.region=="bed_a" and source.world_map.retreat=="bed_a_stone","not a historical bed rest")
verify(#old.garden.bed_a.prey.flies>0 and #old.garden.bed_a.bugs.lice>0,"fixture has no populated ecology")
WorldMap.use("preserve")
local live=newWorld();live.garden={}
local active=WorldMap.regions();local region=WorldMap.region("sill")
local liveBefore=fingerprint(live)
local function unchanged()
 return WorldMap.world()=="preserve" and WorldMap.regions()==active and WorldMap.region("sill")==region
  and WorldMap.region("bed_a")==nil and next(live.garden)==nil
end
local problems,decoded=Checkpoint.inspectRecorded(source,live)
verify(#problems==0 and decoded~=nil,table.concat(problems,";"))
verify(decoded.roots.garden.bed_a~=nil and decoded.roots.garden.bed_a.prey~=old.garden.bed_a.prey,"source graph not owned")
verify(decoded.roots.garden.bed_a.prey.feeding==decoded.roots.prey.feeding,"cross-region jaws identity lost")
verify(decoded.roots.prey.feeding.needs==decoded.roots.needs and decoded.roots.life.needs==decoded.roots.needs,"reserve identity lost")
verify(decoded.roots.life.growth.stage==1 and decoded.roots.life.growth.fedSinceMoult==1.2,"growth lost during inspection")
verify(unchanged() and fingerprint(live)==liveBefore and Json.canonical(source)==sourceText,"inspection changed source/live state")
verify(#(Checkpoint.check(source,live))>0,"ordinary Continue was accidentally enabled")
local commit=Checkpoint.prepare(source,live)
verify(commit==nil and unchanged(),"unsafe cross-world commit became available")
-- Supported map views are bounded to authored revisions; do not claim to validate unknown geometry.
for _,edit in {
 function(r) r.world_map.world="unknown" end,
 function(r) r.world_map.revision="world-2" end,
 function(r) r.world_map.seed=-1 end,
 function(r) r.world_map.seed=0/0 end,
 function(r) r.world_map.region="unknown" end,
 function(r) r.world_map.retreat="unknown";r.player.retreat_id="unknown" end,
 function(r) r.player.position={0,1000,0} end,
 function(r) r.schema_version=Checkpoint.SCHEMA_VERSION+1 end,
} do
 local r=Json.copy(source);edit(r)
 local p,d=Checkpoint.inspectRecorded(r,live)
 verify(#p>0 and d==nil and unchanged(),"invalid source geometry/schema accepted")
end
-- Cooperative validation yields without switching the globally active map.
local clock=0
local function now() clock+=.00001;return clock end
local worker=Work.new(function() return Checkpoint.inspectRecorded(source,live) end,{now=now,budget=.0001,maxSeconds=1000,maxResumes=10000})
local suspensions=0
while worker.state=="pending" do
 worker:step()
 verify(unchanged(),"suspended recorded inspection switched live map")
 if worker.state=="pending" then suspensions+=1 end
end
local result=worker:take()
verify(result~=nil and #result[1]==0 and result[2]~=nil and suspensions>0,"cooperative inspection failed or did not suspend")
verify(Json.canonical(source)==sourceText and fingerprint(live)==liveBefore,"cooperative inspection changed inputs/live roots")
local cancelled=Work.new(function() return Checkpoint.inspectRecorded(source,live) end,{now=now,budget=.0001,maxSeconds=1000})
cancelled:step()
verify(cancelled.state=="pending" and cancelled:cancel() and cancelled:take()==nil and unchanged(),"cancellation leaked a result or changed world")
print("RECORDED_INSPECTION passed="..passedInspection.." failed=0 suspensions="..suspensions)
