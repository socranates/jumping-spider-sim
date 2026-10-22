--!strict
-- Lossless transport for plain checkpoint records. No live objects, RNG draws or geometry regeneration.
-- Strings are negative dictionary indices; numeric values are positive indices into an exact-number dictionary.
-- Lists use {0, values...}; maps use {1, dictionary-key, value, ...}, keys sorted for deterministic output.
-- This codec is not connected to online saves until size, expansion and compatibility gates pass.
local RestCodec = {}
RestCodec.FORMAT = "windowsill-rest-dictionary-1"
RestCodec.MAX_NODES = 600000
RestCodec.MAX_DEPTH = 24
RestCodec.MAX_STRINGS = 65536
RestCodec.MAX_STRING_BYTES = 3000000
RestCodec.MAX_EXPANDED_STRING_BYTES = 8000000

local function finite(v: any): boolean
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function plain(v: any): boolean
 return type(v)=="table" and getmetatable(v)==nil
end
local function listSize(v: any): number?
 if not plain(v) then return nil end
 local n=0
 for k in v do
  if not finite(k) or k<1 or k~=math.floor(k) then return nil end
  n+=1
  if n>RestCodec.MAX_NODES*2+1 then return nil end
 end
 for i=1,n do if v[i]==nil then return nil end end
 return n
end

function RestCodec.encode(record: any): (any?, string?)
 local strings: {string}={}
 local ids: {[string]:number}={}
 local numbers: {number}={}
 local numberIds: {[number]:number}={}
 local seen: {[any]:boolean}={}
 local nodes,bytes,expanded=0,0,0
 local problem: string?=nil
 local function intern(s: string): number
  expanded+=#s
  if expanded>RestCodec.MAX_EXPANDED_STRING_BYTES then problem="expanded strings exceed limit";return 1 end
  local prior=ids[s]
  if prior then return prior end
  bytes+=#s
  if bytes>RestCodec.MAX_STRING_BYTES or #strings>=RestCodec.MAX_STRINGS then problem="string dictionary exceeds limit";return 1 end
  table.insert(strings,s);ids[s]=#strings
  return #strings
 end
 local function value(v: any,depth: number): any
  if problem then return nil end
  nodes+=1
  if nodes>RestCodec.MAX_NODES then problem="too many expanded values";return nil end
  if type(v)=="string" then return -intern(v) end
  if type(v)=="boolean" then return v end
  if finite(v) then
   local id=numberIds[v]
   if not id then table.insert(numbers,v);id=#numbers;numberIds[v]=id end
   return id
  end
  if not plain(v) then problem="not a plain JSON value";return nil end
  if depth>RestCodec.MAX_DEPTH then problem="nested too deeply";return nil end
  if seen[v] then problem="a table met twice";return nil end
  seen[v]=true
  local n=listSize(v)
  local out: {any}={if n~=nil then 0 else 1}
  if n~=nil then
   for i=1,n do table.insert(out,value(v[i],depth+1)) end
  else
   local keys: {string}={}
   for k in v do
    if type(k)~="string" then problem="mixed or sparse table";return nil end
    table.insert(keys,k)
   end
   table.sort(keys)
   for _,k in keys do table.insert(out,intern(k));table.insert(out,value(v[k],depth+1)) end
  end
  return out
 end
 local root=value(record,1)
 if problem then return nil,problem end
 return {format=RestCodec.FORMAT,strings=strings,numbers=numbers,root=root},nil
end

function RestCodec.decode(packed: any): (any?, string?)
 if not plain(packed) or packed.format~=RestCodec.FORMAT then return nil,"unknown compact rest format" end
 local fields=0
 for k in packed do
  fields+=1
  if k~="format" and k~="strings" and k~="numbers" and k~="root" then return nil,"unknown compact rest field" end
 end
 if fields~=4 then return nil,"incomplete compact rest" end
 local count=listSize(packed.strings)
 if count==nil or count>RestCodec.MAX_STRINGS then return nil,"invalid string dictionary" end
 local numberCount=listSize(packed.numbers)
 if numberCount==nil or numberCount>RestCodec.MAX_NODES then return nil,"invalid number dictionary" end
 local numberSet: {[number]:boolean}={}
 for _,n in packed.numbers do
  if not finite(n) or numberSet[n] then return nil,"invalid or repeated dictionary number" end
  numberSet[n]=true
 end
 local unique: {[string]:boolean}={}
 local bytes=0
 for _,s in packed.strings do
  if type(s)~="string" or unique[s] then return nil,"invalid or repeated dictionary string" end
  unique[s]=true;bytes+=#s
  if bytes>RestCodec.MAX_STRING_BYTES then return nil,"string dictionary exceeds limit" end
 end
 local nodes,expanded=0,0
 local seen: {[any]:boolean}={}
 local problem: string?=nil
 local function value(v: any,depth: number): any
  if problem then return nil end
  nodes+=1
  if nodes>RestCodec.MAX_NODES then problem="too many expanded values";return nil end
  if type(v)=="boolean" then return v end
  if finite(v) then
   if v>=0 then
    if v<1 or v>numberCount or v~=math.floor(v) then problem="invalid number reference";return nil end
    return packed.numbers[v]
   end
   if v~=math.floor(v) or -v>count then problem="invalid dictionary reference";return nil end
   local s=packed.strings[-v]
   expanded+=#s
   if expanded>RestCodec.MAX_EXPANDED_STRING_BYTES then problem="expanded strings exceed limit";return nil end
   return s
  end
  if not plain(v) or seen[v] then problem="invalid or repeated compact value";return nil end
  seen[v]=true
  local n=listSize(v)
  if n==nil or n==0 then problem="invalid compact tuple";return nil end
  if depth>RestCodec.MAX_DEPTH then problem="nested too deeply";return nil end
  local out: any={}
  if v[1]==0 then
   for i=2,n do out[i-1]=value(v[i],depth+1) end
  elseif v[1]==1 and n%2==1 then
   local keys: {[number]:boolean}={}
   for i=2,n,2 do
    local k=v[i]
    if not finite(k) or k<1 or k>count or k~=math.floor(k) or keys[k] then problem="invalid or duplicate map key";return nil end
    local key=packed.strings[k]
    expanded+=#key
    if expanded>RestCodec.MAX_EXPANDED_STRING_BYTES then problem="expanded strings exceed limit";return nil end
    keys[k]=true;out[key]=value(v[i+1],depth+1)
   end
  else problem="unknown compact tuple tag";return nil end
  return out
 end
 local root=value(packed.root,1)
 if problem then return nil,problem end
 return root,nil
end

return RestCodec
