--!strict
-- What a region is made of (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): the generators. Each is pure and deterministic from the region (its kind and its
-- seed), so the same region gives the same boxes forever, on the server and on any client; nothing here touches the engine.
--   pieces ... the physical boxes: what the motor walks on, the rival's route is built from, and the prey perch on (Habitat/WindowsillLayout.Piece).
--   decor .... the drawn-only boxes that stand beside them. The sill's are the layout's DECOR (its drawn world is Habitat/Scenery.decor, which still reads the layout);
--              every other kind's are its whole drawn look, one record a part (World/Garden.Drawn, built by Habitat/Scenery.look).
--   keepOut .. the boxes the region's creatures keep out of: the retreats and a margin around them, and the sill's open sash (ROBLOX-95: the rival and the mate
--              are bound to the sill, so the way out is not theirs).
--   budget ... how many drawn parts a region of a kind may carry at each detail tier.
-- The sill is hand-placed and its generator returns the layout's lists as they are (tests/worldmap.luau pins that). ROBLOX-95 adds the three kinds under the
-- window, seeded placers in World/Garden: outer_sill, house_wall and bed; ROBLOX-103 a fourth above it, wall_upper. Asking for a kind with no generator is a
-- mistake, not an empty region.
local Layout = require(script.Parent.Parent.Habitat.WindowsillLayout)
local Rules = require(script.Parent.Parent.Data.RivalRules)
local WorldMap = require(script.Parent.WorldMap)
local Garden = require(script.Parent.Garden)
local PreserveLook = require(script.Parent.PreserveLook)
local Hut = require(script.Parent.Hut)
local Meadow = require(script.Parent.Meadow)

local Region = {}

export type Box = { min: Vector3, max: Vector3 }
export type Drawn = Garden.Drawn

