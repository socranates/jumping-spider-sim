--!strict
-- Cold Preserve startup only. One physical-account ledger owns every save path.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Gate=require(script.Parent.RequestAdmissionGate)
local Accounts=require(script.Parent.RecoveryAccountLifetimes)
local Service=require(script.Parent.ReplacementServicePrototype)
local Owner=require(script.Parent.ReplacementOwnerPrototype)
local Policy=require(script.Parent.RecoveryNewLifePolicyPrototype)
local Raw=require(script.Parent.RecoveryRawBackendPrototype)
local Format=require(script.Parent.RecoveryRestFormatPrototype)
local Entry=require(script.Parent.RecoveryEntryPrototype)
local Loop=require(script.Parent.RecoverySaveLoopPrototype)
local Map=require(Shared.World.WorldMap)
local Composition={}
function Composition.new(cfg:any):any
 assert(Map.world()=="preserve" and cfg.catalog~=nil,"authored Preserve catalog required")
 assert(cfg.backend.ds==cfg.dataStore and type(cfg.available)=="function","one physical store and observed budget required")
 -- Application rolling bounds, not platform quotas. The live platform budget
 -- is checked separately at every dispatch, retaining two unspent units.
 local gate=Gate.new({now=cfg.now,available=cfg.available,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=2})
 local accounts=Accounts.new(gate,{now=cfg.now,sleep=cfg.sleep,legacyHistory=function() return {} end})
 local service=Service.new({backend=cfg.backend,now=cfg.now,sleep=cfg.sleep,spawn=cfg.spawn,
  send=cfg.send,jobId=cfg.jobId,keyOf=cfg.keyOf,log=cfg.log,accountLifetimes=accounts,
  newLifeFactory={new=function(runtime:any):any return Policy.new(runtime,{work={budget=.002,maxSeconds=120}}) end},
  ownerFactory=function(config:any,emit:any):any
   local profiles,why=cfg.catalog:profiles();assert(profiles,why)
   return Owner.new(config,emit,{codec=cfg.codec,rawBackend=Raw.new(cfg.dataStore),currentFormat=Format,
    entryFactory=Entry,saveFactory=Loop,reader={work={budget=.002,maxSeconds=120}},
    pipeline={reuseCompleteOriginal=true,work={budget=.002,maxSeconds=120}},
    entryOptions={work={budget=.002,maxSeconds=120}},saveOptions={work={budget=.002,maxSeconds=120},
     progress={work={budget=.002,maxSeconds=120}}}},profiles)
  end})
 return {service=service,gate=gate,accounts=accounts}
end
return table.freeze(Composition)
