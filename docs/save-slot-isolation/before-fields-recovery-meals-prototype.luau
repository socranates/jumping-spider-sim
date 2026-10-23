--!strict
-- Private portable-meal preparation, after recorded-world inspection. No ecology,
-- clock, growth, destination commit or store permission is supplied by this module.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Needs=require(Shared.Life.NeedsModel)
local Feeding=require(Shared.Prey.Feeding)
local Random=require(Shared.Prey.PreyRandom)
local Objects=require(Shared.Persistence.ObjectRecord)
local Work=require(Shared.Persistence.SaveWork)
local Meals={}
Meals.FORMAT="the-windowsill portable meals"
local CLASSES={NeedsModel=Needs,Feeding=Feeding,PreyRandom=Random}
local NEEDS={energy=true,rest=true,elapsedS=true,grantedTotal=true,grantedBySource=true,grantsMade=true,grantsRefused=true,
 lifeMode=true,gentle=true,starvingHours=true,starvingStreakH=true,_accActive=true,_accStill=true,_accHoursAwake=true,_accHoursAsleep=true,
 drainScale=true,gentleDrainScale=true,streakDecay=true,moveCosts=true,onEnergyChanged=true}
local FEEDING={held=true,struggling=true,feeding=true,grip=true,elapsed=true,waiting=true,jerk=true,venom=true,swallow=true,needs=true,
 taken=true,granted=true,ledger=true,mealsFinished=true,auto=true,tap=true,note=true,rng=true,startGrip=true,tapGain=true,jerkScale=true,
 drainScale=true,tire=true,cap=true,game=true,tapToFeed=true,biteWindow=true,bites=true,bitePulse=true}
local function pulse() local f=Work.pulse();if f then f() end end
local function finite(v:any):boolean return type(v)=="number" and v==v and v>=0 and v<math.huge end
local function prefix(id:any):string?
 if type(id)~="string" or #id<1 or #id>64 or string.match(id,"^[%w_-]+$")==nil then return nil end
 return "@archive/"..id.."/"
end
local function fields(value:any,known:any):string?
 for key in value do pulse();if not known[key] then return "unsupported portable field: "..tostring(key) end end
 return nil
end
local function remap(values:any,p:string):(any?,string?)
 if type(values)~="table" or getmetatable(values)~=nil then return nil,"invalid meal ledger" end
 local out={}
 for k,v in values do
  pulse()
  if type(k)~="string" or #k==0 or not finite(v) then return nil,"unsupported meal source/value" end
  out[p..k]=v
 end
 return out,nil
end
local function freeze(value:any)
 if type(value)~="table" then return end
 for _,v in value do pulse();freeze(v) end
 table.freeze(value)
end
local function validate(n:any,f:any,seen:any):string?
 if getmetatable(n)~=Needs or getmetatable(f)~=Feeding or f.needs~=n then return "meal/reserve graph differs" end
 if f.held~=nil or f.struggling~=false or f.feeding~=false then return "meal in progress cannot be projected" end
 local why=fields(n,NEEDS) or fields(f,FEEDING);if why then return why end
 if n.grantedBySource==f.ledger then return "reserve and feeding books must be separate" end
 if not finite(seen) or not finite(n.grantedTotal) or seen>n.grantedTotal+1e-6 then return "invalid growth food cursor" end
 if type(n.grantedBySource)~="table" or not Needs.new():load(n:toRecord()) then return "invalid reserve record" end
 if getmetatable(f.rng)~=Random then return "invalid feeding random stream" end
 local sum=0
 for _,book in {n.grantedBySource,f.ledger} do
  if type(book)~="table" or getmetatable(book)~=nil then return "invalid meal ledger" end
  for k,v in book do
   pulse();if type(k)~="string" or #k==0 or not finite(v) then return "unsupported meal source/value" end
   if book==f.ledger then sum+=v end
  end
 end
 if not finite(f.granted) or math.abs(sum-f.granted)>1e-6 or f.granted>n.grantedTotal+1e-6
  or not finite(f.taken) or f.granted>f.taken+1e-6 or not finite(f.mealsFinished) or f.mealsFinished%1~=0 then return "invalid feeding totals" end
 return nil
end
function Meals.prepare(decoded:any,archiveId:string):(any?,string?)
 local p=prefix(archiveId);if not p then return nil,"invalid archive identity" end
 if type(decoded)~="table" or type(decoded.roots)~="table" then return nil,"recorded inspection required" end
 local roots=decoded.roots;local n=roots.needs;local f=if type(roots.prey)=="table" then roots.prey.feeding else nil
 local life=roots.life
 if type(life)~="table" or life.needs~=n then return nil,"meal/reserve graph differs" end
 local why=validate(n,f,life.grantedSeen);if why then return nil,why end
 local ledger,errorText=remap(f.ledger,p);if not ledger then return nil,errorText end
 local by,byError=remap(n.grantedBySource,p);if not by then return nil,byError end
 -- The only excluded field is a running program's UI callback, not progress.
 -- The destination reconnects its own callback after the full graph is prepared.
 local ownedNeeds={};for k,v in n do pulse();if k~="onEnergyChanged" then ownedNeeds[k]=v end end
 setmetatable(ownedNeeds,Needs);ownedNeeds.grantedBySource=by
 local ownedFeeding={};for k,v in f do pulse();ownedFeeding[k]=v end
 setmetatable(ownedFeeding,Feeding);ownedFeeding.needs=ownedNeeds;ownedFeeding.ledger=ledger
 local graph,problem=Objects.capture({needs=ownedNeeds,feeding=ownedFeeding},CLASSES,{})
 if not graph then return nil,problem end
 local out={format=Meals.FORMAT,version=1,archive=archiveId,namespace=p,grantedSeen=life.grantedSeen,graph=graph}
 freeze(out);return out,nil
end
-- A private in-process capsule only. The future transport/storage boundary must
-- additionally enforce its aggregate node/character budget before decode.
function Meals.decode(capsule:any):(any?,string?)
 if type(capsule)~="table" or capsule.format~=Meals.FORMAT or capsule.version~=1 then return nil,"invalid portable meals" end
 local p=prefix(capsule.archive);if not p or p~=capsule.namespace then return nil,"invalid portable namespace" end
 for k in capsule do if k~="format" and k~="version" and k~="archive" and k~="namespace" and k~="grantedSeen" and k~="graph" then return nil,"unknown portable meals field" end end
 local d,why=Objects.decode(capsule.graph,CLASSES,{})
 if not d then return nil,table.concat(why,";") end
 local n,f=d.roots.needs,d.roots.feeding
 if getmetatable(n)~=Needs or getmetatable(f)~=Feeding or f.needs~=n or n.onEnergyChanged~=nil then return nil,"portable reserve identity differs" end
 for root in d.roots do if root~="needs" and root~="feeding" then return nil,"unknown portable root" end end
 local problem=validate(n,f,capsule.grantedSeen);if problem then return nil,problem end
 for _,book in {n.grantedBySource,f.ledger} do
  for key in book do if string.sub(key,1,#capsule.namespace)~=capsule.namespace then return nil,"unscoped historical meal" end end
 end
 return {needs=n,feeding=f,grantedSeen=capsule.grantedSeen},nil
end
return table.freeze(Meals)