-- The name of the folder every region's folder of physical boxes is built under, in the workspace (WorldBuild; the client's rays include it).
Region.WORLD_FOLDER = "World"
-- The folder beside it that holds the drawn look of every region but the sill (the sill's is the Decor model, as it always was): since ROBLOX-108 each client's own,
-- made near its spider (Client/LookStream); WorldBuild.looks builds every look into one for the previewer and the tests.
Region.LOOKS_FOLDER = "WorldDecor"

-- ROBLOX-95: the open sash, as the sill's creatures keep out of it: the gap between the back frame's pieces (WindowsillLayout back_frame_*), grown by 0.3 across
-- and up, through the frame's depth and 0.05 into the room (so the floor in front of it is not in it).
Region.SASH_MIN = Vector3.new(-8.3, -0.05, -13.55)
Region.SASH_MAX = Vector3.new(8.3, 6.3, -12.45)

-- The physical boxes of the region.
function Region.pieces(region: WorldMap.Region): { Layout.Piece }
	if region.kind == "sill" then return Layout.PIECES end
	if region.kind == "backdrop" or region.kind == "patch" then return {} end -- (ROBLOX-115: the preserve's backdrop has no boxes; ROBLOX-117: nor a patch)
	if Hut.knows(region.kind) then return Hut.pieces(region :: any) :: any end -- (ROBLOX-116: the ranger hut and its garden, World/Hut)
	if Meadow.knows(region.kind) then return Meadow.pieces(region :: any) :: any end -- (ROBLOX-119: the bench patch and the meadow's edge, World/Meadow)
	return Garden.pieces(region) :: any
end

-- The drawn-only boxes of the region.
function Region.decor(region: WorldMap.Region): { Drawn }
	if region.kind == "sill" then return Layout.DECOR :: any end
	if region.kind == "backdrop" then return PreserveLook.records(region.id, region.seed) :: any end -- (ROBLOX-115: a zone of the preserve's backdrop, World/PreserveLook)
	if Meadow.knows(region.kind) or (region.kind == "patch" and Meadow.patchParent(region :: any) ~= nil) then return Meadow.decor(region :: any) :: any end -- (ROBLOX-119)
	if region.kind == "patch" or Hut.knows(region.kind) then return Hut.decor(region :: any) :: any end -- (ROBLOX-117: a patch is the hut garden's near detail)
	return Garden.decor(region)
end

-- The ids of the region's pieces that its drawn look stands in for (they turn invisible, still solid, once the look exists). The sill's are decided by its Decor
-- (Habitat/Scenery.decor's second result), so none here.
function Region.drawnPieces(region: WorldMap.Region): { string }
	if region.kind == "sill" or region.kind == "backdrop" or region.kind == "patch" then return {} end
	if Hut.knows(region.kind) then return Hut.drawnPieces(region :: any) end
	if Meadow.knows(region.kind) then return Meadow.drawnPieces(region :: any) end
	return Garden.drawnPieces(region)
end

-- Every piece of the region that some drawing may stand in for: its own look's (drawnPieces) and, on the outer sill, the window box's halves, which the sill's
-- Decor draws (Habitat/Plants.garden). WorldBuild hides these when it is not told which drawings exist.
function Region.replaceable(region: WorldMap.Region): { string }
	if region.kind == "sill" or region.kind == "backdrop" or region.kind == "patch" then return {} end
	if Hut.knows(region.kind) then return table.clone(Hut.drawnPieces(region :: any)) end
	if Meadow.knows(region.kind) then return table.clone(Meadow.drawnPieces(region :: any)) end
	local out = table.clone(Garden.drawnPieces(region))
	for _, id in Garden.drawnBySill(region) do table.insert(out, id) end
	return out
end

-- The boxes the region's creatures keep out of (RivalRoute: nothing the rival does goes in): for the sill, the crack grown by a margin, authored with the rival's
-- other rules (Data/RivalRules), then the open sash; for the others, each retreat grown by half a stud. The retreats' boxes come first, in the retreats' order.
function Region.keepOut(region: WorldMap.Region): { Box }
	if region.kind == "sill" then return { { min = Rules.keepOutMin, max = Rules.keepOutMax }, { min = Region.SASH_MIN, max = Region.SASH_MAX } } end
	if region.kind == "backdrop" or region.kind == "patch" then return {} end
	if Hut.knows(region.kind) then return Hut.keepOut(region :: any) end
	if Meadow.knows(region.kind) then return Meadow.keepOut(region :: any) end
	return Garden.keepOut(region)
end

-- The folder a region's physical boxes are built into (WorldBuild), by which the client finds it: the sill is "Windowsill", as it was before there was a
-- world; any other region is named for its id.
function Region.folderName(region: WorldMap.Region): string
	return if region.kind == "sill" then "Windowsill" else region.id
end

-- The most drawn parts (the decor, as tests/world.luau counts them) a region of this kind may carry at a detail tier ("full" or "low", Data/Detail), or nil
-- for a kind with no budget. The sill's are what its decor builds now, with the sun through the window (the most it ever builds), and tests/world.luau holds
-- it to them exactly, so a sill that grows says so here; the garden's kinds are ceilings their placers keep to (World/Garden.BUDGETS).
local BUDGETS: { [string]: { full: number, low: number } } = {
	-- (ROBLOX-95: 1156 and 292 before the raised sash, the window box's halves and the shrubs' bodies: 22 more at each tier. ROBLOX-103: 1178 and 314 before the bushes
	-- to the ground, 62 more at full and 40 at low; the bungalows for the tall houses, 4 more at full and 2 fewer at low; the fences, 9 and 3. ROBLOX-112: 1253 and 355
	-- before the window in true proportion: the upper lights, the transom and the sashes' rails where they meet, 7 more at each tier. ROBLOX-114: 1260 and 362 before
	-- the ground beyond the back fence, under the bungalows that stand 21 m off now, 1 more at each tier)
	sill = { full = 1261, low = 363 },
}
for kind, b in Garden.BUDGETS do BUDGETS[kind] = b end
for kind, b in Hut.BUDGETS do BUDGETS[kind] = b end -- (ROBLOX-116: the hut's and its garden's kinds)
for kind, b in Meadow.BUDGETS do BUDGETS[kind] = b end -- (ROBLOX-119: the bench patch's and the meadow's)

-- Whether a region of this kind has a drawn look the looks stream (World/LookPlan, Client/LookStream): the garden's kinds and (ROBLOX-115) the preserve's backdrop.
function Region.streamed(kind: string): boolean
	return kind == "backdrop" or kind == "patch" or Garden.knows(kind) or Hut.knows(kind) or Meadow.knows(kind)
end

-- (ROBLOX-115: a zone of the preserve's backdrop has its ceilings in World/PreserveLook.BUDGETS, by zone; its kind has none here.)
function Region.budget(kind: string, tier: string): number?
	local b = BUDGETS[kind]
	if b == nil then return nil end
	if tier == "full" then return b.full end
	if tier == "low" then return b.low end
	return nil
end

return table.freeze(Region)
