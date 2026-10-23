--!strict
-- Private schema/immutable proposal only. No store calls, source replacement,
-- lease, receipt, or playable migration permission is granted here.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Progress=require(Shared.Persistence.SaveProgress)
local Checkpoint=require(Shared.Persistence.Checkpoint)
local Json=require(Shared.Persistence.Json)
local Compression=require(script.Parent.RestCompression)
local Archive=require(Shared.Persistence.RecoveryArchivePrototype)
local Life=require(Shared.Persistence.RecoveryLifePrototype)
local Projection=require(Shared.Persistence.RecoveryProgressPrototype)
local Destination=require(Shared.Persistence.RecoveryDestinationPrototype)
local Packet={}
Packet.FORMAT="the-windowsill recovered rest"
Packet.ANCHOR="the-windowsill import proposal"
Packet.REST_SCHEMA=3
-- Proposed schema budget, not a production constant change. The old declared
-- 16K progress character budget is not enforced by current SaveProgress and can
-- be exceeded by a lossless union of individually supported page/rare maps.
Packet.MAX_PROGRESS_CHARS=32768
local ROOT={format=true,version=true,id=true,owner=true,slot=true,archive=true,source=true,binding=true,
 checkpoint=true,progress=true,progressTime=true,entryKind=true,save_life=true}
local function plain(v:any):boolean return type(v)=="table" and getmetatable(v)==nil end
local function known(v:any,fields:any):boolean
 if not plain(v) then return false end
 for k in v do if not fields[k] then return false end end
 return true
end
local function finite(v:any):boolean return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function name(v:any):boolean return type(v)=="string" and #v>0 and #v<=32 and string.match(v,"^[%w_-]+$")~=nil end
local function digest(v:any):boolean return type(v)=="string" and #v==16 and string.match(v,"^[%x]+$")~=nil end
local function id(owner:string,slot:string):string return "M1_"..owner.."_"..slot end
local function freeze(t:any)
 if type(t)~="table" then return end
 for _,v in t do freeze(v) end
 if not table.isfrozen(t) then table.freeze(t) end
end
local function same(a:any,b:any):boolean
 local x=Json.canonical(a);local y=Json.canonical(b);return x~=nil and x==y
end
function Packet.check(slot:string,p:any,context:any?):string?
 if not known(p,ROOT) or p.format~=Packet.FORMAT or p.version~=1 or not name(p.owner) or p.slot~=slot
  or not table.find(Rules.MODES,slot) or p.id~=id(p.owner,slot) then return "invalid recovered rest header" end
 if SaveRest.bounded(p,Rules.MAX_REST_NODES+Rules.MAX_PROGRESS_NODES+512,Rules.MAX_DEPTH+4) then return "recovered rest exceeds node/depth bound" end
 if not known(p.archive,{key=true,manifest=true,observation=true,selected=true,progress=true}) or p.archive.key~="A1_"..p.owner.."_index"
  or not digest(p.archive.manifest) or not digest(p.archive.selected) or not digest(p.archive.progress)
  or type(p.archive.observation)~="string" or #p.archive.observation<1 or #p.archive.observation>256 then return "invalid archive reference" end
 if not known(p.source,{kind=true,schema=true,checksum=true,updatedAt=true}) or (p.source.kind~="primary" and p.source.kind~="backup")
  or not finite(p.source.schema) or p.source.schema<1 or p.source.schema>SaveRest.SCHEMA or p.source.schema%1~=0
  or not digest(p.source.checksum) or not finite(p.source.updatedAt) then return "invalid original rest identity" end
 local progressText=Json.canonical(p.progress)
 if not progressText or #progressText>Packet.MAX_PROGRESS_CHARS or SaveRest.bounded(p.progress,Rules.MAX_PROGRESS_NODES,Rules.MAX_PROGRESS_DEPTH) then return "recovered progress exceeds bound" end
 local problems,clean=Progress.sanitize(p.progress)
 if not clean or #problems>0 or not same(clean,p.progress) then return "recovered progress would change on validation" end
 if not finite(p.progressTime) then return "invalid recovered choice timestamp" end
 local bad=SaveRest.check(slot,p.checkpoint,context);if #bad>0 then return table.concat(bad,";") end
 local _problems,d=Checkpoint.check(p.checkpoint,context or SaveRest.stubWorld());if not d then return "invalid recovered checkpoint" end
 local l=d.roots.life;local h=l.recoveryHistory
 if l.lifeOver or not plain(h) or h.archive~="A1_"..p.owner or p.save_life~=p.checkpoint.save_life then return "recovered life identity differs" end
 if not known(p.binding,{key=true,serial=true,generation=true,born=true}) or not plain(h.origin) then return "invalid recovered binding" end
 local lifeToken=h.origin.save_life or "";local archive="A1_"..p.owner;local generation=l.generation or 0
 local key=`{#archive}:{archive}:{slot}:{#lifeToken}:{lifeToken}:{generation}`
 if p.binding.key~=key or p.binding.serial~=l.rareSerial or p.binding.generation~=generation or p.binding.born~=l.rareBorn
  or l.rareGeneration~=generation or not p.progress.rare or p.progress.rare.serial<l.rareSerial then return "rare identity not covered by global proposal" end
 if l.rareVisit and (p.progress.rare.claimed[l.rareVisit.id] or 0)<l.rareVisit.serial then return "recorded rare claim missing" end
 local stage=if l.mating then l.mating.stage else "none"
 local entry=if stage=="hatched" then "hatching" elseif l.mate and l.mate.scene==true or stage=="courted" then "mating" else "rest"
 if p.entryKind~=entry or h.entryKind~=entry then return "recovery entry differs" end
 local text=Json.canonical(p)
 if not text or #text>Compression.MAX_CORE_BYTES-Compression.HEADER_RESERVE then return "recovered rest exceeds core budget" end
 return nil
