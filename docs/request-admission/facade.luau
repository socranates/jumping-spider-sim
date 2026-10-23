--!strict
-- Private polling facade. Waiting for admission makes no provider request and
-- does not impersonate a failed DataStore attempt. Existing backend transform
-- and physical-lease fences remain required underneath this additional guard.
local Facade={};Facade.__index=Facade
local kinds={readFresh="read",readRawFresh="read",update="update"}
function Facade.new(gate:any,scope:any,backend:any):any
 assert(gate:live(scope),"live physical visit required")
 local methods={}
 for method in kinds do assert(type(backend[method])=="function","backend method required: "..method);methods[method]=backend[method] end
 return setmetatable({gate=gate,scope=scope,backend=backend,methods=table.freeze(methods),jobs={},serial=0},Facade)
end
function Facade.begin(self:any,method:string,key:string,transform:((any)->any)?):(any?,string?)
 if not kinds[method] or type(key)~="string" or #key==0 or #key>50 or method=="update" and type(transform)~="function" then return nil,"bounded typed backend operation required" end
 local ticket,why=self.gate:request(self.scope,kinds[method]);if not ticket then return nil,why end
 self.serial+=1;local handle=table.freeze({id=self.serial})
 self.jobs[handle]={handle=handle,ticket=ticket,method=method,key=key,transform=transform,busy=false,started=false,cancelled=false}
 return handle,nil
end
local function live(self:any,r:any):boolean
 return self.jobs[r.handle]==r and not r.cancelled and self.gate:live(self.scope)
end
function Facade.cancel(self:any,handle:any):boolean
 local r=self.jobs[handle];if not r then return false end
 r.cancelled=true;self.gate:cancel(r.ticket)
 if not r.busy then self.jobs[handle]=nil end
 return true
end
function Facade.step(self:any,handle:any):(string,any?,string?)
 local r=self.jobs[handle];if not r then return "ended",nil,nil end
 if r.busy then return "waiting",nil,"provider already pending" end
 if not live(self,r) then self:cancel(handle);return "cancelled",nil,"visit ended" end
 r.busy=true
 local called,admitted,result,why=pcall(self.gate.dispatch,self.gate,r.ticket,function()
  if not live(self,r) then error("operation ended before provider",0) end
  r.started=true
  if r.method=="update" then
   return self.methods.update(self.backend,r.key,function(old:any):any
    if not live(self,r) then return nil end
    local value=r.transform(old)
    if not live(self,r) then return nil end
    return value
   end)
  end
  return self.methods[r.method](self.backend,r.key)
 end)
 r.busy=false
 if not live(self,r) then self.jobs[handle]=nil;self.gate:cancel(r.ticket);return "cancelled",nil,"operation ended during provider" end
 if not called then self.jobs[handle]=nil;self.gate:cancel(r.ticket);return "failed",nil,tostring(admitted) end
 if admitted then self.jobs[handle]=nil;return "done",result,nil end
 local state=self.gate:status(r.ticket)
 if state=="queued" or state=="reserved" or state=="clock_unavailable" then return "waiting",nil,why end
 self.jobs[handle]=nil;return "failed",nil,why
end
function Facade.inspect(self:any):any
 local jobs,busy,started=0,0,0
 for _,r in self.jobs do jobs+=1;if r.busy then busy+=1 end;if r.started then started+=1 end end
 return {jobs=jobs,busy=busy,started=started}
end
return table.freeze(Facade)
