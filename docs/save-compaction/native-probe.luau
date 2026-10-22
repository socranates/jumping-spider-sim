assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning(),"local edit-mode probe only")
local Shared=game.ReplicatedStorage.Shared
require(Shared.World.WorldMap).use("preserve")
local Compression=require(game.ServerScriptService.Server.RestCompression)
local Json=require(Shared.Persistence.Json)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Rest=require(Shared.Persistence.SaveRest)
local http=game:GetService("HttpService")
local numbers={0,-0.0,2^53-1,-2^53+1,1e-300,-1e300,5e-324,-5e-324,1.2345678901234567}
local random=Random.new(914)
for i=1,1000 do table.insert(numbers,random:NextNumber(-1,1)*10^random:NextInteger(-300,300)) end
assert(Json.canonical(http:JSONDecode(http:JSONEncode(numbers)))==Json.canonical(numbers),"native JSON numeric precision failed")
local text=game.ReplicatedStorage.FullWorldRestFixture.Value
local raw=http:JSONDecode(text)
assert(Json.canonical(raw)==text,"native JSON parser changed canonical numbers")
local spec={kind="rest_main",current=1,migrations={},validate=function(p) return Checkpoint.check(p,Rest.stubWorld()),p end}
local prior=Envelope.make(spec,http:JSONDecode(text),1,nil,nil)
local envelope=Envelope.make(spec,raw,2,prior,nil)
local codec=Compression.engine()
local start=os.clock()
local packed=codec:encode(envelope)
local encodeMs=(os.clock()-start)*1000
local storage=#http:JSONEncode(packed)
start=os.clock()
local decoded=codec:decode(packed)
local decodeMs=(os.clock()-start)*1000
assert(Json.canonical(decoded)==Json.canonical(envelope),"envelope or backup changed in transport")
local opened=Envelope.open(spec,decoded)
assert(opened.status=="ok" and opened.backup and opened.backup.status=="ok","decoded current/backup checkpoint rejected: "..table.concat(opened.reasons,"; "))
local oldRead=Envelope.open(spec,packed)
assert(oldRead.status=="newer","old server would not preserve the new format")
assert(storage<Compression.MAX_STORED_CHARS,"native encoded value exceeds budget")
task.wait()
local broken=table.clone(packed);broken.data="not-base64"
local recovery=Envelope.open(spec,codec:decode(broken,true))
assert(recovery.status=="corrupt" and recovery.backup and recovery.backup.status=="ok","current corruption lost backup")
assert(not pcall(function() codec:decode(broken) end),"corrupt current became writable")
local badBackup=table.clone(packed);badBackup.backup=table.clone(packed.backup);badBackup.backup.data="not-base64"
local current=Envelope.open(spec,codec:decode(badBackup))
assert(current.status=="ok" and current.backup.status=="corrupt","backup corruption hid current")
task.wait()
local expands=0
local expand=codec.adapter.decompress
codec.adapter.decompress=function(s) expands+=1;return expand(s) end
local bomb=table.clone(packed);bomb.backup=nil;bomb.bytes=1
bomb.data=codec.adapter.compress(string.rep("x",Compression.MAX_CORE_BYTES+1))
assert(not pcall(function() codec:decode(bomb) end) and expands==0,"oversized actual frame reached decompression")
print("[CHET_COMPRESSION_NATIVE_V2]",#text,#assert(Json.canonical(envelope)),#packed.data+#packed.backup.data,storage,encodeMs,decodeMs,"exact current+backup; independent recovery; frame bound; numeric precision; old reader refuses")
