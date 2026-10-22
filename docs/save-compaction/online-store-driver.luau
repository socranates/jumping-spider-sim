-- Run only in Studio's edit context for the existing Windowsill experience.
-- `lab` and `nativePacket` are supplied by the local fixture loader. All source in lab is the reviewed candidate.
assert(game.GameId==10771103250 and game.PlaceId==120119801868085,"wrong experience/place")
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(),"edit-context test only")
local J=require(lab.Persistence.Json)
local E=require(lab.Persistence.SaveEnvelope)
local Rest=require(lab.Persistence.SaveRest)
local C=require(lab.Server.RestCompression)
local B=require(lab.Server.DataStoreBackend)
local codec=C.engine()
local http=game:GetService("HttpService")
local original=codec:decode(http:JSONDecode(nativePacket))
local spec=Rest.SPECS.main
assert(E.open(spec,original).status=="ok","native-engine fixture is invalid")
local tag="chet_compaction_"..tostring(DateTime.now().UnixTimestampMillis)
local key="R_"..tag.."_main"
assert(string.sub(key,1,18)=="R_chet_compaction_","unsafe key namespace")
local storeName="WindowsillTest_v1"
assert(storeName~="Windowsill_v1","never use production for a probe")
local ds=game:GetService("DataStoreService"):GetDataStore(storeName)
local options=Instance.new("DataStoreGetOptions");options.UseCache=false
local native={}
function native:GetAsync(k) return ds:GetAsync(k,options) end
function native:UpdateAsync(k,fn) return ds:UpdateAsync(k,fn) end
local backend=B.new(native,codec)
assert(native:GetAsync(key)==nil,"test key unexpectedly exists")
local now=os.time()
local first=E.make(spec,original.payload,now,nil,{session=tag})
local ok,_,err=backend:update(key,function(old) assert(old==nil,"test key raced");return first end)
assert(ok,err)
local readOk,read,readErr=backend:read(key)
assert(readOk,readErr)
assert(J.canonical(read.payload)==J.canonical(original.payload),"first fresh API read changed checkpoint")
task.wait()
ok,_,err=backend:update(key,function(old)
 assert(E.open(spec,old).status=="ok","prior rest is not valid")
 local replacement=http:JSONDecode(http:JSONEncode(old.payload))
 replacement.created_at+=1
 return E.make(spec,replacement,now+1,old,{session=tag})
end)
assert(ok,err)
readOk,read,readErr=backend:read(key);assert(readOk,readErr)
local opened=E.open(spec,read)
assert(opened.status=="ok" and opened.backup and opened.backup.status=="ok","fresh API read lost current/backup")
assert(J.canonical(opened.backup.payload)==J.canonical(original.payload),"backup changed checkpoint")
local stored=native:GetAsync(key)
assert(E.open(spec,stored).status=="newer","old reader would not preserve new storage")
local storedChars=#http:JSONEncode(stored)
assert(storedChars<C.MAX_STORED_CHARS,"native stored value exceeds budget")
task.wait()
-- Deliberately corrupt only this newly created synthetic fixture, then prove recovery and non-overwrite.
ds:UpdateAsync(key,function(value) assert(value.backup,"fixture has no backup");value.data="damaged-test-frame";return value end)
local damaged=assert(J.canonical(native:GetAsync(key)))
readOk,read,readErr=backend:read(key);assert(readOk,readErr)
opened=E.open(spec,read)
assert(opened.status=="corrupt" and opened.backup and opened.backup.status=="ok","real-store backup recovery failed")
local reached=false
ok=backend:update(key,function() reached=true;return nil end)
assert(not ok and not reached,"damaged current reached a write callback")
assert(J.canonical(native:GetAsync(key))==damaged,"refused update replaced damaged fixture")
print("[CHET_SAVE_ONLINE_PASS]",storeName,key,storedChars,"fresh uncached reads; exact checkpoint; independent backup; corruption recovery; failed update preserved bytes")
options:Destroy()
