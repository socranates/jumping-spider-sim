-- The real server template builder over authored collision boxes. No played
-- world is supplied; future engine/menu activation is a separate gate.
local Templates=require("../src/Server/RecoveryTemplates")
local Build=require("../src/Shared/World/WorldBuild")
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local Work=require("../src/Shared/Persistence/SaveWork")
local Objects=require("../src/Shared/Persistence/ObjectRecord")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
Map.use("preserve")
local root=Instance.new("Folder");root.Name="ServerAuthoredRecoveryWorld";root.Parent=workspace
local home=Build.region(assert(Map.region(Map.HOME)),root)
local function probes()
 local n=0;for _,part in workspace:GetChildren() do if part.Name=="FlyClearanceProbe" then n+=1 end end;return n
end
local before=probes();local cache,why=Templates.new(root);assert(cache,why)
check(probes()==before,"builder leaked its temporary geometry probe")
local profiles=assert(cache:profiles());local text={}
for _,mode in Rules.MODES do
 local row=profiles[mode];text[mode]=assert(Json.canonical(row.template))
 check(table.isfrozen(row.template) and table.isfrozen(row) and table.isfrozen(profiles),"template catalog is mutable")
 check(#SaveRest.check(mode,row.template,row.context)==0,"template fails actual save validator")
 local decoded=assert(select(2,Checkpoint.check(row.template,row.context)));local r=decoded.roots
 check(r.life.clock.day==1 and r.life.clock.hour==9 and r.life.elapsed==0 and r.life.checkpoints==0 and r.needs.elapsedS==0,"template has a played clock")
 check(r.prey.now==0 and r.prey.tick==0 and #r.prey.flies==4 and r.prey.feeding.mealsFinished==0 and r.needs.grantedTotal==0,"template has played prey or feeding")
 check(r.needs.gentle==(mode~="main") and r.life.mode==(if mode=="free" then "free" else "main") and r.life.rules==(if mode=="main" then "standard" else "gentle"),"template mode/rules disagree")
 check(type(r.life.save)=="function" and r.life.save==row.context.life.save,"future save callback is not rebound by reference")
 local refs=Checkpoint.refs(row.context)
 check(refs["graph.cast"]~=refs["graph.sweep"] and refs["graph.sweep"]~=refs["graph.overlap"] and refs["graph.overlap"]~=refs["life.save"] and refs["life.save"]~=refs["needs.onEnergyChanged"],"server callback references alias")
 local again=Json.copy(row.template);again.world=assert(Objects.capture(r,Checkpoint.CLASSES,refs))
 local actual=SaveRest.stubWorld();actual.needs.onEnergyChanged=nil
 check(#SaveRest.check(mode,again,actual)==0,"projected recapture invented a callback absent from the game")
 check(r.garden~=nil and next(r.garden)==nil,"template would retain the old world's ecology")
 check(row.template.player.retreat_id=="sill_crevice" and row.template.world_map.world=="preserve" and row.template.created_at==0,"template lacks deterministic authored home pose")
 for _,fly in r.prey.flies do check(fly.state=="PERCHED" and fly.captureSerial==0 and fly.nutrition==fly.profile.body.nutrition,"template prey is already played") end
end
local nextProfiles=assert(cache:profiles())
check(nextProfiles.main.template==profiles.main.template and nextProfiles.main.context~=profiles.main.context,"cache rebuilt records or shared mutable contexts")
local mutable=Json.copy(profiles.main.template);mutable.player.position[1]+=3
check(Json.canonical(profiles.main.template)==text.main,"consumer copy changed cached record")
local part=home:GetChildren()[1];local query=part.CanQuery
part.CanQuery=false
check(cache:profiles()==nil and Templates.new(root)==nil,"missing query collision was accepted")
part.CanQuery=query
local position=part.Position;part.Position+=Vector3.xAxis
check(cache:profiles()==nil,"moved authored collision was accepted")
part.Position=position
local duplicate=Instance.new("Part");duplicate.Name=part.Name;duplicate.Parent=home
check(cache:profiles()==nil,"duplicate authored collision was accepted")
duplicate:Destroy()
check(cache:profiles()~=nil,"restoring authored geometry did not restore cache validity")
Map.use("test_garden");check(cache:profiles()==nil and Templates.new(root)==nil,"foreign map accepted")
Map.use("preserve")
local empty=Instance.new("Folder");empty.Parent=workspace
check(Templates.new(empty)==nil,"incomplete home geometry accepted")
empty:Destroy()
check(Templates.new(root,function() return false end)==nil and probes()==before,"cancelled build allocated/leaked engine helpers")
-- Cancellation after geometry construction must also clean up the probe.
local active=true;local calls=0
local ok,problem=Templates.new(root,function() calls+=1;if calls>4 then active=false end;return active end)
check(ok==nil and type(problem)=="string" and probes()==before,"mid-build cancellation published/leaked a template")
check(Templates.new(root,function() coroutine.yield();return true end)==nil and probes()==before,"yielding scope predicate escaped cleanup")
local worker=Work.new(function() return Templates.new(root) end,{now=function() return 0 end})
while worker.state=="pending" do worker:step() end
local refused=worker:take()
check(refused and refused[1]==nil and type(refused[2])=="string" and probes()==before,"cancellable worker allocated an unowned engine probe")
cache:close();check(cache:profiles()==nil,"closed catalog was reused")
root:Destroy()
print("RECOVERY_TEMPLATES passed="..count.." failed=0")
