--!strict
-- Private bridge for a polled worker. One lane is owned by the server/account
-- visit, not by this job. The owner must route ALL provider work through it.
local Facade=require("./worker-facade")
local Worker={};Worker.__index=Worker
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Worker.new(session:any,job:any,lane:any,maxRequests:number,guard:()->boolean):any
 assert(type(lane)=="table" and getmetatable(lane)==nil,"trusted plain admission lane required")
 local gate,scope=lane.gate,lane.scope
 assert(gate:live(scope) and gate:legacyReady(scope) and scope.actor==tostring(session.cfg.userId) and scope.epoch==session.id,"seeded physical account visit required")
 local self:any=setmetatable({session=session,job=job,gate=gate,scope=scope,backend=session.backend,scheduler=session.sched,
  counters=session.counters,id=session.id,user=tostring(session.cfg.userId),maxRequests=maxRequests,guard=guard,closed=false,starts=0},Worker)
 local methods={}
 for _,name in {"readFresh","readRawFresh","update"} do methods[name]=session.backend[name];assert(type(methods[name])=="function","backend method required") end
 local function valid():boolean
  if self.closed or not gate:live(scope) then return false end
  local okay,live=pcall(guard)
  return okay and live==true and not self.closed and gate:live(scope) and session.backend==self.backend and session.sched==self.scheduler
   and session.counters==self.counters and session.id==self.id and tostring(session.cfg.userId)==self.user
 end
 self.valid=valid
 local wrapped={}
 for _,name in {"readFresh","readRawFresh","update"} do
  wrapped[name]=function(_backend:any,key:string,transform:any):...any
   local now=session.now()
   if not finite(now) or not valid() or job.requests>=maxRequests then error("worker scope/cap changed before provider",0) end
   -- No external callback between accounting and the captured backend method.
   self.scheduler:begin(nil,now);self.counters.requests+=1;job.requests+=1;self.starts+=1
   local returned
   if name=="update" then
    returned=table.pack(pcall(methods[name],self.backend,key,function(old:any):any
     if not valid() then return nil end
     local value=transform(old)
     if not valid() then return nil end
     return value
    end))
   else
    returned=table.pack(pcall(methods[name],self.backend,key))
   end
   -- A provider exception is an actual failed attempt. Preserve the worker's
   -- existing retry/backoff path rather than treating it as an admission denial.
   if not returned[1] then return false,nil,tostring(returned[2]) end
   return table.unpack(returned,2,returned.n)
  end
 end
 self.facade=Facade.new(gate,scope,wrapped)
 return self
end
function Worker.cancel(self:any)
 self.closed=true
 if self.handle then self.facade:cancel(self.handle);self.handle=nil end
end
function Worker.poll(self:any,method:string,key:string,transform:any):(string,any?,boolean)
 if not self.valid() then self:cancel();return "cancelled",nil,false end
 if self.handle and (self.method~=method or self.key~=key or self.transform~=transform) then self:cancel();return "failed",nil,false end
 if not self.handle then
  local handle=self.facade:begin(method,key,transform)
  if not handle then return "failed",nil,false end
  self.handle,self.method,self.key,self.transform=handle,method,key,transform
 end
 local before=self.starts
 local state,result=self.facade:step(self.handle)
 local asked=self.starts>before
 if state~="waiting" then self.handle=nil end
 if not self.valid() then self:cancel();return "cancelled",nil,asked end
 if state=="done" then return state,result,asked end
 return state,nil,asked
end
return table.freeze(Worker)
