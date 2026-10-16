--!strict
-- The windowsill of scripts/habitat/windowsill.gd ("windowsill-v1"), box for box. Coordinates are studs = Godot WU = cm,
-- in the same right-handed, Y-up, -Z-forward frame, so every number is copied unchanged.

export type Piece = {
	id: string,
	lo: Vector3,
	hi: Vector3,
	profile: string,
	color: Color3,
}

export type Decor = {
	id: string,
	size: Vector3,
	at: Vector3,
	color: Color3,
	transparency: number?,
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local Layout = {}

Layout.CONTENT_REVISION = "windowsill-v1"
Layout.SPAWN = Vector3.new(-22.0, 0.0, 6.0)
Layout.SPAWN_HEADING = Vector3.new(1, 0, 0) -- Basis(UP, -90 deg) * forward
Layout.PLAY_BOUNDS_MIN = Vector3.new(-33, -5, -16)
Layout.PLAY_BOUNDS_MAX = Vector3.new(33, 35, 16)
Layout.RETREAT_MIN = Vector3.new(-27.8, 0.0, 3.0)
Layout.RETREAT_MAX = Vector3.new(-23.3, 1.5, 9.0)
-- Whether a point is inside the silk-lined crack (Godot's windowsill.gd in_retreat: the box, edges included).
function Layout.inRetreat(p: Vector3): boolean
	local lo, hi = Layout.RETREAT_MIN, Layout.RETREAT_MAX
	return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y and p.Z >= lo.Z and p.Z <= hi.Z
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

Layout.PIECES = {
	{ id = "sill_floor", lo = v(-30, -1, -12.5), hi = v(30, 0, 12.5), profile = "painted_wood_dry", color = hex("b6a082") },
	{ id = "back_frame", lo = v(-31, 0, -13.5), hi = v(31, 14, -12.5), profile = "bare_wood_rough", color = hex("ded7c3") },
	{ id = "left_frame", lo = v(-31, 0, -12.5), hi = v(-30, 14, 12.5), profile = "bare_wood_rough", color = hex("ded7c3") },
	{ id = "right_frame", lo = v(30, 0, -12.5), hi = v(31, 14, 12.5), profile = "bare_wood_rough", color = hex("ded7c3") },
	{ id = "front_lip", lo = v(-30, 0, 12.0), hi = v(30, 0.7, 12.5), profile = "bare_wood_rough", color = hex("8b7256") },
	{ id = "planter", lo = v(3, 0, -8), hi = v(17, 4, 0), profile = "brick_rough", color = hex("9f6650") },
	{ id = "planter_rim", lo = v(2.5, 4, -8.5), hi = v(17.5, 4.6, 0.5), profile = "brick_rough", color = hex("ba8264") },
	{ id = "leaf_west", lo = v(-18, 3.8, -4), hi = v(-12, 4.2, 1), profile = "leaf_dry_prototype", color = hex("607952") },
	{ id = "leaf_middle", lo = v(-4, 3.8, -4), hi = v(2, 4.2, 1), profile = "leaf_dry_prototype", color = hex("738a59") },
	{ id = "leaf_east", lo = v(18, 5.0, -6), hi = v(25, 5.4, 0), profile = "leaf_dry_prototype", color = hex("829960") },
	{ id = "stem_west", lo = v(-16.5, 0, -2), hi = v(-15.5, 3.8, -1), profile = "leaf_dry_prototype", color = hex("536b43") },
	{ id = "stem_middle", lo = v(-2.5, 0, -2), hi = v(-1.5, 3.8, -1), profile = "leaf_dry_prototype", color = hex("536b43") },
	{ id = "stem_east", lo = v(21, 0, -3.5), hi = v(22, 5, -2.5), profile = "leaf_dry_prototype", color = hex("536b43") },
	{ id = "leaf_tip", lo = v(25.6, 5.15, -4.2), hi = v(28.4, 5.35, -1.8), profile = "leaf_dry_prototype", color = hex("cdb27a") },
	{ id = "crevice_back", lo = v(-29, 0, 2), hi = v(-28, 3, 10), profile = "bare_wood_rough", color = hex("655640") },
	{ id = "crevice_roof", lo = v(-29, 2.6, 2), hi = v(-23, 3, 10), profile = "bare_wood_rough", color = hex("8b775a") },
	{ id = "crevice_north", lo = v(-29, 0, 2), hi = v(-23, 2.6, 2.6), profile = "bare_wood_rough", color = hex("786448") },
	{ id = "crevice_south", lo = v(-29, 0, 9.4), hi = v(-23, 2.6, 10), profile = "bare_wood_rough", color = hex("786448") },
} :: { Piece }

local decor: { Decor } = {
	{ id = "soil", size = v(12, 0.01, 6), at = v(10, 4.61, -4), color = hex("665644") },
	{ id = "window_glass", size = v(55, 10, 0.04), at = v(0, 8, -12.44), color = hex("a9c2c1"), transparency = 0.55 },
	{ id = "mullion_w", size = v(0.7, 12, 0.1), at = v(-10, 8, -12.35), color = hex("e2dbc7") },
	{ id = "mullion_e", size = v(0.7, 12, 0.1), at = v(10, 8, -12.35), color = hex("e2dbc7") },
}
for i = 0, 6 do
	table.insert(decor, { id = "silk_" .. i, size = v(4.6, 0.012, 0.045), at = v(-25.5, 0.025, 3.3 + i * 0.85), color = hex("ddd9bf") })
end
Layout.DECOR = decor

return table.freeze(Layout)
