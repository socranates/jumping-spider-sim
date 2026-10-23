--!strict
-- Private archive preparation only. Inputs must come from raw server-owned reads,
-- before RestCompression.decode/SaveEnvelope.open. No storage, restore or authority
-- grant occurs here. A future publisher must preserve the source until durable
-- archive acknowledgement and recheck the observed source/lease/life identities.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Json=require(Shared.Persistence.Json)
local Work=require(Shared.Persistence.SaveWork)
local Archive={}
Archive.FORMAT="the-windowsill recovery archive"
Archive.VERSION=1
Archive.SLOTS=table.freeze({"progress","main","free","easy"})
Archive.MAX_ENTRY_CHARS=3900000 -- leaves room below the4MiB DataStore value limit
Archive.MAX_TOTAL_CHARS=12000000
Archive.MAX_NODES=600000
Archive.MAX_DEPTH=24

local function finite(v:any):boolean
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function name(v:any):boolean
 return type(v)=="string" and #v>0 and #v<=32 and string.match(v,"^[%w_-]+$")~=nil
end
local function limits(options:any):any
 local out={}
 for k,cap in {entry=Archive.MAX_ENTRY_CHARS,total=Archive.MAX_TOTAL_CHARS,nodes=Archive.MAX_NODES,depth=Archive.MAX_DEPTH} do
  local value=if options then options[k] else nil
  if value==nil then value=cap end
  assert(finite(value) and value>=1 and value%1==0 and value<=cap,"invalid archive bound "..k)
  out[k]=value
 end
 return out
end

