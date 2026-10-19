--!strict
-- Builds the physical world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): every region of the map, each as a folder of anchored boxes, all under one `World` folder in the
-- workspace. The server does it once at startup (Server/Main); deterministic generation (Region) means a rebuilt server is the same world. `World` is what the client's rays
-- include (the motor, the sight and perch casts): it holds the physical boxes of every region and nothing drawn, so the casts see exactly what they saw. The drawn sill
-- (Scenery.decor) stays beside it in the workspace, as it has always been.
--
-- The sill is built by the sill's own part-making (Habitat/Scenery.sill, from the region's pieces), so its folder is exactly the one Main used to parent to the workspace: the
-- same name ("Windowsill"), the same 28 parts, the same attributes, the same hidden-but-solid pieces where the decor drew its own. Only its parent changed. Any other kind
-- gets a folder named for its region and the same parts, from its generator (Region.pieces), when it has one.
local Scenery = require(script.Parent.Parent.Habitat.Scenery)
local WorldMap = require(script.Parent.WorldMap)
local Region = require(script.Parent.Region)

local WorldBuild = {}

-- One region's folder of physical parts, under `parent`. `replaced`: the ids of the pieces whose drawing exists (Scenery.decor's second result): those turn invisible but stay
-- solid; nil means every piece the decor can replace, {} none (as Scenery.sill has it).
function WorldBuild.region(region: WorldMap.Region, parent: Instance, replaced: { [string]: boolean }?): Folder
	local pieces = Region.pieces(region)
	local folder: Folder
	if region.kind == "sill" then
		folder = Scenery.sill(replaced, pieces)
	else
		folder = Instance.new("Folder")
		folder.Name = Region.folderName(region)
		Scenery.parts(folder, pieces, replaced or {})
	end
	folder.Parent = parent
	return folder
end

-- The whole world: a `World` folder with a folder for every region, under `parent`. It is built before it is parented, so it arrives in one piece. Returns the World folder.
function WorldBuild.world(parent: Instance, worldSeed: number?, replaced: { [string]: boolean }?): Folder
	local world = Instance.new("Folder")
	world.Name = Region.WORLD_FOLDER
	for _, region in WorldMap.regions(worldSeed) do
		WorldBuild.region(region, world, replaced)
	end
	world.Parent = parent
	return world
end

return table.freeze(WorldBuild)
