-- Private correctness checks. Never publish; no real DataStore requests.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and workspace:GetAttribute("SessionCacheProbe")==true)
local Shared=game.ReplicatedStorage.Shared
local Json=require(Shared.Persistence.Json)
local MemoryBackend=require(Shared.Persistence.MemoryBackend)
local SaveEnvelope=require(Shared.Persistence.SaveEnvelope)
local SaveProgress=require(Shared.Persistence.SaveProgress)
local SaveRest=require(Shared.Persistence.SaveRest)
local SaveSession=require(Shared.Persistence.SaveSession)
local Backend=require(script.Parent.DataStoreBackend)
local fixtures=require(script.Parent.SessionFixtures)
local function realRest(ticks,mode) return Json.copy(fixtures[mode][tostring(ticks)]) end
local id=tostring(DateTime.now().UnixTimestampMillis)
local ok,err=xpcall(function()
 print("[NATIVE_SESSION_CACHE_BEGIN]",id)
-- Real SaveSession + real DataStoreBackend; simulated four-second DataStore cache.
-- The payloads were captured by the real checkpoint code in the CLI fixture.
local checks=0
local function check(ok,why) assert(ok,why);checks+=1 end
for index,mode in {"main","free","easy"} do
 for _,scenario in {"same","changed","missing","corrupt","newer","unavailable"} do
  local now=100;local storage=MemoryBackend.new();local uid=9200+index
  local ds={cache={},expires={},fresh=0,ordinary=0,fail=false}
  function ds:GetAsync(key,options)
   if options and options.UseCache==false then self.fresh+=1 else
    self.ordinary+=1
    if self.expires[key] and now<self.expires[key] then return Json.copy(self.cache[key]) end
   end
   if self.fail then error("503: unavailable") end
   local ok,value,why=storage:read(key);assert(ok,why)
   self.cache[key]=Json.copy(value);self.expires[key]=now+4
   return value
  end
  function ds:UpdateAsync(key,fn)
   local ok,value,why=storage:update(key,fn);assert(ok,why)
   self.cache[key]=Json.copy(value);self.expires[key]=now+4
   return value
  end
  local backend=Backend.new(ds)
  local record=realRest(1,mode);record.save_life="adapter-"..mode
  local initial=SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil)
  local key="R_"..uid.."_"..mode
  storage:poke(key,initial)
  local progress=SaveProgress.default();progress.finished_main=true
  storage:poke("P_"..uid,SaveEnvelope.make(SaveProgress.SPEC,progress,90,nil))
  local s=SaveSession.new({backend=backend,userId=uid,sessionId="adapter-probe",now=function() return now end})
  check(s:load()=="active","adapter load failed")
  s:enableOffers();for _=1,3 do now+=.1;s:step() end
  local offer=assert(s:offer(mode));local original=Json.canonical(initial)
  local replacement=Json.copy(initial)
  if scenario=="changed" then
   local other=realRest(2,mode);other.save_life=record.save_life
   replacement=SaveEnvelope.make(SaveRest.SPECS[mode],other,90,nil)
  elseif scenario=="missing" then replacement=nil
  elseif scenario=="corrupt" then replacement.checksum="bad"
  elseif scenario=="newer" then replacement.schema=initial.schema+1
  elseif scenario=="unavailable" then ds.fail=true end
  storage:poke(key,replacement)
  local stored=Json.canonical(replacement);local writes=storage.writes
  check(s:requestLife("continue",mode,1,offer.id),"adapter choice refused")
  now+=.1;s:step();local r=s.intents.requests[mode]
  if scenario=="same" then
   check(r.state=="writable" and type(r.credential)=="string","unchanged source not writable")
  elseif scenario=="unavailable" then
   check(r.credential==nil and r.needsCheck and r.nextAt>now,"failed uncached request granted authority")
   ds.fail=false;now=r.nextAt+.001;s:step()
   check(r.state=="writable" and type(r.credential)=="string","uncached retry failed")
  else check(r.state=="changed" and r.credential==nil,"foreign source accepted: "..scenario) end
  check(ds.ordinary==0 and ds.fresh>0,"adapter silently used cached GetAsync")
  check(Json.canonical(storage.data[key])==stored and storage.writes==writes,"session validation wrote source")
  check(Json.canonical(initial)==original,"original observation mutated")
  print("SESSION_ADAPTER_CASE "..mode.." "..scenario)
 end
end
print("SESSION_ADAPTER passed="..checks.." failed=0")

assert(checks==111,"unexpected assertion count")
print("[NATIVE_SESSION_CACHE_PASS]",id,checks)
end,debug.traceback)
if not ok then warn("[NATIVE_SESSION_CACHE_FAIL]",id,tostring(err)) end
