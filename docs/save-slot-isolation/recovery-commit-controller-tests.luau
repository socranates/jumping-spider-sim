do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Rules=require("../src/Shared/Data/SaveRules")
local Commit=__commitControllerPrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function admission(b,clock,id,record)
 local s=SaveSession.new({backend=b,userId=46001,sessionId=id,now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 -- Diagnostic bridge only: production does not yet publish a recorded-world
 -- protected offer. Validate the actual source then use real observation/intent
 -- APIs. This tests admission fencing, not the missing legacy-offer UI wiring.
 local problems,d=Checkpoint.inspectRecorded(record,fresh);assert(#problems==0 and d)
 local offer=assert(s.observations:publish("main",record,{checksum=rest.checksum,updatedAt=rest.updatedAt,life=record.save_life,kind="primary"},true))
 assert(s:requestLife("continue","main",1,offer.id))
 return s,offer
end
local function fixture(options)
 local b=Memory.new();b.readRawFresh=b.read;b.readFresh=b.read;b.updateRaw=b.update
 local clock={now=100};b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(rest));b:poke("R_46001_free",{original="unselected"})
 local s,offer=admission(b,clock,"commit-A",source)
 local a=assert(__packetArchive.prepare("46001","completed-archive",{progress={loaded=true,value=b.data.P_46001},main={loaded=true,value=b.data.R_46001_main},free={loaded=true,value=b.data.R_46001_free},easy={loaded=true}}))
 local repo=__archiveStorePrototype.new(b,"46001");local pub=assert(repo:begin(a,function() return true end))
 for _=1,20 do if pub.state=="pending" then repo:step(pub) end end
 assert(pub.state=="complete")
 local cfg=options or {};cfg.work=cfg.work or {now=function() return 0 end}
 local c=Commit.new(s,codec,b,template,fresh,cfg);local j=assert(c:begin("main",1,offer.id,a))
 return b,clock,s,c,j,a,offer
end
local function archives(b)
 return Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index})
