--!strict
-- Cooperative preparation only. Callers must own/hold stable inputs and gate
-- publication against their current intent. This scheduler does not snapshot
-- mutable inputs or make a function's side effects transactional.
-- Step at most once per frame. Budgets are soft: native calls and code without
-- pulse points cannot be preempted. Results remain private until take().
local Work={}
Work.__index=Work
type Pulse=(number?)->()
local active:{[thread]:Pulse}={}
local YIELD={}
local function positive(n:any):boolean
 return type(n)=="number" and n==n and n>0 and n<math.huge
end
function Work.pulse():Pulse?
 local co=coroutine.running()
 return if co then active[co] else nil
end
function Work.new(fn:()->...any,options:any?):any
 local cfg=options or {}
 local now=cfg.now or os.clock
 local budget=cfg.budget or .004
 local maxSeconds=cfg.maxSeconds or 60
 local maxResumes=cfg.maxResumes or 10000
 assert(positive(budget) and positive(maxSeconds) and positive(maxResumes) and maxResumes==math.floor(maxResumes),"invalid work bounds")
 local self:any=setmetatable({now=now,budget=budget,maxSeconds=maxSeconds,maxResumes=maxResumes,
  born=now(),deadline=0,resumes=0,units=0,state="pending",problem=nil,result=nil,thread=coroutine.create(fn)},Work)
 self.checkpoint=function(units:number?)
  self.units+=units or 1
  if self.units>=64 then
   self.units=0
   if self.now()>=self.deadline then coroutine.yield(YIELD) end
  end
 end
 return self
end
local function fail(self:any,problem:string)
 self.state,self.problem,self.thread,self.result="failed",problem,nil,nil
end
function Work.step(self:any):boolean
 if self.state~="pending" then return false end
 if self.resumes>=self.maxResumes or self.now()-self.born>=self.maxSeconds then fail(self,"preparation timed out");return false end
 local co=self.thread
 self.resumes+=1;self.deadline=self.now()+self.budget;self.state="running"
 active[co]=self.checkpoint
 local reply:any=table.pack(coroutine.resume(co))
 active[co]=nil -- remove even after an error or an unexpected yield
 if (self.state :: string)=="cancelled" then self.thread,self.result=nil,nil;return false end
 if not reply[1] then fail(self,tostring(reply[2]));return false end
 if self.now()-self.born>=self.maxSeconds then fail(self,"preparation timed out");return false end
 if coroutine.status(co)=="dead" then
  local result:any={n=reply.n-1}
  for i=2,reply.n do result[i-1]=reply[i] end
  self.result,self.thread,self.state=result,nil,"done"
 elseif reply.n==2 and reply[2]==YIELD then self.state="pending"
 else fail(self,"unexpected preparation yield");return false end
 return true
end
function Work.cancel(self:any):boolean
 if self.state=="consumed" or self.state=="failed" or self.state=="cancelled" then return false end
 self.state,self.thread,self.result="cancelled",nil,nil
 return true
end
function Work.take(self:any):any?
 if self.state~="done" then return nil end
 local result=self.result;self.result=nil;self.state="consumed"
 return result
end
return Work
