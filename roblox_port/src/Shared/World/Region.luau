--!strict
-- What a region is made of (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): the generators. Each is pure and deterministic from the region (its kind and its
-- seed), so the same region gives the same boxes forever, on the server and on any client; nothing here touches the engine.
--   pieces ... the physical boxes: what the motor walks on, the rival's route is built from, and the prey perch on (Habitat/WindowsillLayout.Piece).
--   decor .... the drawn-only boxes that stand beside them (Habitat/WindowsillLayout.Decor). The sill's drawn world (Habitat/Scenery.decor) is its own
--              generator and still reads these; a region of any other kind will put its looks here.
--   keepOut .. the boxes the rival's route keeps out of: the retreats and a margin around them.
--   budget ... how many drawn parts a region of a kind may carry at each detail tier.
-- The sill is the one kind so far, and its generator returns the layout's lists as they are: the sill is hand-placed and byte-identical to what it was
-- before there was a world (tests/worldmap.luau pins that). Every later kind is a seeded placer (soil mounds, litter leaves, grass tufts, stones, stems
-- and a flower head) that respects its budget; asking for a kind with no generator is a mistake, not an empty region.
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)
local Rules = require(script.Parent.Parent.Data.RivalRules)
local WorldMap = require(script.Parent.WorldMap)

local Region = {}

export type Box = { min: Vector3, max: Vector3 }

-- The name of the folder every region's folder of physical boxes is built under, in the workspace (WorldBuild; the client's rays include it).
Region.WORLD_FOLDER = "World"

-- The physical boxes of the region.
function Region.pieces(region: WorldMap.Region): { Layout.Piece }
	if region.kind == "sill" then return Layout.PIECES end
	error("no generator for the region kind " .. region.kind)
end

-- The drawn-only boxes of the region.
function Region.decor(region: WorldMap.Region): { Layout.Decor }
	if region.kind == "sill" then return Layout.DECOR end
	error("no generator for the region kind " .. region.kind)
end

-- The boxes the rival's route keeps out of (RivalRoute: nothing the rival does goes in): the sill's are the crack grown by a margin, authored with the
-- rival's other rules (Data/RivalRules). One box per retreat, in the retreats' order.
function Region.keepOut(region: WorldMap.Region): { Box }
	if region.kind == "sill" then return { { min = Rules.keepOutMin, max = Rules.keepOutMax } } end
	error("no generator for the region kind " .. region.kind)
end

-- The folder a region's physical boxes are built into (WorldBuild), by which the client finds it: the sill is "Windowsill", as it was before there was a
-- world; any other region is named for its id.
function Region.folderName(region: WorldMap.Region): string
	return if region.kind == "sill" then "Windowsill" else region.id
end

-- The most drawn parts (the decor, as tests/world.luau counts them) a region of this kind may carry at a detail tier ("full" or "low", Data/Detail), or nil
-- for a kind with no budget yet. A stub: the sill's are what its decor builds now, with the sun through the window (the most it ever builds), and
-- tests/world.luau holds it to them exactly, so a sill that grows says so here; every later kind brings its own numbers with its generator.
local BUDGETS: { [string]: { full: number, low: number } } = {
	sill = { full = 1156, low = 292 },
}

function Region.budget(kind: string, tier: string): number?
	local b = BUDGETS[kind]
	if b == nil then return nil end
	if tier == "full" then return b.full end
	if tier == "low" then return b.low end
	return nil
end

return table.freeze(Region)
