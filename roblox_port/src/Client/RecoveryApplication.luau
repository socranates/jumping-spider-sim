--!strict
-- Application ownership around the negotiated recovery/replacement adapters.
-- Installing this coordinator does not grant save authority or resume a world.
local Application = {}; Application.__index = Application
function Application.new(cfg: any): any
 for _, name in {"pause", "held", "invalidate", "pauseUI", "show", "visible", "freshMenu", "resumeUI", "generation", "started", "healthy"} do
  assert(type(cfg[name]) == "function", "recovery application callback required: " .. name)
 end
 return setmetatable({cfg=cfg,phase="idle",client=nil,entry=nil}, Application)
end
function Application.bind(self: any, client: any, entry: any)
 assert(self.client == nil and client.phase == "searching" and client.remotes == nil and client.bound and client.bound.epoch == nil,
  "recovery must bind before transport starts")
 for _,name in {"select","entry","decision","cancel","update"} do assert(type(entry[name])=="function","entry callback required: "..name) end
 self.client,self.entry = client,entry
end
function Application.held(self: any): boolean return self.cfg.held() end
function Application.choosing(self: any): boolean return self.phase == "menu" end
function Application.busy(self: any): boolean
 return self.phase == "entry" or self.phase == "new" or self.phase == "replacing" or self.phase == "failed"
end
function Application.canExit(self: any): boolean
 return self.client ~= nil and self.client.replacementEnabled == true and self.client.transition == nil and self.cfg.healthy()
end
function Application.render(self: any)
 if not self:busy() or self.screenBroken then return end
 local key = self.phase .. tostring(self:canExit())
 if key ~= self.rendered or not self.cfg.visible() then
  self.rendered=key
  local ok,why=pcall(self.cfg.show,self.phase,self:canExit())
  if not ok then
   self.screenBroken=true;self.phase,self.problem="failed",tostring(why)
   if not self:held() then self.hold=self.cfg.pause() end
   pcall(self.cfg.pauseUI)
  end
 end
end
function Application.fail(self: any, why: any)
 if self.entry then pcall(self.entry.cancel,self.entry) end
 if not self:held() then self.hold=self.cfg.pause() end
 self.phase,self.problem="failed",tostring(why)
 pcall(self.cfg.pauseUI);self:render()
end
function Application.select(self: any, mode: string, serial: number): boolean
 if self:busy() or not self.cfg.healthy() then return false end
 local request=self.client:decision(mode)
 if not request or request.kind~="continue" or request.serial~=serial or request.state~="readonly" then return false end
 self.cfg.invalidate()
 if not self.entry:select(mode,serial) then return false end
 self.phase,self.problem="entry",nil;self.cfg.pauseUI();self:render();return true
end
-- A playing recovered life owns an enforced server save route. Leaving that
-- world always obtains a new epoch first; never reuse its menu's old offer IDs.
function Application.beforeWorldChoice(self:any):boolean
 if self.phase~="playing" or not self.recoveredPlaying then return false end
 local okay,accepted=pcall(self.client.requestReplacement,self.client)
 if not okay or accepted~=true then self:fail("saved spider could not be closed") end
 return true
end
function Application.prepareNew(self:any,mode:string,id:string?):boolean
 if not self.client.newLifeEnabled then return false end
 local info=self.client:offerInfo(mode)
 if not info or not info.protected then return false end
 self.entry:cancel();self.cfg.invalidate();self.hold=self.cfg.pause()
 self.phase,self.problem="new",nil;self.cfg.pauseUI();self:render()
 local okay,accepted=pcall(self.client.prepareNewLife,self.client,mode,id)
 if not okay or accepted~=true then self:fail("new spider preparation was refused");return true end
 local n=self.client.newLife
 self.newOperation={epoch=n.epoch,mode=n.mode,serial=n.serial}
 return true
end
function Application.newState(self:any,state:string,mode:string,serial:number,epoch:string)
 local n=self.newOperation
 if self.phase~="new" or not n or n.epoch~=epoch or n.mode~=mode or n.serial~=serial or self.client.bound.epoch~=epoch or not self:held() then return end
 if state=="refused" then self:fail("the previous saved spider could not be kept safely")
 elseif state=="verified" then
  local okay,accepted=pcall(self.client.requestReplacement,self.client)
  if not okay or accepted~=true then self:fail("new spider preparation could not close the previous session") end
 end
