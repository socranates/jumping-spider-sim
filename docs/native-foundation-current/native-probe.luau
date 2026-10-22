-- Local diagnostic only. Exact source guard required; never publish.
-- Uses real Instance shadow lifecycle and synthetic save backends, not online DataStores.
-- Diagnostic only: real Instance lifecycle on the exact guarded game module.
-- Cases mirror the new CLI regression; not a network streaming or FPS test.
local Run=game:GetService("RunService")
local WorldShadows=require(script.Parent.WorldShadows)
local Shared=game:GetService("ReplicatedStorage").Shared
local WorldMap=require(Shared.World.WorldMap)
local Region=require(Shared.World.Region)
local function shadowProbe(_d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("ShadowCleanupProbe")==true)
 local run=tostring(DateTime.now().UnixTimestampMillis)
 local checks,cases=0,0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function case(name,fn) fn();cases+=1;print("[SHADOW_CLEANUP_CASE]",run,cases,checks,name) end
 local ok,problem=pcall(function()
 task.wait(5)
-- Small real-region fixtures isolate lifecycle behavior without rebuilding the
-- preserve. Old Instance keys are retained by the test solely to inspect whether
-- the manager released them; this is not a GC or frame-rate measurement.
local function streamFixture()
	assert(WorldMap.world()=="preserve", "native fixture must not change the active map")
	local region = assert(WorldMap.region("hut_desk"))
	local root = Instance.new("Folder")
	local sh = WorldShadows.new(root, { regions = function() return { region } end }, nil)
	return root, region, sh
end
local function streamPart(folder: Instance, name: string, kind: string): any
	local p: any = Instance.new("Part")
	p.Name, p.Size, p.Position = name, Vector3.one, Vector3.zero
	p.Transparency = if kind == "hidden" or kind == "hidden_lit" then 1 else 0
	p.CastShadow = kind == "visible" or kind == "hidden_lit"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
	p.Parent = folder
	return p
end
local function streamBatch(root: Instance, region: any, kind: string): (Instance, { any })
	local f = Instance.new("Folder"); f.Name = Region.folderName(region); f.Parent = root
	local parts = {}
	local kinds = { "hidden", "off", "visible" }
	for i, piece in Region.pieces(region) do
		table.insert(parts, streamPart(f, piece.id, if kind == "mixed" then kinds[(i - 1) % #kinds + 1] else kind))
	end
	return f, parts
end
local STREAM_FAR = Vector3.new(20000, 0, 0)
case("hidden whole-folder stream-out releases bindings and accepts fresh visible arrivals", function()
	for _, kind in { "hidden", "off", "visible", "mixed" } do
	for _, removal in { "destroy", "unparent" } do
	local root, region, sh = streamFixture()
	local old, oldParts = streamBatch(root, region, kind)
	local eligible = 0; for _, p in oldParts do if p.Transparency < 1 and p.CastShadow then eligible += 1 end end
	sh:update(STREAM_FAR, 0)
	check(sh:counts() == eligible and sh.holders[1].count == #oldParts, "all bindings counted, only eligible parts enter visible rule")
	if removal == "destroy" then old:Destroy() else old.Parent = nil end
	local fresh, parts = streamBatch(root, region, "visible")
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
	for _, p in oldParts do check(sh.holders[1].bound[p] == nil, "obsolete hidden key released") end
	for _, p in parts do
		check(sh.holders[1].bound[p] == true and p.CastShadow == false, "fresh identity immediately receives the existing distance rule")
		check(p.Size == Vector3.one and p.Position == Vector3.zero and p.Anchored and p.CanCollide and p.CanQuery and not p.CanTouch, "binding never changes physical properties")
	end
	check(sh.holders[1].count == #parts and sh:counts() == #parts, "only the current visible generation is counted")
	check(sh.holders[1].folder == fresh, "rearrival binds the current folder identity")
	old:Destroy(); fresh:Destroy(); root:Destroy()
	end
	end
end)

case("a detached folder's visible parts are released instead of written on a movement pass", function()
	local root, region, sh = streamFixture()
	local folder, parts = streamBatch(root, region, "visible")
	sh:update(STREAM_FAR, 0)
	folder.Parent = nil -- descendants still have the same immediate parent
	local writes = sh.writes
	sh:update(Vector3.zero, 0.1)
	check(sh:counts() == 0 and sh.holders[1].count == 0 and next(sh.holders[1].bound) == nil, "movement drops a folder that left the world")
	local unchanged = true; for _, p in parts do if p.CastShadow ~= false then unchanged = false end end
	check(unchanged and sh.writes == writes, "old detached parts are not toggled back on")
	folder:Destroy(); root:Destroy()
end)

case("hidden and permanently non-casting child replacements release once and preserve flags", function()
	for _, kind in { "hidden", "hidden_lit", "off", "visible" } do
		local root, region, sh = streamFixture()
		local f, parts = streamBatch(root, region, kind)
		sh:update(STREAM_FAR, 0)
		local old = parts[1]
		local name = old.Name; old:Destroy()
		local p = streamPart(f, name, kind)
		local transparency, shadow = p.Transparency, p.CastShadow
		sh:update(STREAM_FAR, WorldShadows.BIND_EVERY / 2)
		check(sh.holders[1].bound[old] == true and sh.holders[1].bound[p] == nil, "cleanup keeps its existing periodic cadence: " .. kind)
		sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
		check(sh.holders[1].bound[old] == nil and sh.holders[1].bound[p] == true, "only the replacement identity stays bound: " .. kind)
		check(sh.holders[1].count == #parts, "release/rebind keeps one count per part: " .. kind)
		check(p.Transparency == transparency and (if kind == "visible" then p.CastShadow == false else p.CastShadow == shadow), "hidden/off flags preserved, visible rule applied: " .. kind)
		sh:update(STREAM_FAR, 2 * WorldShadows.BIND_EVERY + 0.2)
		check(sh.holders[1].count == #parts, "later checks do not release an already-released identity twice: " .. kind)
		f:Destroy(); root:Destroy()
	end
end)

case("mixed repeated region arrivals do not accumulate obsolete generations", function()
	local root, region, sh = streamFixture()
	local folder: Instance? = nil
	local previous: { any } = {}
	local kinds = { "hidden", "off", "mixed", "visible", "hidden_lit" }
	for cycle = 1, 30 do
		if folder then folder:Destroy() end
		local f, parts = streamBatch(root, region, kinds[(cycle - 1) % #kinds + 1])
		folder = f
		sh:update(STREAM_FAR, (cycle - 1) * (WorldShadows.BIND_EVERY + 0.1))
		for _, p in previous do check(sh.holders[1].bound[p] == nil, "prior generation released on cycle " .. cycle) end
		local bound = 0; for _ in sh.holders[1].bound do bound += 1 end
		check(bound == #parts and sh.holders[1].count == #parts, "bound membership stays at current population on cycle " .. cycle)
		check(#sh.entries + #sh.ignored == #parts, "tracking lists stay at current population on cycle " .. cycle)
		previous = parts
	end
	assert(folder); folder:Destroy()
	sh:update(STREAM_FAR, 31 * (WorldShadows.BIND_EVERY + 0.1))
	check(sh.holders[1].count == 0 and next(sh.holders[1].bound) == nil and #sh.entries == 0 and #sh.ignored == 0, "empty final region releases all tracked references")
	root:Destroy()
end)

case("ignored cleanup has its own bounded budget without consuming visible checks", function()
	local root, region, sh = streamFixture()
	local f = Instance.new("Folder"); f.Name = Region.folderName(region); f.Parent = root
	for i = 1, 250 do streamPart(f, "hidden" .. i, "hidden"); streamPart(f, "visible" .. i, "visible") end
	sh:update(STREAM_FAR, 0)
	check(#sh.entries == 250 and #sh.ignored == 250, "both large populations are tracked")
	check(WorldShadows.CHECK_SLICE == 100 and WorldShadows.IGNORED_CHECK_SLICE == 100, "visible and ignored check budgets are each capped at one hundred")
	local writes = sh.writes
	f:Destroy()
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY / 2)
	check(#sh.entries == 250 and #sh.ignored == 250, "neither list is scanned before its next binding tick")
	for tick = 1, 3 do
		sh:update(STREAM_FAR, tick * (WorldShadows.BIND_EVERY + 0.1))
		local remain = math.max(0, 250 - 100 * tick)
		check(#sh.entries == remain and #sh.ignored == remain, "one tick releases at most each independent budget: " .. tick)
		check(sh.holders[1].count == remain * 2, "holder count matches both remaining populations: " .. tick)
	end
	check(sh.writes == writes and next(sh.holders[1].bound) == nil, "cleanup writes no dead-part properties and leaves no keys")
	root:Destroy()
end)

case("release belongs to the original holder when a part moves between region folders", function()
	assert(WorldMap.world()=="preserve", "native fixture must not change the active map")
	local a, b = assert(WorldMap.region("hut_desk")), assert(WorldMap.region("hut_doorway"))
	for _, kinds in { { "visible", "visible" }, { "hidden", "visible" }, { "visible", "off" }, { "off", "hidden_lit" } } do
	local root = Instance.new("Folder")
	local fa = Instance.new("Folder"); fa.Name = Region.folderName(a); fa.Parent = root
	local fb = Instance.new("Folder"); fb.Name = Region.folderName(b); fb.Parent = root
	-- New holder first: searching all holders would release its binding by mistake.
	local sh = WorldShadows.new(root, { regions = function() return { b, a } end }, nil)
	local p = streamPart(fa, "moving", kinds[1])
	sh:update(STREAM_FAR, 0)
	p.Parent = fb
	p.Transparency = if kinds[2] == "hidden_lit" then 1 else 0
	p.CastShadow = kinds[2] ~= "off"
	sh:bind()
	check(sh.holders[1].bound[p] and sh.holders[2].bound[p], "both generation bindings exist before the cleanup tick")
	sh:update(STREAM_FAR, WorldShadows.BIND_EVERY + 0.1)
	check(sh.holders[2].bound[p] == nil and sh.holders[2].count == 0, "obsolete owner released")
	check(sh.holders[1].bound[p] and sh.holders[1].count == 1 and #sh.entries + #sh.ignored == 1, "new owner and its single tracked entry survive")
	check(sh:counts() == (if kinds[2] == "visible" then 1 else 0), "new owner's eligibility is preserved")
	root:Destroy()
	end
end)

case("home-region exclusion also excludes ignored tracking", function()
	local root, region = streamFixture()
	local f, parts = streamBatch(root, region, "visible")
	local sh = WorldShadows.new(root, { regions = function() return { region } end }, region.id)
	sh:update(STREAM_FAR, 0)
	check(#sh.holders == 0 and #sh.entries == 0 and #sh.ignored == 0, "home retains no shadow-manager bindings")
	local untouched = true; for _, p in parts do if not p.CastShadow then untouched = false end end
	check(untouched, "home parts retain their authored flags")
	f:Destroy(); root:Destroy()
end)


 assert(cases==7,"native regression cases missing")
 end)
 if ok then print("[SHADOW_CLEANUP_DONE]",run,cases,checks) else warn("[SHADOW_CLEANUP_FAIL]",run,tostring(problem)) end
 workspace:SetAttribute("ShadowCleanupFinished",true);workspace:SetAttribute("ShadowCleanupPassed",ok)
end

local Shared=game:GetService("ReplicatedStorage").Shared
local SaveSession=require(Shared.Persistence.SaveSession)
local MemoryBackend=require(Shared.Persistence.MemoryBackend)
local SaveRules=require(Shared.Data.SaveRules)
local SaveEnvelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Json=require(Shared.Persistence.Json)
return function(d)
 assert(game:GetService("RunService"):IsStudio() and game.PlaceId==0 and workspace:GetAttribute("ObservedLifeProbe")==true)
 local runId=tostring(DateTime.now().UnixTimestampMillis)
 local passed,caseCount=0,0
 local function check(ok,why) passed+=1;assert(ok,why) end
 local function case(name,fn) fn();caseCount+=1;print("[OBSERVED_LIFE_CASE]",runId,caseCount,passed,name) end
 local function canon(v) return assert(Json.canonical(v)) end
 local function newEnv()
  local e={t=100000,backend=MemoryBackend.new()}
  e.now=function() return e.t end;e.sleep=function(s) e.t+=s end
  return e
 end
 local function newSession(e,uid,id,extra)
  local cfg={backend=e.backend,userId=uid,sessionId=id,now=e.now,sleep=e.sleep}
  if extra then for k,v in extra do cfg[k]=v end end
  return SaveSession.new(cfg)
 end
 local function run(e,s,seconds) for _=1,seconds do e.t+=1;s:step() end end
 local seeds={}
 local function realRest(t,mode) local r=Json.copy(assert(seeds[mode]));r.created_at=t;return r end
 local ok,problem=pcall(function()
  shadowProbe(d)
  assert(workspace:GetAttribute("ShadowCleanupPassed")==true,"shadow lifecycle regression failed")
  d.title.seen=true
  d.session.finishedMain=true -- fixture only: unlock the existing Easy path
  for _,mode in {"main","free","easy"} do
   local ready=false;local deadline=os.clock()+30
   repeat if d.fresh(if mode=="easy" then "main" else mode,mode=="easy",nil) then ready=true;break end;task.wait(.1) until os.clock()>deadline
   assert(ready,"cannot start native fixture mode "..mode)
   d.openMenu();task.wait(.1)
   local r,why=Checkpoint.capture({motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,wasp=d.wasp,garden=d.world.garden,cat=d.cat,water=d.water},120)
   assert(r,"native checkpoint capture: "..tostring(why))
   local issues=SaveRest.check(mode,r);assert(#issues==0,"native fixture: "..tostring(issues[1]))
   seeds[mode]=r
  end
-- An intent chosen before reading a slot cannot retire a subsequently discovered life.
case("unseen New Life intent survives no foreign save after delayed ownership",function()
 for _,changed in {false,true} do
  local e=newEnv();local uid=if changed then 982 else 981
  local a=newSession(e,uid,"owner");a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
  local ack=0;local b=newSession(e,uid,"visitor",{onLife=function() ack+=1 end})
  check(b:load()=="session" and not b.restLoaded.main,"visitor has not read the leased slot")
  check(b:beginLife("main",1),"local intent accepted while waiting")
  if changed then
   a:beginLife("main",1);run(e,a,15)
   check(a:setRestForLife("main",realRest(240,"main"),a.lifeTokens.main),"owner starts and saves another life")
  end
  a:flush(e.t+20)
  local before=canon(e.backend.data["R_"..uid.."_main"])
  run(e,b,40)
  check(canon(e.backend.data["R_"..uid.."_main"])==before,"late ownership never retires the unseen stored life")
  check(ack==0 and not b.lifeRequests.main.done,"no durable acknowledgement for refused unseen retirement")
  check(b.state=="session" and b.reason=="other_session" and not b.canRetry,"conflict stays read-only for this visit")
  run(e,b,SaveRules.LOCK_STALE+30)
  check(canon(e.backend.data["R_"..uid.."_main"])==before and ack==0,"later retries never erase the protected life")
 end
end)
case("preload New Life on a genuinely empty slot remains usable",function()
 local e=newEnv();local ack=0;local a=newSession(e,983,"fresh",{onLife=function() ack+=1 end})
 check(a:beginLife("main",1),"fresh intent can precede initial load")
 check(a:load()=="active","missing slot acquires normally")
 run(e,a,15)
 check(ack==1 and a.lifeRequests.main.done,"empty-slot retirement is durably acknowledged")
 check(e.backend.data.R_983_main.payload.save_life==a.lifeTokens.main,"acknowledged identity matches storage")
end)

case("observed New Life cannot retire a different life after lease recovery",function()
 for i,mode in {"main","free","easy"} do
  local e=newEnv();local uid=990+i;local b=newSession(e,uid,"visitor")
  b:load();b:beginLife(mode,1);run(e,b,15)
  check(b:setRestForLife(mode,realRest(120,mode),b.lifeTokens[mode]),mode..": visitor stores an observed life")
  run(e,b,15);local old=b.lifeTokens[mode]
  e.t+=SaveRules.LOCK_STALE+1
  local a=newSession(e,uid,"owner");check(a:load()=="active",mode..": owner takes expired lease")
  a:beginLife(mode,1);run(e,a,15)
  check(a:setRestForLife(mode,realRest(240,mode),a.lifeTokens[mode]) and a.lifeTokens[mode]~=old,mode..": owner saves a different life")
  run(e,a,15);b:beginLife(mode,2);run(e,b,1)
  check(b.state=="session",mode..": visitor discovers lost lease")
  a:flush(e.t+20);local key="R_"..uid.."_"..mode;local before=canon(e.backend.data[key])
  run(e,b,45)
  check(canon(e.backend.data[key])==before,mode..": newer checkpoint and backup remain byte-equivalent")
  check(not b.lifeRequests[mode].done and b.state=="session" and not b.canRetry,mode..": stale intent never acknowledged")
 end
end)
case("nil legacy life tokens still require the observed rest revision",function()
 local e=newEnv();local b=newSession(e,995,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 check(b.lifeTokens.main==nil,"legacy rest has no identity token")
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,995,"owner");a:load();a:setRest("main",realRest(240,"main"));run(e,a,15)
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20)
 local before=canon(e.backend.data.R_995_main);run(e,b,45)
 check(canon(e.backend.data.R_995_main)==before and not b.lifeRequests.main.done,"revision change protects a legacy rest without a token")
end)
case("unchanged previously observed rest permits explicit retirement after lease recovery",function()
 local e=newEnv();local b=newSession(e,996,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,996,"owner");a:load()
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20);run(e,b,45)
 check(b.lifeRequests.main.done and b.state=="active","unchanged observation remains valid")
 check(e.backend.data.R_996_main.payload.save_retired and e.backend.data.R_996_main.payload.save_life==b.lifeTokens.main,"retirement matches durable acknowledgement")
end)
case("preload own retirement survives ambiguous response and reacquisition",function()
 local e=newEnv();local ack=0;local b=newSession(e,997,"visitor",{onLife=function() ack+=1 end})
 b:beginLife("main",1);b:load()
 e.backend:fail({op="update",key="R_997_main",times=1,afterWrite=true,message="lost response"})
 run(e,b,1)
 check(ack==0 and not b.lifeRequests.main.done and e.backend.data.R_997_main.payload.save_retired,"retirement stored but acknowledgement lost")
 local before=canon(e.backend.data.R_997_main)
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,997,"owner");a:load();a:flush(e.t+20)
 check(b:load()=="active","own ambiguous marker is not a foreign conflict")
 run(e,b,15)
 check(ack==1 and b.lifeRequests.main.done and canon(e.backend.data.R_997_main)==before,"retry acknowledges without duplicating backup or changing marker")
end)

case("equal timestamps and life tokens do not make changed rest contents identical",function()
 local e=newEnv();local b=newSession(e,998,"visitor");b:load();b:setRest("main",realRest(120,"main"));run(e,b,15)
 local observed=e.backend.data.R_998_main
 e.t+=SaveRules.LOCK_STALE+1
 local a=newSession(e,998,"owner");a:load()
 -- A valid foreign envelope can have the same revision time and nil legacy token.
 -- Its intact checksum still distinguishes the changed payload.
 local changed=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),observed.updatedAt,observed,{session="owner"})
 check(changed.checksum~=observed.checksum,"fixture differs in contents despite equal timestamp/token")
 e.backend:poke("R_998_main",changed)
 b:beginLife("main",1);run(e,b,1);a:flush(e.t+20)
 local before=canon(e.backend.data.R_998_main);run(e,b,45)
 check(canon(e.backend.data.R_998_main)==before and not b.lifeRequests.main.done,"changed checksum blocks stale consent")
end)
case("write-time revision protects an equal-time foreign update after the slot was read",function()
 local e=newEnv();local a=newSession(e,999,"visitor");a:load();a:setRest("main",realRest(120,"main"));run(e,a,15)
 local observed=e.backend.data.R_999_main
 a:beginLife("main",1)
 local changed=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),observed.updatedAt,observed,{session="owner"})
 e.backend:poke("R_999_main",changed);local before=canon(changed)
 run(e,a,20)
 check(canon(e.backend.data.R_999_main)==before and not a.lifeRequests.main.done,"atomic callback refuses the changed observed revision")
end)


  assert(caseCount==8 and passed==45,"native save cases/checks missing")
 end)
 if ok then print("[OBSERVED_LIFE_DONE]",runId,caseCount,passed) else warn("[OBSERVED_LIFE_FAIL]",runId,tostring(problem)) end
 workspace:SetAttribute("ObservedLifeFinished",true);workspace:SetAttribute("ObservedLifePassed",ok)
end
