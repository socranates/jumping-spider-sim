-- Boundary tests use a reversible in-memory adapter, not a simulated Zstandard performance claim.
local Compression=require("../src/Server/RestCompression")
local Backend=require("../src/Server/DataStoreBackend")
local Json=require("../src/Shared/Persistence/Json")
local Envelope=require("../src/Shared/Persistence/SaveEnvelope")
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function copy(v) if type(v)~="table" then return v end local out={} for k,x in v do out[k]=copy(x) end return out end
local values,texts={},{}
local decompressions=0
local codec=Compression.new({serialize=Json.canonical,
 compress=function(text) local id="packed-"..tostring(#texts+1);texts[#texts+1]=text;values[id]=text;return id end,
 expandedSize=function(id) return if values[id] then #values[id] else nil end,
 decompress=function(id) decompressions+=1;return assert(values[id]) end,
 parse=function(text) return copy(assert(values[text])) end,
})
local spec={kind="rest_main",current=1,migrations={},validate=function(v) return {},v end}
local raw=Envelope.make(spec,{rng=914,phase=-1.2345678912345678,refs={{["$o"]=1}}},10,nil,nil)
values[assert(Json.canonical(raw))]=raw
local wrapped=codec:encode(raw)
check(wrapped.schema==2 and wrapped.payload==nil,"outer header is not opaque")
check(Envelope.open(spec,wrapped).status=="newer","old server did not recognize newer save")
check(assert(Json.canonical(codec:decode(wrapped)))==assert(Json.canonical(raw)),"transport changed the envelope")
check(codec:decode(raw)==raw and codec:decode(nil)==nil,"legacy/missing data changed")
local newer=copy(wrapped);newer.schema=3
check(codec:decode(newer)==newer,"future transport decoded")
local function refuses(v)
 local before=decompressions
 check(not pcall(function() codec:decode(v) end),"malformed wrapper accepted")
 check(decompressions==before,"invalid header allocated expanded payload")
end
for _,bytes in {0,-1,.5,math.huge,Compression.MAX_EXPANDED_BYTES+1,wrapped.bytes+1} do
 local bad=copy(wrapped);bad.bytes=bytes;refuses(bad)
end
local bad=copy(wrapped);bad.data="not-compressed";refuses(bad)
bad=copy(wrapped);bad.schema=1;refuses(bad)
bad=copy(wrapped);bad.kind="progress";refuses(bad)
local forged=copy(wrapped);forged.updatedAt+=1
check(not pcall(function() codec:decode(forged) end),"mismatched inner header accepted")
local ds={data={R_1_main=wrapped,P_1={notebook=true}},calls=0}
function ds:GetAsync(key) return copy(self.data[key]) end
function ds:UpdateAsync(key,transform)
 self.calls+=1
 local candidate=transform(copy(self.data[key]))
 -- Real UpdateAsync can repeat a callback. It must always receive decoded state.
 candidate=transform(copy(self.data[key]))
 if candidate~=nil then self.data[key]=copy(candidate) end
 return copy(self.data[key])
end
local backend=Backend.new(ds,codec)
local ok,read=backend:read("R_1_main")
check(ok and read.payload.rng==914,"backend did not decode read")
local progress=select(2,backend:read("P_1"))
check(progress.notebook==true,"progress store changed")
local seen=0
ok,read=backend:update("R_1_main",function(old)
 seen+=1;check(old.schema==1 and old.payload.rng==914,"transform received transport instead of envelope")
 values[assert(Json.canonical(old))]=copy(old)
 return old
end)
check(ok and seen==2 and read.schema==1 and ds.data.R_1_main.schema==2,"repeated transform failed")
local previous=assert(Json.canonical(ds.data.R_1_main))
ds.data.R_1_main.bytes+=1
ok=backend:update("R_1_main",function() error("must not reach transform") end)
check(not ok,"corrupt stored wrapper reached update")
ds.data.R_1_main.bytes-=1
check(assert(Json.canonical(ds.data.R_1_main))==previous,"failed read replaced earlier storage")
ok=backend:update("R_1_main",function() return nil end)
check(ok and assert(Json.canonical(ds.data.R_1_main))==previous,"cancelled update changed stored bytes")
local max=Compression.MAX_STORED_CHARS
Compression.MAX_STORED_CHARS=1
ok=backend:update("R_1_main",function(old) return old end)
check(not ok and assert(Json.canonical(ds.data.R_1_main))==previous,"oversize output replaced prior save")
Compression.MAX_STORED_CHARS=max
-- Independent blobs preserve the pre-compression checksum/backup recovery behavior.
local withBackup=Envelope.make(spec,copy(raw.payload),20,raw,nil)
local currentOnly=copy(withBackup);currentOnly.backup=nil
values[assert(Json.canonical(currentOnly))]=currentOnly
local backupFull=copy(raw)
values[assert(Json.canonical(backupFull))]=backupFull
local two=codec:encode(withBackup)
check(two.backup~=nil and two.backup.data~=two.data,"backup is not independently compressed")
check(assert(Json.canonical(codec:decode(two)))==assert(Json.canonical(withBackup)),"backup round-trip changed the envelope")
local brokenCurrent=copy(two);brokenCurrent.data="damaged-current"
local recovered=codec:decode(brokenCurrent,true)
local opened=Envelope.open(spec,recovered)
check(opened.status=="corrupt" and opened.backup and opened.backup.status=="ok","good backup was lost when current blob broke")
check(opened.backup.payload.rng==914,"wrong backup recovered")
check(not pcall(function() codec:decode(brokenCurrent) end),"corrupt current reached a write callback")
ds.data.R_1_main=brokenCurrent
ok,read=backend:read("R_1_main")
check(ok and Envelope.open(spec,read).backup.status=="ok","backend did not offer recovered backup")
local brokenBytes=assert(Json.canonical(ds.data.R_1_main))
ok=backend:update("R_1_main",function() error("must not transform corrupt storage") end)
check(not ok and assert(Json.canonical(ds.data.R_1_main))==brokenBytes,"corrupt current storage was overwritten")
local brokenBackup=copy(two);brokenBackup.backup.data="damaged-backup"
opened=Envelope.open(spec,codec:decode(brokenBackup))
check(opened.status=="ok" and opened.backup.status=="corrupt","damaged backup hid valid current")
local futureBackup=copy(two);futureBackup.backup.schema=3
check(codec:decode(futureBackup)==futureBackup,"future backup was decoded or made writable")
local unknown=copy(two);unknown.futureMetadata={keep=true}
check(codec:decode(unknown)==unknown,"unknown transport metadata was silently discarded")
local nested=copy(two);nested.backup.backup=copy(two.backup)
opened=Envelope.open(spec,codec:decode(nested))
check(opened.status=="ok" and opened.backup.status=="corrupt","nested backup accepted")
-- Native Studio evidence: UpdateAsync can log a transform error yet return nil without raising.
-- This adapter emulates that API boundary; an outer pcall alone must not report success.
local nativeLike={data={R_probe_main=copy(two),P_probe={n=1}},transformErrors=0,replay=false}
function nativeLike:GetAsync(key) return copy(self.data[key]) end
function nativeLike:UpdateAsync(key,fn)
 local good,candidate=pcall(fn,copy(self.data[key]))
 if not good then self.transformErrors+=1;return nil end
 if self.replay then
  good,candidate=pcall(fn,copy(self.data[key]))
  if not good then self.transformErrors+=1;return nil end
 end
 if candidate~=nil then self.data[key]=copy(candidate) end
 return if candidate~=nil then copy(self.data[key]) else nil
end
local guarded=Backend.new(nativeLike,codec)
local before=assert(Json.canonical(nativeLike.data.R_probe_main))
local reached=0
local worked,value,why=guarded:update("R_probe_main",function() reached+=1;error("intentional transform refusal",0) end)
check(not worked and value==nil and type(why)=="string" and string.find(why,"intentional transform refusal",1,true)~=nil,"native swallowed transform error was reported as success")
check(reached==1 and assert(Json.canonical(nativeLike.data.R_probe_main))==before,"failed transform changed stored current/backup")
check(nativeLike.transformErrors==0,"application error escaped into the native transform callback")
-- Progress has no compression; its transform errors need the same reporting contract.
worked,value,why=guarded:update("P_probe",function() error("progress refusal",0) end)
check(not worked and value==nil and string.find(why,"progress refusal",1,true)~=nil and nativeLike.data.P_probe.n==1,"progress callback error was swallowed")
worked,value,why=guarded:update("R_probe_main",function() return nil end)
check(worked and value==nil and why==nil,"ordinary cancellation was mistaken for an error")
check(assert(Json.canonical(nativeLike.data.R_probe_main))==before,"ordinary cancellation changed storage")
-- Decode failure must cancel before user code; encode failure must cancel before storage.
nativeLike.data.R_probe_main=copy(brokenCurrent);local corruptBefore=assert(Json.canonical(nativeLike.data.R_probe_main));reached=0
worked,value,why=guarded:update("R_probe_main",function(old) reached+=1;return old end)
check(not worked and value==nil and type(why)=="string" and reached==0,"native swallowed decoder error was reported as success")
check(assert(Json.canonical(nativeLike.data.R_probe_main))==corruptBefore,"decoder failure replaced corrupt record or its backup")
nativeLike.data.R_probe_main=copy(two);Compression.MAX_STORED_CHARS=1
worked,value,why=guarded:update("R_probe_main",function(old) return old end)
Compression.MAX_STORED_CHARS=max
check(not worked and value==nil and type(why)=="string","native swallowed encoder error was reported as success")
check(assert(Json.canonical(nativeLike.data.R_probe_main))==before,"encoder failure replaced current/backup")
-- Once any attempt fails, a replay in this operation cannot turn it into a later write.
nativeLike.replay=true;reached=0
worked,value,why=guarded:update("P_probe",function(old) reached+=1;if reached==1 then error("first attempt refusal",0) end;return {n=99} end)
check(not worked and reached==1 and nativeLike.data.P_probe.n==1,"retry after a failed transform was allowed to write")
-- The next operation starts clean, and successful native retries still run normally.
reached=0
worked,value,why=guarded:update("P_probe",function(old) reached+=1;return {n=old.n+1} end)
check(worked and value.n==2 and why==nil and reached==2 and nativeLike.data.P_probe.n==2,"error latch leaked into the next operation or suppressed valid retry")
check(nativeLike.transformErrors==0,"codec failure escaped into the engine callback")
print(`REST_COMPRESSION passed={passed} failed=0`)
