-- Diagnostic only: unbound Studio, production persistence disabled. Never publish.
local Run=game:GetService("RunService")
local WS=game:GetService("Workspace")
assert(Run:IsStudio() and game.PlaceId==0 and game.ServerScriptService.Server.Persistence.Disabled)
local Templates=require(script.Parent.RecoveryTemplates)
local Shared=game.ReplicatedStorage.Shared
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Rest=require(Shared.Persistence.SaveRest)
local Objects=require(Shared.Persistence.ObjectRecord)
local Json=require(Shared.Persistence.Json)
local Rules=require(Shared.Data.SaveRules)
local run=tostring(DateTime.now().UnixTimestampMillis);local checks=0
local function check(ok,why) checks+=1;assert(ok,why) end
print("[SERVER_TEMPLATE_NATIVE_BEGIN]",run)
local ok,why=pcall(function()
 local root=assert(WS:WaitForChild("World",60),"authored server world missing")
 local function probes()
  local n=0;for _,part in WS:GetChildren() do if part.Name=="FlyClearanceProbe" then n+=1 end end;return n
 end
 local before=probes();local at=os.clock();local cache,problem=Templates.new(root);assert(cache,problem)
 local elapsed=(os.clock()-at)*1000
 check(probes()==before,"template builder leaked its engine probe")
 local rows=assert(cache:profiles());local bytes=0
 for _,mode in Rules.MODES do
  local row=rows[mode];local record=row.template
  check(table.isfrozen(record) and table.isfrozen(rows),"mutable authored catalog")
  check(#Rest.check(mode,record,row.context)==0,"template rejected by native validator")
  local decoded=assert(select(2,Checkpoint.check(record,row.context)));local roots=decoded.roots
  check(roots.life.clock.day==1 and roots.life.clock.hour==9 and roots.life.elapsed==0 and roots.needs.elapsedS==0,"template clock already advanced")
  check(roots.prey.tick==0 and roots.prey.now==0 and #roots.prey.flies==4 and roots.prey.feeding.mealsFinished==0,"played template prey")
  check(roots.needs.gentle==(mode~="main") and roots.life.rules==(if mode=="main" then "standard" else "gentle"),"template mode mismatch")
  check(roots.garden~=nil and next(roots.garden)==nil and record.player.retreat_id=="sill_crevice","old ecology or invalid home")
  local refs=Checkpoint.refs(row.context)
  check(refs["graph.cast"]~=refs["graph.sweep"] and refs["life.save"]~=refs["needs.onEnergyChanged"],"aliased callback references")
  local again={};for k,v in record do again[k]=v end
  again.world=assert(Objects.capture(roots,Checkpoint.CLASSES,refs))
  local actual=Rest.stubWorld();actual.needs.onEnergyChanged=nil
  check(#Rest.check(mode,again,actual)==0,"native recapture invented a game callback")
  bytes+=#assert(Json.canonical(record))
 end
 local again=assert(cache:profiles())
 check(again.main.template==rows.main.template and again.main.context~=rows.main.context,"cache/reference ownership differs")
 cache:close();check(cache:profiles()==nil,"closed catalog reused")
 print("[SERVER_TEMPLATE_NATIVE_MEASURE]",run,Json.canonical({build_ms=elapsed,template_chars=bytes,mode_count=3,comparison_gain_claim=false}))
 WS:SetAttribute("ServerTemplateNativeChecks",checks)
 WS:SetAttribute("ServerTemplateNativePassed",true)
end)
if ok then print("[SERVER_TEMPLATE_NATIVE_PASS]",run,checks)
else warn("[SERVER_TEMPLATE_NATIVE_FAIL]",run,tostring(why)) end