end
function Application.decision(self: any, decision: any)
 if self.phase=="entry" then self.entry:decision(decision);self:update() end
end
function Application.pauseReplacement(self: any, epoch: string, serial: number): boolean
 if not self.client or self.client.bound.epoch~=epoch or not self.cfg.healthy() then return false end
 self.entry:cancel();self.cfg.invalidate();self.hold=self.cfg.pause()
 self.recoveredPlaying=false;self.newOperation=nil
 self.replacement={epoch=epoch,serial=serial,hold=self.hold}
 self.phase,self.problem="replacing",nil;self.cfg.pauseUI();self:render()
 return self.hold.held()
end
function Application.ready(self: any, oldEpoch: string, newEpoch: string, serial: number): boolean
 local pending=self.replacement
 if self.phase~="replacing" or not pending or pending.epoch~=oldEpoch or pending.serial~=serial or pending.hold~=self.hold
  or not self.hold or not self.hold.held() or oldEpoch==newEpoch or self.client.bound.epoch~=newEpoch then return false end
 self.phase,self.epoch,self.menuGeneration="menu",newEpoch,self.cfg.generation()
 self.rendered=nil
 -- A fresh choice screen retains its own hold. Hiding it cannot resume the
 -- old world. Only a subsequent explicit new-life/restore commit may release.
 local ok,visible=pcall(self.cfg.freshMenu)
 if not ok or visible~=true then self:fail("fresh menu could not be displayed");return false end
 return true
end
function Application.finishChoice(self: any): boolean
 if self.phase~="menu" then return false end
 if self.client.bound.epoch~=self.epoch or not self.hold or not self.hold.held()
  or self.cfg.generation()<=self.menuGeneration or not self.cfg.started() or self.client.activeSlot==nil or not self.cfg.healthy() then
  self:fail("new choice was not committed in the current session");return false
 end
 if not self.hold.release() then return false end
 self.phase,self.hold="playing",nil;return true
end
function Application.exit(self: any): boolean
 if not self:held() or not self:canExit() then return false end
 local ok,accepted=pcall(self.client.requestReplacement,self.client)
 if not ok or accepted~=true then self:fail("session replacement was not accepted");return false end
 return true
end
function Application.update(self: any)
 if self:held() and self.phase~="failed" and self.client.transition and self.client.transition.stage=="failed" then self:fail(self.client.transition.problem);return end
 if self.phase=="entry" then
  local ok,why=pcall(self.entry.update,self.entry)
  if not ok then self:fail(why);return end
  if self.phase~="entry" then return end -- a reentrant grant already finished
  local job=self.entry.job
  if not job or job.phase=="held" then self:fail(job and job.problem or "entry work disappeared");return end
  if job.phase=="granted" then
   self.phase="playing";self.recoveredPlaying=true
   local resumed,problem=pcall(self.cfg.resumeUI)
   if not resumed then self:fail(problem) end
   return
  end
 elseif self.phase=="replacing" and self.client.transition and self.client.transition.stage=="failed" then
  self:fail(self.client.transition.problem);return
 end
 self:render()
end
function Application.configure(self: any, original: any): any
 local cfg={};for k,v in original do cfg[k]=v end
 local continuation={};for k,v in original.continuation do continuation[k]=v end
 cfg.continuation=continuation
 continuation.onDecision=function(d: any)
  self:decision(d)
  if original.continuation.onDecision then original.continuation.onDecision(d) end
 end
 cfg.recovery={onSelected=function(mode: string,serial: number): boolean return self:select(mode,serial) end,
  onEntry=function(offer: any,epoch: string,sequence: number) self.entry:entry(offer,epoch,sequence) end}
 return cfg
end
function Application.replacementOptions(self: any): any
 return {onPause=function(epoch: string,serial: number): boolean return self:pauseReplacement(epoch,serial) end,
  onReady=function(oldEpoch: string,newEpoch: string,serial: number): boolean return self:ready(oldEpoch,newEpoch,serial) end,
  onNewState=function(state:string,mode:string,serial:number,epoch:string) self:newState(state,mode,serial,epoch) end}
end
return table.freeze(Application)
