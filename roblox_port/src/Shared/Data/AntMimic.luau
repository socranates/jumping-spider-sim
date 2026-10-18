--!strict
-- The ant-mimicking jumping spider's walk and antennae (ROBLOX-64): every number the pose needs, each marked DOC (reported in the
-- paper) or ART (artistic: not reported, chosen to read well on a small screen). The pose is presentation only: it bends the drawn
-- legs and turns the drawn body a little; it never changes the motor, the collider, the path, the speed, the jump, the senses or the
-- wasp. The real animal's path is a sine-like trail (wavelength about ten body lengths); the game's spider goes where the player
-- sends it, so the zigzag is drawn on the body and not walked.
--
-- Source: Shamble, P. S., Hoy, R. R., Cohen, I. & Beatus, T. (2017). Walking like an ant: a quantitative and experimental approach to
-- understanding locomotor mimicry in the jumping spider Myrmarachne formicaria. Proceedings of the Royal Society B 284: 20170308.
-- doi:10.1098/rspb.2017.0308. What it reports, and the game uses:
--   * the mimic walks on all eight legs; when stationary the forelegs (legs I) are raised above head height and move in phase, like
--     ant antennae (the "antennal illusion"); when moving they work as legs;
--   * the mimic makes only short stops, 83.3 +- 82.6 ms on average, so to an observer it seems to move almost constantly, like an ant
--     (a non-mimic jumping spider such as Salticus scenicus is stationary about 55 % of the time; ants about 5 to 10 %);
--   * its path is sine-like, wavelength about ten body lengths (range 5 to 10), amplitude about five body lengths, statistically like
--     a trail-following ant;
--   * in playbacks to Phidippus audax (the genus of the game's first spider) as the predator, non-mimic spider targets were attacked
--     4.5 times as often as ants and 3 times as often as mimics; ants and mimics did not differ (protective Batesian mimicry);
--   * the playback target's body length was 5 mm.
-- The drawn animal is the female (the male's chelicerae are enormous and point forward: a possible later variant).

local AntMimic = {}

AntMimic.id = "myrmarachne_formicaria_female"
AntMimic.citation = "Shamble, Hoy, Cohen & Beatus 2017, Proc. R. Soc. B 284: 20170308 (doi:10.1098/rspb.2017.0308)"

-- ---------------------------------------------------------------- reported: DOC
AntMimic.bodyLengthMm = 5 -- the playbacks' body length (DOC); 1 stud = 1 cm, so the drawn spider is 0.5 studs long
AntMimic.bodyLengthStuds = 0.5
AntMimic.walkingLegs = 8 -- DOC: all eight legs walk
AntMimic.stops = { meanMs = 83.3, sdMs = 82.6 } -- DOC: the mimic's stops are this short
AntMimic.stationaryShare = { nonMimicSpider = 0.55, antLow = 0.05, antHigh = 0.10 } -- DOC: share of the time stationary (S. scenicus about 55 %, ants 5 to 10 %)
AntMimic.path = { wavelengthBodyLengths = { min = 5, max = 10, used = 10 }, amplitudeBodyLengths = 5 } -- DOC: the real path; the game draws only the wavelength
AntMimic.playback = { predator = "Phidippus audax", nonMimicVsAnt = 4.5, nonMimicVsMimic = 3.0 } -- DOC: times attacked more than ants, and than mimics

-- ---------------------------------------------------------------- artistic: ART (the paper reports none of these)
-- Antennae: legs I raised above head height and waving in phase. The paper gives no wave rate; both rates stay at or below 3 Hz
-- (a slow, calm flutter, and nothing that flashes).
AntMimic.antennae = {
	delaySeconds = 0.25, -- how long the spider must keep still before the legs go up (no twitching on a key tap)
	riseSeconds = 0.25, -- the legs go up over this long
	fallSeconds = 0.12, -- and come down this fast when it moves (legs I are legs again)
	waveHz = 1.6, -- waving rate, resting
	waveAmount = 0.55, -- how much of the foot's path from "up" to "swept" a wave covers, resting (0..1)
	highWaveHz = 3.0, -- the display key: waving faster
	highWaveAmount = 1.0, -- and wider
	highRaise = 1.0, -- and the legs lift to their highest
}
-- The drawn walk: the body's yaw and sideways sway follow the distance walked (so slow motion and frame rate change nothing but speed).
-- The wavelength is DOC (ten body lengths); the drawn sizes are ART and small, because the real path cannot change.
AntMimic.walk = {
	yawDeg = 12, -- ART: the drawn body turns this far either side of its heading
	lateralStuds = 0.04, -- ART: and sways this far to either side (0.08 body lengths)
	easeInSeconds = 0.15, easeOutSeconds = 0.25, -- ART: the wobble arrives and leaves over these
	stopHoldSeconds = AntMimic.stops.meanMs / 1000, -- DOC value, used as the drawn rule: a stop shorter than 83.3 ms is not drawn as a pause
	teleportStuds = 2.0, -- ART: a step longer than this in one frame is a respawn or a return, not a walk
}
AntMimic.reducedMotion = 0.5 -- ReducedMotion halves the yaw and the sway and stops the waving (the legs stay up)
AntMimic.noticeSeconds = 1.0 -- ART: with the antennae fully up this long, the notebook opens its page

return AntMimic
