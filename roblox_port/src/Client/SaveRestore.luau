--!strict
-- One private preparation at a time. prepare owns a stable record and returns
-- an atomic commit closure. Inputs are never live simulation tables. No network
-- request, authority grant or old world is changed by the scheduler itself.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Work=require(Shared.Persistence.SaveWork)
local Restore={}
Restore.__index=Restore
function Restore.new(cfg:any):any
 return setmetatable({cfg=cfg,job=nil},Restore)
end
function Restore.cancel(self:any):boolean
 local j=self.job
 if not j then return false end
 self.job=nil;j.work:cancel()
 if self.cfg.cancelled then self.cfg.cancelled(j.stamp) end
 return true
end
function Restore.begin(self:any,record:any,stamp:any)
 self:cancel()
 self.job={stamp=stamp,work=Work.new(function() return self.cfg.prepare(record,stamp) end,self.cfg.workOptions)}
end
function Restore.update(self:any)
 local j=self.job
 if not j then return end
 local current=self.cfg.current(j.stamp)
 if self.job~=j then return end
 if not current then self:cancel();return end
 j.work:step()
 if self.job~=j then return end
 if j.work.state=="pending" then return end
 if j.work.state~="done" then
  self.job=nil
  self.cfg.failed(j.stamp,j.work.problem or "The rest could not be prepared")
  return
 end
 local result=j.work:take()
 current=self.cfg.current(j.stamp)
 if self.job~=j then return end
 if not current then self:cancel();return end
 self.job=nil -- commit/callbacks may start or cancel a different preparation
 local commit=result and result[1]
 if type(commit)~="function" then self.cfg.failed(j.stamp,result and result[2] or "The rest could not be prepared");return end
 local ok,done,problem=pcall(commit)
 if not ok or done~=true then self.cfg.failed(j.stamp,if ok then problem else done);return end
 self.cfg.completed(j.stamp)
end
return Restore
