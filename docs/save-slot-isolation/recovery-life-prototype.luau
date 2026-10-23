--!strict
-- Private life-state projection. Produces data, never a destination world or
-- authority credential. Recorded actors/skins remain explicitly historical.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loop=require(Shared.Life.LifeLoop)
local Clock=require(Shared.Life.LifeClock)
local Growth=require(Shared.Life.Growth)
local Mating=require(Shared.Life.Mating)
local Rare=require(Shared.Life.RareDirector)
local Nature=require(Shared.Life.Nature)
local Ballooning=require(Shared.Life.Ballooning)
local Worlds=require(Shared.World.Worlds)
local Objects=require(Shared.Persistence.ObjectRecord)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Work=require(Shared.Persistence.SaveWork)
local Meals=require(script.Parent.RecoveryMealsPrototype)
local Life={};Life.FORMAT="the-windowsill portable life"
local CLASSES={LifeLoop=Loop,LifeClock=Clock,Growth=Growth}
local FIELDS={clock="preserve",needs="rebind",save="rebind",growth="preserve",grantedSeen="preserve",mode="preserve",rules="preserve",
 lifeOver="preserve",resting="preserve",restSeconds="preserve",asleep="reset",elapsed="preserve",checkpointDue="reset",checkpointResult="reset",
 checkpoints="preserve",notice="reset",noticeSeconds="reset",morningText="reset",restoreGrace="reset",events="reset",daylight="derive",rangeScale="derive",
 weakAfterH="preserve",starveAfterH="preserve",mealFood="preserve",rival="history",mate="history",mating="preserve",generation="preserve",
 born="preserve",mealsBase="preserve",cold_day="preserve",start_zone="preserve",start_region="preserve",rareSerial="preserve",
 rareGeneration="preserve",rareBorn="preserve",rareVisit="preserve",_checkpointPending="refuse"}
Life.FIELDS=table.freeze(FIELDS)
local function pulse() local f=Work.pulse();if f then f() end end
local function known(value:any,fields:any):boolean
 if type(value)~="table" then return false end
 for k in value do pulse();if fields[k]==nil then return false end end
 return true
end
local function freeze(t:any)
 if type(t)~="table" then return end
 for _,v in t do pulse();freeze(v) end
 if not table.isfrozen(t) then table.freeze(t) end
end
local CLOCK={day=true,hour=true,sleeping=true}
local GROWTH={stage=true,fedSinceMoult=true,ready=true,moultingHoursLeft=true,softHoursLeft=true,exuviae=true,readyFood=true,gameRules=true}
local MATING={stage=true,ready_day=true,guard_day=true,sac_day=true,hatch_day=true,hatch_hour=true,brood=true,mates=true,visits=true,visit_day=true,
 away_day=true,drive_offs=true,courts=true,rejections=true,cut_ins=true}
