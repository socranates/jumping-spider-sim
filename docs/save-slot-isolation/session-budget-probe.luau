-- Reproduce the periodic worker's claimed one-request and minute-budget bounds.
-- Filling its request history represents prior legitimate operations this minute.
local passedBudget=0
local function verifyBudget(ok,why) assert(ok,why);passedBudget+=1 end
for _,kind in {"rest_retry","lease_retry"} do
 local now=100;local b=MemoryBackend.new()
 if kind=="rest_retry" then b:fail({op="read",key="R_*",times=3})
 else b:fail({op="update",key="P_*",times=1}) end
 local s=SaveSession.new({backend=b,userId=9300,sessionId="request-budget-probe",now=function() return now end})
 s:load()
 verifyBudget(if kind=="rest_retry" then s.state=="active" and not s:restsLoaded() else s.state=="session" and s.canRetry,"invalid recovery fixture")
 now=if kind=="rest_retry" then s.restRetryAt+.001 else s.retryAt+.001
 verifyBudget(now<130,"fixture unexpectedly crossed heartbeat or request expiry")
 while #s.sched.started<SaveRules.REQUESTS_PER_MINUTE-1 do s.sched:begin(nil,now) end
 local requests=b.requests;local started=#s.sched.started
 verifyBudget(s:step(),"periodic recovery did not run")
 local delta=b.requests-requests
 verifyBudget(delta==(if kind=="rest_retry" then 3 else 4),"baseline multi-request recovery did not reproduce")
 verifyBudget(#s.sched.started>SaveRules.REQUESTS_PER_MINUTE,"baseline minute-budget overrun did not reproduce")
 verifyBudget(#s.sched.started-started==delta,"backend requests escaped accounting")
 print("SESSION_BUDGET_CASE "..kind.." requests="..delta.." minute_count="..#s.sched.started.." cap="..SaveRules.REQUESTS_PER_MINUTE)
end
print("SESSION_BUDGET_PROBE passed="..passedBudget.." failed=0 reproduced=true")
