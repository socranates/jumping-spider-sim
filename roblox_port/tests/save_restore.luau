local Restore=require("../src/Client/SaveRestore")
local Work=require("../src/Shared/Persistence/SaveWork")
local Json=require("../src/Shared/Persistence/Json")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL SAVE_RESTORE "..why) end end
local record={items={}}
for i=1,1000 do record.items[i]={index=i} end
local function fixture()
 local clock=0
 local state={version=1,world="original",commits=0,done=0,cancels=0,failures=0}
 local cfg={workOptions={budget=.001,maxSeconds=1000,now=function() clock+=.001;return clock end}}
 cfg.current=function(stamp) return stamp==state.version end
 cfg.prepare=function(value,stamp)
  local private=Json.copy(value)
  return function()
   check(Work.pulse()==nil,"live commit runs outside worker context")
   state.world=private;state.commits+=1;return true
  end
 end
 cfg.cancelled=function() state.cancels+=1 end
 cfg.failed=function(_,why) state.failures+=1;state.problem=why end
 cfg.completed=function() state.done+=1 end
 return Restore.new(cfg),state,cfg
end
local function finish(r)
 for _=1,10000 do if not r.job then break end;r:update() end
 check(r.job==nil,"bounded restore preparation finishes")
end
local r,state,cfg=fixture()
r:begin(record,1);r:update()
check(r.job~=nil and state.world=="original" and state.commits==0,"partial preparation keeps the old world")
finish(r)
check(state.done==1 and state.commits==1 and state.world~=record and state.world.items[1]~=record.items[1],"complete preparation publishes one private world")
r:update();check(state.done==1 and state.commits==1,"idle frames never replay a commit")
r,state,cfg=fixture();r:begin(record,1);r:update();r:cancel();finish(r)
check(state.world=="original" and state.cancels==1 and state.done==0,"cancelled selection cannot commit")
r,state,cfg=fixture();r:begin(record,1);r:update();state.version=2;finish(r)
check(state.world=="original" and state.cancels==1 and state.commits==0,"superseded selection is rejected after a yield")
r,state,cfg=fixture();r:begin(record,1);r:update();state.version=2;r:begin({replacement=true},2);finish(r)
check(state.cancels==1 and state.commits==1 and state.world.replacement,"one new job replaces old preparation without publishing it")
r,state,cfg=fixture();cfg.prepare=function() return nil,"corrupt checkpoint" end;r:begin(record,1);finish(r)
check(state.world=="original" and state.failures==1 and state.problem=="corrupt checkpoint","validation refusal leaves original world")
r,state,cfg=fixture();cfg.prepare=function() error("synthetic preparation failure") end;r:begin(record,1);finish(r)
check(state.world=="original" and state.failures==1,"preparation error leaves original world")
r,state,cfg=fixture();cfg.prepare=function() return function() return false,"commit refused" end end;r:begin(record,1);finish(r)
check(state.world=="original" and state.failures==1 and state.done==0,"refused commit cannot produce success")
r,state,cfg=fixture();r:begin(record,1)
for _=1,10000 do if r.job.work.state~="pending" then break end;r.job.work:step() end
check(r.job.work.state=="done" and state.commits==0,"finished result stays private before controller publication")
state.version=2;r:update()
check(state.world=="original" and state.cancels==1,"late selection change discards a completed result")
r,state,cfg=fixture()
local probes=0;local normal=cfg.current
cfg.current=function(stamp)
 probes+=1
 if probes==2 then state.version=2 end
 return normal(stamp)
end
cfg.prepare=function() return function() state.world="obsolete";return true end end
r:begin(record,1);r:update()
check(state.world=="original" and state.commits==0 and state.cancels==1,"selection is checked again after preparation finishes in one resume")
r,state,cfg=fixture()
local normalCurrent=cfg.current
cfg.current=function(stamp)
 if stamp==1 then state.version=2;r:begin({reentrant=true},2);return true end
 return normalCurrent(stamp)
end
r:begin(record,1);r:update();finish(r)
check(state.commits==1 and state.world.reentrant,"reentrant current check cannot resume the displaced job")
print(`SAVE_RESTORE passed={passed} failed={failed}`)
assert(failed==0,"restore preparation failures")
