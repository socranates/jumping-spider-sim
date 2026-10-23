--!strict
-- Private server-side publication protocol. Every step makes at most one backend
-- request; a future SaveSession integration must supply its request budget/backoff
-- and a synchronous authority/source fence. Only A1_ archive keys are touched.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Work=require(Shared.Persistence.SaveWork)
local Json=require(Shared.Persistence.Json)
local Rules=require(Shared.Data.SaveRules)
local Archive=require(script.Parent.RecoveryArchivePrototype)
local Store={};Store.__index=Store
Store.FORMAT="the-windowsill recovery publication"
local function plain(value:any):boolean return type(value)=="table" and getmetatable(value)==nil end
local function same(expected:any,value:any):boolean
 if type(expected)~=type(value) then return false end
 if type(expected)~="table" then
  return expected==value and (type(expected)~="number" or expected~=0 or 1/expected==1/value)
 end
 if not plain(value) then return false end
 for k,v in expected do if not same(v,value[k]) then return false end end
 for k in value do if expected[k]==nil then return false end end
 return true
end
local function allowed(value:any,fields:any):boolean
 if not plain(value) then return false end
 for k in value do if not fields[k] then return false end end
 return true
end
local function knownOwner(owner:any):boolean
 return type(owner)=="string" and #owner>0 and #owner<=32 and string.match(owner,"^[%w_-]+$")~=nil
end
function Store.new(backend:any,owner:string,limits:any?):any
 assert(knownOwner(owner),"invalid archive owner")
 local bounds:{[string]:number}={value=Rules.MAX_VALUE_CHARS,total=Archive.MAX_TOTAL_CHARS}
 if limits then
  assert(plain(limits),"invalid publication bounds")
  for k,v in limits do
   assert(bounds[k]~=nil and type(v)=="number" and v==v and v%1==0 and v>=1 and v<=bounds[k],"invalid publication bound")
   bounds[k]=v
  end
 end
 return setmetatable({backend=backend,owner=owner,bounds=table.freeze(bounds)},Store)
end
local function key(self:any,slot:string):string return "A1_"..self.owner.."_"..slot end
local function anchor(plan:any):any
 return table.freeze({format=Store.FORMAT,version=1,owner=plan.index.owner,index=plan.index,progress=plan.entries.progress})
end
local function manifest(plan:any):any
 return table.freeze({format=Store.FORMAT,version=1,owner=plan.index.owner,complete=true,index=plan.index})
end
local function sequence(self:any,plan:any):(any?,string?,number?)
 local out={{key=key(self,"progress"),value=anchor(plan)}}
 for _,slot in {"main","free","easy"} do table.insert(out,{key=key(self,slot),value=plan.entries[slot]}) end
 table.insert(out,{key=key(self,"index"),value=manifest(plan)})
 local total=0
 for _,item in out do
  local text,why=Json.canonical(item.value)
  if not text then return nil,why,nil end
  if #text>self.bounds.value then return nil,"archive artifact exceeds storage value limit",nil end
  total+=#text
 end
 if total>self.bounds.total then return nil,"archive publication exceeds aggregate storage limit",nil end
 return out,nil,total
end
local function live(job:any):boolean
 if job.state=="cancelled" then return false end
 local ok,result=pcall(job.fence)
 return ok and result==true and job.state~="cancelled"
end
local function refuse(job:any,why:string)
 if job.state=="cancelled" then return end
 job.state,job.problem="refused",why
end
local function retryLater(job:any,why:any)
 job.state,job.problem="retry",tostring(why or "archive readback unavailable")
end
local function newJob(self:any,fence:any):any
 assert(type(fence)=="function","archive publication needs an authority/source fence")
 return {repository=self,fence=fence,state="pending",phase="write",index=1,requests=0,verified=0,problem=nil}
end
-- Own and validate the plan once, before any backend call can yield. A mutable
-- caller cannot change what a later step writes or claims to have verified.
function Store.begin(self:any,plan:any,fence:any):(any?,string?)
 if Work.pulse() then return nil,"archive storage must run outside preparation" end
 if type(fence)~="function" then return nil,"archive publication needs an authority/source fence" end
 if not plain(plan) or not plain(plan.index) or not plain(plan.entries) then return nil,"invalid archive plan" end
 local sources={}
 for _,slot in Archive.SLOTS do
  local entry=plan.entries[slot]
  if not plain(entry) then return nil,"missing archive entry" end
  sources[slot]={loaded=true,value=entry.raw}
 end
 local owned,why=Archive.prepare(self.owner,plan.index.observation,sources)
 if not owned or not same(owned,plan) then return nil,why or "archive plan changed" end
 local items,errorText,characters=sequence(self,owned)
 if not items then return nil,errorText end
 local job=newJob(self,fence);job.plan=owned;job.sequence=items;job.characters=characters
 return job,nil
