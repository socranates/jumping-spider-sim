--!strict
-- Private nested-operation bridge. Explicit method bindings preserve raw-write
-- adapters; bounded plain counter rows charge parent and child atomically.
local Facade=require(script.Parent.RequestAdmissionFacade)
local Operation={};Operation.__index=Operation
local function number(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function plain(v:any):boolean return type(v)=="table" and getmetatable(v)==nil end
local function pruneHistory(scheduler:any,now:number):boolean
 local source=rawget(scheduler,"started")
 if type(source)~="table" or getmetatable(source)~=nil or #source>32768 then return false end
 local keep={};local n=0
 for key,at in source do
  if not number(key) or key%1~=0 or key<1 or key>#source or not number(at) then return false end
  n+=1;if now-at<60 then table.insert(keep,at) end
 end
 if n~=#source then return false end
 rawset(scheduler,"started",keep);return true
end
function Operation.new(session:any,lane:any,guard:()->boolean,rows:any,bindings:any?,mark:any?):any
 assert(plain(lane) and type(guard)=="function" and plain(rows) and #rows>=1 and #rows<=7 and plain(session.counters),"bounded trusted operation context required")
 local gate,scope=lane.gate,lane.scope
 assert(gate:live(scope) and gate:legacyReady(scope) and scope.actor==tostring(session.cfg.userId) and scope.epoch==session.id,"seeded account visit required")
 local counters={table.freeze({object=session.counters,field="requests",max=9007199254740000})};local seen:any={[session.counters]={requests=true}}
 local rowCount=0
 for i,row in rows do
  assert(type(i)=="number" and i%1==0 and i>=1 and i<=#rows and plain(row) and plain(row.object) and type(row.field)=="string"
   and number(row.max) and row.max>=1 and row.max%1==0 and row.max<=9007199254740000,"plain bounded counter row required")
  local fields=seen[row.object] or {};assert(not fields[row.field],"duplicate accounting row");fields[row.field]=true;seen[row.object]=fields
  table.insert(counters,table.freeze({object=row.object,field=row.field,max=row.max}))
  rowCount+=1
 end
 assert(rowCount==#rows,"dense counter rows required")
 local status=nil
 if mark then assert(plain(mark) and plain(mark.object) and type(mark.field)=="string" and type(mark.value)=="string" and not (seen[mark.object] and seen[mark.object][mark.field]),"plain non-counter dispatch marker required");status=table.freeze({object=mark.object,field=mark.field,value=mark.value}) end
 local self:any=setmetatable({session=session,backend=session.backend,scheduler=session.sched,counters=session.counters,id=session.id,user=tostring(session.cfg.userId),gate=gate,scope=scope,closed=false,starts=0},Operation)
 local function valid():boolean
  if self.closed or not gate:live(scope) then return false end
  local okay,live=pcall(guard)
  return okay==true and live==true and not self.closed and gate:live(scope)==true and session.backend==self.backend and session.sched==self.scheduler
   and session.counters==self.counters and session.id==self.id and tostring(session.cfg.userId)==self.user
 end
 local function fits():boolean
  for _,row in counters do
   if not plain(row.object) then return false end
   local value=row.object[row.field]
   if not number(value) or value%1~=0 or value<0 or value>=row.max then return false end
  end
  return status==nil or plain(status.object)
 end
 self.valid=valid
 local wrapped={}
 for _,method in {"readFresh","readRawFresh","update"} do
  local binding=if bindings then bindings[method] else nil
  local target=if binding then binding.object else session.backend
  local fn=if binding then binding.fn else target[method]
  assert(type(target)=="table" and type(fn)=="function","explicit backend method binding required")
  wrapped[method]=function(_backend:any,key:string,transform:any):...any
   local now=session.now()
   if not number(now) or not valid() or not fits() then error("operation scope/cap changed before bookkeeping",0) end
   if not pruneHistory(self.scheduler,now) then error("invalid scheduler request history",0) end
   self.scheduler:begin(nil,now)
   if not valid() or not fits() then error("operation scope/cap changed during bookkeeping",0) end
   if not pruneHistory(self.scheduler,now) then error("invalid scheduler request history",0) end
   -- All rows/marker are plain, captured and validated. No callbacks or yields
   -- occur between this atomic accounting block and the captured method.
   for _,row in counters do row.object[row.field]+=1 end
   if status then status.object[status.field]=status.value end
   self.starts+=1
   local returned
   if method=="update" then
    returned=table.pack(pcall(fn,target,key,function(old:any):any
     if not valid() then return nil end
     local value=transform(old)
     if not valid() then return nil end
     return value
    end))
   else returned=table.pack(pcall(fn,target,key)) end
   if not returned[1] then return false,nil,tostring(returned[2]) end
   return table.unpack(returned,2,returned.n)
  end
 end
 self.facade=Facade.new(gate,scope,wrapped);return self
end
function Operation.cancel(self:any)
 self.closed=true;if self.handle then self.facade:cancel(self.handle);self.handle=nil end
end
function Operation.poll(self:any,method:string,key:string,transform:any):(string,any?,boolean)
 if not self.valid() then self:cancel();return "cancelled",nil,false end
 if self.handle and (self.method~=method or self.key~=key or self.transform~=transform) then self:cancel();return "failed",nil,false end
 if not self.handle then
  local ticket=self.facade:begin(method,key,transform);if not ticket then return "failed",nil,false end
  self.handle,self.method,self.key,self.transform=ticket,method,key,transform
 end
 local before=self.starts;local state,result=self.facade:step(self.handle);local asked=self.starts>before
 if state~="waiting" then self.handle=nil end
 if not self.valid() then self:cancel();return "cancelled",nil,asked end
 return state,result,asked
end
return table.freeze(Operation)
