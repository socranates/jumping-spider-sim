do
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Json=require("../src/Shared/Persistence/Json")
local Base=__progressBaselinePrototype
local Owner=__pipelinePrototype
local Gate=__typedGate
local count,groups=0,0
local function check(ok,why) assert(ok,why);count+=1 end
local function test(name,fn) local before=count;fn();groups+=1;print("COMMIT_ADMISSION_CASE",name,count-before) end
local function driveLegacy(b,clock,s,reader,j)
 for _=1,1000 do if j.state~="pending" then return end;reader:step(j);clock.now+=1 end
 error("legacy discovery did not settle")
end
__pipelineFixture
local function typed(compressed,options)
 local cfg={deferBegin=true};for k,v in options or {} do cfg[k]=v end
 local b,clock,s,w,c,_,discovery=fixture(compressed,cfg)
 local budget={read=0,write=0}
 local g=Gate.new({now=s.now,available=function() return budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started))
 c.options.admission={gate=g,scope=scope}
 local base={global=s.counters.requests,provider=b.requests,history=#s.sched.started,rest=Json.canonical(b.data.R_46001_main),other=Json.canonical(b.data.R_46001_free)}
 local j=assert(c:begin("main",1,discovery.offer.id,discovery))
 return b,clock,s,w,c,j,discovery,g,scope,budget,base
end
local function tick(b,s,w,c,j,base)
 local before=b.requests;local asked=c:step(j)
 check(b.requests-before<=1,"typed pipeline made more than one request")
 check(j.requests==s.counters.requests-base.global and j.requests==b.requests-base.provider,"root/global/provider counts differ")
 check(not c.busy and not s.busy and not w:permitted(j.held),"pipeline leaked busy/held permission")
 return asked
end
local function driveTyped(b,s,w,c,j,base,done)
 for _=1,30000 do if done and done() or j.state~="pending" then return end;tick(b,s,w,c,j,base) end
 error("typed pipeline did not settle: "..j.phase.."/"..tostring(j.child and j.child.phase).." "..tostring(j.problem))
end
local function archives(b)
 return Json.canonical({b.data.A1_46001_progress,b.data.A1_46001_main,b.data.A1_46001_free,b.data.A1_46001_easy,b.data.A1_46001_index})
end
local function logUpdates(b,prefix,after)
 local n=0;for i,row in b.log do if i>(after or 0) and row.op=="update" and string.sub(row.key,1,#prefix)==prefix then n+=1 end end;return n
end
test("cold-plain-compressed-and-archive-policies",function()
 for _,compressed in {false,true} do for _,reuse in {false,true} do
  local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(compressed,{reuseCompleteOriginal=reuse})
  for _=1,20 do check(not tick(b,s,w,c,j,base),"zero allowance started root request") end
  check(j.requests==0 and j.phase=="admitRead" and j.failures==0 and g:inspect().queued==1,"root wait consumed attempts/phase")
  budget.read=1000;budget.write=1000;driveTyped(b,s,w,c,j,base)
  check(j.state=="rebound" and j.result.requiresSchema3Entry and not j.result.gameplayAuthorized,"typed cold pipeline failed/granted play: "..tostring(j.problem))
  check(j.requests<=96 and s.intents.requests.main.credential==nil and s.recoveryOwner==nil and w.held==nil,"root cap/hold/credential result differs")
  check(Json.canonical(b.data.R_46001_free)==base.other and b.data.A1_46001_index.complete,"pipeline changed other slot or omitted complete archive")
  check(Json.canonical(b.data.A1_46001_main.raw)==base.rest and Json.canonical(b.data.R_46001_main)==Json.canonical(b.data.M1_46001_main.target),"selected original/target does not match exact durable proposal")
  check(j.io==nil and j.beatIO==nil and j.component==nil and j.work==nil and g:inspect().queued==0,"completed root retained I/O/staging")
  print("COMMIT_ADMISSION cold_compressed="..tostring(compressed).." read_only_archive="..tostring(reuse).." requests="..j.requests.." exact_raw_target=true gameplay_grant=false")
 end end
end)
test("selected-rest-readback-wait-does-not-repeat-cas",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,{reuseCompleteOriginal=true})
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="rest" and j.child.child.phase=="readback" end)
 local child=j.child.child;local countBefore=j.requests;local stored=Json.canonical(b.data.R_46001_main)
 budget.read=0
 for _=1,20 do check(not tick(b,s,w,c,j,base),"readback wait started a request") end
 check(j.requests==countBefore and child.state=="pending" and child.phase=="readback" and j.child.phase=="rest","rest wait advanced commit or spent counters")
 check(Json.canonical(b.data.R_46001_main)==stored and s.intents.requests.main.credential==nil and w.held.enforced,"unverified CAS result granted gameplay/released hold")
 budget.read=1000;driveTyped(b,s,w,c,j,base)
 check(j.state=="rebound" and logUpdates(b,"R_46001_main")==1,"capacity wait repeated selected-R CAS")
end)
test("ambiguous-m1-rest-and-progress-writes-require-readback",function()
 for _,key in {"M1_46001_main","R_46001_main","P_46001"} do
  local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(true,{reuseCompleteOriginal=true})
  if key=="P_46001" then
   budget.read=1000;budget.write=1000
   driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="progress" and j.child.child.phase=="write" end)
  end
  b:fail({op="update",key=key,times=1,afterWrite=true,message="503: committed acknowledgement lost"})
  budget.read=1000;budget.write=1000;driveTyped(b,s,w,c,j,base)
  check(j.state=="rebound" and b.data.A1_46001_index.complete and b.data.M1_46001_main~=nil,"ambiguous write failed verified continuation: "..key.." "..tostring(j.problem))
  check(Json.canonical(b.data.R_46001_main)==Json.canonical(b.data.M1_46001_main.target) and s.intents.requests.main.credential==nil,"ambiguous write skipped exact readback or granted play")
  check(Json.canonical(b.data.R_46001_free)==base.other and g:inspect().queued==0,"ambiguous continuation altered another slot/leaked operation")
 end
