--!strict
-- Private actual-game adapter. Caller installs these callbacks only after safe
-- server profile/session routing exists. No engine startup uses this module.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Work=require(Shared.Persistence.SaveWork)
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local Entry=require(Shared.Persistence.RecoveryEntryClientPrototype)
local GameEntry={};GameEntry.__index=GameEntry
local function same(a:any,b:any):boolean
 return type(a)=="table" and type(b)=="table" and a.id==b.id and a.epoch==b.epoch and a.mode==b.mode and a.serial==b.serial
  and a.revision==b.revision and type(a.identity)=="table" and type(b.identity)=="table"
  and a.identity.checksum==b.identity.checksum and a.identity.updatedAt==b.identity.updatedAt
end
local function current(self:any,j:any,ignoreEntry:boolean?):boolean
 local c=self.cfg.client();local b=c and c.bound
 return self.job==j and c~=nil and c:recoveryReady() and b~=nil and b.epoch==j.epoch and b.requests[j.mode]==j.request
  and b.serial==j.serial and c.activeSlot==j.mode and j.request.kind=="continue" and j.request.serial==j.serial
  and j.request.offerId==j.offerId and self.cfg.state.worldGeneration==j.generation and j.hold.held()
  and (ignoreEntry==true or j.entry==nil or same(c.recoveryOffer,j.entry))
end
local function fail(j:any,why:string)
 if j.work then j.work:cancel();j.work=nil end
 j.commit=nil;j.phase="held";j.problem=why -- never infer rollback or release from failure
end
function GameEntry.new(cfg:any):any
 assert(type(cfg.client)=="function" and type(cfg.now)=="function" and type(cfg.prepareAdoption)=="function"
  and type(cfg.state)=="table" and type(cfg.state.pauseRecovery)=="function" and type(cfg.world)=="table","actual-game entry callbacks required")
 local seconds=cfg.maxSeconds or 1200
 assert(type(seconds)=="number" and seconds>0 and seconds<math.huge,"finite entry deadline required")
 return setmetatable({cfg=cfg,maxSeconds=seconds,job=nil},GameEntry)
end
function GameEntry.cancel(self:any):boolean
 local j=self.job;if not j then return false end
 fail(j,"entry cancelled; current world remains held");return true
end
function GameEntry.select(self:any,mode:string,serial:number):boolean
 local c=self.cfg.client();local b=c and c.bound;local r=b and b.requests[mode]
 if not c or not c:recoveryReady() or not r or r.kind~="continue" or r.serial~=serial or b.serial~=serial or r.state~="readonly" then return false end
 self:cancel()
 -- Acquire before returning to SaveClient, which sets activeSlot after this
 -- callback. Replacing a handle invalidates the obsolete job's release.
 self.job={mode=mode,serial=serial,epoch=b.epoch,request=r,offerId=r.offerId,generation=self.cfg.state.worldGeneration,
  hold=self.cfg.state.pauseRecovery(),born=self.cfg.now(),phase="selected",lastSend=-math.huge}
 return true
end
local function send(self:any,j:any):boolean
 if not current(self,j) or j.phase~="applied" or not j.receipt then return false end
 j.lastSend=self.cfg.now()
 -- Receipt/phase are already cached before this potentially reentrant send.
 local ok,sent=pcall(self.cfg.client().sendRecoveryApplied,self.cfg.client(),Json.copy(j.receipt))
 if not ok or not sent then j.problem="applied receipt not sent; current world remains held";return false end
 return true
