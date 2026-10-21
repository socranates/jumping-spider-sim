--!strict
-- Builds the physical world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): every region of the map, each as a folder of anchored boxes, all under one `World` folder in the
-- workspace. The server does it once at startup (Server/Main); deterministic generation (Region) means a rebuilt server is the same world. `World` is what the client's rays
-- include (the motor, the sight and perch casts): it holds the physical boxes of every region and nothing drawn, so the casts see exactly what they saw. The drawn sill
-- (Scenery.decor) stays beside it in the workspace, as it has always been.
--
-- The sill is built by the sill's own part-making (Habitat/Scenery.sill, from the region's pieces), so its folder is exactly the one Main used to parent to the workspace: the
-- same name ("Windowsill"), the same parts, the same attributes, the same hidden-but-solid pieces where the decor drew its own. Only its parent changed. Any other kind
-- gets a folder named for its region and the same parts, from its generator (Region.pieces).
--
-- ROBLOX-95: three regions outside the window (World/Garden). Their drawn looks (Region.decor) are built by `looks` into a `WorldDecor` folder beside `World`, a persistent
-- Model per region, as the sill's Decor is, so each look reaches a client whole and the low tier can thin it once (Client/WorldDetail); the pieces a look draws instead
-- (the wall's bricks, the bed's leaves and stems) turn invisible and stay solid, as the sill's back wall and Pilea do. (ROBLOX-108: the looks are each client's own now,
-- made near its spider, Client/LookStream; the pieces are hidden as before.)
local Scenery = require(script.Parent.Parent.Habitat.Scenery)
local WorldMap = require(script.Parent.WorldMap)
local Region = require(script.Parent.Region)

local WorldBuild = {}

-- One region's folder of physical parts, under `parent`. `replaced`: the ids of the pieces whose drawing exists (Scenery.decor's second result, and `looks`'): those turn
-- invisible but stay solid; nil means every piece a drawing can replace, {} none (as Scenery.sill has it).
function WorldBuild.region(region: WorldMap.Region, parent: Instance, replaced: { [string]: boolean }?): Folder
	local pieces = Region.pieces(region)
	local folder: Folder
	if region.kind == "sill" then
		folder = Scenery.sill(replaced, pieces)
	else
		folder = Instance.new("Folder")
		folder.Name = Region.folderName(region)
		local hide = replaced
		if hide == nil then
			local all: { [string]: boolean } = {}
			for _, id in Region.replaceable(region) do all[id] = true end
			hide = all
		end
		Scenery.parts(folder, pieces, hide :: { [string]: boolean })
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

-- The drawn look of every region but the sill (whose look is the Decor, Scenery.decor): a `WorldDecor` folder under `parent` holding a persistent Model per region, named
-- for its id. Best effort, as the sill's decor is: a region whose look fails is warned about and left out (its pieces stay visible). Returns the folder and the ids of the
-- pieces the looks that were built stand in for.
-- ROBLOX-108: the server no longer calls this. Each client makes the looks near its spider itself (Client/LookStream, World/LookPlan); every look at once is what the
-- previewer draws (tools/preview/scene.py without --looks-at) and what tests/world.luau holds to the budgets.
function WorldBuild.looks(parent: Instance, worldSeed: number?): (Folder, { [string]: boolean })
	local looks = Instance.new("Folder")
	looks.Name = Region.LOOKS_FOLDER
	local drawn: { [string]: boolean } = {}
	for _, region in WorldMap.regions(worldSeed) do
		if region.kind ~= "sill" then
			local model = Instance.new("Model")
			model.Name = region.id
			model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			local ok, err = pcall(function() return Scenery.look(model, Region.decor(region)) end)
			if ok then
				model.Parent = looks
				for _, id in Region.drawnPieces(region) do drawn[id] = true end
			else
				warn(`[Windowsill] decor: the look of {region.id} failed: {tostring(err)}`)
				model:Destroy()
			end
		end
	end
	looks.Parent = parent
	return looks, drawn
end

return table.freeze(WorldBuild)
