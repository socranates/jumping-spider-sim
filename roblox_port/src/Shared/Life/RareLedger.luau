--!strict
-- Player progress, outside rests. High-water marks prevent a rewound rest
-- creating a second visit; restoring a rest DURING a visit restores that animal.
local Ledger = {}
Ledger.LIMIT = 64
Ledger.MAX_SERIAL = 1000000000
export type Record = { serial: number, claimed: { [string]: number }, once: { [string]: boolean }, blocked: boolean? }
function Ledger.new(): Record return {serial=0,claimed={},once={}} end
local function whole(x: any): boolean
 return type(x)=="number" and x==x and x>=0 and x<=Ledger.MAX_SERIAL and x%1==0
end
function Ledger.clean(raw: any): Record?
 if type(raw)~="table" or not whole(raw.serial) or type(raw.claimed)~="table" or type(raw.once)~="table" then return nil end
 local out=Ledger.new();out.serial=raw.serial
 if raw.blocked~=nil and type(raw.blocked)~="boolean" then return nil end
 if raw.blocked==true then out.blocked=true end
 for _,field in {"claimed","once"} do
  local count=0
  for id,value in raw[field] do
   count+=1
   if count>Ledger.LIMIT or type(id)~="string" or #id<1 or #id>64 or not string.match(id,"^[%w_]+$") then return nil end
   if field=="claimed" then
    if not whole(value) or value>raw.serial then return nil end
    out.claimed[id]=value
   else
    if value~=true then return nil end
    out.once[id]=true
   end
  end
 end
 return out
end
function Ledger.merge(a: Record?,b: Record?): Record
 local out=Ledger.new()
 for _,record in {a or Ledger.new(),b or Ledger.new()} do
  out.serial=math.max(out.serial,record.serial)
  if record.blocked then out.blocked=true end
  for id,n in record.claimed do out.claimed[id]=math.max(out.claimed[id] or 0,n) end
  for id in record.once do out.once[id]=true end
 end
 -- Retain a bounded record even when two individually valid maps overflow on
 -- merge. Fail closed: a discarded claim must never make an animal repeat.
 for _,field in {"claimed","once"} do
  local map=(out :: any)[field];local keys={}
  for id in map do table.insert(keys,id) end
  table.sort(keys)
  for i=Ledger.LIMIT+1,#keys do map[keys[i]]=nil;out.blocked=true end
 end
 return out
end
function Ledger.signature(record: Record): string
 local sum,count=0,0
 for _,n in record.claimed do sum+=n end
 for _ in record.once do count+=1 end
 return `{record.serial}:{sum}:{count}:{record.blocked==true}`
end
function Ledger.same(a: Record?,b: Record?): boolean
 local x,y=a or Ledger.new(),b or Ledger.new()
 if x.serial~=y.serial or (x.blocked==true)~=(y.blocked==true) then return false end
 for _,field in {"claimed","once"} do
  for id,value in (x :: any)[field] do if (y :: any)[field][id]~=value then return false end end
  for id,value in (y :: any)[field] do if (x :: any)[field][id]~=value then return false end end
 end
 return true
end
function Ledger.beginLife(record: Record): number
 assert(record.serial<Ledger.MAX_SERIAL,"rare life counter exhausted")
 record.serial+=1;return record.serial
end
return Ledger
