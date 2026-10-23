local passedController=0
local function checkController(ok,why) assert(ok,why);passedController+=1 end
local function beginSession(b,clock,id)
 local s=SaveSession.new({backend=b,userId=46001,sessionId=id,now=function() return clock.now end})
 checkController(s:load()=="active","session failed to load")
 s:enableOffers();s:step()
 local offer=assert(s:offer("main"));checkController(s:requestLife("continue","main",1,offer.id),"Continue refused")
 local c=__controllerPrototype.new(s,{work={now=function() return 0 end}})
 local j=assert(c:begin("main",1,offer.id,"preserved-original"))
 return s,c,j,offer
end
local function fixtureController()
 local b=MemoryBackend.new();b.readFresh=b.read;b.readRawFresh=b.read
 local clock={now=100};local rec=realRest(1,"main");rec.save_life="legacy-garden"
 b:poke("R_46001_main",SaveEnvelope.make(SaveRest.SPECS.main,rec,90,nil))
 local s,c,j,offer=beginSession(b,clock,"controller-A")
 return s,c,j,b,clock,offer
end
local function finishController(c,j,s,b,clock,hook)
 local spent=0;local cpuWithoutBudget=0
 for tick=1,900 do
  if j.state~="pending" then break end
  if hook then hook(tick) end
  local before=b.requests;local allowed=s.sched:budgetOk(clock.now)
  local phase=j.phase;local worker=if j.collection then j.collection.work else j.work
  c:step(j)
  checkController(b.requests-before<=1,"controller issued multiple requests in one step")
  checkController(#s.sched.started<=SaveRules.REQUESTS_PER_MINUTE,"controller exceeded session minute allowance")
  if not allowed and worker and worker.state~="pending" then cpuWithoutBudget+=1 end
  spent+=b.requests-before;clock.now+=1
 end
 return spent,cpuWithoutBudget
end
do
 local s,c,j,b,clock=fixtureController();local rest=Json.canonical(b.data.R_46001_main)
 s.sched:markDirty("progress",clock.now) -- preserved for the ordinary worker later
 b:fail({op="update",key="A1_46001_progress",times=1,afterWrite=true,message="503: lost acknowledgement"})
 local spent,cpu=finishController(c,j,s,b,clock)
 checkController(j.state=="ready" and j.plan~=nil,"controller did not finish: "..tostring(j.problem))
 checkController(b.data.A1_46001_index.complete and j.plan.entries.progress.raw.lock.beat<b.data.P_46001.lock.beat,"original lock metadata was not preserved")
 checkController(Json.canonical(b.data.R_46001_main)==rest and s.intents.requests.main.credential==nil,"archive preparation modified original rest or granted permission")
 checkController(s.sched:isDirty("progress"),"controller cleared ordinary queued progress")
 checkController(clock.now-j.started>=120 and spent>=19,"fixture missed long budgeted collection/publication")
 checkController(j.collection==nil and j.publication==nil and j.work==nil and not s.busy and not c.busy,"completed controller retained staging or worker lock")
 print("RECOVERY_CONTROLLER long_pipeline_requests="..spent.." elapsed_seconds="..(clock.now-j.started).." cpu_without_budget="..cpu)
 -- End the old owned session without changing any content; acquire a new lease.
 local archived=Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index})
 s:demote("test_departure",false);clock.now+=60;s:step()
 local s2,c2,j2=beginSession(b,clock,"controller-B")
 finishController(c2,j2,s2,b,clock)
 checkController(j2.state=="ready","complete archive failed restart: "..tostring(j2.problem))
 checkController(Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index})==archived,"restart replaced original archive metadata")
 s2:demote("test_departure",false);clock.now+=60;s2:step()
 b:poke("R_46001_free","different original from a later life")
 local s3,c3,j3=beginSession(b,clock,"controller-C")
 finishController(c3,j3,s3,b,clock)
 checkController(j3.state=="refused" and j3.plan==nil,"existing archive silently accepted a changed unselected slot")
 checkController(Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index})==archived,"conflict replaced an immutable original archive")
end
do
 local s,c,j,b,clock=fixtureController()
 for _=1,500 do
  if b.data.A1_46001_progress then break end
  c:step(j);clock.now+=1
 end
 local anchor=Json.canonical(b.data.A1_46001_progress)
 checkController(anchor~="null" and b.data.A1_46001_index==nil,"fixture missed interrupted publication")
 checkController(c:cancel(j),"publication did not cancel")
 s:demote("test_departure",false);clock.now+=60;s:step()
 local s2,c2,j2=beginSession(b,clock,"controller-restart")
 finishController(c2,j2,s2,b,clock)
 checkController(j2.state=="ready" and Json.canonical(b.data.A1_46001_progress)==anchor,"interrupted archive was not resumed immutably: "..tostring(j2.problem))
