do
local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read
local s={cfg={userId="a"},id="startup-visit",backend=b,sched=Scheduler.new(),counters={requests=0},now=function() return 100 end,
 state="loading",intents={requests={}},lifeRequests={},pkey="P_a"}
b.source=b;b.boundSource=b;b.boundSession=s
local rt={session=s,phase="normal",loading=true};local live=true
local startup=Startup.new(function() live=false;return 80,80 end,s.now)
local startupTicket=startup:attach(rt);s._loadSerial=1
local gate=Admission.new({now=s.now,available=function() return {read=80,write=80} end,actorRead=20,actorWrite=20,serverRead=40,serverWrite=40,headroom=0})
local scope=assert(gate:open("a",s.id));assert(gate:importLegacy(scope,s.sched.started))
local j={requests=0};local worker=Worker.new(s,j,{gate=gate,scope=scope},4,function() return live end)
local state,result,asked=worker:poll("readRawFresh","x",nil)
assert(b.requests==0,"actual startup scheduler cancellation still started a provider")
assert(state=="cancelled" and result==nil and not asked and j.requests==0 and s.counters.requests==0,"actual startup callback produced a request/result")
assert(startupTicket.startupRequests==1 and startup.granted==1 and #s.sched.started==1,"actual startup wrapper was not exercised")
assert(gate:inspect().history==1 and gate:inspect().started==0,"ended startup dispatch refunded debt or failed to drain")
print("STARTUP_DISPATCH_GUARD passed=4 failed=0 groups=1 actual_startup_wrapper=true")
end
