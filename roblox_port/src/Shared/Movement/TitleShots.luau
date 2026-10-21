--!strict
-- The camera of the first minute (ROBLOX-109), as pure functions of time: the drift the splash (First/SplashScreen) and the title card (Client/TitleCard)
-- both draw, and the intro of a new life, shot by shot, with its captions' times and the spider's walk out of the crack. Pure: tests/title.luau checks it,
-- and tools/preview/scene.py --title renders its frames from these same numbers (TitleShots.views).
--
-- The drift: the garden in the morning seen from outside, from over the lawn beyond the bed, low, drawing in toward the window over DRIFT_S seconds, then
-- breathing in place (a slow sway of a stud or two) for as long as the title card is up. It is a function of the game's clock (`time()`), so the splash
-- and the title card, two scripts, put the camera in the same place on the same frame and the hand-over between them cannot jump.
-- The intro: the morning light through the glass from low on the sill; the camera low over the sill floor finding the crack; the spider stepping out of it;
-- then the camera eases into the game's own camera behind the spider and the controls are the player's. Captions come in the notebook's voice
-- (UI/TitleText.captions). Reduced Motion: each shot is held still (its middle frame) and the shots cut; no ease into the game's camera, a cut.
-- One stud is a centimetre: the sill's floor is y 0, the crack's mouth is at x -23.3 (Habitat/WindowsillLayout.RETREAT_MAX), the glass at z -12.6, the
-- outer sill's top y 0 out to z -24 (the house's face), the bed's soil y -90.
local TitleShots = {}

export type Key = { t: number, eye: Vector3, at: Vector3, fov: number }
export type Shot = { name: string, t0: number, t1: number, eye0: Vector3, eye1: Vector3, at0: Vector3, at1: Vector3, fov: number, follow: boolean? }
export type Frame = {
	cframe: CFrame, fov: number, shot: string, veil: number, caption: number?, captionAlpha: number,
	blend: number, walking: boolean, holding: boolean, done: boolean,
}

local v = Vector3.new