end
local function step(b,clock,s,c,j)
 local before=b.requests;c:step(j)
 check(b.requests-before<=1,"commit issued multiple requests in one step")
 check(#s.sched.started<=Rules.REQUESTS_PER_MINUTE,"commit exceeded session minute allowance")
 clock.now+=1
end
local function drive(b,clock,s,c,j,hook)
 for tick=1,900 do
  if j.state~="pending" then return end
  if hook then hook(tick) end
  step(b,clock,s,c,j)
 end
 error("commit coordinator did not settle")
end
do
 local b,clock,s,c,j,a=fixture();local originalArchive=archives(b);local other=Json.canonical(b.data.R_46001_free)
 s.sched:markDirty("progress",clock.now)
 drive(b,clock,s,c,j)
 check(j.state=="verified" and j.result and j.result.requiresSessionRebind and not j.result.gameplayAuthorized,"coordinated commit failed/granted gameplay: "..tostring(j.problem))
 local payload=assert(__packetPrototype.open(b.data.M1_46001_main,codec,fresh));local q=assert(Envelope.open(Progress.SPEC,b.data.P_46001,false).payload)
 check(Json.canonical(b.data.R_46001_main)==Json.canonical(b.data.M1_46001_main.target) and q.rare.serial>=payload.binding.serial,"assembled commit did not retain rest/global identity")
 check(archives(b)==originalArchive and Json.canonical(b.data.R_46001_free)==other,"coordinator changed archive/unselected save")
 check(s.intents.requests.main.credential==nil and s.intents.requests.main.state=="readonly" and s.sched:isDirty("progress"),"coordinator issued credential/cleared queued observations")
 check(j.plan==nil and j.child==nil and j.work==nil and not c.busy and not s.busy,"commit retained staging/worker lock")
 print("RECOVERY_COMMIT_CONTROLLER completed_requests="..j.requests.." simulated_seconds="..(clock.now-j.started))
end
for _,key in {"M1_46001_main","R_46001_main","P_46001"} do
 local b,clock,s,c,j=fixture();local before=archives(b)
 b:fail({op="update",key=key,afterWrite=true,times=1,message="503: lost acknowledgement"})
 drive(b,clock,s,c,j)
 check(j.state=="verified" and archives(b)==before,"coordinator lost-ack path failed: "..key.." "..tostring(j.problem))
end
do
 local b,clock,s,c,j,a,offer=fixture();local before=archives(b)
 for _=1,800 do
  if j.phase=="progress" then break end
  step(b,clock,s,c,j);assert(j.state=="pending",j.problem)
 end
 check(j.phase=="progress" and b.data.M1_46001_main~=nil,"fixture missed post-rest interruption")
 local saved=Json.canonical(b.data.M1_46001_main);local writes=b.writes
 check(c:cancel(j),"post-rest commit could not cancel")
 local again=Commit.new(s,codec,b,template,fresh,{work={now=function() return 0 end}})
 local restart=assert(again:begin("main",1,offer.id,a));drive(b,clock,s,again,restart)
 check(restart.state=="verified" and Json.canonical(b.data.M1_46001_main)==saved and archives(b)==before,"same-session post-rest restart re-prepared original/proposal")
end
do
 local b,clock,s,c,j,a=fixture()
 for _=1,800 do if j.phase=="progress" then break end;step(b,clock,s,c,j);assert(j.state=="pending",j.problem) end
 local before=archives(b);local saved=Json.canonical(b.data.M1_46001_main);assert(c:cancel(j))
 s:demote("diagnostic_departure",false);clock.now+=Rules.LOCK_STALE+1
 local s2,offer=admission(b,clock,"commit-B",source)
 local next=Commit.new(s2,codec,b,template,fresh,{work={now=function() return 0 end}});local resumed=assert(next:begin("main",1,offer.id,a))
 drive(b,clock,s2,next,resumed)
 check(resumed.state=="verified" and archives(b)==before and Json.canonical(b.data.M1_46001_main)==saved,"new diagnostic session failed post-rest restart: "..tostring(resumed.problem))
end
do
 local b,clock,s,c,j,a,offer=fixture();local originalRest=Json.canonical(b.data.R_46001_main)
 local triggered=false
 drive(b,clock,s,c,j,function()
  if not triggered and j.phase=="inspect" then triggered=true;assert(s:requestLife("continue","main",2,offer.id)) end
 end)
 check(triggered and j.state=="cancelled" and b.data.M1_46001_main==nil and Json.canonical(b.data.R_46001_main)==originalRest,"superseded Continue committed")
end
do
 local b,clock,s,c,j=fixture();local before=archives(b);local changed=false
 drive(b,clock,s,c,j,function()
  if not changed and j.phase=="rest" then changed=true;local p=Envelope.withLock(b.data.P_46001,{session="remote-takeover",beat=clock.now});b:poke("P_46001",p) end
 end)
 check(changed and j.state=="refused" and archives(b)==before,"remote lease takeover granted verified")
end
for _,key in {"A1_46001_index","A1_46001_main"} do
 local b,clock,s,c,j=fixture();b:poke(key,{future=true});local originalRest=Json.canonical(b.data.R_46001_main)
 drive(b,clock,s,c,j)
 check(j.state=="refused" and b.data.M1_46001_main==nil and Json.canonical(b.data.R_46001_main)==originalRest,"corrupt durable archive accepted")
end
do
 local b,clock,s,c,j=fixture({maxRequests=2});drive(b,clock,s,c,j)
 check(j.state=="refused" and j.requests==2 and b.data.M1_46001_main==nil,"request cap not enforced")
end
do
 local b,clock,s,c,j=fixture({timeout=2});drive(b,clock,s,c,j)
 check(j.state=="refused" and b.data.M1_46001_main==nil,"commit deadline not enforced")
end
do
 local b,clock,s,c,j=fixture();local nested=false;local update=b.update
 b.update=function(self,key,fn)
  local before=self.requests;nested=s:step()==false and self.requests==before
  return update(self,key,fn)
 end
 step(b,clock,s,c,j)
 check(nested and not s.busy and not c.busy,"ordinary worker reentered commit request")
 assert(c:cancel(j))
end
do
 local b,clock,s,c,j=fixture()
 b:fail({op="read",key="A1_46001_progress",times=5,message="503: archive read unavailable"})
 local beats=0;local last=s.sched.lastBeat
 drive(b,clock,s,c,j,function() if s.sched.lastBeat~=last then beats+=1;last=s.sched.lastBeat end end)
 check(j.state=="verified" and beats>=3,"archive retry backoff starved lease heartbeat")
end
do
 local b,clock,s,c,j=fixture();b:fail({op="update",key="M1_46001_main",times=1,message="503: write unavailable"})
 drive(b,clock,s,c,j)
 check(j.state=="verified","proposal pre-write failure did not recover with backoff: "..tostring(j.problem))
end
do
 local b,clock,s,c,j=fixture();local crossed=false;local read=b.readRawFresh
 b.readRawFresh=function(self,key)
  local ok,value,why=read(self,key)
  if key=="R_46001_main" and j.phase=="finalRest" then
   crossed=true;b:poke("P_46001",Envelope.withLock(b.data.P_46001,{session="late-takeover",beat=clock.now}))
  end
  return ok,value,why
 end
 drive(b,clock,s,c,j)
 check(crossed and j.state=="refused" and j.result==nil,"final rest read crossed a remote lease takeover")
end
print("RECOVERY_COMMIT_CONTROLLER passed="..count.." failed=0")
end
