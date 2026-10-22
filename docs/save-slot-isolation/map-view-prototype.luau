-- Private prototype injected before WorldMap's final return; not gameplay code.
-- Uses this module's trusted AUTHORS and MAPS; no WorldMap.use or global cache.
function WorldMap.recordedView(worldId: any, worldSeed: any, revision: any, pulse: (() -> ())?): (any?, string?)
 if not Worlds.known(worldId) then return nil,"unsupported recorded world" end
 if type(worldSeed)~="number" or worldSeed~=worldSeed or worldSeed<0 or worldSeed>4294967295 or worldSeed%1~=0 then
  return nil,"invalid recorded seed"
 end
 if revision~=Worlds.get(worldId).revision then return nil,"unsupported recorded revision" end
 local originals=if worldSeed==WorldMap.SEED then MAPS[worldId].regions else AUTHORS[worldId](worldSeed)
 local seen: {[any]:any}={}
 local function owned(value: any): any
  if pulse then pulse() end
  if type(value)~="table" then return value end
  if seen[value] then return seen[value] end
  local copy={};seen[value]=copy
  for k,v0 in value do copy[owned(k)]=owned(v0) end
  -- Roblox vectors are immutable values. The CLI shim represents them as
  -- tables, so preserve their value methods on an owned frozen clone too.
  local meta=getmetatable(value)
  if meta~=nil then assert(type(meta)=="table","unexpected protected map metatable");setmetatable(copy,meta) end
  return table.freeze(copy)
 end
 local list=owned(originals)
 local byId={}
 for _,r in list do byId[r.id]=r end
 table.freeze(byId)
 local lo,hi=WorldMap.unionOf(list)
 local function at(pos: Vector3): any
  for _,r in list do if within(r.bounds[1],r.bounds[2],pos) then return r end end
  return nil
 end
 local function region(id: string): any return byId[id] end
 local function retreat(id: string): any
  for _,r in list do for _,t in r.retreats do if t.id==id then return t end end end
  return nil
 end
 return table.freeze({
  id=worldId,seed=worldSeed,revision=revision,HOME=WorldMap.HOME,
  regions=function() return list end,region=region,retreat=retreat,at=at,
  bounds=function() return lo,hi end,
  inBounds=function(pos: Vector3,id: string?): boolean
   if id==nil then return at(pos)~=nil end
   local r=byId[id];return r~=nil and within(r.bounds[1],r.bounds[2],pos)
  end,
 }),nil
end
