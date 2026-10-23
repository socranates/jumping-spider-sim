--!strict
-- Private schema-3 readers/preparation, not an entry/storage authority grant.
-- Initial immutable proposal and later live checkpoints have distinct shapes.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Json=require(Shared.Persistence.Json)
local SaveRest=require(Shared.Persistence.SaveRest)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Work=require(Shared.Persistence.SaveWork)
local Packet=require(script.Parent.RecoveryPacketPrototype)
local Rest={FORMAT="the-windowsill continued recovery",VERSION=1,SCHEMA=3}
local ROOT={format=true,version=true,slot=true,provenance=true,checkpoint=true,entryKind=true,save_life=true,save_retired=true}
local META={version=true,owner=true,slot=true,proposal=true,archive=true,source=true,originLife=true,originGeneration=true,originBinding=true,historyChecksum=true}
local ARCHIVE={key=true,manifest=true,observation=true,selected=true,progress=true}
local SOURCE={kind=true,schema=true,checksum=true,updatedAt=true}
local function pulse() local f=Work.pulse();if f then f() end end
local function plain(v:any):boolean return type(v)=="table" and getmetatable(v)==nil end
local function known(v:any,fields:any):boolean
 if not plain(v) then return false end
 for k in v do pulse();if not fields[k] then return false end end
 return true
end
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function name(v:any):boolean return type(v)=="string" and #v>0 and #v<=32 and string.match(v,"^[%w_-]+$")~=nil end
local function digest(v:any):boolean return type(v)=="string" and #v==16 and string.match(v,"^[%x]+$")~=nil end
local function same(a:any,b:any):boolean local x=Json.canonical(a);return x~=nil and x==Json.canonical(b) end
local function freeze(v:any)
 if type(v)~="table" then return end
 for _,x in v do pulse();freeze(x) end
 if not table.isfrozen(v) then table.freeze(v) end
end
local function metadata(p:any,slot:string):string?
 if not known(p,META) or p.version~=1 or not name(p.owner) or p.slot~=slot or not table.find(Rules.MODES,slot)
  or p.proposal~="M1_"..p.owner.."_"..slot or p.originLife~=nil and not SaveRest.validLife(p.originLife)
  or not finite(p.originGeneration) or p.originGeneration<0 or p.originGeneration>1e6 or p.originGeneration%1~=0
  or not digest(p.historyChecksum) then return "invalid recovery provenance" end
 if not known(p.archive,ARCHIVE) or p.archive.key~="A1_"..p.owner.."_index" or not digest(p.archive.manifest)
  or not digest(p.archive.selected) or not digest(p.archive.progress) or type(p.archive.observation)~="string"
  or #p.archive.observation<1 or #p.archive.observation>256 then return "invalid recovery archive reference" end
 if not known(p.source,SOURCE) or p.source.kind~="primary" and p.source.kind~="backup" or not finite(p.source.schema)
  or p.source.schema<1 or p.source.schema>SaveRest.SCHEMA or p.source.schema%1~=0 or not digest(p.source.checksum)
  or not finite(p.source.updatedAt) then return "invalid recovery source reference" end
 local archive="A1_"..p.owner;local token=p.originLife or ""
 local key=`{#archive}:{archive}:{slot}:{#token}:{token}:{p.originGeneration}`
 if p.originBinding~=key then return "original recovery binding differs" end
 return nil
end
-- Same outer record/slot bounds as SaveRest.check, with one authoritative
-- Checkpoint decode reused for history/scene checks rather than decoding twice.
local function checkpoint(slot:string,record:any,context:any):(any?,string?)
 if not plain(record) or record.save_retired~=nil or record.save_life~=nil and not SaveRest.validLife(record.save_life) then return nil,"invalid current checkpoint identity" end
 local bound=SaveRest.bounded(record,Rules.MAX_REST_NODES,Rules.MAX_DEPTH);if bound then return nil,bound end
 local text=Json.canonical(record);if not text or #text>Rules.MAX_REST_CHARS then return nil,"current checkpoint exceeds character budget" end
 local rules=record.life_rules
 if not plain(rules) or rules.mode~=(if slot=="free" then "free" else "main") or slot=="easy" and rules.rules~="gentle" then return nil,"current checkpoint slot/rules differ" end
 local called,problems,decoded=pcall(Checkpoint.check,record,context or SaveRest.stubWorld())
 if not called or not decoded then return nil,if called then table.concat(problems,";") else tostring(problems) end
 return decoded,nil
end
local function scene(life:any):string
 local stage=if life.mating then life.mating.stage else "none"
 return if stage=="hatched" then "hatching" elseif life.mate and life.mate.scene==true or stage=="courted" then "mating" else "rest"
