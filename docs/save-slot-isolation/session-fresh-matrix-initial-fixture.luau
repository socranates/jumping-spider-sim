-- Acceptance cases beyond the retained stale-grant counterexample.
local checks=0
local function check(ok,why) assert(ok,why);checks+=1 end
for index,mode in {"main","free","easy"} do
 for _,scenario in {"same", "changed", "missing", "corrupt", "newer", "unavailable", "memory"} do
  local now=100;local b=MemoryBackend.new();local read=b.read
  local ordinary,fresh=0,0;local fail=false;local uid=9100+index
  local record=realRest(1,mode);record.save_life="fresh-matrix-"..mode
  local initial=SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil)
  local restKey="R_"..uid.."_"..mode
  b:poke(restKey,initial)
  local progress=SaveProgress.default();progress.finished_main=true
  b:poke("P_"..uid,SaveEnvelope.make(SaveProgress.SPEC,progress,90,nil))
  b.read=function(self,key) ordinary+=1;return read(self,key) end
  if scenario~="memory" then
   b.readFresh=function(self,key)
    fresh+=1
    if fail then return false,nil,"offline" end
    return read(self,key)
   end
  end
  local s=SaveSession.new({backend=b,userId=uid,sessionId="fresh-matrix",now=function() return now end})
  check(s:load()=="active","load lost ownership")
  s:enableOffers();for _=1,3 do now+=.1;s:step() end
  local offer=assert(s:offer(mode));local before=assert(Json.canonical(initial))
  local replacement=Json.copy(initial)
  if scenario=="changed" then
   local other=realRest(2,mode);other.save_life=record.save_life
   replacement=SaveEnvelope.make(SaveRest.SPECS[mode],other,90,nil)
  elseif scenario=="missing" then replacement=nil
  elseif scenario=="corrupt" then replacement.checksum="bad"
  elseif scenario=="newer" then replacement.version=initial.version+1
  elseif scenario=="unavailable" then fail=true end
  b:poke(restKey,replacement)
  local storedBefore=Json.canonical(replacement);local writes=b.writes
  check(s:requestLife("continue",mode,1,offer.id),"offer submission refused")
  now+=.1;s:step();local r=s.intents.requests[mode]
  if scenario=="same" or scenario=="memory" then
   check(r.state=="writable" and type(r.credential)=="string","unchanged source not granted")
   check(s:setRestForIntent(mode,realRest(3,mode),r.life,1,r.credential),"unchanged source cannot queue checkpoint")
  elseif scenario=="unavailable" then
   check(r.credential==nil and r.needsCheck and r.nextAt>now,"read failure granted authority or lost backoff")
   check(not s:setRestForIntent(mode,realRest(3,mode),record.save_life,1,"guess"),"failed fresh read admitted write")
   -- Retry a real fresh read after backoff; unchanged source can then resume.
   fail=false;now=r.nextAt+.001;s:step()
   check(r.state=="writable" and type(r.credential)=="string","fresh retry did not restore valid authority")
  else
   check(r.state=="changed" and r.credential==nil,"different source granted authority: "..scenario)
   check(not s:setRestForIntent(mode,realRest(3,mode),record.save_life,1,"guess"),"changed source admitted write")
  end
  check(Json.canonical(b.data[restKey])==storedBefore and b.writes==writes,"validation changed stored data")
  check(Json.canonical(initial)==before,"validation mutated source")
  check(if scenario=="memory" then ordinary>0 and fresh==0 else ordinary==0 and fresh>0,"wrong backend path")
  print("SESSION_FRESH_MATRIX "..mode.." "..scenario)
 end
end
print("SESSION_FRESH_MATRIX passed="..checks.." failed=0")
