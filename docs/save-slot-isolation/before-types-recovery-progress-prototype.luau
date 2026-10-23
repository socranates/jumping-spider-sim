--!strict
-- Private global progress projection. Pure preparation, never a lease grant,
-- global write, life allocation or destination commit.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Progress=require(Shared.Persistence.SaveProgress)
local Envelope=require(Shared.Persistence.SaveEnvelope)
local SaveRest=require(Shared.Persistence.SaveRest)
local Rules=require(Shared.Data.SaveRules)
local Settings=require(Shared.UI.SettingsModel)
local Rare=require(Shared.Life.RareLedger)
local Loop=require(Shared.Life.LifeLoop)
local Clock=require(Shared.Life.LifeClock)
local Growth=require(Shared.Life.Growth)
local Objects=require(Shared.Persistence.ObjectRecord)
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Life=require(script.Parent.RecoveryLifePrototype)
local Projection={}
local FIELDS={notebook=true,finished_main=true,appearance=true,settings=true,settings_version=true,intro_seen=true,hut_window=true,rare=true}
local function pulse() local f=Work.pulse();if f then f() end end
local function finite(n:any):boolean return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function known(v:any,fields:any):boolean
 if type(v)~="table" or getmetatable(v)~=nil then return false end
 for k in v do pulse();if not fields[k] then return false end end
 return true
end
local function normalize(raw:any,schema:number):(any?,string?)
 local fields={};for k,v in FIELDS do fields[k]=v end
 if schema==1 then fields.settings=nil;fields.settings_version=nil;fields.prefs=true end
 if not known(raw,fields) or not known(raw.notebook,{opened=true,eye_seconds=true}) then return nil,"unsupported progress/notebook fields" end
 if raw.rare~=nil and not known(raw.rare,{serial=true,claimed=true,once=true,blocked=true}) then return nil,"unsupported rare history fields" end
 local expected=Json.copy(raw)
 if schema==1 then expected.settings=expected.prefs or {};expected.settings_version=1;expected.prefs=nil end
 local settings=expected.settings or {}
 if type(settings)~="table" then return nil,"invalid settings" end
 for id,value in settings do
  pulse();local clean,problem=Settings.clean(id,value)
  if problem or clean==nil or clean~=value then return nil,"setting would be dropped or changed: "..tostring(id) end
 end
 local problems,clean=Progress.sanitize(expected)
 if not clean then return nil,table.concat(problems,";") end
 return clean,nil
end
local function capacity(a:any,b:any):boolean
 local pages,count={},0
 for _,list in {a.notebook.opened,b.notebook.opened} do
  for _,id in list do pulse();if not pages[id] then pages[id]=true;count+=1 end end
 end
 if count>Rules.MAX_PAGES then return false end
 for _,field in {"claimed","once"} do
  local seen,n={},0
  for _,ledger in {a.rare or Rare.new(),b.rare or Rare.new()} do
   for id in ledger[field] do pulse();if not seen[id] then seen[id]=true;n+=1 end end
  end
  if n>Rare.LIMIT then return false end
 end
 return true
end
local function freeze(t:any)
 if type(t)~="table" then return end
 for _,v in t do pulse();freeze(v) end
 if not table.isfrozen(t) then table.freeze(t) end
end
function Projection.prepare(raw:any,incoming:any,incomingTime:number,capsule:any,slot:string):(any?,string?)
 if not finite(incomingTime) or not table.find(Rules.MODES,slot) then return nil,"invalid progress clock/slot" end
 local boundary=SaveRest.bounded(raw,Rules.MAX_PROGRESS_NODES*2+64,Rules.MAX_DEPTH+2)
 if boundary then return nil,boundary end
 -- The immutable archive retains the entire current/backup envelopes. Projection
 -- does not silently select an older backup or default an unreadable primary.
 local opened=Envelope.open(Progress.SPEC,raw,false)
 if opened.status~="ok" and opened.status~="migrated" then return nil,"progress primary is "..opened.status end
 local sourceTime=opened.updatedAt
 if type(sourceTime)~="number" or not finite(sourceTime) then return nil,"invalid stored progress clock" end
 local base,why=normalize(raw.payload,raw.schema);if not base then return nil,why end
 if not Progress.same(base,opened.payload) then return nil,"progress migration changed unsupported data" end
 local incomingBoundary=SaveRest.bounded(incoming,Rules.MAX_PROGRESS_NODES,Rules.MAX_DEPTH)
 if incomingBoundary then return nil,incomingBoundary end
 local localProgress,localError=normalize(incoming,Progress.SCHEMA);if not localProgress then return nil,localError end
 if not capacity(base,localProgress) then return nil,"combined progress exceeds lossless history capacity" end
 local merged=Progress.merge(base,localProgress,sourceTime,incomingTime)
 local decoded,problem=Life.decode(capsule);if not decoded then return nil,problem end
 local l=decoded.life;local generation=l.generation or 0
 if (slot=="free")~=(l.mode=="free") or slot=="easy" and l.rules~="gentle" then return nil,"selected life/slot disagree" end
 if slot=="easy" and not merged.finished_main then return nil,"Easy progress prerequisite missing" end
 local ledger=merged.rare or Rare.new()
 if l.rareSerial~=nil and l.rareGeneration~=generation then return nil,"generation requires an explicit durable rare binding" end
 local serial=l.rareSerial or math.max(1,ledger.serial)
 ledger.serial=math.max(ledger.serial,serial)
 if l.rareSerial==nil then l.rareSerial=serial;l.rareGeneration=generation;l.rareBorn=l.clock.day end
 if l.rareVisit then ledger.claimed[l.rareVisit.id]=math.max(ledger.claimed[l.rareVisit.id] or 0,l.rareVisit.serial) end
 if not Rare.clean(ledger) then return nil,"rare binding exceeds lossless history capacity" end
 merged.rare=ledger
 local graph,errorText=Objects.capture({life=l},{LifeLoop=Loop,LifeClock=Clock,Growth=Growth},{["portable.needs"]=decoded.needs})
 if not graph then return nil,errorText end
 local bound={};for k,v in capsule do bound[k]=v end;bound.graph=graph
 if not Life.decode(bound) then return nil,"bound rare life is invalid" end
 local sourceLife=decoded.origin.save_life or ""
 local binding=`{#capsule.archive}:{capsule.archive}:{slot}:{#sourceLife}:{sourceLife}:{generation}`
 local out={progress=merged,life=bound,binding={key=binding,serial=serial,generation=generation,born=l.rareBorn},
  source={schema=raw.schema,checksum=raw.checksum,updatedAt=sourceTime},status="prepared-only",destinationCommitAuthorized=false}
 freeze(out);return out,nil
end
return table.freeze(Projection)
