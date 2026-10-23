local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Session=require("../src/Shared/Persistence/SaveSession")
local Rules=require("../src/Shared/Data/SaveRules")
local Baseline=__boundaryBaseline
local case=__boundaryCase
local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
local clock={now=100}
if case=="late-lock" then
 local update=b.update;local first=true
 b.update=function(self,key,fn)
  if first and key=="P_47001" then first=false;clock.now+=Rules.LOCK_STALE+1 end
  return update(self,key,fn)
 end
else
 local read=b.readFresh;local first=true
 b.readFresh=function(self,key)
  local out=table.pack(read(self,key))
  if first then first=false;coroutine.yield("rest-read-returned") end
  return table.unpack(out,1,out.n)
 end
end
local tracked=Baseline.new(b,"47001")
local s=Session.new({backend=tracked,userId=47001,sessionId="session-boundary",now=function() return clock.now end})
tracked:bindSession(s)
if case=="late-lock" then
 local state=s:load(true)
 print("SESSION_BOUNDARY late-lock state="..state.." now="..clock.now.." stored_beat="..b.data.P_47001.lock.beat.." scheduler_beat="..s.sched.lastBeat.." baseline_ack="..tostring(tracked.base~=nil))
 assert(state=="active","late-lock probe did not acquire a synthetic record")
 assert(clock.now-b.data.P_47001.lock.beat<Rules.LOCK_STALE,"initial load reported active with an already expired stored lease")
else
 local co=coroutine.create(function() return s:load() end);local ok,mark=coroutine.resume(co);assert(ok,mark)
 assert(mark=="rest-read-returned","rest read did not suspend after its physical start")
 print("SESSION_BOUNDARY read-account provider="..b.requests.." session="..s.counters.requests.." history="..#s.sched.started)
 assert(s.counters.requests==b.requests and #s.sched.started==b.requests,"in-flight initial rest read is absent from request accounting")
 assert(coroutine.resume(co))
end
print("SESSION_BOUNDARY case="..case.." fixed=true")
