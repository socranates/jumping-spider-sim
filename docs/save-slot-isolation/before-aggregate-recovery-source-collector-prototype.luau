--!strict
-- Private server-side raw collection. No original/archive writes, decoding,
-- world application or authority grant. The caller supplies real lease/intent
-- fences, scheduling/backoff and an isolated backend-owned raw read result.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Work=require(Shared.Persistence.SaveWork)
local Rules=require(Shared.Data.SaveRules)
local Archive=require(script.Parent.RecoveryArchivePrototype)
local Collector={};Collector.__index=Collector
local function plain(v:any):boolean return type(v)=="table" and getmetatable(v)==nil end
local function finite(v:any):boolean return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function empty():any
 local out={};for _,slot in Archive.SLOTS do out[slot]={loaded=true} end;return out
end
local function same(a:any,b:any):boolean
 local pulse=Work.pulse();if pulse then pulse() end
 if type(a)~=type(b) then return false end
 if type(a)~="table" then return a==b and (type(a)~="number" or a~=0 or 1/a==1/b) end
 if not plain(a) or not plain(b) then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
-- Only an explicitly supplied same-session heartbeat may advance. Preserve the
-- first raw progress envelope unchanged; never ignore settings/checksum/backup
-- changes, a different owner, unknown added fields or a backwards heartbeat.
local function sameSource(self:any,slot:string,a:any,b:any):boolean
 if same(a,b) then return true end
 if slot~="progress" or self.leaseSession==nil or not plain(a) or not plain(b) then return false end
 local first,last=a.lock,b.lock
 if not plain(first) or not plain(last) or first.session~=self.leaseSession or last.session~=self.leaseSession
  or not finite(first.beat) or not finite(last.beat) or last.beat<first.beat then return false end
 for k,v in a do if k~="lock" and not same(v,b[k]) then return false end end
 for k in b do if k~="lock" and a[k]==nil then return false end end
 for k,v in first do if k~="beat" and not same(v,last[k]) then return false end end
 for k in last do if k~="beat" and first[k]==nil then return false end end
 return true