TitleShots.DRIFT_S = 36
TitleShots.DRIFT = {
	{ t = 0, eye = v(40, -82, -170), at = v(0, -25, -24), fov = 55 }, -- low over the lawn past the bed: the bed's foot, the bushes, the window high in the wall
	{ t = 18, eye = v(16, -20, -80), at = v(0, 0, -18), fov = 48 }, -- risen in front of the wall, the window in its deep reveal
	{ t = 36, eye = v(10, 6.5, -45), at = v(0, 2.5, -14), fov = 46 }, -- level with the outer sill, looking in: the window boxes, the glass, the sill beyond
} :: { Key }
-- ROBLOX-115: the preserve's drift (World/Preserve: the ranger hut's north window, the sill in it, looking north over the hut garden): from over the hut garden's far
-- end, at a person's knee, drawing in over the herb beds to the window from outside, arriving where the test garden's does (in front of the glass, looking in).
TitleShots.PRESERVE_DRIFT = {
	{ t = 0, eye = v(380, 60, -1250), at = v(0, 30, -16), fov = 55 }, -- over the far end of the hut garden: the beds, the fence, the hut with its window
	{ t = 18, eye = v(120, 25, -360), at = v(0, 15, -16), fov = 48 }, -- in over the herb beds, the hut's log wall and its green casing
	{ t = 36, eye = v(10, 6.5, -45), at = v(0, 2.5, -14), fov = 46 }, -- level with the outer sill, looking in: the glass, the sill beyond
} :: { Key }
-- The drift of each world (World/Worlds' ids); any other world (or none: the splash before the server has said) has the default world's, the preserve's
-- (ROBLOX-118: World/Worlds.DEFAULT, the game's world; this module is required by the splash before World/ is known to have replicated, so it names it itself).
TitleShots.DRIFTS = { test_garden = TitleShots.DRIFT, preserve = TitleShots.PRESERVE_DRIFT } :: { [string]: { Key } }
TitleShots.DEFAULT_WORLD = "preserve"

-- The breathing once the drift has arrived: amplitudes in studs and the periods' rates (radians a second), slow enough never to be noticed as a move.
TitleShots.SWAY = { x = 1.6, y = 0.5, rateX = 0.07, rateY = 0.05 }

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- The drift's camera and field of view at the game's time `t` (seconds since the client began), in the world `world` (the Workspace attribute World; the
-- default world's drift when nil or unknown: the preserve's since ROBLOX-118).
function TitleShots.drift(t: number, world: string?): (CFrame, number)
	local keys = (if world ~= nil then TitleShots.DRIFTS[world] else nil) or TitleShots.DRIFTS[TitleShots.DEFAULT_WORLD]
	t = math.max(t, 0)
	local last = keys[#keys]
	if t >= last.t then
		local s = TitleShots.SWAY
		local after = t - last.t
		-- (the sway starts from nothing: sin(0) = 0 and its rate is slow, so the arrival is still)
		local eye = last.eye + v(math.sin(after * s.rateX) * s.x, math.sin(after * s.rateY) * s.y, 0)
		return CFrame.lookAt(eye, last.at), last.fov
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local k = smooth((t - a.t) / (b.t - a.t))
			return CFrame.lookAt(a.eye:Lerp(b.eye, k), a.at:Lerp(b.at, k)), a.fov + (b.fov - a.fov) * k
		end
	end
	return CFrame.lookAt(last.eye, last.at), last.fov
end

-- The intro of a new life. `start` is where the spider is put when it begins (just inside the crack, facing out: the game's spawn heading); it walks out
-- (the motor's own walk, `walk`) from `walk.from` until it is past `walk.untilX` or `walk.latest` has come. `skipAfter`: the skip is refused before it.
-- The captions are UI/TitleText.captions' three, each faded in and out over `captionFade`; the last outlives the intro by a few seconds, over the game.
TitleShots.INTRO = {
	skipAfter = 2.0,
	fadeIn = 0.8,
	start = { pos = v(-25.2, 0.31, 6.0), heading = v(1, 0, 0) },
	walk = { from = 7.4, untilX = -21.6, latest = 11.5 },
	shots = {
		{ name = "glass", t0 = 0, t1 = 3.8, eye0 = v(-15.0, 1.0, 10.5), eye1 = v(-17.0, 0.9, 9.0), at0 = v(-5.0, 4.6, -12.6), at1 = v(-8.0, 4.3, -12.6), fov = 55 },
		{ name = "sill", t0 = 3.8, t1 = 7.4, eye0 = v(-9.5, 0.85, 4.2), eye1 = v(-16.8, 0.7, 5.4), at0 = v(-24.5, 0.6, 6.0), at1 = v(-24.8, 0.55, 6.0), fov = 50 },
		{ name = "out", t0 = 7.4, t1 = 12.2, eye0 = v(-17.6, 0.75, 9.2), eye1 = v(-18.4, 0.7, 8.8), at0 = v(-24.6, 0.5, 6.0), at1 = v(-21.8, 0.5, 6.0), fov = 46, follow = true },
	} :: { Shot },
	blend = { t0 = 12.2, t1 = 13.6 },
	total = 13.6,
	captions = { { t0 = 4.2, t1 = 8.2 }, { t0 = 8.6, t1 = 11.8 }, { t0 = 12.2, t1 = 16.0 } },
	captionFade = 0.6,
	captionsEnd = 16.0,
}

-- ROBLOX-118: in the preserve the intro opens inside the ranger hut: from the room, low over the sill's front edge, the morning coming in through the hut's window
-- over the sill (the sill, its crack and the spider's walk out of it are the same in both worlds: the sill is the same sill at the origin). The other shots are the same.
TitleShots.PRESERVE_GLASS = { name = "glass", t0 = 0, t1 = 3.8, eye0 = v(-4.0, 9.0, 34.0), eye1 = v(-9.0, 6.5, 24.0), at0 = v(0.0, 16.0, -14.0), at1 = v(-3.0, 9.0, -13.0), fov = 58 } :: Shot

-- The intro's shots in a world (the Workspace attribute World): the preserve's opens in the hut; any other world's (or none) is the shared list.
function TitleShots.introShots(world: string?): { Shot }
	local shots: { Shot } = TitleShots.INTRO.shots
	if world ~= "preserve" then return shots end
	local out = table.clone(shots)
	out[1] = TitleShots.PRESERVE_GLASS
	return out
end

-- One frame of the intro at `t` seconds. `reduced`: Reduced Motion. `spider`: where the spider's body is now (the "out" shot looks at it; the planned
-- path when nil). `blend` is how far the view has eased into the game's camera (0 none, 1 all of it; the caller lerps); `holding` is whether the intro
-- still has the camera and the controls, `done` whether everything, the last caption included, is over.
function TitleShots.intro(t: number, reduced: boolean, spider: Vector3?, world: string?): Frame
	local I = TitleShots.INTRO
	local shots: { Shot } = TitleShots.introShots(world) -- (ROBLOX-118: `world` the Workspace attribute World; the preserve's opens in the hut)
	local shot = shots[#shots]
	for _, s in shots do
		if t < s.t1 then shot = s; break end
	end
	local k = if reduced then 0.5 else smooth((t - shot.t0) / (shot.t1 - shot.t0))
	local eye = shot.eye0:Lerp(shot.eye1, k)
	local at = shot.at0:Lerp(shot.at1, k)
	if shot.follow and spider ~= nil then at = spider + v(0, 0.2, 0) end
	local caption: number? = nil
	local alpha = 0
	for i, c in I.captions do
		if t >= c.t0 and t < c.t1 then
			caption = i
			alpha = math.min(1, (t - c.t0) / I.captionFade, (c.t1 - t) / I.captionFade)
		end
	end
	local blend = if reduced then (if t >= I.blend.t1 then 1 else 0) else smooth((t - I.blend.t0) / (I.blend.t1 - I.blend.t0))
	return {
		cframe = CFrame.lookAt(eye, at), fov = shot.fov, shot = shot.name,
		veil = 1 - math.clamp(t / I.fadeIn, 0, 1),
		caption = caption, captionAlpha = math.clamp(alpha, 0, 1),
		blend = blend,
		walking = t >= I.walk.from and t < I.walk.latest,
		holding = t < I.total,
		done = t >= I.captionsEnd,
	}
end

-- The frames tools/preview/scene.py --title renders (and tests/title.luau keeps clear of the world's boxes): the drift's start, middle and arrival, and
-- each intro shot's middle, the "out" shot with the spider where its walk ends.
function TitleShots.views(): { { name: string, eye: Vector3, at: Vector3, fov: number } }
	local out = {}
	for _, key in TitleShots.DRIFT do
		table.insert(out, { name = `title_drift_{key.t}`, eye = key.eye, at = key.at, fov = key.fov })
	end
	for _, s in TitleShots.INTRO.shots do
		table.insert(out, { name = `intro_{s.name}`, eye = s.eye0:Lerp(s.eye1, 0.5), at = s.at0:Lerp(s.at1, 0.5), fov = s.fov })
	end
	return out
end

-- ROBLOX-115: the preserve's drift's three keys as the previewer's views (tools/preview/scene.py --preserve): preserve_drift_0, _18 and _36.
function TitleShots.preserveViews(): { { name: string, eye: Vector3, at: Vector3, fov: number } }
	local out = {}
	for _, key in TitleShots.PRESERVE_DRIFT do
		table.insert(out, { name = `preserve_drift_{key.t}`, eye = key.eye, at = key.at, fov = key.fov })
	end
	-- (ROBLOX-118) and the preserve's first shot of the intro, in the hut
	local g = TitleShots.PRESERVE_GLASS
	table.insert(out, { name = "preserve_intro_glass", eye = g.eye0:Lerp(g.eye1, 0.5), at = g.at0:Lerp(g.at1, 0.5), fov = g.fov })
	return out
end

return TitleShots