end
function Rest.check(slot:string,p:any,context:any?):(string?,any?)
 if not table.find(Rules.MODES,slot) or not known(p,ROOT) or p.format~=Rest.FORMAT or p.version~=1 or p.slot~=slot then return "invalid continued rest header",nil end
 local bound=SaveRest.bounded(p,Rules.MAX_REST_NODES+512,Rules.MAX_DEPTH+4);if bound then return bound,nil end
 local why=metadata(p.provenance,slot);if why then return why,nil end
 if p.save_retired==true then
  if p.checkpoint~=nil or p.entryKind~=nil or not SaveRest.validLife(p.save_life) then return "invalid provenance retirement marker",nil end
  return nil,{retired=true,gameplayAuthorized=false}
 elseif p.save_retired~=nil then return "invalid retirement flag",nil end
 local decoded,errorText=checkpoint(slot,p.checkpoint,context);if not decoded then return errorText,nil end
 local life=decoded.roots.life;local history=life.recoveryHistory
 if life.lifeOver~=false then return "ended life requires an explicit retired record",nil end
 if p.save_life~=p.checkpoint.save_life or p.save_life~=p.provenance.originLife then return "continued life token differs",nil end
 if (life.generation or 0)<p.provenance.originGeneration then return "generation predates original import",nil end
 if not known(history,{version=true,archive=true,origin=true,record=true,entryKind=true}) or history.version~=1
  or history.archive~="A1_"..p.provenance.owner or not plain(history.origin)
  or history.origin.save_life~=p.provenance.originLife then return "checkpoint recovery history differs",nil end
 local text=Json.canonical(history)
 if not text or Json.checksum(text)~=p.provenance.historyChecksum then return "checkpoint history checksum differs",nil end
 if p.entryKind~=scene(life) then return "current recovery entry differs",nil end
 return nil,{checkpoint=p.checkpoint,decoded=decoded,entryKind=p.entryKind,provenance=p.provenance,gameplayAuthorized=false}
end
function Rest.spec(slot:string,context:any?):any
 assert(table.find(Rules.MODES,slot),"invalid schema3 rest slot")
 local initial=Packet.spec(slot,context)
 return {kind=initial.kind,current=Rest.SCHEMA,migrations=initial.migrations,validate=function(p:any):(any,any)
  if plain(p) and p.format==Rest.FORMAT then
   local why=Rest.check(slot,p,context);return if why then {why} else {},if why then nil else p
  end
  -- An ordinary payload cannot smuggle recovered history into a schema-2 shape.
  if plain(p) and p.format~=Packet.FORMAT and not SaveRest.isRetired(p) then
   local d,why=checkpoint(slot,p,context)
   if not d then return {why or "ordinary checkpoint invalid"},nil end
   if d.roots.life.recoveryHistory~=nil then return {"recovered checkpoint requires schema3 provenance wrapper"},nil end
   return {},p
  end
  return initial.validate(p)
 end}
end
function Rest.fromProposal(anchor:any,codec:any,context:any):(any?,string?)
 local p,why=Packet.open(anchor,codec,context);if not p then return nil,why end
 local decoded,errorText=checkpoint(p.slot,p.checkpoint,context);if not decoded then return nil,errorText end
 local text=Json.canonical(decoded.roots.life.recoveryHistory);if not text then return nil,"original recovery history is not storable" end
 local ref={version=1,owner=p.owner,slot=p.slot,proposal=p.id,archive=Json.copy(p.archive),source=Json.copy(p.source),
  originLife=p.save_life,originGeneration=p.binding.generation,originBinding=p.binding.key,historyChecksum=Json.checksum(text)}
 local out={format=Rest.FORMAT,version=1,slot=p.slot,provenance=ref,checkpoint=Json.copy(p.checkpoint),entryKind=p.entryKind,save_life=p.save_life}
 local problem=Rest.check(p.slot,out,context);if problem then return nil,problem end
 freeze(out);return out,nil
end
function Rest.advance(prior:any,record:any,context:any):(any?,string?)
 if not plain(prior) or prior.format~=Rest.FORMAT then return nil,"continued recovery source required" end
 local why=Rest.check(prior.slot,prior,context);if why then return nil,why end
 if prior.save_retired then return nil,"retired recovery cannot become active by advancing" end
 local decoded,errorText=checkpoint(prior.slot,record,context);if not decoded then return nil,errorText end
 local out={format=Rest.FORMAT,version=1,slot=prior.slot,provenance=Json.copy(prior.provenance),checkpoint=Json.copy(record),entryKind=scene(decoded.roots.life),save_life=record.save_life}
 local problem=Rest.check(prior.slot,out,context);if problem then return nil,problem end
 freeze(out);return out,nil
end
function Rest.retire(prior:any,newLifeToken:string,context:any):(any?,string?)
 if not plain(prior) or prior.format~=Rest.FORMAT then return nil,"continued recovery source required" end
 local why=Rest.check(prior.slot,prior,context);if why then return nil,why end
 local out={format=Rest.FORMAT,version=1,slot=prior.slot,provenance=Json.copy(prior.provenance),save_retired=true,save_life=newLifeToken}
 local problem=Rest.check(prior.slot,out,context);if problem then return nil,problem end
 freeze(out);return out,nil
end
function Rest.matchesProposal(p:any,anchor:any,codec:any,context:any):boolean
 local expected=Rest.fromProposal(anchor,codec,context)
 return expected~=nil and Rest.check(expected.slot,p,context)==nil and same(p.provenance,expected.provenance)
end
return table.freeze(Rest)
