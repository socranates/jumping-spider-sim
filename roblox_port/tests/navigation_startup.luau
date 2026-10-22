-- Loading must be bounded work with no gameplay or checkpoint before both graphs.
local Prep=require("../src/Shared/World/NavigationPreparation")
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
local Air=require("../src/Shared/World/StationAir")
local Route=require("../src/Shared/Predator/RivalRoute")
local Station=require("../src/Shared/World/StationTerritory")
local warn=print -- Luau CLI has no Roblox warn global; retain deliberate diagnostics.
local passed,failed=0,0
local function check(name,fn)
 local ok,problem=pcall(fn)
 if ok then passed+=1 else failed+=1;print("FAIL NAVIGATION_STARTUP "..name..": "..tostring(problem)) end
end
local function fixture()
 local h={time=0,surface=100,airWork=100,airReady=false,surfaceCalls=0,airCalls=0}
 h.config={now=function() return h.time end,prepare=function() end,
  pending=function() return h.surface end,
  advance=function() h.surfaceCalls+=1;h.surface=math.max(0,h.surface-1);return true end,
  air={prepare=function(yieldWork)
   for _=1,h.airWork do h.airCalls+=1;yieldWork() end;h.airReady=true
  end,ready=function() return h.airReady end}}
 return h
end
check("flat clock cannot exceed slice cap and both queues make progress",function()
 local h=fixture();local p=Prep.new(h.config)
 assert(p:step()=="pending" and p.slices==Prep.MAX_SLICES)
 assert(h.surfaceCalls>0 and h.airCalls>0 and h.surface>0 and not h.airReady)
 for _=1,10 do p:step() end
 assert(p.status=="ready" and h.surface==0 and h.airReady)
 local n=p.slices;p:step();assert(p.slices==n,"ready gate does no recurring work")
end)
check("time budget yields independently from work cap",function()
 local h=fixture();h.config.advance=function() h.surfaceCalls+=1;h.time+=.004;return true end
 local p=Prep.new(h.config);assert(p:step()=="pending")
 assert(p.slices>0 and p.slices<Prep.MAX_SLICES and h.surfaceCalls==2)
end)
check("completed surfaces cannot bypass pending air",function()
 local h=fixture();h.surface=0;h.airWork=1000;local p=Prep.new(h.config)
 assert(p:step()=="pending" and h.surfaceCalls==0 and h.airCalls==Prep.MAX_SLICES)
end)
check("completed air cannot bypass pending surfaces",function()
 local h=fixture();h.airWork=0;h.surface=1000;local p=Prep.new(h.config)
 assert(p:step()=="pending" and h.airReady and h.surfaceCalls>0 and h.surface>0)
end)
check("cached graphs become ready without resuming simulation work",function()
 local h=fixture();h.surface=0;h.airWork=0;local p=Prep.new(h.config)
 assert(p:step()=="ready" and h.surfaceCalls==0 and h.airReady)
end)
for _,kind in {"prepare","surface","air","incomplete_air"} do
 check("failure is sticky: "..kind,function()
  local h=fixture()
  if kind=="prepare" then h.config.prepare=function() error("synthetic prepare failure") end
  elseif kind=="surface" then h.config.advance=function() return false,"synthetic route failure" end
  elseif kind=="air" then h.config.air.prepare=function() error("synthetic air failure") end
  else h.surface=0;h.config.air.prepare=function() end end
  local p=Prep.new(h.config);assert(p:step()=="failed" and type(p.problem)=="string")
  local n=p.slices;assert(p:step()=="failed" and p.slices==n)
 end)
end
check("elapsed loading timeout refuses a stalled warm-up",function()
 local h=fixture();local p=Prep.new(h.config);h.time=Prep.TIMEOUT_SECONDS
 assert(p:step()=="failed" and string.find(p.problem,"timed out",1,true))
 assert(coroutine.status(p.airThread)=="dead","failed owner closes its suspended work")
end)

Map.use("preserve")
check("cancel only the closed air builder, then allow a fresh owner",function()
 assert(type(Air.ready)=="function" and type(Air.cancelPreparation)=="function","no owned air cancellation API")
 local thread=coroutine.create(function() Air.prepare(function() coroutine.yield() end) end)
 assert(coroutine.resume(thread) and not Air.ready())
 assert(not Air.cancelPreparation(thread),"live builders cannot be cancelled by another owner")
 coroutine.close(thread)
 local other=coroutine.create(function() end);coroutine.close(other)
 assert(not Air.cancelPreparation(other),"wrong owner cannot release construction")
 assert(Air.cancelPreparation(thread) and not Air.ready(),"closed owner's partial graph was discarded")
end)
check("air preparation error releases its owner without publishing partial data",function()
 local attempts=0
 for i=1,2 do
  local ok=pcall(function() Air.prepare(function() attempts+=1;error("synthetic air yield failure") end) end)
  assert(not ok and attempts==i,"a failed air build prevented a subsequent owner from starting")
 end
 assert(not Air.ready())
end)
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",false)
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client failed to load")
local d=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
local player=game:GetService("Players").LocalPlayer
local nav=d.navigation
check("cold client refuses early Begin and holds its state behind loading",function()
 assert(nav,"no navigation startup owner")
 assert(nav.status=="pending" and not d.fresh("main",false,nil))
 local hour,energy,pos=d.life.clock.hour,d.needs.energy,d.motor.pos
 local advance=nav.config.advance
 nav.config.advance=function() return true end -- deliberately stalled real surface queue
 frame(1/30);frame(1/120)
 nav.config.advance=advance
 assert(nav.status=="pending" and player:GetAttribute("TitleReady")~=true)
 assert(d.life.clock.hour==hour and d.needs.energy==energy and d.motor.pos==pos)
 assert((d.life.rival==nil or d.life.rival.state=="dormant") and d.wasp.phase=="away")
 assert(not d.currentStore():loadBest().ok,"no initial playable checkpoint")
end)
check("real resident surface and air graphs finish before a playable capture",function()
 assert(nav,"no navigation startup owner")
 for _=1,5000 do frame(1/60);if player:GetAttribute("TitleReady")==true then break end end
 assert(nav.status=="ready" and Air.ready() and player:GetAttribute("TitleReady")==true)
 for id in Station.roam() do assert(Route.prepared(id),"resident destination missing: "..id) end
 assert(d.fresh("main",false,nil),"Normal starts after readiness")
 assert(d.fresh("free",false,nil),"Free starts after readiness")
 d.session.finishedMain=true;assert(d.fresh("main",true,nil),"Easy starts after readiness")
 local slices=nav.slices;for _=1,30 do frame(1/60) end
 assert(nav.slices==slices,"gameplay and new lives do not restart preparation")
end)
check("controller preparation failure keeps simulation stopped and signals recovery",function()
 assert(nav,"no navigation startup owner")
 d.menu:hide();local hour,pos=d.life.clock.hour,d.motor.pos
 nav.status="pending";nav.config.pending=function() error("synthetic controller navigation failure") end
 frame(1/60)
 assert(nav.status=="failed" and player:GetAttribute("WorldStartupFailed")==true)
 frame(1/60);assert(d.life.clock.hour==hour and d.motor.pos==pos)
end)
print(`NAVIGATION_STARTUP passed={passed} failed={failed}`)
if failed>0 then error("navigation startup checks failed") end
