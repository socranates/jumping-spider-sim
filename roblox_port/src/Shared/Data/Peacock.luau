--!strict
-- The peacock spider's courtship dance (ROBLOX-29): every number the dance needs, each marked DOC (reported in the paper) or ART
-- (artistic: not reported, chosen to read well on a small screen). The dance is presentation only: a pose for the drawn spider,
-- never a change to the motor, the senses, the jump or the silk.
--
-- Source: Girard, M. B., Kasumovic, M. M. & Elias, D. O. (2011). Multi-Modal Courtship in the Peacock Spider, Maratus volans
-- (O.P.-Cambridge, 1874). PLoS ONE 6(9): e25390 (PMC3181266). Rates are mean +- SD of the paper's high-speed video and laser
-- vibrometer records. Order in the paper: rumble-rumps and bobbing on approach, then leg waving with fan dancing, fan-flapping in
-- the pauses, then a pre-mount display and a mounting attempt. The last two are left out on purpose: this is a family game.
-- A real courtship lasts 6 to 51 minutes (mean 24.35, DOC); `loopSeconds` squeezes one round of it into a loop a player can watch.

local Peacock = {}

export type Phase = {
	id: string, seconds: number, ease: number?, rumble: number?,
	pitch: number, open: number, legs: number, sway: number, wave: number, flap: number, bob: number, palp: number,
}

Peacock.id = "maratus_volans_male"
Peacock.citation = "Girard, Kasumovic & Elias 2011, PLoS ONE 6(9): e25390"

-- Real courtship length in minutes (DOC: range 6 to 51, mean 24.35). The game's loop is ART.
Peacock.courtshipMinutes = { min = 6, max = 51, mean = 24.35 }
Peacock.loopSeconds = 14.0 -- ART: one compressed round of the display (the phases below add up to it)

-- ---------------------------------------------------------------- rates: DOC
-- Hz = cycles (or flicks, waves, flaps, bumps) per second; sd is the paper's standard deviation, kept for the docs and tests.
Peacock.rates = {
	palpFlicker = { hz = 3.5, sd = 1.6 }, -- pedipalps flicker up and down in unison (DOC)
	fanDance = { hz = 3.2, sd = 1.5 }, -- abdomen sways side to side with the fan raised (DOC)
	legWave = { hz = 3.2, sd = 0.6 }, -- legs III wave (DOC)
	fanFlap = { hz = 2.5, sd = 1.8 }, -- the fan flaps in and out during the pauses (DOC)
	-- Opisthosomal bobbing comes in bouts; the paper gives no rate. ART:
	bob = { hz = 4.0, boutSeconds = 0.8, restSeconds = 0.5 },
}
-- Rumble-rumps: vibrations through the substrate (felt, not seen). 2.44 +- 0.28 s long, 12.1 +- 2.9 bumps a second (DOC).
Peacock.rumble = { seconds = 2.44, sd = 0.28, bumpsHz = 12.1, bumpsSd = 2.9, edgeSeconds = 0.12 }
-- The fan dance sweeps the abdomen over an arc of 19 to 35 degrees (DOC); the game uses the middle of the range.
Peacock.fanArcDeg = { min = 19, max = 35, used = 27 }

-- ---------------------------------------------------------------- amplitudes: ART (the paper reports none of these)
Peacock.amplitude = {
	raiseDeg = 80, -- how far the abdomen pitches up (rear end up) to show the fan
	bobDeg = 6, -- the abdomen's bob, either side of its pitch
	shiverDeg = 1.2, -- the abdomen's visible tremble at 12.1 bumps a second during a rumble-rump
	waveDeg = 38, -- how far legs III sweep down in a wave
	flapDepth = 0.45, -- the fan closes to this much narrower (0.45: down to 55 % of its width) at the bottom of a flap
	palpDeg = 22, -- the pedipalps' flick
}

-- ---------------------------------------------------------------- the phases (ART: the order is DOC, the times are ART)
-- Each phase eases the levels from the previous phase's (the last phase's, for the first) over `ease` seconds, then holds them.
-- Levels run 0..1: pitch (the abdomen raised: 1 is amplitude.raiseDeg), open (the fan), legs (legs III up), sway (the fan dance),
-- wave (legs III waving), flap (fan-flapping), bob (bobbing bouts), palp (the pedipalps' flicker). `rumble` starts a rumble-rump
-- `at` seconds into the phase and lasts Peacock.rumble.seconds.
Peacock.ease = 0.45
Peacock.phases = {
	{ id = "approach", seconds = 3.2, ease = 0.4, pitch = 0, open = 0, legs = 0, sway = 0, wave = 0, flap = 0, bob = 1, palp = 0.6, rumble = 0.4 },
	{ id = "raise", seconds = 1.3, ease = 1.1, pitch = 1, open = 1, legs = 1, sway = 0, wave = 0, flap = 0, bob = 0, palp = 0.4 },
	{ id = "dance", seconds = 3.4, ease = 0.4, pitch = 1, open = 1, legs = 1, sway = 1, wave = 1, flap = 0, bob = 0, palp = 1 },
	{ id = "freeze", seconds = 2.2, ease = 0.35, pitch = 1, open = 1, legs = 1, sway = 0, wave = 0, flap = 1, bob = 0, palp = 0.5 },
	{ id = "dance_again", seconds = 2.6, ease = 0.35, pitch = 1, open = 1, legs = 1, sway = 1, wave = 1, flap = 0, bob = 0, palp = 1 },
	{ id = "fold", seconds = 1.3, ease = 1.0, pitch = 0, open = 0, legs = 0, sway = 0, wave = 0, flap = 0, bob = 0, palp = 0.2 },
} :: { Phase }

-- ---------------------------------------------------------------- starting and stopping (ART)
Peacock.rampInSeconds = 0.25 -- the pose arrives
Peacock.fadeOutSeconds = 0.2 -- a stop (a step, a jump, leaving the surface) eases the pose out over this long
Peacock.reducedMotion = 0.5 -- ReducedMotion halves the sway, wave, flap, bob and flick amplitudes and stops the tremble

-- ---------------------------------------------------------------- the words (felt, not seen)
Peacock.feltCaption = "[a fine buzzing through your feet]"

return Peacock