end
function GameEntry.entry(self:any,offer:any,epoch:string,_sequence:number):boolean
 local j=self.job
 if not j or (j.phase~="selected" and j.phase~="preparing" and j.phase~="applied") or not current(self,j,true)
  or not same(self.cfg.client().recoveryOffer,offer) or epoch~=j.epoch or type(offer)~="table" or offer.epoch~=j.epoch or offer.mode~=j.mode
  or offer.serial~=j.serial or j.request.state~="readonly" or j.request.revision~=offer.revision then return false end
 if j.entry then
  if same(j.entry,offer) then
   if j.phase=="applied" and self.cfg.now()-j.lastSend>=Rules.CLIENT_LIFE_GAP then send(self,j) end
   return j.phase=="preparing" or j.phase=="applied"
  end
  if j.applied then fail(j,"entry identity changed after adoption; current world remains held");return false end
  if j.work then j.work:cancel();j.work=nil end
 end
 -- Only bounded scalar identity is retained outside the cooperative worker.
 if type(offer.identity)~="table" then return false end
 j.entry={id=offer.id,epoch=offer.epoch,mode=offer.mode,serial=offer.serial,revision=offer.revision,
  identity={checksum=offer.identity.checksum,updatedAt=offer.identity.updatedAt}}
 j.life=offer.life
 j.phase="preparing";j.problem=nil
 j.work=Work.new(function()
  return Entry.prepare(offer,self.cfg.world,function()
   return current(self,j) and j.request.state=="readonly" and j.request.revision==j.entry.revision
  end,function(record:any,stamp:any):(any?,string?)
   local commit,why=self.cfg.prepareAdoption(record,stamp)
   if type(commit)~="function" then return nil,why end
   return function():(boolean,string?)
    if not current(self,j) then return false,"selection changed before adoption" end
    local generation=j.generation;j.applied=true -- partial failures may have changed live state
    local okay,problem=commit()
    if okay~=true then return false,problem end
    -- Only this closure's one deliberate generation transition is accepted.
    if self.job~=j or not j.hold.held() or self.cfg.state.worldGeneration~=generation+1 then return false,"unexpected adoption generation/choice" end
    j.generation=generation+1
    if not current(self,j) then return false,"selection changed during adoption" end
    return true,nil
   end,nil
  end)
 end,self.cfg.workOptions)
 return true
end
function GameEntry.decision(self:any,d:any):boolean
 local j=self.job
 if not j or j.phase~="applied" or not j.receipt or not current(self,j) or type(d)~="table" then return false end
 local r=j.request
 if r.state~="writable" or d.state~="writable" or d.mode~=j.mode or d.kind~="continue" or d.serial~=j.serial or d.offerId~=j.offerId
  or d.revision~=j.entry.revision+1 or r.revision~=d.revision or r.credential~=d.credential or r.life~=d.life
  or type(d.credential)~="string" or #d.credential==0 or #d.credential>Rules.MAX_LIFE_TOKEN_CHARS then return false end
 if d.life~=j.life then return false end
 if not j.hold.release() then return false end
 j.phase="granted";j.problem=nil;return true
end
function GameEntry.update(self:any)
 local j=self.job;if not j or j.phase=="granted" or j.phase=="held" then return end
 if not current(self,j) then fail(j,"entry selection/epoch/world changed; current world remains held");return end
 if self.cfg.now()-j.born>=self.maxSeconds then fail(j,"entry timed out; current world remains held");return end
 if j.phase=="applied" then
  if j.request.state=="writable" then self:decision(self.cfg.client():decision(j.mode))
  elseif j.request.state~="readonly" or j.request.revision~=j.entry.revision then fail(j,"entry authority changed; current world remains held")
  elseif self.cfg.now()-j.lastSend>=Rules.CLIENT_LIFE_GAP then send(self,j) end
  return
 end
 if j.phase~="preparing" then return end
 j.work:step()
 if self.job~=j then return end
 if j.work.state=="pending" then return end
 if j.work.state~="done" then fail(j,j.work.problem or "entry preparation failed");return end
 local result=j.work:take();j.work=nil
 local commit=result and result[1]
 if type(commit)~="function" then fail(j,tostring(result and result[2] or "entry preparation refused"));return end
 if not current(self,j) then fail(j,"entry changed before apply");return end
 local ok,receipt,why=pcall(commit)
 if self.job~=j then return end
 if not ok or type(receipt)~="table" then fail(j,tostring(if ok then why else receipt));return end
 j.receipt=receipt
 j.phase="applied";send(self,j)
end
return table.freeze(GameEntry)
