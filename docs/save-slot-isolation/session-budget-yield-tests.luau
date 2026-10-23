local checksYield=0
local function verifyYield(ok,why) assert(ok,why);checksYield+=1 end
for _,operation in {"read","lock"} do
 for _,action in {"close","demote","supersede"} do
  local now=100;local b=MemoryBackend.new();local callbacks=0
  local record=realRest(1,"main");record.save_life="yield-life"
  b:poke("R_9400_main",SaveEnvelope.make(SaveRest.SPECS.main,record,90,nil))
  if operation=="read" then b:fail({op="read",key="R_*",times=3})
  else b:fail({op="update",key="P_*",times=1}) end
  local s=SaveSession.new({backend=b,userId=9400,sessionId="budget-yield",now=function() return now end,
   onRest=function() callbacks+=1 end,onLoaded=function() callbacks+=1 end})
  s:load();now=if operation=="read" then s.restRetryAt+.001 else s.retryAt+.001
  local key=if operation=="read" then "read" else "update"
  local original=b[key];local suspended=false
  b[key]=function(self,...)
   if not suspended then suspended=true;coroutine.yield("request-pending") end
   return original(self,...)
  end
  local worker=coroutine.create(function() return s:step() end)
  local ok,signal=coroutine.resume(worker)
  verifyYield(ok and signal=="request-pending" and s.busy,"fixture did not suspend an actual recovery request")
  local requests=b.requests;verifyYield(not s:step() and b.requests==requests,"reentrant step started a parallel request")
  local progress=Json.canonical(s.progress)
  if action=="close" then s:flush(now+.001);verifyYield(s.closed,"departure failed to close pending session")
  elseif action=="demote" then s:demote("offline",false)
  else verifyYield(s:load()=="active","superseding load failed") end
  local retained=Json.canonical({rests=s.rests,loaded=s.restLoaded,progress=s.progress})
  ok,signal=coroutine.resume(worker)
  verifyYield(ok and coroutine.status(worker)=="dead","pending recovery failed to settle")
  verifyYield(callbacks==0,"cancelled or superseded recovery emitted a late callback: "..operation.."/"..action)
  if action=="supersede" then
   verifyYield(s.state=="active" and s:restsLoaded(),"stale operation damaged newer load")
  else
   verifyYield(Json.canonical(s.progress)==progress,"cancelled recovery adopted progress")
   verifyYield(if action=="close" then s.closed else s.state=="session" and not s.lockHeld,"cancelled recovery regained authority")
  end
  verifyYield(Json.canonical({rests=s.rests,loaded=s.restLoaded,progress=s.progress})==retained,"cancelled recovery changed retained state")
  print("SESSION_BUDGET_YIELD "..operation.." "..action.." fenced")
 end
end
print("SESSION_BUDGET_YIELD passed="..checksYield.." failed=0")
