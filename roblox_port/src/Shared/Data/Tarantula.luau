--!strict
-- The tarantulas' threat display and silk mat (ROBLOX-82): every number the pose needs. The pose is presentation only: it bends and
-- turns the drawn spider; it never changes the motor, the collider, the path, the speed, the jump, the senses, the dragline, the wasp or
-- the rival. Unlike the peacock's dance (Girard et al. 2011) and the ant mimic's walk (Shamble et al. 2017) there is no measured record
-- behind these numbers: nothing below is a rate or an angle from a paper, and every one is marked ART (artistic: chosen to read well on a
-- small screen, from what is generally known of the behaviour, which this round did not check against a source; see
-- docs/NOTEBOOK_SOURCES.md for what the notebook page rests on).
--
-- What the pose draws, as general knowledge of New World tarantulas (the pack's two species both are): a threatened tarantula rears up on
-- its hind legs, raising the front of the body, lifting the first pair of legs and the pedipalps and showing its fangs, and holds the
-- posture; and tarantulas lay silk by drawing their spinnerets over the ground, in sheets and mats. The game's loop puts the two side by
-- side: the rear-up, a settle, then a turn about on the spot with the spinnerets swinging side to side as if laying a mat, and back.
-- The tarantula is a costume on the jumping spider's body (ROBLOX-81), so the display is a drawn pose and nothing more.

local Tarantula = {}

Tarantula.pack = "tarantula_pack"
Tarantula.ids = { "brachypelma_hamorii", "chromatopelma_cyaneopubescens" } :: { string }

-- ---------------------------------------------------------------- the loop (ART)
-- One loop is 6 seconds, in order; it repeats until the player ends it. Every level starts and ends the loop at 0, so the repeat has no jump.
--   rear   the prosoma pitches up and legs I and the pedipalps lift (the rise);
--   threat the posture is held, with a faint tremble of the raised legs;
--   settle the prosoma comes back down and legs I and the pedipalps lower;
--   turn   the drawn body pivots about its up axis, 0 to 180 degrees, the spinnerets swinging side to side;
--   mat    the body holds at 180 degrees, spinnerets still swinging;
--   return the body pivots back to 0 as the swing dies away.
Tarantula.loopSeconds = 6.0
Tarantula.phases = {
	{ id = "rear", seconds = 0.5 },
	{ id = "threat", seconds = 2.2 },
	{ id = "settle", seconds = 0.5 },
	{ id = "turn", seconds = 1.2 },
	{ id = "mat", seconds = 0.4 },
	{ id = "return", seconds = 1.2 },
} :: { { id: string, seconds: number } }

-- ---------------------------------------------------------------- amplitudes and rates (ART)
Tarantula.rearDeg = 32 -- how far the prosoma pitches up about the waist
Tarantula.palpDeg = 55 -- how far each pedipalp lifts at its base (the palp is leg-like, so it comes up with legs I)
Tarantula.pivotDeg = 180 -- how far the body turns about its up axis
Tarantula.sweepDeg = 25 -- how far the spinnerets swing either side of straight back (the second segment swings `tipSweep` times as far: the profile's `threat`)
Tarantula.sweepHz = 1.4 -- the swing's rate (a slow stroke: never above 3 Hz, nothing that flashes)
Tarantula.sweepEaseSeconds = 0.3 -- the swing arrives and leaves over this long at the ends of the turn
Tarantula.tremorHz = 2.2 -- the raised legs' faint tremble in the hold (its size is the profile's `threat.tremor`)
Tarantula.rampInSeconds = 0.1 -- a pose given after a stop does not start with a jump
Tarantula.fadeOutSeconds = 0.25 -- an ended pose eases out over this long and the legs go back to the motor
Tarantula.reducedMotion = 0.5 -- ReducedMotion halves every angle and stops the tremble; the posture still shows

return Tarantula
