--!strict
local Ledger=require(script.Parent.RareLedger)
local Catalog=require(script.Parent.Parent.Data.RareSightings)
local Environment=require(script.Parent.Parent.World.Environment)
local Director={}
-- Optional life fields are part of the existing checkpoint object graph.
function Director.beginLife(history: Ledger.Record,life: any)
 life.rareSerial=Ledger.beginLife(history)
 life.rareGeneration=life.generation or 0;life.rareBorn=life.clock.day;life.rareVisit=nil
end
function Director.ensureLife(history: Ledger.Record,life: any)
 if life.rareSerial==nil then
  -- Legacy rests get the current high-water mark, not another roll on reload.
  if history.serial==0 then Ledger.beginLife(history) end
  life.rareSerial=history.serial;life.rareGeneration=life.generation or 0;life.rareBorn=life.clock.day
 elseif life.rareGeneration~=(life.generation or 0) then Director.beginLife(history,life) end
 history.serial=math.max(history.serial,life.rareSerial)
end
function Director.plan(seed: number,serial: number,born: number): any?
 local spec=Catalog.luna
 if Environment.hash(seed,serial,701)>=spec.chance then return nil end
 return {id=spec.id,serial=serial,day=born+1+math.floor(Environment.hash(seed,serial,703)*spec.days),
  hour=20+Environment.hash(seed,serial,709)*2}
end
function Director.step(history: Ledger.Record,life: any,seed: number): any?
 Director.ensureLife(history,life)
 if life.lifeOver then return nil end
 local spec=Catalog.luna;local day,hour=life.clock.day,life.clock.hour
 local now=(day-1)*24+hour
 local visit=life.rareVisit
 if visit==nil and not history.blocked and (history.claimed[spec.id] or 0)<life.rareSerial then
  local plan=Director.plan(seed,life.rareSerial,life.rareBorn)
  if plan then
   local at=(plan.day-1)*24+plan.hour;local dawn=plan.day*24+6
   local doy=Environment.solar(plan.day,plan.hour).dayOfYear
   if now>=at and now<dawn and doy>=spec.firstDay and doy<=spec.lastDay then
    -- Weather is sampled at the scheduled arrival, not at the player's reload.
    local weather=Environment.sample(plan.day,plan.hour,seed)
    if weather.temperature>=spec.minTemperature and weather.rain<=spec.maxRain then
     history.claimed[spec.id]=life.rareSerial
     visit={id=spec.id,serial=life.rareSerial,day=plan.day,hour=plan.hour}
     life.rareVisit=visit
    end
   end
  end
 end
 if visit==nil or visit.serial~=life.rareSerial then return nil end
 local start=(visit.day-1)*24+visit.hour;local dawn=visit.day*24+6
 if now<start or now>=dawn then return nil end
 -- Current weather never rerolls the arrival. Later rain does not erase it.
 return {id=spec.id,serial=visit.serial,at=spec.at,ageHours=now-start,day=visit.day}
end
function Director.problems(life: any): {string}
 local problems={}
 local function whole(n: any,minimum: number): boolean
  return type(n)=="number" and n==n and n>=minimum and n<=Ledger.MAX_SERIAL and n%1==0
 end
 if life.rareSerial==nil then
  if life.rareBorn~=nil or life.rareGeneration~=nil or life.rareVisit~=nil then table.insert(problems,"rare visit without life identity") end
  return problems
 end
 if not whole(life.rareSerial,1) or not whole(life.rareBorn,1) or not whole(life.rareGeneration,0) then
  table.insert(problems,"invalid rare life identity")
 end
 local v=life.rareVisit
 if v~=nil then
  if type(v)~="table" or v.id~=Catalog.luna.id or v.serial~=life.rareSerial or not whole(v.day,1)
   or type(v.hour)~="number" or v.hour~=v.hour or v.hour<20 or v.hour>=22 then
   table.insert(problems,"invalid rare visit")
  end
 end
 return problems
end
return Director