end
-- The progress anchor carries the complete source matrix before any other part
-- is written. After a restart it supplies the original observation and progress;
-- missing parts may be rebuilt only from matching raw original source reads.
function Store.beginRecovery(self:any,sources:any,fence:any):(any?,string?)
 if Work.pulse() then return nil,"archive storage must run outside preparation" end
 if type(fence)~="function" then return nil,"archive publication needs an authority/source fence" end
 if sources~=nil and not plain(sources) then return nil,"invalid raw recovery sources" end
 local normalized,available={},{}
 for _,slot in Archive.SLOTS do
  local source=if sources then sources[slot] else nil
  if source~=nil and (not allowed(source,{loaded=true,value=true}) or type(source.loaded)~="boolean") then return nil,"invalid raw source read" end
  available[slot]=source~=nil and source.loaded==true
  normalized[slot]={loaded=true,value=if available[slot] then source.value else nil}
 end
 if sources then for slot in sources do if available[slot]==nil then return nil,"unknown raw recovery slot" end end end
 local owned,why=Archive.prepare(self.owner,"recovery-input",normalized)
 if not owned then return nil,why end
 local job=newJob(self,fence);job.phase="recover";job.recovery={};job.sources=owned;job.available=available
 return job,nil
end
local function rebuild(self:any,job:any):(any?,string?)
 local a=job.recovery.progress
 if not allowed(a,{format=true,version=true,owner=true,index=true,progress=true}) or a.format~=Store.FORMAT or a.version~=1 or a.owner~=self.owner
  or not plain(a.index) or not plain(a.progress) then return nil,"invalid archive anchor" end
 local sources:{[string]:any}={progress={loaded=true,value=a.progress.raw}}
 for _,slot in {"main","free","easy"} do
  local entry=job.recovery[slot]
  if entry~=nil then
   if not plain(entry) then return nil,"invalid archived part" end
   sources[slot]={loaded=true,value=entry.raw}
  elseif job.available[slot] then sources[slot]={loaded=true,value=job.sources.entries[slot].raw}
  else return nil,"an archive part is missing and its original raw source is unavailable" end
 end
 local plan,why=Archive.prepare(self.owner,a.index.observation,sources)
 if not plan then return nil,why end
 if not same(anchor(plan),a) then return nil,"archive anchor/source matrix differs" end
 for _,slot in {"main","free","easy"} do
  if job.recovery[slot]~=nil and not same(plan.entries[slot],job.recovery[slot]) then return nil,"archive part differs" end
 end
 return plan,nil
end
function Store.cancel(self:any,job:any):boolean
 if job.repository~=self or job.state=="complete" or job.state=="cancelled" then return false end
 job.state,job.problem="cancelled","archive publication cancelled";return true
end
function Store.retry(self:any,job:any):boolean
 if job.repository~=self or job.state~="retry" then return false end
 if not live(job) then refuse(job,"archive authority/source changed");return false end
 job.state,job.problem="pending",nil
 if job.phase=="recover" then job.index=1;job.recovery={} else job.phase="write" end
 return true
end
function Store.step(self:any,job:any):boolean
 if job.repository~=self or job.state~="pending" then return false end
 if Work.pulse() then refuse(job,"archive storage must run outside preparation");return false end
 if not live(job) then refuse(job,"archive authority/source changed");return false end
 job.state="running";job.requests+=1
 if job.phase=="write" then
  local item=job.sequence[job.index];local outcome=""
  local called,ok,_value,why=pcall(self.backend.update,self.backend,item.key,function(old:any):any
   outcome=""
   if not live(job) then outcome="authority";return nil end
   if old==nil then outcome="new";return item.value end
   if same(item.value,old) then outcome="same";return nil end
   outcome="conflict";return nil
  end)
  -- A yielding backend or its callback may cancel the job; widen the narrowed
  -- pre-call discriminator before inspecting that externally changed state.
  if (job.state::string)=="cancelled" then return false end
  if not live(job) or outcome=="authority" then refuse(job,"archive authority/source changed");return false end
  if outcome=="conflict" then refuse(job,"a different archive already occupies this key");return false end
  -- Read after both success and ambiguous failure. A returned candidate or an
  -- UpdateAsync acknowledgement alone never makes a part verified.
  job.lastWriteError=if called and ok==true then nil else tostring(if called then why else ok)
  job.phase,job.state="read","pending";return true
 end
 local readKey=if job.phase=="recover" then key(self,Archive.SLOTS[job.index]) else job.sequence[job.index].key
 local called,ok,value,why=pcall(self.backend.read,self.backend,readKey)
 if (job.state::string)=="cancelled" then return false end
 if not live(job) then refuse(job,"archive authority/source changed");return false end
 if not called or ok~=true then retryLater(job,if called then why else ok);return false end
 if job.phase=="recover" then
  if job.index==1 and value==nil then refuse(job,"no archive anchor exists");return false end
  job.recovery[Archive.SLOTS[job.index]]=value;job.index+=1
  if job.index<=4 then job.state="pending";return true end
  local plan,problem=rebuild(self,job)
  if not plan then refuse(job,problem or "archive reconstruction failed");return false end
  local items,errorText,characters=sequence(self,plan)
  if not items then refuse(job,errorText or "archive publication exceeds bounds");return false end
  job.plan,job.sequence,job.characters,job.index,job.phase,job.state=plan,items,characters,1,"write","pending"
  return true
 end
 local expected=job.sequence[job.index].value
 if value==nil then retryLater(job,job.lastWriteError or "archive part not visible yet");return false end
 if not same(expected,value) then refuse(job,"archive readback differs");return false end
 job.verified+=1;job.index+=1
 if job.index>#job.sequence then job.state,job.problem="complete",nil;return true end
 job.phase,job.state="write","pending";return true
end
return table.freeze(Store)
