do
local Gate=__typedGate
local Controller=__archiveControllerPrototype
local Reader=__offerReaderPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Session=require("../src/Shared/Persistence/SaveSession")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local checks,groups=0,0
local function check(ok,why) assert(ok,why);checks+=1 end
local function test(name,fn) local before=checks;fn();groups+=1;print("ARCHIVE_ADMISSION_CASE",name,checks-before) end
local function fixture(options)
 local b=Memory.new();b.readFresh=b.read;b.readRawFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(rest))
 local clock={now=200};local s=Session.new({backend=b,userId=46001,sessionId="typed-archive",now=function() return clock.now end})
 assert(s:load()=="active");s:enableOffers()
 local found=assert(Reader.prepare("46001","main",rest,nil,{},codec,fresh))
 local offer=assert(s.observations:publish("main",found.record,found.identity,true));assert(s:requestLife("continue","main",1,offer.id))
 local budget={read=0,write=0};local g=Gate.new({now=s.now,available=function() return budget end,actorRead=40,actorWrite=40,serverRead=80,serverWrite=80,headroom=0})
 local scope=assert(g:open("46001",s.id));assert(g:importLegacy(scope,s.sched.started))
 local cfg={admission={gate=g,scope=scope},work={now=function() return 0 end},restCodec=codec}
 for k,v in options or {} do cfg[k]=v end
 local c=Controller.new(s,cfg);local j=assert(c:begin("main",1,offer.id,"typed-original"))
 return b,clock,s,g,scope,budget,c,j,{global=s.counters.requests,provider=b.requests,history=#s.sched.started,rest=Json.canonical(b.data.R_46001_main)},offer
end
local function tick(b,s,c,j,base)
 local before=b.requests;local asked=c:step(j)
 check(b.requests-before<=1,"archive controller started multiple providers in a step")
 check(not c.busy and not s.busy,"archive worker leaked busy flags")
 check(s.counters.requests-base.global==j.requests and j.requests==b.requests-base.provider,"parent/global/provider counters differ")
 return asked
end
local function drive(b,s,c,j,base,done)
 for _=1,20000 do if done and done() or j.state~="pending" then return end;tick(b,s,c,j,base) end
 error("typed archive did not settle: "..j.phase.." "..tostring(j.problem))
end
local function archiveBytes(b)
 local rows={};for key,value in b.data do if string.sub(key,1,3)=="A1_" then rows[key]=value end end;return Json.canonical(rows)
end
test("cold-archive-retains-child-state-and-exact-accounting",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture()
 for _=1,20 do check(not tick(b,s,c,j,base),"zero capacity reported a request") end
 check(j.requests==0 and j.beatFailures==0 and j.failures==0 and j.lastAck==nil and g:inspect().queued==1,"initial ownership wait spent attempts or skipped first acknowledgement")
 budget.read=80;budget.write=80
 drive(b,s,c,j,base,function() return j.phase=="archive" end)
 local collection=j.collection;local publication=j.publication
 check(collection.state=="complete" and collection.reads==8 and publication.state=="pending" and publication.requests==0,"collection witnesses/counters differ")
 budget.write=0;local count=j.requests
 for _=1,20 do check(not tick(b,s,c,j,base),"publication without write capacity reported request") end
 local transform=publication.writeState.transform
 check(j.requests==count and publication.requests==0 and publication.state=="pending" and b.data.A1_46001_progress==nil,"waiting publication entered running state or wrote archive")
 tick(b,s,c,j,base);check(publication.writeState.transform==transform and g:inspect().queued==1,"publication transform/ticket replaced during wait")
 budget.write=80;drive(b,s,c,j,base)
 check(j.state=="ready" and j.plan~=nil and b.data.A1_46001_index.complete,"typed archive did not complete")
 check(publication.requests==10 and publication.verified==5 and j.requests==20,"nested requests were charged twice or skipped")
 check(s.intents.requests.main.credential==nil and Json.canonical(b.data.R_46001_main)==base.rest,"archive granted play or modified original rest")
 check(j.collection==nil and j.publication==nil and j.io==nil and j.beatIO==nil and g:inspect().queued==0,"completed archive retained staging/requests")
end)
test("collector-failure-backoff-and-budget-wait-are-distinct",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture();budget.read=80;budget.write=80
 b:fail({op="read",key="R_46001_main",times=1,message="503: collection unavailable"})
 drive(b,s,c,j,base,function() return j.collection.state=="retry" end)
 local count=j.requests;local reads=j.collection.reads;local failures=j.failures;local due=j.nextAt
 check(failures==1 and due>clock.now,"collector failure did not enter parent backoff")
 clock.now=due;budget.read=0
 for _=1,10 do check(not tick(b,s,c,j,base),"capacity denial retried provider") end
 check(j.requests==count and j.collection.reads==reads and j.failures==failures and j.nextAt==due,"waiting changed collector attempts/backoff")
 budget.read=80;drive(b,s,c,j,base)
 check(j.state=="ready" and j.requests==21 and Json.canonical(b.data.R_46001_main)==base.rest,"collection did not recover from one actual failed read")
end)
test("changed-unselected-source-refuses-before-publication",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture();budget.read=80;budget.write=80
 drive(b,s,c,j,base,function() return j.collection.phase=="verify" end)
 b:poke("R_46001_free","changed unselected original")
 drive(b,s,c,j,base)
 check(j.state=="refused" and j.plan==nil and b.data.A1_46001_progress==nil,"changed unselected source was archived")
 check(g:inspect().queued==0 and s.intents.requests.main.credential==nil,"refused collection retained authority/request")
end)
test("parent-cap-closes-all-child-operations",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture({maxRequests=3});budget.read=80;budget.write=80
 drive(b,s,c,j,base)
 check(j.state=="refused" and j.requests==3 and s.counters.requests-base.global==3 and b.requests-base.provider==3,"parent request cap was bypassed/double charged")
 check(g:inspect().queued==0 and j.collection==nil and j.publication==nil and j.io==nil and j.beatIO==nil,"capped controller leaked child staging")
end)
test("committed-publication-cancellation-keeps-debt-and-drains",function()
 local b,clock,s,g,scope,budget,c,j,base=fixture();budget.read=80;budget.write=80
 drive(b,s,c,j,base,function() return j.phase=="archive" end)
 local publication=j.publication;local update=b.update
 b.update=function(self,key,fn)
  local result=table.pack(update(self,key,fn));if key=="A1_46001_progress" then coroutine.yield("archive-committed") end;return table.unpack(result,1,result.n)
 end
 -- Repository's explicit method is captured in Operation.new at begin; install
 -- the test provider before constructing a new publication operation.
 c:cancel(j)
 local cfg={admission={gate=g,scope=scope},work={now=function() return 0 end},restCodec=codec}
 assert(s:requestLife("continue","main",2,s.observations.latest.main.id))
 c=Controller.new(s,cfg);j=assert(c:begin("main",2,s.observations.latest.main.id,"typed-cancelled-publication"))
 base={global=s.counters.requests,provider=b.requests};drive(b,s,c,j,base,function() return j.phase=="archive" end)
 publication=j.publication
 local co=coroutine.create(function() c:step(j) end);local okay,why=coroutine.resume(co)
 check(okay and why=="archive-committed" and publication.state=="running" and publication.requests==1 and b.data.A1_46001_progress~=nil,"publication did not suspend after actual commit")
 local count=j.requests;check(c:cancel(j) and j.state=="cancelled" and publication.state=="cancelled","busy archive cancellation did not revoke children")
 g:close(scope);check(g:open("46001","next")==nil,"new visit opened before publication drained")
 check(coroutine.resume(co) and coroutine.status(co)=="dead","cancelled archive provider did not drain")
 check(j.state=="cancelled" and j.requests==count and publication.verified==0 and b.data.A1_46001_index==nil,"late result completed archive/refunded counters")
 check(not c.busy and not s.busy and g:open("46001","next")~=nil and b.data.A1_46001_progress~=nil,"drained publication lost committed data or leaked flags")
end)
test("completed-original-reuse-is-read-only-except-lease",function()
 local b,clock,s,g,scope,budget,c,j,base,offer=fixture();budget.read=80;budget.write=80
 drive(b,s,c,j,base);local preserved=archiveBytes(b);local writes=b.writes
 assert(s:requestLife("continue","main",2,offer.id))
 local nextController=Controller.new(s,{admission={gate=g,scope=scope},work={now=function() return 0 end},restCodec=codec,reuseCompleteOriginal=true})
 local nextJob=assert(nextController:begin("main",2,offer.id,"reuse-original"));local baseline={global=s.counters.requests,provider=b.requests}
 drive(b,s,nextController,nextJob,baseline)
 check(nextJob.state=="ready" and nextJob.reusedOriginal and nextJob.requests<=8,"typed completed-original reuse failed")
 check(archiveBytes(b)==preserved and b.writes==writes+1,"reuse updated an immutable archive instead of only renewing lease")
 check(Json.canonical(b.data.R_46001_main)==base.rest and s.intents.requests.main.credential==nil,"reuse changed rest or granted permission")
end)
print("ARCHIVE_ADMISSION passed="..checks.." failed=0 groups="..groups)
end
