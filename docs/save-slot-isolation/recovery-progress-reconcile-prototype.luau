--!strict
-- Shared pure three-way global progress reconciliation. No lease/authority or
-- I/O; callers supply an acknowledged baseline and stable owned observations.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local Progress=require(Shared.Persistence.SaveProgress)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local SaveRest=require(Shared.Persistence.SaveRest)
local Json=require(Shared.Persistence.Json)
local Reconcile={}
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Reconcile.prepare(baseRaw:any,localProgress:any,localTime:number,remoteRaw:any,maxCharacters:number):(any?,string?)
 if type(baseRaw)~="table" or type(remoteRaw)~="table" or not finite(localTime) or not finite(maxCharacters)
  or maxCharacters<1 or maxCharacters>Rules.MAX_VALUE_CHARS then return nil,"invalid progress reconciliation inputs" end
 local base,errorText=Projection.mergePending(baseRaw,Progress.default(),baseRaw.updatedAt);if not base then return nil,errorText end
 if SaveRest.bounded(localProgress,Rules.MAX_PROGRESS_NODES,Rules.MAX_DEPTH) then return nil,"local progress exceeds bound" end
 local current,currentError=Projection.mergePending(Envelope.make(Progress.SPEC,localProgress,localTime,nil),Progress.default(),localTime)
 if not current then return nil,currentError end
 local delta=Json.copy(current.progress);delta.settings={};delta.appearance=nil
 for key,value in current.progress.settings do if base.progress.settings[key]~=value then delta.settings[key]=value end end
 if current.progress.appearance~=base.progress.appearance then delta.appearance=current.progress.appearance end
 local merged,mergeError=Projection.mergePending(remoteRaw,delta,localTime);if not merged then return nil,mergeError end
 if localTime==remoteRaw.updatedAt then
  for key,value in delta.settings do merged.progress.settings[key]=value end
  if delta.appearance~=nil then merged.progress.appearance=delta.appearance end
 end
 local text=Json.canonical(merged.progress);if not text or #text>maxCharacters then return nil,"reconciled progress exceeds budget" end
 local opened=Envelope.open(Progress.SPEC,remoteRaw,false)
 if opened.payload==nil then return nil,"progress decoder returned no supported payload" end
 local dirty=not Progress.same(merged.progress,opened.payload)
 return {progress=merged.progress,progressTime=if dirty then math.max(localTime,remoteRaw.updatedAt) else remoteRaw.updatedAt,dirty=dirty},nil
end
return table.freeze(Reconcile)
