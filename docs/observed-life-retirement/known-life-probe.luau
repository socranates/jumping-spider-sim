local Session=require("../src/Shared/Persistence/SaveSession")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local clock=100000
local backend=Memory.new()
local function make(id) return Session.new({backend=backend,userId=991,sessionId=id,now=function() return clock end,sleep=function(dt) clock+=dt end}) end
local function run(s,n) for _=1,n do clock+=1;s:step() end end
local b=make("visitor");assert(b:load()=="active")
b:beginLife("main",1);run(b,15);assert(b.lifeRequests.main.done)
local old=b.lifeTokens.main
clock+=Rules.LOCK_STALE+1
local a=make("owner");assert(a:load()=="active")
a:beginLife("main",1);run(a,15);assert(a.lifeRequests.main.done and a.lifeTokens.main~=old)
-- Visitor remembers an old slot, but has not yet discovered its expired lease.
b:beginLife("main",2);run(b,1);assert(b.state=="session" and b.reason=="other_session")
a:flush(clock+20)
local before=assert(Json.canonical(backend.data.R_991_main))
run(b,45)
local after=assert(Json.canonical(backend.data.R_991_main))
print("KNOWN_LIFE_RETIRE", "preserved="..tostring(before==after),"ack="..tostring(b.lifeRequests.main.done),"state="..b.state)
assert(before==after and not b.lifeRequests.main.done,"a prior observation must not authorize retiring a different life")
