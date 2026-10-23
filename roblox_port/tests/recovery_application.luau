local Application=require("../src/Client/RecoveryApplication")
local n=0
local function check(ok,why) assert(ok,why);n+=1 end
local function fixture()
 local f={generation=0,started=false,healthy=true,resumes=0,shows=0,visible=false}
 local token
 local function pause()
  local t={};token=t
  return {held=function() return token==t end,release=function() if token~=t then return false end;token=nil;return true end}
 end
 local app=Application.new({pause=pause,held=function() return token~=nil end,invalidate=function() f.generation+=1 end,
  generation=function() return f.generation end,started=function() return f.started end,healthy=function() return f.healthy end,
  pauseUI=function() end,visible=function() return f.visible end,show=function(phase,exit) f.shows+=1;f.visible=true;f.screen=phase;f.exit=exit end,
  freshMenu=function() f.visible=true;f.started=false;return true end,resumeUI=function() f.resumes+=1;f.visible=false end})
 local c={phase="searching",bound={epoch=nil},replacementEnabled=true}
 function c:decision() return self.choice end
 local e={};function e:select() self.job={phase="selected",hold=pause()};return true end
 function e:cancel() if self.job then self.job.phase="held" end end
 function e:entry() end
 function e:decision(d) if d.granted then self.job.phase="granted";self.job.hold.release() end end
 function e:update() if f.raise then error("synthetic entry failure") end;if f.reenter then f.reenter=false;app:decision({granted=true}) end end
 app:bind(c,e);c.bound.epoch="old"
 f.app,f.client,f.entry=app,c,e;return f
end
do
 local f=fixture();check(not f.app:select("main",1) and not f.app:held(),"unbound choice gained hold")
 f.client.choice={kind="continue",serial=1,state="readonly"}
 check(f.app:select("main",1) and f.app:held() and f.screen=="entry","selection did not pause and show recovery")
 local shown=f.shows;for _=1,60 do f.app:update() end
 check(f.shows==shown,"unchanged recovery screen rebuilt every frame")
 f.visible=false;f.app:update();check(f.visible and f.shows==shown+1,"hiding menu bypassed or lost recovery")
 f.reenter=true;f.app:update()
 check(f.app.phase=="playing" and not f.app:held() and f.resumes==1,"reentrant grant resumed twice or retained hold")
end
do
 local f=fixture();f.client.choice={kind="continue",serial=1,state="readonly"};f.app:select("main",1);f.raise=true
 f.app:update();check(f.app.phase=="failed" and f.app:held() and f.screen=="failed","exception released world or hid error")
 check(not f.app:select("free",2),"failed world accepted an ordinary new choice")
 function f.client:requestReplacement() self.transition={stage="requesting"};return f.app:pauseReplacement("old",1) end
 check(f.app:exit() and f.app.phase=="replacing" and f.app:held(),"explicit exit failed to preserve pause")
 check(not f.app:ready("old","wrong",1),"wrong new epoch opened choice screen")
 f.client.bound.epoch="new"
 check(not f.app:ready("obsolete","new",1) and not f.app:ready("old","new",2),"stale application callback opened fresh menu")
 check(f.app:ready("old","new",1) and f.app:choosing() and f.app:held(),"new epoch did not produce held fresh menu")
 check(not f.app:finishChoice() and f.app.phase=="failed" and f.app:held(),"menu alone resumed old world")
end
do
 local f=fixture();check(f.app:pauseReplacement("old",1),"replacement pause refused")
 f.client.bound.epoch="new";check(f.app:ready("old","new",1),"fresh menu refused")
 f.generation+=1;f.started=true;f.client.activeSlot="main"
 check(f.app:finishChoice() and f.app.phase=="playing" and not f.app:held(),"explicit current-session commit could not release fresh-menu hold")
end
do
 local f=fixture();f.app:pauseReplacement("old",1);f.client.transition={stage="failed",problem="close failed"}
 f.app:update();check(f.app.phase=="failed" and f.app:held() and not f.exit,"failed departure offered impossible retry or resumed")
 f.healthy=false;check(not f.app:exit(),"broken save path attempted replacement")
end
do
 local f=fixture();local original={continuation={onDecision=function() f.baseCalled=true end}}
 local cfg=f.app:configure(original)
 check(cfg~=original and cfg.continuation~=original.continuation and original.recovery==nil,"configuration mutated ordinary startup")
 cfg.continuation.onDecision({});check(f.baseCalled,"existing decision callback was lost")
 local ok=pcall(f.app.bind,f.app,f.client,f.entry);check(not ok,"application rebound a live transport")
end
do
 local f=fixture();f.client.choice={kind="continue",serial=1,state="readonly"}
 f.app.cfg.show=function() error("synthetic GUI failure") end
 check(f.app:select("main",1) and f.app.phase=="failed" and f.app:held(),"GUI exception escaped frame or released world")
 for _=1,10 do f.app:update() end
 check(f.app.screenBroken and f.app:held(),"failed renderer retried unsafely or released")
end
do
 local f=fixture();f.app:pauseReplacement("old",1);f.client.bound.epoch="new"
 f.app.cfg.freshMenu=function() error("synthetic fresh-menu failure") end
 check(not f.app:ready("old","new",1) and f.app.phase=="failed" and f.app:held(),"fresh menu exception activated old world")
end
do
 local f=fixture();f.client.newLifeEnabled=true
 function f.client:offerInfo() return {id="shown",protected=true} end
 function f.client:prepareNewLife(mode,id)
  if id~="shown" then return false end
  self.newLife={mode=mode,epoch=self.bound.epoch,serial=7};return true
 end
 function f.client:requestReplacement() self.transition={stage="requesting"};return f.app:pauseReplacement("old",1) end
 check(f.app:prepareNew("main","shown") and f.app.phase=="new" and f.app:held(),"protected New did not pause before sending")
 f.app:newState("verified","free",7,"old");f.app:newState("verified","main",8,"old");f.app:newState("verified","main",7,"stale")
 check(f.app.phase=="new" and f.client.transition==nil and f.app:held(),"stale New completion escaped its scope")
 f.app:newState("verified","main",7,"old")
 check(f.app.phase=="replacing" and f.app:held(),"verified New released world before replacement")
 f.client.bound.epoch="fresh"
 check(f.app:ready("old","fresh",1) and not f.started and f.app:held(),"verified New silently started a new life")
end
do
 local f=fixture();f.client.newLifeEnabled=true
 function f.client:offerInfo() return {id="shown",protected=true} end
 function f.client:prepareNewLife(mode) self.newLife={mode=mode,epoch="old",serial=1};return true end
 f.app:prepareNew("main","shown");f.app:newState("refused","main",1,"old")
 check(f.app.phase=="failed" and f.app:held() and f.visible,"refused New lost its held error screen")
end
do
 local f=fixture();check(not f.app:prepareNew("main","shown") and not f.app:held(),"unsupported New capability changed ordinary startup")
 f.app.phase="playing";f.app.recoveredPlaying=true
 function f.client:requestReplacement() return f.app:pauseReplacement("old",1) end
 check(f.app:beforeWorldChoice() and f.app.phase=="replacing" and f.app:held(),"recovered world choice did not replace its owner first")
 check(not f.app:beforeWorldChoice(),"already held world choice requested replacement twice")
end
print("RECOVERY_APPLICATION passed="..n.." failed=0")
