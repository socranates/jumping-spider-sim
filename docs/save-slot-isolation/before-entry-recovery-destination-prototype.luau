--!strict
-- Private checkpoint assembly. Requires a freshly authored, validated Preserve
-- template; never constructs arbitrary terrain, edits live roots or writes keys.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Objects=require(Shared.Persistence.ObjectRecord)
local SaveRest=require(Shared.Persistence.SaveRest)
local Json=require(Shared.Persistence.Json)
local Map=require(Shared.World.WorldMap)
local Garden=require(Shared.World.Garden)
local Rival=require(Shared.Predator.RivalSpider)
local Mate=require(Shared.Predator.Mate)
local Work=require(Shared.Persistence.SaveWork)
local Life=require(script.Parent.RecoveryLifePrototype)
local Destination={}
local MATE={state=true,position=true,previous=true,up=true,heading=true,leg=true,elapsed=true,meter=true,lost=true,sex=true,scale=true,
 reason=true,scene=true,region=true,court_t=true,court_ok=true,court_near=true,court_away=true,court_breaks=true,court_on=true,cut=true}
local SPATIAL={position=true,previous=true,up=true,heading=true,leg=true,region=true}
local function pulse() local f=Work.pulse();if f then f() end end
local function reserved(key:any):boolean return type(key)~="string" or string.sub(key,1,9)=="@archive/" end
local function freshDirector(d:any):boolean
 if d.captures~=0 or reserved(d.prefix or "fly_") then return false end
 for _,f in d.flies do
  pulse()
  if reserved(f.id) or f.captureSerial~=0 or f.state~="PERCHED" or f.nutrition~=f.profile.body.nutrition then return false end
 end
 return true
end
local function eachDirector(roots:any,fn:(any)->boolean):boolean
 if not fn(roots.prey) then return false end
 for _,entry in roots.garden or {} do
  if entry.prey and not fn(entry.prey) then return false end
  for _,d in entry.kinds or {} do if not fn(d) then return false end end
 end
 return true
end
local function currentPrefixes():boolean
 -- Inspect future streamed constructors too, not only the populations currently
 -- present in the template. Current authored keys must stay out of history.
 for _,region in Map.regions() do
  pulse();local spec=Garden.prey(region)
  if spec and reserved(spec.prefix) then return false end
  for _,kind in Garden.bestiary(region) or {} do if reserved(kind.prefix) then return false end end
 end
 return true
end
local function relocatedMate(history:any):(any?,string?)
 local m=Mate.new()
 if history then
  for k,v in history do
   pulse();if not MATE[k] then return nil,"unsupported historical mate field" end
   if not SPATIAL[k] then m[k]=v end
  end
 end
 if not Mate.valid(m) then return nil,"relocated mate is invalid" end
 return m,nil
end
local function freeze(t:any)
 if type(t)~="table" then return end
 for _,v in t do pulse();freeze(v) end
 if not table.isfrozen(t) then table.freeze(t) end
end
function Destination.prepare(capsule:any,template:any,context:any,slot:string):(any?,string?)
 if Map.world()~="preserve" then return nil,"destination must be the Preserve" end
 local imported,problem=Life.decode(capsule);if not imported then return nil,problem end
 if imported.origin.seed~=Map.SEED then return nil,"source simulation seed requires explicit support" end
 if type(template)~="table" or type(template.world_map)~="table" or template.world_map.world~="preserve"
  or template.world_map.revision~=Map.revision() or template.world_map.seed~=Map.SEED then return nil,"fresh current Preserve template required" end
 local problems,decoded=Checkpoint.check(template,context)
 if not decoded then return nil,table.concat(problems,";") end
 local roots=decoded.roots;local l=roots.life;local f=roots.prey.feeding
 if roots.needs.grantedTotal~=0 or f.granted~=0 or f.taken~=0 or f.mealsFinished~=0 or f.held~=nil or next(f.ledger)~=nil
  or l.clock.day~=1 or l.clock.hour~=9 or l.elapsed~=0 or l.growth.stage~=0 or (l.generation or 0)~=0 then return nil,"template already contains a played life" end
 if template.player.retreat_id=="" or template.world_map.region~=Map.HOME then return nil,"fresh home-retreat template required" end
 if not eachDirector(roots,freshDirector) or not currentPrefixes() then return nil,"fresh capture namespace or population differs" end
 if imported.life.needs.gentle~=(imported.life.rules=="gentle") then return nil,"imported mode/reserves disagree" end
 local mate,errorText=relocatedMate(imported.history.mate);if not mate then return nil,errorText end
 local life=imported.life
 life.save=l.save;imported.needs.onEnergyChanged=roots.needs.onEnergyChanged
 -- The rival belongs to the new ecology. Its complete former state remains in
 -- recovery history. Mate courtship/cycle progress stays, with authored new pose.
 life.rival=Rival.new();life.mate=mate
 life.recoveryHistory={version=1,archive=capsule.archive,origin=imported.origin,record=capsule.history}
 roots.life=life;roots.needs=imported.needs
 eachDirector(roots,function(d:any):boolean d.feeding=imported.feeding;return true end)
 local graph,why=Objects.capture(roots,Checkpoint.CLASSES,Checkpoint.refs(context));if not graph then return nil,why end
 local record=Json.copy(template);record.world=graph
 record.life_rules={mode=life.mode,rules=life.rules};record.save_life=imported.origin.save_life
 -- These records contain counters, not active world positions. Normal restore
 -- already ends their in-progress encounters while retaining their history.
 for _,name in {"wasp","cat","water"} do if imported.history[name]~=nil then record[name]=Json.copy(imported.history[name]) end end
 -- Old falling leaves remain historical. Fresh geometry owns breakaway state.
 local bad=SaveRest.check(slot,record,context);if #bad>0 then return nil,table.concat(bad,";") end
 local requiresScene=mate.scene==true or life.mating~=nil and (life.mating.stage=="courted" or life.mating.stage=="hatched")
 local out={checkpoint=record,archive=capsule.archive,origin=imported.origin,requiresSceneResume=requiresScene,
  status="prepared-only",destinationCommitAuthorized=false}
 freeze(out);return out,nil
end
return table.freeze(Destination)
