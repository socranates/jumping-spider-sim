-- Private prototype: one fragment buffer, rather than a buffer/string per table.
-- Traversal, validation, number formatting, quoting and error paths stay the same.
function Json.canonical(v: any): (string?, string?)
 local pulse=Work.pulse()
 local seen: {[any]:boolean}={}
 local problem:string?=nil
 local trail:{any}={}
 local parts:{string}={}
 local function where():string
  local out="value"
  for _,k in trail do
   if type(k)=="number" then out..=`[{k}]` else out..=`.{k}` end
  end
  return out
 end
 local function enc(x:any)
  if pulse then pulse() end
  if problem then return end
  local t=type(x)
  if t=="string" then table.insert(parts,quote(x));return end
  if t=="boolean" then table.insert(parts,if x then "true" else "false");return end
  if t=="number" then
   if not finite(x) then problem=`{where()}: a number JSON cannot hold`;return end
   if x==math.floor(x) and math.abs(x)<2^53 then table.insert(parts,string.format("%d",x))
   else table.insert(parts,string.format("%.17g",x)) end
   return
  end
  if t~="table" then problem=`{where()}: a {typeof(x)}`;return end
  if getmetatable(x)~=nil then problem=`{where()}: a table with a metatable`;return end
  if seen[x] then problem=`{where()}: a table met twice`;return end
  seen[x]=true
  local kind=shape(x,pulse)
  local depth=#trail+1
  if kind=="list" then
   table.insert(parts,"[")
   for i,y in ipairs(x) do
    if i>1 then table.insert(parts,",") end
    trail[depth]=i;enc(y)
    if problem then break end
   end
   trail[depth]=nil;table.insert(parts,"]")
  elseif kind=="object" then
   local keys:{string}={}
   for k in x do if pulse then pulse() end;table.insert(keys,k) end
   table.sort(keys)
   table.insert(parts,"{")
   for i,k in keys do
    if i>1 then table.insert(parts,",") end
    trail[depth]=k;table.insert(parts,quote(k)..":");enc(x[k])
    if problem then break end
   end
   trail[depth]=nil;table.insert(parts,"}")
  else problem=`{where()}: a table with mixed or sparse keys` end
 end
 enc(v)
 if problem then return nil,problem end
 return table.concat(parts),nil
end

