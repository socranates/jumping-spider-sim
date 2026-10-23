-- Native server correctness fixture. MemoryBackend only; never publish.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("RecoveryIdleProbe")==true)
local id=tostring(DateTime.now().UnixTimestampMillis)
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local ok,why=xpcall(function()
 print("[RECOVERY_IDLE_NATIVE_BEGIN]",id)
 for _,root in {game.ReplicatedFirst,Shared,script.Parent,game.StarterPlayer.StarterPlayerScripts.Client} do
  for _,it in root:GetDescendants() do
   if it:IsA("Script") or it:IsA("LocalScript") then check(it==script or it.Disabled,"another project executable is enabled: "..it:GetFullName()) end
  end
 end
 local Json=require(Shared.Persistence.Json)
 local Envelope=require(Shared.Persistence.SaveEnvelope)
 local Progress=require(Shared.Persistence.SaveProgress)
 local Session=require(Shared.Persistence.SaveSession)
 local Memory=require(Shared.Persistence.MemoryBackend)
 local Base=require(script.Parent.RecoveryProgressBaselinePrototype)
 local Pipeline=require(script.Parent.RecoveryPipelinePrototype)
 local Idle=require(script.Parent.RecoveryIdlePrototype)
 local Departure=require(script.Parent.RecoveryDeparturePrototype)
 local function fixture()
  local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
  local clock={now=200};local w=Base.new(b,"native_idle")
  local s=Session.new({backend=w,userId="native_idle",sessionId="native-owner",now=function() return clock.now end})
  assert(s:load()=="active");s:enableOffers()
  local held=assert(w:hold(s,true));local c=Pipeline.new(s,{},b,{},{})
  -- Controlled terminal metadata isolates lease/closed-scope behavior. The
  -- full real-discovery/pipeline composition is covered by the CLI cohort.
  c.current={state="cancelled",held=held,ticket={load=s._loadSerial,sessionId=s.id,owner="native_idle",pkey=s.pkey,scheduler=s.sched}}
  s.recoveryOwner=c;local idle=Idle.new(c);local j=assert(idle:begin())
  return b,clock,s,w,c,idle,j
 end
 do
  local b,clock,s,w,c,idle,j=fixture();local raw=Json.copy(b.data[s.pkey]);raw.lock=nil;local original=Json.canonical(raw)
  for _=1,180 do idle:step(j);clock.now+=1 end
  check(j.state=="pending" and j.requests>=6 and j.requests<=8,"native idle renewal failed")
  local current=Json.copy(b.data[s.pkey]);current.lock=nil
  check(Json.canonical(current)==original and w.held~=nil and not w:permitted(w.held),"native heartbeat changed payload/barrier/permit")
  local p=Json.copy(s.progress);p.notebook.opened={"native_departure"};p.settings.MasterVolume=.35;assert(s:setProgress(p))
  local d=Departure.new(c);local departure=assert(d:begin());local before=b.requests;idle:step(j)
  check(j.state=="stopped" and b.requests==before and not s:setProgress(Progress.default()),"native departure failed to stop intake/idle")
  for _=1,24 do if departure.state~="pending" then break end;d:step(departure);clock.now+=1 end
  check(departure.state=="preserved" and departure.requests==2 and b.data[s.pkey].lock==nil,"native departure did not preserve/release")
  check(table.find(b.data[s.pkey].payload.notebook.opened,"native_departure") and b.data[s.pkey].payload.settings.MasterVolume==.35,"native departure lost local progress")
  local nextVisit=Session.new({backend=b,userId="native_idle",sessionId="next-visit",now=function() return clock.now end})
  check(nextVisit:load()=="active" and table.find(nextVisit.progress.notebook.opened,"native_departure"),"native new session failed to load preserved global progress")
 end
 do
  local b,clock,s,w,c,idle,j=fixture();idle:step(j);clock.now=s.sched.lastBeat+30
  b:fail({op="update",key=s.pkey,afterWrite=true,message="timeout"})
  idle:step(j);check(j.phase=="probe" and j.state=="pending","native lost acknowledgement did not require uncached probe")
  clock.now+=3;idle:step(j)
  check(j.phase=="renew" and j.state=="pending" and s.sched.lastBeat==b.data[s.pkey].lock.beat,"native lost-ack probe failed")
 end
 do
  local b,clock,s,w,c,idle,j=fixture();idle:step(j);clock.now=s.sched.lastBeat+30
  local update=b.update
  b.update=function(self,key,fn)
   clock.now+=60;local result=table.pack(update(self,key,fn));clock.now+=35;return table.unpack(result,1,result.n)
  end
  idle:step(j);b.update=update
  check(j.state=="pending" and not c.leaseLost and clock.now-s.sched.lastBeat==35,"native slow acknowledgement falsely expired owner")
 end
 do
  local b,clock,s,w,c,idle,j=fixture();idle:step(j);clock.now=s.sched.lastBeat+30
  local update=b.update
  b.update=function(self,key,fn) coroutine.yield("native-paused");return update(self,key,fn) end
  local co=coroutine.create(function() return idle:step(j) end);local resumed,marker=coroutine.resume(co);assert(resumed,marker)
  check(marker=="native-paused" and s.busy and c.busy and idle.busy and w.activeUpdates==1 and not w:permitted(w.held),"native yielding permit/drain setup failed")
  local d=Departure.new(c);local departure=assert(d:begin());local before=b.requests;d:step(departure)
  check(departure.phase=="drain" and b.requests==before,"native departure raced yielded provider")
  assert(coroutine.resume(co));b.update=update
  check(j.state=="stopped" and w.activeUpdates==0 and not s.busy and not c.busy and not idle.busy,"native provider did not drain")
  for _=1,24 do if departure.state~="pending" then break end;d:step(departure);clock.now+=1 end
  check(departure.state=="preserved","native departure failed after yielded provider")
 end
 for _,foreign in {false,true} do
  local b,clock,s,w,c,idle,j=fixture()
  if foreign then b:poke(s.pkey,Envelope.withLock(b.data[s.pkey],{session="foreign",beat=clock.now}))
  else clock.now=j.expiresAt end
  local writes=b.writes;local raw=Json.canonical(b.data[s.pkey]);idle:step(j)
  check(j.state=="lost" and c.leaseLost and j.result.requiresFreshSession and not j.result.gameplayAuthorized,"native unsafe scope was not fenced")
  check(b.writes==writes and Json.canonical(b.data[s.pkey])==raw,"native unsafe scope changed storage")
 end
 print("[RECOVERY_IDLE_NATIVE_PASS]",id,count,"memory_backend_only")
end,debug.traceback)
if not ok then warn("[RECOVERY_IDLE_NATIVE_FAIL]",id,tostring(why)) end
