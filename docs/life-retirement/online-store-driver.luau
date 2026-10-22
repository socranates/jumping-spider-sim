-- Diagnostic only: called in Studio edit mode with an unparented candidate module tree.
assert(game.GameId==10771103250 and game.PlaceId==120119801868085)
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning())
assert(lab.Parent==nil,"candidate modules must never enter the cloud edit model")
local Shared=lab.Shared
require(Shared.World.WorldMap).use("preserve")
local J=require(Shared.Persistence.Json)
local E=require(Shared.Persistence.SaveEnvelope)
local Rest=require(Shared.Persistence.SaveRest)
local C=require(lab.Server.RestCompression)
local B=require(lab.Server.DataStoreBackend)
local codec=C.engine();local http=game:GetService("HttpService")
local original=codec:decode(http:JSONDecode(nativePacket))
local spec=Rest.SPECS.main;local initial=E.open(spec,original)
assert(initial.status=="ok" or initial.status=="migrated","invalid native fixture")
local record=initial.payload
local function copy(v) return http:JSONDecode(http:JSONEncode(v)) end
local tag="chet_life_"..tostring(DateTime.now().UnixTimestampMillis)
local key="R_"..tag.."_main";local storeName="WindowsillTest_v1"
assert(string.sub(key,1,12)=="R_chet_life_" and #key<50,"unsafe synthetic key")
assert(storeName~="Windowsill_v1")
local ds=game:GetService("DataStoreService"):GetDataStore(storeName)
local options=Instance.new("DataStoreGetOptions");options.UseCache=false
local native={}
function native:GetAsync(k) assert(k==key);return ds:GetAsync(k,options) end
function native:UpdateAsync(k,fn) assert(k==key);return ds:UpdateAsync(k,fn) end
local backend=B.new(native,codec)
assert(native:GetAsync(key)==nil,"synthetic key already exists")
print("[CHET_LIFE_ONLINE_START]",storeName,key)
local now=os.time();local a,b=tag.."_A",tag.."_B"
local first=copy(record);first.save_life=a
local ok,_,err=backend:update(key,function(old) assert(old==nil);return E.make(spec,first,now,nil,{session=tag}) end);assert(ok,err)
local readOk,value,readErr=backend:read(key);assert(readOk,readErr)
assert(J.canonical(E.open(spec,value).payload)==J.canonical(first),"first uncached read changed checkpoint")
task.wait(6)
ok,_,err=backend:update(key,function(old)
 assert(E.open(spec,old).status=="ok" and old.payload.save_life==a)
 return E.make(spec,{save_retired=true,save_life=b},now+1,old,{session=tag})
end);assert(ok,err)
readOk,value,readErr=backend:read(key);assert(readOk,readErr)
local retired=E.open(spec,value)
assert(retired.status=="ok" and Rest.isRetired(retired.payload) and retired.payload.save_life==b)
assert(retired.backup and retired.backup.status=="ok" and J.canonical(retired.backup.payload)==J.canonical(first),"retirement lost backup")
local retiredBytes=assert(J.canonical(native:GetAsync(key)))
ok,_,err=backend:update(key,function(old)
 assert(old.payload.save_life~=a,"stale credential unexpectedly current")
 return nil -- same refusal boundary as the session's guarded writer
end);assert(ok,err)
assert(J.canonical(native:GetAsync(key))==retiredBytes,"refused stale write changed marker")
local reloaded=B.new(native,codec)
readOk,value,readErr=reloaded:read(key);assert(readOk,readErr)
assert(Rest.isRetired(E.open(spec,value).payload),"fresh backend read revived retired life")
task.wait(6)
local second=copy(record);second.save_life=b
ok,_,err=reloaded:update(key,function(old)
 assert(old.payload.save_life==b and Rest.isRetired(old.payload))
 return E.make(spec,second,now+2,old,{session=tag})
end);assert(ok,err)
readOk,value,readErr=reloaded:read(key);assert(readOk,readErr)
local restored=copy(E.open(spec,value).payload);restored.save_life=nil
assert(J.canonical(restored)==J.canonical(record),"new life storage changed simulation fields")
task.wait(6)
local third=copy(second);third.created_at+=1
ok,_,err=reloaded:update(key,function(old) return E.make(spec,third,now+3,old,{session=tag}) end);assert(ok,err)
local stored=native:GetAsync(key);local storedChars=#http:JSONEncode(stored)
assert(storedChars<C.MAX_STORED_CHARS)
local oldSpec={kind=spec.kind,current=1,migrations={},validate=spec.validate}
assert(E.open(oldSpec,stored).status=="newer","schema-1 reader does not refuse new storage")
task.wait(6)
-- Damage only the single synthetic key created above, never a player record.
native:UpdateAsync(key,function(v) assert(v.backup);v.data="damaged-test-frame";return v end)
local damaged=assert(J.canonical(native:GetAsync(key)))
readOk,value,readErr=reloaded:read(key);assert(readOk,readErr)
local opened=E.open(spec,value)
assert(opened.status=="corrupt" and opened.backup and opened.backup.status=="ok")
assert(J.canonical(opened.backup.payload)==J.canonical(second),"independent backup changed")
local reached=false
ok=reloaded:update(key,function() reached=true;return nil end)
assert(not ok and not reached,"damaged frame reached write callback")
assert(J.canonical(native:GetAsync(key))==damaged,"refused update changed damaged fixture")
options:Destroy()
print("[CHET_LIFE_ONLINE_PASS]",storeName,key,storedChars,"native codec; fresh uncached reads; retirement envelope and backup; stale refusal; independent corruption recovery; single synthetic key; not a real client rejoin")
