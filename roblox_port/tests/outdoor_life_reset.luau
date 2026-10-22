local awaitRest=require("./studio/AwaitRest")
-- Real preserve client: New Life must not inherit another spider's predator reactions.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL OUTDOOR_RESET "..why) end end
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",false)
Map.use("preserve")
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
local loaded,err=pcall(function() require("../src/Client/SpiderClient.client") end)
assert(loaded,tostring(err))
local d=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
local function frames(n) for _=1,n do frame(1/60) end end
local ready=false;for _=1,5000 do if d.fresh("free",false,nil) then ready=true;break end;frames(1) end
assert(ready,"fresh life never became ready")
local actors={{d.frog,d.Frog,"frog"},{d.crab,d.CrabSpider,"crabs"},{d.bird,d.Bird,"robin"}}
local function equal(a,b,path)
 if typeof(a)~=typeof(b) then return false,path.." type" end
 if typeof(a)~="table" then return a==b,path end
 for k,v in b do local ok,why=equal(a[k],v,path.."."..tostring(k));if not ok then return false,why end end
 for k in a do if b[k]==nil then return false,path.." stale "..tostring(k) end end
 return true,path
end
local function arm()
 local f,c,b=d.frog,d.crab,d.bird
 local fs,cs,bs=f.strikes,c.grabs,b.strikes
 for _,row in actors do row[1].enabled=true;row[1].gentle=false end
 f:place(1)
 local prey={pos=f:mouth()+f.heading*2,speed=3,hidden=false}
 for _=1,60 do f:step(1/60,1,prey);if f.strikes>fs then break end end
 check(f.strikes>fs and f.cooldown>0 and #f.signals>0,"frog fixture actually struck and queued signals")
 c:place(1);assert(#c.crabs>0,"no crab sites")
 c:step(d.CrabSpider.LATENCY+.01,1,12,{pos=c.crabs[1].pos,hidden=false})
 check(c.grabs>cs and c.crabs[1].cooldown>0 and #c.signals>0,"crab fixture actually struck and queued signals")
 local visit=assert(d.Bird.plan(b.seed,1)[1]);local h=d.Bird.hourOf(visit,d.Bird.APPROACH_S+4)
 b:step(6,1,h,nil) -- let the previous attack's cooldown expire between independent fixtures
 local spot=b.pos+Vector3.new(b.heading.X,0,b.heading.Z).Unit*30+Vector3.yAxis*.31
 for _=1,360 do
  h+=d.Bird.HOUR_PER_S/60;b:step(1/60,1,h,{pos=spot,speed=3,hidden=false,covered=false})
  if b.strikes>bs then break end
 end
 check(b.strikes>bs and b.cooldown>0 and #b.signals>0,"robin fixture actually struck and queued signals")
end
for _,mode in {"main","free"} do
 arm()
 local notices=d.frog.notices
 check(not d.fresh("main",true,nil),"locked Easy request is refused")
 check(d.frog.notices==notices and #d.frog.signals>0,"refused New Life leaves current actors intact")
 -- A debug-disabled animal must stay disabled, while rules follow the new life.
 for _,row in actors do row[1].enabled=false end
 check(d.fresh(mode,false,nil),mode.." starts successfully")
 check(d.life.clock.day==1,mode.." returns to the same day as the old attacks")
 check(d.frog==actors[1][1] and d.crab==actors[2][1] and d.bird==actors[3][1],"references held by renderers and hooks stay valid")
 for _,row in actors do
  local clean=row[2].new(row[1].seed);clean.enabled=false;clean.gentle=mode=="free"
  local ok,why=equal(row[1],clean,row[3]);check(ok,mode.." starts with constructor state: "..why)
 end
 frames(120)
 check(not d.life.lifeOver,mode.." is not killed by an old queued strike")
 for _,row in actors do
  check(row[1].strikes==0 or row[1].grabs==0,mode.." attack counter starts over for "..row[3])
  check(#row[1]:drainSignals()==0,mode.." has no old queued signals for "..row[3])
 end
end
-- These three predators keep seeded schedules, not checkpointed combat state.
-- Returning to a rest must not retain a reaction that happened after that rest.
local day,hour=d.life.clock.day,d.life.clock.hour
local saved=awaitRest(d.life.save(),function() frames(1) end)
check(saved.ok,"the real client keeps a rest for the recovery case: "..tostring(saved.message))
if saved.ok then
 arm()
 for _,row in actors do row[1].enabled=false end
 d.returnToCheckpoint()
 check(d.life.clock.day==day and d.life.clock.hour==hour,"recovery restores the saved clock")
 for _,row in actors do
  local clean=row[2].new(row[1].seed);clean.enabled=false;clean.gentle=true
  local ok,why=equal(row[1],clean,row[3]);check(ok,"recovery resets unrecorded reactions: "..why)
 end
 check(d.currentStore():loadBest().ok,"the valid rest is still available after recovery")
end
print("OUTDOOR_RESET passed="..passed.." failed="..failed)
if failed>0 then error("OUTDOOR_RESET failed") end
