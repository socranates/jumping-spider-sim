--!strict
-- The worlds the engine can run (ROBLOX-115, docs/PARK_WORLD_DESIGN.md). One engine, two worlds:
--   test_garden ... "The Test Garden": the windowsill at the house, the bed under it, the bushes, the walls, the kitchen (ROBLOX-94..114), unchanged. The engine's
--                   proving ground (the published game until ROBLOX-118); every CLI suite runs on it unless it asks for the preserve, and a place reaches it with
--                   the Workspace attribute World = "test_garden".
--   preserve ...... "The Preserve": the game's real world, a nature preserve of 100 by 60 m in the middle of an American city (World/Preserve). Phase A builds its
--                   map and its backdrop; the only walkable thing in it is the ranger hut's windowsill (the same sill, byte for byte, at the origin).
-- Which world a server runs is the Workspace attribute `World` (ATTRIBUTE): a place may author it (Studio: select the preserve by setting it to "preserve" before
-- Play), and the server writes the world it chose back to it at startup, so every client reads the same answer. A value that is not a world's id is the
-- default's. ROBLOX-118 (Phase B, round 3): the preserve is the game, so it is the default: a place that does not say runs the preserve.
-- Pure data; World/WorldMap answers for the active world.
local Worlds = {}

export type World = { id: string, name: string, revision: string }

Worlds.TEST_GARDEN = "test_garden"
Worlds.PRESERVE = "preserve"
-- The world a server runs when the place does not say: the preserve (ROBLOX-118; the test garden before).
Worlds.DEFAULT = Worlds.PRESERVE
-- The Workspace attribute that names the world.
Worlds.ATTRIBUTE = "World"

-- Each world's revision is its own: a rest kept in one world is never measured against the other's geometry (Persistence/Checkpoint reads a record without a world
-- as the test garden's). The test garden's is WorldMap.REVISION, as it always was.
Worlds.LIST = table.freeze({
	test_garden = table.freeze({ id = "test_garden", name = "The Test Garden", revision = "world-3" }),
	preserve = table.freeze({ id = "preserve", name = "The Preserve", revision = "preserve-2" }), -- (ROBLOX-118: the path round the east end moved round the back room)
}) :: { [string]: World }

-- The ids in a fixed order (the test garden first).
Worlds.IDS = table.freeze({ "test_garden", "preserve" })

-- Whether this is a world's id.
function Worlds.known(id: any): boolean
	return type(id) == "string" and Worlds.LIST[id] ~= nil
end

-- The world a value names (an attribute's value, a record's field), or the default for anything that names none.
function Worlds.choose(value: any): string
	if Worlds.known(value) then return value :: string end
	return Worlds.DEFAULT
end

-- The world with this id (an unknown id is an error: ask `choose` first).
function Worlds.get(id: string): World
	local w = Worlds.LIST[id]
	assert(w ~= nil, "no world " .. tostring(id))
	return w
end

return table.freeze(Worlds)
