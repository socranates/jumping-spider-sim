--!strict
-- The inhabited ranger station, excluding its garden and exterior wall/eaves.
-- Shared by residency, streaming and route checks; no player-position tracking.
local WorldMap=require(script.Parent.WorldMap)
local Station={}
local KINDS={sill=true,hut_window=true,hut_desk=true,hut_board=true,hut_shelf=true,
 hut_chair=true,hut_floor=true,room_floor=true,hut_upper=true,hut_door=true,
 hut_door_up=true,hut_doorway=true,room_window=true,room_tv=true,room_games=true,room_sofa=true}
local cached: {[string]:boolean}?=nil
function Station.contains(id: string?): boolean
 if WorldMap.world()~="preserve" or id==nil then return false end
 local region=WorldMap.region(id)
 return region~=nil and (KINDS :: {[string]:boolean})[region.kind]==true
end
function Station.roam(): {[string]:boolean}
 if WorldMap.world()~="preserve" then return table.freeze({}) end
 if cached==nil then
  local ids: {[string]:boolean}={}
  for _,region in WorldMap.regions() do
   if (KINDS :: {[string]:boolean})[region.kind] then ids[region.id]=true end
  end
  cached=table.freeze(ids)
 end
 return cached :: {[string]:boolean}
end
Station.ARRIVE=Vector3.new(-20,-69.69,70)
Station.REGION="hut_floor_b"
Station.REPLACE_SECONDS=60
return table.freeze(Station)