end)
test("root-cap-and-deadline-close-nested-work",function()
 for _,kind in {"cap","deadline"} do
  local cfg=if kind=="cap" then {maxRequests=10} else {timeout=2}
  local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,cfg)
  if kind=="deadline" then tick(b,s,w,c,j,base);clock.now+=2
  else budget.read=1000;budget.write=1000 end
  driveTyped(b,s,w,c,j,base)
  check(j.state=="refused" and j.result.requiresPausedWorker and not j.result.gameplayAuthorized and w.held.enforced,"bounded root released ownership")
  check((kind=="cap" and j.requests==10 or kind=="deadline" and j.requests==0) and g:inspect().queued==0,"root cap/deadline charged or retained wrong operations")
  check(b.data.M1_46001_main==nil and Json.canonical(b.data.R_46001_main)==base.rest,"bounded root wrote selected rest/proposal")
 end
end)
test("cancel-committed-raw-rest-drains-without-rebind",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,{reuseCompleteOriginal=true})
 local raw=b.updateRaw
 b.updateRaw=function(self,key,fn)
  local result=table.pack(raw(self,key,fn));if key=="R_46001_main" then coroutine.yield("raw-rest-committed") end;return table.unpack(result,1,result.n)
 end
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="rest" and j.child.child.phase=="write" end)
 local preserved=archives(b);local co=coroutine.create(function() c:step(j) end);local okay,why=coroutine.resume(co)
 check(okay and why=="raw-rest-committed" and Json.canonical(b.data.R_46001_main)==Json.canonical(b.data.M1_46001_main.target),"raw binding did not reach actual committed selected rest")
 local charged=s.counters.requests;check(c:cancel(j) and j.state=="cancelled" and w.held.enforced,"busy pipeline cancellation released source hold")
 g:close(scope);check(g:open("46001","next")==nil,"replacement opened over raw provider")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","cancelled raw provider did not drain")
 check(j.state=="cancelled" and not j.result.gameplayAuthorized and s.intents.requests.main.credential==nil and s.counters.requests==charged,"late raw result rebound/granted/refunded attempt")
 check(archives(b)==preserved and not c.busy and not s.busy and not w:permitted(j.held) and g:open("46001","next")~=nil,"raw drain changed archive or leaked permission")
end)
test("resume-reuses-exact-m1-and-immutable-originals",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(true,{reuseCompleteOriginal=true})
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="progress" end)
 local anchor=Json.canonical(b.data.M1_46001_main);local original=archives(b)
 assert(c:cancel(j));assert(s:requestLife("continue","main",2,discovery.offer.id))
 local before=#b.log;local second=assert(c:begin("main",2,discovery.offer.id,discovery));local baseline={global=s.counters.requests,provider=b.requests}
 driveTyped(b,s,w,c,second,baseline)
 check(second.state=="rebound" and Json.canonical(b.data.M1_46001_main)==anchor and archives(b)==original,"resume regenerated proposal/originals")
 check(logUpdates(b,"A1_",before)==0 and logUpdates(b,"M1_",before)==0 and s.intents.requests.main.credential==nil,"resume republished immutable metadata or granted life")
end)
test("foreign-final-lease-cannot-verify-commit",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,{reuseCompleteOriginal=true})
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="commit" and j.child.phase=="finalLease" end)
 local progress=Json.copy(b.data.P_46001);progress.lock.session="foreign-owner";b:poke("P_46001",progress)
 local beat=s.sched.lastBeat;driveTyped(b,s,w,c,j,base)
 check(j.state=="refused" and w.held.enforced and j.result.requiresPausedWorker and not j.result.gameplayAuthorized,"foreign final lease was accepted")
 check(b.data.P_46001.lock.session=="foreign-owner" and s.sched.lastBeat==beat and s.intents.requests.main.credential==nil,"foreign lease was overwritten or granted play")
end)
test("deferred-rebind-witness-is-fresh-and-held-on-change",function()
 local b,clock,s,w,c,j,discovery,g,scope,budget,base=typed(false,{reuseCompleteOriginal=true})
 budget.read=1000;budget.write=1000
 driveTyped(b,s,w,c,j,base,function() return j.phase=="witnessM1" end)
 budget.read=0;tick(b,s,w,c,j,base);local localProgress=Json.canonical(s.progress);local countBefore=j.requests
 b:poke("M1_46001_main",{changed=true});budget.read=1000
 driveTyped(b,s,w,c,j,base)
 check(j.state=="refused" and j.requests==countBefore+1 and Json.canonical(s.progress)==localProgress,"rebind used stale proposal/local state after waiting")
 check(w.held.enforced and s.recoveryOwner==c and s.intents.requests.main.credential==nil and g:inspect().queued==0,"failed rebind released hold/permission")
end)
print("COMMIT_ADMISSION passed="..count.." failed=0 groups="..groups)
end
