-- Real SaveSession and valid checkpoints; a four-second cache at its backend
-- boundary. EXPECT_FRESH distinguishes the unchanged baseline from the candidate.
local passedCache=0
local function verifyCache(ok,why) assert(ok,why);passedCache+=1 end
for i,mode in {"main","free","easy"} do
 local now=100;local backend=MemoryBackend.new();local fresh=backend.read
 local cache,expires={},{};local freshCalls,cachedCalls=0,0
 backend.read=function(self,key)
  cachedCalls+=1
  if expires[key] and now<expires[key] then return true,Json.copy(cache[key]),nil end
  local ok,value,why=fresh(self,key)
  if ok then cache[key]=Json.copy(value);expires[key]=now+4 end
  return ok,value,why
 end
 backend.readFresh=function(self,key) freshCalls+=1;return fresh(self,key) end
 local uid=9000+i
 local original=realRest(1,mode);original.save_life="same-life-"..mode
 local changed=realRest(2,mode);changed.save_life=original.save_life
 local a=SaveEnvelope.make(SaveRest.SPECS[mode],original,90,nil,{session="original"})
 local b=SaveEnvelope.make(SaveRest.SPECS[mode],changed,90,nil,{session="foreign"})
 verifyCache(a.checksum~=b.checksum and #SaveRest.check(mode,original)==0 and #SaveRest.check(mode,changed)==0,"invalid changed-rest fixture")
 backend:poke("R_"..uid.."_"..mode,a)
 local progress=SaveProgress.default();progress.finished_main=true
 backend:poke("P_"..uid,SaveEnvelope.make(SaveProgress.SPEC,progress,90,nil))
 local s=SaveSession.new({backend=backend,userId=uid,sessionId="cache-probe",now=function() return now end})
 verifyCache(s:load()=="active","session did not acquire progress ownership")
 s:enableOffers()
 for _=1,3 do now+=.1;s:step() end
 local offer=assert(s:offer(mode));verifyCache(offer.record.save_life==original.save_life,"displayed source absent")
 local previous=assert(Json.canonical(a));local replacement=assert(Json.canonical(b))
 backend:poke(s.rkey[mode],b) -- another writer changes the exact observed rest
 verifyCache(s:requestLife("continue",mode,1,offer.id),"choice refused before validation")
 local writes=backend.writes;now+=.1;s:step()
 local r=s.intents.requests[mode]
 if EXPECT_FRESH then
  verifyCache(r.state=="changed" and r.credential==nil,"fresh validation granted a stale observation")
  verifyCache(freshCalls>0 and cachedCalls==0,"session did not use the fresh backend method")
  verifyCache(not s:setRestForIntent(mode,realRest(3,mode),original.save_life,1,"guess"),"changed source admitted a checkpoint")
 else
  verifyCache(r.state=="writable" and type(r.credential)=="string","baseline stale grant did not reproduce")
  verifyCache(r.expected.checksum==a.checksum and r.expected.checksum~=b.checksum,"baseline did not bind the stale checksum")
  -- The final UpdateAsync fence still protects the actual stored replacement.
  verifyCache(s:setRestForIntent(mode,realRest(3,mode),r.life,1,r.credential),"baseline did not queue its erroneously granted candidate")
  now+=.1;s:step()
  verifyCache(r.state=="changed" and r.credential==nil,"final write CAS failed to revoke stale authority")
 end
 verifyCache(Json.canonical(backend.data[s.rkey[mode]])==replacement and backend.writes==writes,"probe overwrote the foreign rest")
 verifyCache(Json.canonical(a)==previous,"probe mutated original observation")
 print("SESSION_CACHE_CASE "..mode.." "..(if EXPECT_FRESH then "stale_grant_refused" else "stale_grant_reproduced_final_CAS_protected"))
end
print("SESSION_CACHE_PROBE passed="..passedCache.." failed=0 fresh="..tostring(EXPECT_FRESH))