end
do
 local s,c,j,b,clock=fixtureController();local original=Json.canonical(b.data.R_46001_main)
 local update=b.update;local suspended=false;local runningProbe=false
 b.update=function(self,key,fn)
  if not suspended then
   suspended=true
   local count=self.requests;runningProbe=s:step()==false and self.requests==count
   coroutine.yield("heartbeat-suspended")
  end
  return update(self,key,fn)
 end
 local thread=coroutine.create(function() c:step(j) end)
 local ok,marker=coroutine.resume(thread)
 checkController(ok and marker=="heartbeat-suspended" and runningProbe and s.busy,"controller failed to serialize ordinary step")
 checkController(not c:step(j),"reentrant controller started another request")
 s:requestLife("new","main",2,nil)
 checkController(coroutine.resume(thread),"cancelled heartbeat failed to resume")
 checkController(j.state=="cancelled" and j.plan==nil and b.data.A1_46001_progress==nil,"superseded Continue published archive")
 checkController(Json.canonical(b.data.R_46001_main)==original and not s.busy and not c.busy,"supersession damaged original or leaked worker lock")
end
for _,kind in {"foreign","expired","read_failure","deadline","request_cap"} do
 local s,c,j,b,clock=fixtureController()
 if kind=="foreign" then b.data.P_46001.lock.session="another-server"
 elseif kind=="expired" then b.data.P_46001.lock.beat=clock.now-SaveRules.LOCK_STALE
 elseif kind=="read_failure" then b:fail({op="read",key="R_*",times=3})
 elseif kind=="deadline" then c.timeout=1
 else c.maxRequests=1 end
 local original=Json.canonical(b.data.R_46001_main)
 finishController(c,j,s,b,clock)
 checkController(Json.canonical(b.data.R_46001_main)==original,"failure changed original rest: "..kind)
 if kind=="read_failure" then checkController(j.state=="ready","retry/backoff did not recover")
 else checkController(j.state=="refused" and j.plan==nil and b.data.A1_46001_progress==nil,"unsafe failure was not refused: "..kind) end
end
do
 local s,c,j,b,clock=fixtureController()
 b:fail({op="update",key="P_46001",times=1,afterWrite=true,message="503: heartbeat acknowledgement lost"})
 local before=b.requests;c:step(j)
 checkController(b.requests==before+1 and j.state=="pending" and j.lastAck==nil,"uncertain heartbeat enabled raw collection")
 local untilRetry=j.nextAt;before=b.requests;c:step(j)
 checkController(b.requests==before and untilRetry>clock.now,"heartbeat failure ignored backoff")
 finishController(c,j,s,b,clock)
 checkController(j.state=="ready","uncertain heartbeat did not recover safely")
end
do
 local s,c,j,b,clock=fixtureController()
 b:fail({op="read",key="A1_46001_progress",times=2,message="429: throttled"})
 finishController(c,j,s,b,clock)
 checkController(j.state=="ready","archive probe/recovery read retry failed")
end
do
 local s,c,j,b,clock=fixtureController()
 for _=1,500 do
  if j.phase=="archive" then break end
  c:step(j);clock.now+=1
 end
 checkController(j.phase=="archive" and b.data.A1_46001_progress==nil,"publication cancellation fixture missed first write")
 local update=b.update;local paused=false
 b.update=function(self,key,fn)
  if string.sub(key,1,3)=="A1_" then paused=true;coroutine.yield("archive-write-suspended") end
  return update(self,key,fn)
 end
 local thread
 for _=1,100 do
  thread=coroutine.create(function() c:step(j) end)
  local ok,why=coroutine.resume(thread)
  checkController(ok,"publication worker failed before cancellation")
  if paused then checkController(why=="archive-write-suspended","unexpected worker yield");break end
  clock.now+=1
 end
 checkController(paused and s.busy,"archive call did not suspend under the session lock")
 checkController(c:cancel(j),"suspended publication did not cancel")
 checkController(coroutine.resume(thread),"cancelled publication failed to resume")
 checkController(j.state=="cancelled" and j.plan==nil and b.data.A1_46001_progress==nil,"cancelled callback published archive")
 checkController(not s.busy and not c.busy,"cancelled archive leaked worker lock")
end
print("RECOVERY_CONTROLLER passed="..passedController.." failed=0")
