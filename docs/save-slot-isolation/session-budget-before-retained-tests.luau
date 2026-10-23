local passedBudget=0
local function verifyBudget(ok,why) assert(ok,why);passedBudget+=1 end
for _,kind in {"rest_retry","lease_retry"} do
 local now=100;local b=MemoryBackend.new();local loaded=0;local delivered={}
 for _,mode in SaveRules.MODES do
  local record=realRest(1,mode);record.save_life="budget-"..mode
  b:poke("R_9300_"..mode,SaveEnvelope.make(SaveRest.SPECS[mode],record,90,nil))
 end
 if kind=="rest_retry" then b:fail({op="read",key="R_*",times=3})
 else b:fail({op="update",key="P_*",times=1}) end
 local s
 s=SaveSession.new({backend=b,userId=9300,sessionId="budget-candidate",now=function() return now end,
  onLoaded=function(snapshot)
   for _,mode in SaveRules.MODES do
    verifyBudget(s.restLoaded[mode] or snapshot.rests[mode]==nil,"loaded callback exposed an unvalidated slot")
   end
   loaded+=1
  end,onRest=function(mode,record)
   verifyBudget(record.save_life=="budget-"..mode,"wrong source delivered")
   delivered[mode]=(delivered[mode] or 0)+1
  end})
 s:load()
 verifyBudget(if kind=="rest_retry" then s.state=="active" and not s:restsLoaded() else s.state=="session" and s.canRetry,"invalid recovery fixture")
 now=if kind=="rest_retry" then s.restRetryAt+.001 else s.retryAt+.001
 while #s.sched.started<SaveRules.REQUESTS_PER_MINUTE-1 do s.sched:begin(nil,now) end
 local before=b.requests;verifyBudget(s:step(),"recovery did not run")
 verifyBudget(b.requests-before==1 and #s.sched.started==SaveRules.REQUESTS_PER_MINUTE,"periodic recovery exceeded remaining request budget")
 verifyBudget(loaded==(if kind=="lease_retry" then 1 else 0),"merged progress notification was delayed")
 now+=.1;before=b.requests;s:step()
 verifyBudget(b.requests==before,"exhausted budget admitted another request")
 now+=61
 for _=1,8 do
  before=b.requests;s:step()
  verifyBudget(b.requests-before<=1,"periodic step exceeded one request")
  verifyBudget(#s.sched.started<=SaveRules.REQUESTS_PER_MINUTE,"periodic minute budget exceeded")
  now+=.1
 end
 verifyBudget(s.state=="active" and s:restsLoaded(),"recovery did not finish")
 verifyBudget(loaded==(if kind=="lease_retry" then 1 else 0),"load notification missing or repeated")
 for _,mode in SaveRules.MODES do verifyBudget(delivered[mode]==1,"slot callback missing or duplicated") end
 print("SESSION_BUDGET_CANDIDATE "..kind.." bounded_and_complete")
end
-- A persistently unreadable first slot cannot starve other slots.
do
 local now=100;local b=MemoryBackend.new()
 b:fail({op="read",key="R_*",times=3})
 local s=SaveSession.new({backend=b,userId=9301,sessionId="budget-fairness",now=function() return now end})
 s:load();b:fail({op="read",key="R_9301_main",times=20})
 for _=1,3 do
  now=math.max(now+.1,s.restRetryAt+.001);local before=b.requests;s:step()
  verifyBudget(b.requests-before==1,"fairness retry made multiple requests")
 end
 verifyBudget(not s.restLoaded.main and s.restLoaded.free and s.restLoaded.easy,"failed slot starved other modes")
end
print("SESSION_BUDGET_CANDIDATE passed="..passedBudget.." failed=0")