end
function Packet.spec(slot:string,context:any?):any
 assert(table.find(Rules.MODES,slot),"invalid recovered slot")
 local prior=SaveRest.SPECS[slot]
 return {kind=prior.kind,current=Packet.REST_SCHEMA,migrations={[1]=function(p:any):any return p end,[2]=function(p:any):any return p end},
  validate=function(p:any):(any,any)
   if plain(p) and p.format==Packet.FORMAT then local why=Packet.check(slot,p,context);return if why then {why} else {},if why then nil else p end
   return prior.validate(p)
  end}
end
local function anchorCore(a:any):any
 return {format=a.format,version=a.version,id=a.id,owner=a.owner,slot=a.slot,archive=a.archive,source=a.source,target=a.target}
end
function Packet.open(anchor:any,codec:any,context:any?):(any?,string?)
 if not known(anchor,{format=true,version=true,id=true,owner=true,slot=true,archive=true,source=true,target=true,checksum=true})
  or anchor.format~=Packet.ANCHOR or anchor.version~=1 or not name(anchor.owner) or not table.find(Rules.MODES,anchor.slot)
  or anchor.id~=id(anchor.owner,anchor.slot) or not digest(anchor.archive) or not digest(anchor.source) then return nil,"invalid immutable proposal" end
 local text=Json.canonical(anchorCore(anchor));if not text or #text+64>Rules.MAX_VALUE_CHARS or Json.checksum(text)~=anchor.checksum then return nil,"proposal checksum/budget differs" end
 if not plain(anchor.target) or anchor.target.encoding~=Compression.ENCODING or anchor.target.schema~=2 or anchor.target.innerSchema~=Packet.REST_SCHEMA then return nil,"unsupported proposal transport" end
 local ok,value=pcall(codec.decode,codec,anchor.target)
 if not ok then return nil,tostring(value) end
 local opened=Envelope.open(Packet.spec(anchor.slot,context),value,false)
 if opened.status~="ok" or not opened.payload or opened.payload.format~=Packet.FORMAT then return nil,"proposal payload is "..opened.status end
 local p=opened.payload
 if p.owner~=anchor.owner or p.id~=anchor.id or p.archive.manifest~=anchor.archive or p.archive.selected~=anchor.source then return nil,"proposal/payload scope differs" end
 return p,nil
end
function Packet.prepare(owner:string,slot:string,archive:any,incoming:any,incomingTime:number,template:any,context:any,codec:any,kind:string,updatedAt:number):(any?,string?)
 if not name(owner) or not table.find(Rules.MODES,slot) or (kind~="primary" and kind~="backup") or not finite(updatedAt) then return nil,"invalid proposal scope/time" end
 local valid,why=Archive.check(archive)
 if not valid or archive.index.owner~=owner then return nil,why or "archive owner differs" end
 local raw=archive.entries[slot].raw
 local ok,value=pcall(codec.decode,codec,raw,true);if not ok then return nil,tostring(value) end
 -- Header/checksum validation precedes the dedicated recorded-world validation.
 local header={kind=SaveRest.SPECS[slot].kind,current=SaveRest.SCHEMA,migrations={[1]=function(p:any):any return p end},validate=function(p:any):(any,any) return {},p end}
 local opened=Envelope.open(header,value)
 local selected=if kind=="backup" then opened.backup else opened
 local core=if kind=="backup" and plain(value) then value.backup else value
 if not selected or (selected.status~="ok" and selected.status~="migrated") or not plain(core) then return nil,"selected original rest unavailable" end
 local life,errorText=Life.prepare(selected.payload,context,"A1_"..owner);if not life then return nil,errorText end
 local progress,progressError=Projection.prepare(archive.entries.progress.raw,incoming,incomingTime,life,slot);if not progress then return nil,progressError end
 local destination,destinationError=Destination.prepare(progress.life,template,context,slot);if not destination then return nil,destinationError end
 local p={format=Packet.FORMAT,version=1,id=id(owner,slot),owner=owner,slot=slot,
  archive={key="A1_"..owner.."_index",manifest=archive.index.checksum,observation=archive.index.observation,
   selected=archive.entries[slot].checksum,progress=archive.entries.progress.checksum},
  source={kind=kind,schema=core.schema,checksum=core.checksum,updatedAt=selected.updatedAt},binding=progress.binding,
  checkpoint=destination.checkpoint,progress=progress.progress,progressTime=progress.progressTime,
  entryKind=destination.entryKind,save_life=destination.checkpoint.save_life}
 local problem=Packet.check(slot,p,context);if problem then return nil,problem end
 local envelope=Envelope.make(Packet.spec(slot,context),p,updatedAt,nil)
 -- The complete old current/backup values stay in A1. This first schema-3 rest
 -- does not duplicate them inside its compressed 1.5M storage allowance.
 local encoded,stored=pcall(codec.encode,codec,envelope);if not encoded then return nil,tostring(stored) end
 local a={format=Packet.ANCHOR,version=1,id=p.id,owner=owner,slot=slot,archive=p.archive.manifest,source=p.archive.selected,target=stored}
 local text,encodingError=Json.canonical(a);if not text or #text+64>Rules.MAX_VALUE_CHARS then return nil,encodingError or "proposal exceeds stored-value budget" end
 a.checksum=Json.checksum(text)
 local roundtrip,roundtripError=Packet.open(a,codec,context)
 if not roundtrip or not same(roundtrip,p) then return nil,roundtripError or "proposal round trip changed data" end
 freeze(a);return a,nil
end
return table.freeze(Packet)
