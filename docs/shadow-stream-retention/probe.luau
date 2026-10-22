-- A fully hidden region streams out, then returns as fresh visible instances.
-- This tests reference release and the existing distance rule, not frame rate.
local Shadows=require("../src/Client/WorldShadows")
local Map=require("../src/Shared/World/WorldMap")
local Region=require("../src/Shared/World/Region")
Map.use("test_garden")
local region=assert(Map.region("outer_sill"))
local pieces=Region.pieces(region)
local root=Instance.new("Folder")
local function incoming(hidden)
 local folder=Instance.new("Folder");folder.Name=Region.folderName(region);folder.Parent=root
 local parts={}
 for _,piece in pieces do
  local p=Instance.new("Part");p.Name=piece.id;p.Size=Vector3.one;p.Position=Vector3.zero
  p.Transparency=if hidden then 1 else 0;p.CastShadow=not hidden;p.Parent=folder
  table.insert(parts,p)
 end
 return folder,parts
end
local old,oldParts=incoming(true)
local shadows=Shadows.new(root,{regions=function() return {region} end},nil)
local far=Vector3.new(20000,0,0)
shadows:update(far,0)
local visible=shadows:counts();assert(visible==0,"hidden boxes should not enter shadow rule")
old:Destroy()
local fresh,freshParts=incoming(false)
shadows:update(far,Shadows.BIND_EVERY+1)
local retained=0
for _,holder in shadows.holders do for _,p in oldParts do if holder.bound[p]~=nil then retained+=1 end end end
local off=0;for _,p in freshParts do if p.CastShadow==false then off+=1 end end
print(`SHADOW_STREAM_RETAIN old_parts={#oldParts} retained={retained} fresh_shadow_off={off} expected_off={#freshParts}`)
assert(retained==0,"shadow manager retains streamed-out hidden instances")
assert(off==#freshParts,"returned visible instances are skipped by shadow management")
fresh:Destroy();root:Destroy()