-- Return owned frozen values, refusing non-DataStore graphs before encoding.
-- count is shared across all four entries, so splitting a large value cannot
-- bypass the aggregate object budget. No input or external map is changed.
local function owned(value:any,budget:any,state:any,seen:any,depth:number,pulse:any):any
 if pulse then pulse() end
 state.nodes+=1;assert(state.nodes<=budget.nodes,"archive node limit")
 assert(depth<=budget.depth,"archive depth limit")
 local kind=type(value)
 if kind=="nil" or kind=="boolean" then return value end
 if kind=="number" then assert(finite(value),"archive non-finite number");return value end
 if kind=="string" then assert(#value<=budget.entry,"archive string limit");return value end
 assert(kind=="table" and getmetatable(value)==nil,"archive value is not storable")
 assert(not seen[value],"archive repeated or cyclic table");seen[value]=true
 local copy={}
 for key,child in value do
  assert(type(key)=="string" or (finite(key) and key>=1 and key%1==0),"archive invalid table key")
  copy[owned(key,budget,state,seen,depth+1,pulse)]=owned(child,budget,state,seen,depth+1,pulse)
 end
 return table.freeze(copy)
end

-- A fixed four-slot source set; unavailable is different from physically missing.
-- sources[slot]={loaded=true,value=rawValue?}. Unknown fields are refused rather
-- than silently omitted. rawValue itself stays opaque, including unknown schemas.
function Archive.prepare(owner:any,stamp:any,sources:any,options:any?):(any?,string?)
 local ok,result=pcall(function():any
  assert(name(owner),"invalid archive owner")
  assert(type(stamp)=="string" and #stamp>0 and #stamp<=160,"invalid archive observation")
  assert(type(sources)=="table" and getmetatable(sources)==nil,"invalid archive sources")
  local known={};for _,slot in Archive.SLOTS do known[slot]=true end
  for slot in sources do assert(known[slot],"unknown archive slot") end
  local budget=limits(options);local state={nodes=0,total=0};local entries={};local descriptors={}
  local pulse=Work.pulse()
  for _,slot in Archive.SLOTS do
   if pulse then pulse() end
   local source=sources[slot]
   assert(type(source)=="table" and getmetatable(source)==nil and source.loaded==true,"archive source unavailable: "..slot)
   for key in source do assert(key=="loaded" or key=="value","unknown archive source field") end
   local raw=owned(source.value,budget,state,{},0,pulse)
   local core={slot=slot,present=source.value~=nil,raw=raw}
   local text,why=Json.canonical(core);assert(text,why)
   local checksum=Json.checksum(text)
   local entry=table.freeze({format=Archive.FORMAT,version=Archive.VERSION,owner=owner,slot=slot,
    present=core.present,raw=raw,checksum=checksum})
   local encoded,errorText=Json.canonical(entry);assert(encoded,errorText)
   assert(#encoded<=budget.entry,"archive entry character limit: "..slot)
   state.total+=#encoded;assert(state.total<=budget.total,"archive total character limit")
   entries[slot]=entry
   table.insert(descriptors,table.freeze({slot=slot,key="A1_"..owner.."_"..slot,
    present=core.present,checksum=checksum,characters=#encoded}))
  end
  local indexCore={format=Archive.FORMAT,version=Archive.VERSION,owner=owner,observation=stamp,entries=table.freeze(descriptors)}
  local text,why=Json.canonical(indexCore);assert(text,why)
  -- Count the manifest too; the declared aggregate cap includes every artifact.
  state.total+=#text+64;assert(state.total<=budget.total,"archive manifest character limit")
  local index=table.freeze({format=indexCore.format,version=indexCore.version,owner=owner,observation=stamp,
   entries=indexCore.entries,checksum=Json.checksum(text)})
  return table.freeze({index=index,entries=table.freeze(entries),characters=state.total,nodes=state.nodes})
 end)
 if not ok then return nil,tostring(result) end
 return result,nil
end

local function sameFields(value:any,expected:any,skip:any?):boolean
 if type(value)~="table" or getmetatable(value)~=nil then return false end
 for k in value do if not (skip and skip[k]) and expected[k]==nil then return false end end
 for k,v in expected do if not (skip and skip[k]) and value[k]~=v then return false end end
 return true
end
-- Validation of a private plan before storage. Rebuild it from its opaque raw
-- values under the same caps; compare every metadata field, not just checksums.
-- This is corruption detection, not authentication or a durable readback proof.
function Archive.check(plan:any,options:any?):(boolean,string?)
 if type(plan)~="table" or getmetatable(plan)~=nil then return false,"invalid archive plan" end
 if type(plan.index)~="table" or getmetatable(plan.index)~=nil or type(plan.entries)~="table" or getmetatable(plan.entries)~=nil then return false,"invalid archive plan" end
 if plan.index.format~=Archive.FORMAT or plan.index.version~=Archive.VERSION then return false,"unsupported archive format" end
 local sources={}
 for _,slot in Archive.SLOTS do
  local entry=plan.entries[slot]
  if type(entry)~="table" or getmetatable(entry)~=nil then return false,"missing archive entry" end
  if entry.present~=true and entry.present~=false then return false,"invalid archive presence" end
  if (entry.raw~=nil)~=entry.present then return false,"archive presence disagrees" end
  sources[slot]={loaded=true,value=entry.raw}
 end
 local rebuilt,why=Archive.prepare(plan.index.owner,plan.index.observation,sources,options)
 if not rebuilt then return false,why end
 local ok=sameFields(plan,rebuilt,{index=true,entries=true})
  and sameFields(plan.index,rebuilt.index,{entries=true})
  and sameFields(plan.entries,rebuilt.entries,{progress=true,main=true,free=true,easy=true})
 if type(plan.index.entries)~="table" or getmetatable(plan.index.entries)~=nil then return false,"invalid archive index" end
 for k in plan.index.entries do if type(k)~="number" or k%1~=0 or k<1 or k>4 then return false,"invalid archive descriptor list" end end
 for i,slot in Archive.SLOTS do
  ok=ok and sameFields(plan.entries[slot],rebuilt.entries[slot],{raw=true})
   and sameFields(plan.index.entries[i],rebuilt.index.entries[i])
 end
 return ok,if ok then nil else "archive metadata or contents changed"
end
return table.freeze(Archive)
