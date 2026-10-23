--!strict
-- Private client entry preparation. Caller pauses simulation until the matching
-- server decision, and supplies its actual selection/epoch guard.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local SaveRest=require(Shared.Persistence.SaveRest)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Client={}
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do if not fields[k] then return false end end;return true
end
local function token(v:any):boolean return type(v)=="string" and #v>0 and #v<=Rules.MAX_LIFE_TOKEN_CHARS end
local function integer(v:any):boolean return type(v)=="number" and v==v and v%1==0 and v>=1 and v<=Rules.MAX_LIFE_SERIAL end
-- Stable ownership of offer is required until preparation returns, as with the
-- existing Checkpoint.prepare API. A private owned record is retained thereafter.
function Client.prepare(offer:any,world:any,stillCurrent:any):(any?,string?)
 if type(stillCurrent)~="function" or not stillCurrent() or not known(offer,{v=true,id=true,epoch=true,mode=true,serial=true,revision=true,entryKind=true,life=true,identity=true,checkpoint=true})
  or offer.v~=1 or not token(offer.id) or not token(offer.epoch) or not table.find(Rules.MODES,offer.mode) or not integer(offer.serial) or not integer(offer.revision)
  or not known(offer.identity,{checksum=true,updatedAt=true}) or type(offer.identity.checksum)~="string" or #offer.identity.checksum~=16
  or type(offer.identity.updatedAt)~="number" or offer.identity.updatedAt~=offer.identity.updatedAt or math.abs(offer.identity.updatedAt)==math.huge
  or offer.life~=nil and not SaveRest.validLife(offer.life) then return nil,"invalid/current entry offer required" end
 if type(offer.checkpoint)~="table" or SaveRest.bounded(offer.checkpoint,Rules.MAX_REST_NODES,Rules.MAX_DEPTH) then return nil,"entry checkpoint exceeds bound" end
 local record=Json.copy(offer.checkpoint)
 local text=Json.canonical(record);local rules=record.life_rules
 if not text or #text>Rules.MAX_REST_CHARS or record.save_retired~=nil or record.save_life~=offer.life
  or type(rules)~="table" or rules.mode~=(if offer.mode=="free" then "free" else "main") or offer.mode=="easy" and rules.rules~="gentle" then return nil,"entry checkpoint slot/life differs" end
 local problems,decoded=Checkpoint.check(record,world);if not decoded then return nil,table.concat(problems,";") end
 local life=decoded.roots.life;local stage=if life.mating then life.mating.stage else "none"
 local kind=if stage=="hatched" then "hatching" elseif life.mate and life.mate.scene or stage=="courted" then "mating" else "rest"
 if life.lifeOver~=false or kind~=offer.entryKind then return nil,"ended/different entry scene refused" end
 local commit,issues=Checkpoint.prepare(record,world);if not commit then return nil,table.concat(issues,";") end
 if not stillCurrent() then return nil,"selection changed during entry preparation" end
 local receipt={kind="recovery_applied",v=1,id=offer.id,epoch=offer.epoch,mode=offer.mode,serial=offer.serial,revision=offer.revision,identity=Json.copy(offer.identity)}
 local used=false
 return function():(any?,string?)
  if used or Work.pulse() or not stillCurrent() then return nil,"prepared entry no longer current" end
  used=true
  local okay,bad=commit();if not okay then return nil,table.concat(bad,";") end
  if not stillCurrent() then return nil,"selection changed during entry application" end
  return Json.copy(receipt),nil
 end,nil
end
return table.freeze(Client)