end
function Collector.new(backend:any,owner:string,leaseSession:string?,bounds:any?,workOptions:any?):any
 assert(type(backend.readRawFresh)=="function","raw collection requires readRawFresh; cached/decoded reads cannot substitute")
 if leaseSession~=nil then assert(type(leaseSession)=="string" and #leaseSession>0 and #leaseSession<=256,"invalid lease session") end
 local limits={}
 if bounds~=nil then
  assert(plain(bounds),"invalid collection bounds")
  for k,v in bounds do assert(k=="entry" or k=="total" or k=="nodes" or k=="depth","unknown collection bound");limits[k]=v end
 end
 local valid,why=Archive.prepare(owner,"collector preflight",empty(),limits);assert(valid,why)
 local work={}
 if workOptions~=nil then
  assert(plain(workOptions),"invalid work options")
  for k,v in workOptions do assert(k=="now" or k=="budget" or k=="maxSeconds" or k=="maxResumes","unknown work option");work[k]=v end
 end
 local probe=Work.new(function() end,work);probe:cancel()
 return setmetatable({backend=backend,owner=owner,leaseSession=leaseSession,bounds=table.freeze(limits),workOptions=table.freeze(work),current=nil,busy=false,serial=0},Collector)
end
local function live(self:any,j:any):boolean return self.current==j and j.serial==self.serial and j.state=="pending" end
local function reject(j:any,state:string,why:string)
 if j.state=="cancelled" then return end
 j.state=state;j.reason=why;j.plan=nil
 if j.work then j.work:cancel();j.work=nil end
end
local function fence(self:any,j:any):boolean
 if not live(self,j) then return false end
 local ok,allowed=pcall(j.fence)
 if not live(self,j) then return false end
 if not ok or allowed~=true then reject(j,"refused","source/authority fence refused");return false end
 return true
end
function Collector.cancel(self:any,j:any):boolean
 if self.current~=j or j.state=="complete" or j.state=="cancelled" then return false end
 j.state="cancelled";j.plan=nil;j.reason="cancelled";j.sources={}
 if j.work then j.work:cancel();j.work=nil end
 return true
end
function Collector.begin(self:any,stamp:string,guard:()->boolean):any
 assert(type(guard)=="function","missing collection fence")
 local valid,why=Archive.prepare(self.owner,stamp,empty(),self.bounds);assert(valid,why)
 if self.current then self:cancel(self.current) end
 self.serial+=1
 local j={serial=self.serial,stamp=stamp,fence=guard,state="pending",phase="collect",cursor=1,sources={},reads=0,verified=0,plan=nil}
 self.current=j;return j
end
function Collector.retry(self:any,j:any):boolean
 if self.current~=j or j.state~="retry" or self.busy then return false end
 j.state="pending";j.reason=nil;return true
end
local function key(self:any,slot:string):string
 return if slot=="progress" then Rules.KEY_PROGRESS..self.owner else Rules.KEY_REST..self.owner.."_"..slot
end
local function snapshot(self:any,slot:string,raw:any):(any?,string?)
 local sources=empty();sources[slot].value=raw
 local plan,why=Archive.prepare(self.owner,"raw slot copy",sources,self.bounds)
 if not plan then return nil,why end
 return table.freeze({loaded=true,value=plan.entries[slot].raw}),nil
end
local function stepInner(self:any,j:any):boolean
 if not fence(self,j) then return false end
 if j.work then
  local worker=j.work;worker:step()
  if not fence(self,j) then return false end
  if worker.state=="pending" then return false end
  local result=worker:take();j.work=nil
  if not result then reject(j,"refused",worker.problem or "raw preparation failed");return false end
  if j.phase=="prepare" then
   if not result[1] then reject(j,"refused",result[2] or "archive preparation refused");return false end
   j.plan=result[1];j.sources={};j.state="complete";return false
  end
  local slot=Archive.SLOTS[j.cursor];local captured,errorText=result[1],result[2]
  if not captured then reject(j,"refused",errorText or "raw copy refused");return false end
  if j.phase=="collect" then j.sources[slot]=captured
  else
   if not result[3] then reject(j,"changed","raw source changed: "..slot);return false end
   j.verified+=1
  end
  j.cursor+=1
  if j.cursor>#Archive.SLOTS then
   if j.phase=="collect" then j.phase="verify";j.cursor=1
   else
    j.phase="prepare"
    j.work=Work.new(function() return Archive.prepare(self.owner,j.stamp,j.sources,self.bounds) end,self.workOptions)
   end
  end
  return false
 end
 local slot=Archive.SLOTS[j.cursor];j.reads+=1
 local ran,ok,raw,why=pcall(self.backend.readRawFresh,self.backend,key(self,slot))
 if not fence(self,j) then return true end
 if not ran or not ok then reject(j,"retry",tostring(if ran then why else ok));return true end
 -- CPU work is privately owned and resumable; no later backend request starts
 -- until this raw value has been bounded/copied/frozen. Cancelling its worker
 -- releases preparation without abandoning an in-flight backend coroutine.
 local phase=j.phase
 j.work=Work.new(function()
  local captured,errorText=snapshot(self,slot,raw)
  if not captured then return nil,errorText end
  return captured,nil,if phase=="verify" then sameSource(self,slot,j.sources[slot].value,captured.value) else true
 end,self.workOptions)
 return true
end
function Collector.wantsRead(self:any,j:any):boolean
 return not self.busy and live(self,j) and j.work==nil and j.phase~="prepare"
end
function Collector.step(self:any,j:any):boolean
 if self.busy or not live(self,j) then return false end
 self.busy=true
 local ok,asked=pcall(stepInner,self,j)
 self.busy=false
 if not ok then if live(self,j) then reject(j,"refused",tostring(asked)) end;return false end
 return asked
end
return table.freeze(Collector)
