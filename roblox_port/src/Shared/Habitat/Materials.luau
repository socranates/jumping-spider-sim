--!strict
-- Material names (as Data/Graphics spells them) to Roblox's Enum.Material, so the data stays plain text and a typo is caught by
-- tests/world.luau instead of showing up as a grey part in Studio. These are Roblox's built-in materials; with
-- MaterialService.Use2022Materials on (both Rojo projects set it) they carry their own PBR textures.
local Materials = {}

local MAP: { [string]: Enum.Material } = {
	Plastic = Enum.Material.Plastic, SmoothPlastic = Enum.Material.SmoothPlastic, Neon = Enum.Material.Neon,
	Wood = Enum.Material.Wood, WoodPlanks = Enum.Material.WoodPlanks, Plaster = Enum.Material.Plaster,
	Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick, Glass = Enum.Material.Glass,
	Ground = Enum.Material.Ground, Grass = Enum.Material.Grass, LeafyGrass = Enum.Material.LeafyGrass,
	Fabric = Enum.Material.Fabric, Cardboard = Enum.Material.Cardboard, Sand = Enum.Material.Sand,
	Slate = Enum.Material.Slate, Pebble = Enum.Material.Pebble, Rock = Enum.Material.Rock, Mud = Enum.Material.Mud,
	Limestone = Enum.Material.Limestone, Marble = Enum.Material.Marble, Metal = Enum.Material.Metal,
}

function Materials.known(name: string): boolean
	return MAP[name] ~= nil
end

function Materials.get(name: string): Enum.Material
	return MAP[name] or Enum.Material.SmoothPlastic
end

function Materials.names(): { string }
	local out = {}
	for name in MAP do table.insert(out, name) end
	table.sort(out)
	return out
end

return Materials