local VISIT={id=true,serial=true,day=true,hour=true}
local function whole(v:any,cap:number):boolean return type(v)=="number" and v==v and v>=0 and v<=cap and v%1==0 end
local function origin(value:any):(any?,string?)
 if not known(value,{world=true,seed=true,revision=true,region=true,retreat=true,save_life=true}) or not Worlds.known(value.world)
  or not whole(value.seed,4294967295) or value.revision~=Worlds.get(value.world).revision
  or type(value.region)~="string" or type(value.retreat)~="string" then return nil,"invalid recorded origin" end
 local token=value.save_life
 if token~=nil and (type(token)~="string" or #token<1 or #token>160 or string.match(token,"^[%w_:%.%-]+$")==nil) then return nil,"invalid recorded life identity" end
 local out={};for k,v in value do out[k]=v end;return out,nil
end
local function validate(l:any,history:any):string?
 if getmetatable(l)~=Loop or not known(l,FIELDS) or getmetatable(l.clock)~=Clock or not known(l.clock,CLOCK)
  or getmetatable(l.growth)~=Growth or not known(l.growth,GROWTH) then return "unsupported portable life/clock/growth fields" end
 if l._checkpointPending~=nil then return "checkpoint preparation is still pending" end
 if (l.mode~="main" and l.mode~="free") or (l.rules~="standard" and l.rules~="gentle") or (l.mode=="free" and l.rules~="gentle") or type(l.lifeOver)~="boolean" then return "invalid life rules" end
 if l.generation~=nil and not whole(l.generation,1e6) then return "invalid generation" end
 for _,k in {"born","mealsBase"} do if l[k]~=nil and not whole(l[k],1e9) then return "invalid generation grace" end end
 if not Nature.validCold(l.cold_day) then return "invalid cold history" end
 if l.start_zone~=nil and (not Ballooning.valid(l.start_zone) or l.start_zone==Ballooning.HUT or l.start_region==nil) then return "invalid lineage origin" end
 if l.start_region~=nil and (l.start_zone==nil or not Ballooning.landsIn(l.start_zone,l.start_region)) then return "invalid lineage landing" end
 if l.growth.gameRules~=nil and type(l.growth.gameRules)~="boolean" then return "invalid growth rules" end
 if l.growth.readyFood~=nil and (type(l.growth.readyFood)~="number" or l.growth.readyFood~=l.growth.readyFood or l.growth.readyFood<=0 or l.growth.readyFood==math.huge) then return "invalid growth threshold" end
 if history.mate~=nil and type(history.mate)~="table" then return "invalid historical mate" end
 if #Loop.problems(l:toRecord())>0 or #Mating.problemsWith(l.mating,history.mate)>0 or #Rare.problems(l)>0 then return "invalid portable life state" end
 if l.mating~=nil and not known(l.mating,MATING) then return "unsupported mating fields" end
 if l.rareVisit~=nil and not known(l.rareVisit,VISIT) then return "unsupported rare visit fields" end
 if l.growth:isMoulting() and not l.resting then return "moult outside rest" end
 return nil
end
function Life.prepare(record:any,context:any,archiveId:string):(any?,string?)
 if type(Checkpoint.inspectRecorded)~="function" then return nil,"recorded-world validator unavailable" end
 local problems,decoded=Checkpoint.inspectRecorded(record,context)
 if not decoded then return nil,table.concat(problems,";") end
 local source=decoded.roots.life;local history={rival=source.rival,mate=source.mate,skins=source.growth.exuviae,
  wasp=record.wasp,cat=record.cat,water=record.water,breakaway=record.breakaway}
 local problem=validate(source,history);if problem then return nil,problem end
 local meals,why=Meals.prepare(decoded,archiveId);if not meals then return nil,why end
 local rules=record.life_rules or {mode="main",rules="standard"}
 if source.mode~=rules.mode or source.rules~=rules.rules or (source.needs.gentle==true)~=(rules.rules=="gentle") then return nil,"record and life rules disagree" end
 local l:any={};for k,v in source do
  pulse();if FIELDS[k]=="preserve" then l[k]=v end
 end
 setmetatable(l,Loop)
 -- Keep all growth mechanics/configuration. Old skins are located in the old
 -- habitat and belong to history, not the active Preserve renderer.
 local g:any={};for k,v in source.growth do pulse();g[k]=v end
 setmetatable(g,Growth);g.exuviae={};l.growth=g;l.needs=source.needs
 l.asleep=false;l.checkpointDue=false;l.notice="";l.noticeSeconds=0;l.morningText="";l.restoreGrace=Loop.RESTORE_GRACE_TICKS;l.events={}
 l:applyLight()
 local graph,errorText=Objects.capture({life=l},CLASSES,{["portable.needs"]=source.needs})
 if not graph then return nil,errorText end
 local historyGraph,historyError=Objects.capture(history,{},{});if not historyGraph then return nil,historyError end
 local map=record.world_map
 if type(map)~="table" then return nil,"explicit recorded map required" end
 local sourceOrigin,originError=origin({world=map.world or "test_garden",seed=map.seed,revision=map.revision,region=map.region,retreat=map.retreat,save_life=record.save_life})
 if not sourceOrigin then return nil,originError end
 -- Use object records for historical vectors rather than JSON-copying native
 -- Vector3 values or exposing shared live tables.
 local out={format=Life.FORMAT,version=1,archive=archiveId,meals=meals,graph=graph,history=historyGraph,
  origin=sourceOrigin}
 freeze(out);return out,nil
end
function Life.decode(capsule:any):(any?,string?)
 if type(capsule)~="table" or capsule.format~=Life.FORMAT or capsule.version~=1 or type(capsule.meals)~="table" or capsule.archive~=capsule.meals.archive then return nil,"invalid portable life" end
 for k in capsule do
  if k~="format" and k~="version" and k~="archive" and k~="meals" and k~="graph" and k~="history" and k~="origin" then return nil,"unknown portable life field" end
 end
 local meals,why=Meals.decode(capsule.meals);if not meals then return nil,why end
 local d,problems=Objects.decode(capsule.graph,CLASSES,{["portable.needs"]=meals.needs})
 if not d then return nil,table.concat(problems,";") end
 for root in d.roots do if root~="life" then return nil,"unknown portable life root" end end
 local history,errors=Objects.decode(capsule.history,{},{})
 if not history then return nil,table.concat(errors,";") end
 for root in history.roots do if root~="rival" and root~="mate" and root~="skins" and root~="wasp" and root~="cat" and root~="water" and root~="breakaway" then return nil,"unknown encounter history root" end end
 local sourceOrigin,originError=origin(capsule.origin);if not sourceOrigin then return nil,originError end
 local l=d.roots.life
 if type(l)~="table" or l.needs~=meals.needs or l.grantedSeen~=meals.grantedSeen or l.save~=nil or l.rival~=nil or l.mate~=nil then return nil,"portable life/reserve identity differs" end
 local problem=validate(l,history.roots);if problem then return nil,problem end
 return {life=l,needs=meals.needs,feeding=meals.feeding,history=history.roots,origin=sourceOrigin},nil
end
return table.freeze(Life)
