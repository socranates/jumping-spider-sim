--!strict
-- The numbers of the spider-eye picture (ROBLOX-20): how each way of seeing looks, how the two retinae move, how the lateral
-- eyes' sense of movement is drawn and what is shown the first time. Shared/UI/EyeOptics works the pictures out from these and
-- Client/SpiderEyes draws them. Presentation only: nothing here reaches the senses, the motor, the jump planner, the aim ray or
-- where the camera stands. A number that is a choice and not a measurement says so. Nothing here has been seen in Roblox Studio.
--
-- What the picture leans on (related species, not measured in the player's Phidippus audax unless a line says so):
--   * The principal eyes (anterior median, AM) are the high-acuity telephoto pair with a tiny field: the fovea-based field is
--     0.8 degrees (Portia fimbriata) to 5 degrees (Metaphidippus aeneolus) wide and up to 20 degrees tall (Shepeleva 2022,
--     Vision 6(1):2, summarising Land 1969). Each retina is a narrow boomerang- or V-shaped strip moved by three pairs of
--     muscles (side to side, up and down, rotation), so the sharp strip scans a target while the lens stays put (Land 1969,
--     J. Exp. Biol. 51, doi:10.1242/jeb.51.2.471). The retina has four layers, and distance is judged from how defocused the
--     image is on them (Nagata et al. 2012, Science 335:469-471).
--   * The principal eyes of Phidippus have a UV receptor (about 370 nm) and a green one (about 525-532 nm): possibly
--     dichromatic colour vision (DeVoe 1975, J. Gen. Physiol. 66:193-207, Phidippus regius). Several species studied lack a red
--     receptor, so red would look like dark, low-luminance green (Glenszczyk et al. 2022, Sci. Nat. 109:6, Saitis barbipes).
--   * The secondary eyes are the anterior lateral (ALE), the posterior median (often vestigial) and the posterior lateral (PLE).
--     Together they cover about 330 degrees horizontally (Trite planiceps; Shepeleva 2022). Their acuity is much lower (ALE 0.3-1.3
--     cycles per degree, PLE 0.3-0.6) than the AM eyes' (up to 12.5, Portia), and their photoreceptors are almost entirely
--     green-sensitive. The ALEs detect motion and trigger the turn toward it (Zurek et al. 2010, J. Exp. Biol. 213:2372-2378,
--     doi:10.1242/jeb.042382); the PLEs are wide-angle motion detectors.
-- What it does not claim: a spider's colour experience, the receptor responses of this species, or the all-round field. The
-- ultraviolet layer is authored decor shown only through the principal eyes, an illustration and not a measured reflectance
-- (docs/VISION_RESEARCH.md, EYE-14, still applies to prey, glass and leaves). The sensor's own peripheral cone (Species,
-- peripheral_cone_degrees 300) is narrower than the anatomical 330 degrees: the shimmer shows what the sensor found.

local Eyes = {}

Eyes.sources = {
	land1969 = "Land 1969, Movements of the retinae of jumping spiders in response to visual stimuli, J. Exp. Biol. 51 (doi:10.1242/jeb.51.2.471)",
	shepeleva2022 = "Shepeleva 2022, Vision 6(1):2 (summarising Land 1969 and others)",
	nagata2012 = "Nagata et al. 2012, Science 335:469-471 (depth from image defocus between retinal layers)",
	devoe1975 = "DeVoe 1975, J. Gen. Physiol. 66:193-207 (UV and green receptors in the principal eyes of Phidippus regius)",
	glenszczyk2022 = "Glenszczyk et al. 2022, Sci. Nat. 109:6 (no red receptor in Saitis barbipes)",
	zurek2010 = "Zurek et al. 2010, J. Exp. Biol. 213:2372-2378 (the anterior lateral eyes detect motion and trigger the turn)",
}

-- ---------------------------------------------------------------- the two ways of seeing (k = 0 and k = 1)
-- Everything that depends on k is listed here for both ends; EyeOptics.profile blends every number by k (the field of view in
-- tangent space, so the zoom looks even).
-- Side eyes (k = 0): a wide view, almost one colour, a little blurred, and loosely focused. The field of view is a choice: a flat
-- screen cannot show about 330 degrees, so it is a wide 90 degrees vertical. Saturation -0.85 and a clear green tint stand for
-- receptors that are almost all green-sensitive: one kind of receptor, so one colour. Roblox does not document whether the tint
-- is applied before or after the saturation; at -0.85 either order leaves a green picture (tint last: green monochrome; tint
-- first: reds already darkened, then mostly grey with a green cast). Judge it in Studio and tune here. The blur is far gentler than the measured acuity ratio (about 10 to 40 times lower than the
-- AM eyes), so the sill stays readable; it never touches the GUI. The loose depth of field (far 0.35, near 0.25, in focus out to at
-- least 6 studs or 0.6 of the distance looked at) says only that nothing is sharp.
-- Principal eyes (k = 1): a narrow telephoto view, sharp, in green and ultraviolet, with only the looked-at distance in focus
-- (depth from defocus, Nagata 2012). 24 degrees is a choice: just wider than the 20 degrees a retina is tall. The tint cuts red
-- (115 of 255), so reds go dark as for a green-and-UV dichromat; blue is kept as the stand-in for the short-wave (UV) receptor. That
-- is an illustration, not a spectral response. The depth of field is tight (far 0.75, near 0.6, in focus within 0.12 of the
-- distance looked at, never less than 0.6 stud).
-- The retina strips' stroke is faint while the side eyes look and a little stronger once the principal eyes do; `sweepDeg` and `torsionDeg`
-- are how far each strip swings side to side and turns about its middle (scanning with the side eyes, small tracking movements
-- with the principal eyes). The vignette is the telephoto dark edge, as an opacity at the screen's edge.
Eyes.side = {
	fovDeg = 90,
	saturation = -0.85, tint = { 170, 228, 165 }, contrast = 0.12, brightness = 0.03,
	blur = 2.5,
	dofFar = 0.35, dofNear = 0.25, dofRadiusMin = 6, dofRadiusPerStud = 0.6,
	strokeTransparency = 0.82, fillTransparency = 0.96,
	sweepDeg = 4, torsionDeg = 12,
	vignette = 0.35,
}
Eyes.principal = {
	fovDeg = 24,
	saturation = 0.15, tint = { 115, 255, 236 }, contrast = 0.16, brightness = 0.02,
	blur = 0,
	dofFar = 0.75, dofNear = 0.6, dofRadiusMin = 0.6, dofRadiusPerStud = 0.12,
	strokeTransparency = 0.68, fillTransparency = 0.93, -- fainter than first drawn: zoomed in, the strips are large and frame the target
	sweepDeg = 0.6, torsionDeg = 3,
	vignette = 0.55,
}

-- How fast k moves: it runs 0 to 1 in engageSeconds while Focus is held (or toggled on) and back in releaseSeconds. A choice; the
-- time is a duration, not a time constant, so any frame rate gives the same picture after the same time.
Eyes.timing = { engageSeconds = 0.35, releaseSeconds = 0.5 }

-- Reduced motion (Player attribute ReducedMotion = true): the retinae hold still, the shimmer holds steady, and the zoom stops at
-- 45 degrees, a gentler change than 90 to 24.
Eyes.reducedMotion = { minFovDeg = 45 }

-- Depth of field follows what is looked at: a ray along the view, at most maxDistance studs, eased with a time constant so the focus
-- racks from one distance to the next instead of jumping.
Eyes.focus = { maxDistance = 40, tauSeconds = 0.15 }

-- ---------------------------------------------------------------- the retinae
-- Each strip is drawn at its true angular size for the field of view (widthDeg x heightDeg, from Shepeleva 2022 / Land 1969: the
-- widest and the tallest reported), offsetDeg either side of the middle, tilted tiltDeg into a shallow V (the boomerang, Land
-- 1969). Offset and tilt are choices. Scanning (Land 1969: side to side, up and down, rotation) is drawn as a side-to-side sweep
-- and a turn about the strip's middle: the sweep has a period of sweepSeconds and the second strip follows the first lagSeconds
-- later in both movements; the turn has a period of torsionSeconds. The amplitudes are in Eyes.side and Eyes.principal. Land's
-- own periods are slower for the turn (about 5-15 s, up to about 50 degrees; docs/VISION_RESEARCH.md): these are faster and
-- smaller so that the scanning can be seen within a few seconds. They are presentation values.
Eyes.retina = {
	widthDeg = 5, heightDeg = 20, offsetDeg = 3, tiltDeg = 10,
	sweepSeconds = 1.7, lagSeconds = 0.3, torsionSeconds = 2.6,
	strokeColor = { 200, 255, 220 }, strokeThickness = 1.5,
	fillColor = { 200, 255, 220 },
	-- the fill's transparency along the strip, from one end to the other (more see-through toward the ends)
	fillRamp = { { 0, 0.6 }, { 0.5, 0 }, { 1, 0.6 } },
}

-- ---------------------------------------------------------------- the lateral eyes' sense of movement
-- A thing the sensor's sight-line checks found moving (Sensor.motionSeen, the T13a record the eye picture reads and nothing else
-- does) gets a ring where it is on screen, pulsing between scaleMin and scaleMax times its apparent size (never less than minPx
-- across), faded over the sensor's hold (Sensor.MOTION_HOLD_TICKS), and at alpha x insideStripFactor where it lies inside a
-- retina strip: the principal eyes see form there, the surround sees movement (Zurek 2010; Godot EYE-10). Off screen it shows as a
-- short arc at the screen's edge toward it. At most maxMovers at once, freshest first. The pulse is at or under the 3 Hz flash
-- guideline over a small area, and holds steady with reduced motion. The look (light ring with a dark outline so it reads on bright
-- and dark ground) is a choice.
Eyes.shimmer = {
	hz = 3, scaleMin = 1.0, scaleMax = 1.6, minPx = 14, maxMovers = 8,
	alpha = 0.9, insideStripFactor = 0.3,
	ringColor = { 226, 255, 232 }, ringThickness = 2,
	shadowColor = { 8, 20, 12 }, shadowThickness = 1.5, shadowAlpha = 0.6, shadowGrowPx = 2, -- the dark ring sits just outside the light one
	-- the edge arc: `segments` short bars `stepDeg` apart along a circle of `radius` px whose outermost point is `inset` px
	-- from the screen's edge, in the direction of the thing; alpha breathes with the pulse by `breath`
	arc = { inset = 20, radius = 56, segments = 5, stepDeg = 8, length = 10, thickness = 3.5, alpha = 0.85, breath = 0.25 },
}

-- ---------------------------------------------------------------- the telephoto vignette
-- Four edge frames, each darkest at the screen's edge and clear toward the middle. The peak opacity is in Eyes.side and
-- Eyes.principal. `ramp` is the gradient's transparency from the edge inward; the bands are fractions of the screen's height
-- (top and bottom) and width (left and right).
Eyes.vignette = {
	color = { 8, 20, 12 },
	ramp = { { 0, 0 }, { 0.25, 0.35 }, { 0.55, 0.75 }, { 1, 1 } },
	topBottom = 0.22, leftRight = 0.16,
}

-- ---------------------------------------------------------------- the words, the first time
-- Shown the first time the eye view is open (for `seconds` of it; leaving pauses it), under the status lines, fading in and out.
-- %s is "Hold" or "Press" (a toggled Focus) and then the Focus key or button of the device in use (ControlText).
Eyes.caption = {
	seconds = 6, fadeInSeconds = 0.4, fadeOutSeconds = 1.5,
	side = "Spider-eye view: the side eyes see wide, mostly in green, and catch movement.",
	principal = "%s %s for the principal eyes: narrow, sharp, telephoto, in green and ultraviolet (shown as violet).",
	hold = "Hold", toggle = "Press",
}

-- ---------------------------------------------------------------- the ultraviolet layer
-- Workspace.Decor.UVLayer holds parts drawn only for the principal eyes (flower petal patterns), each fully transparent with a
-- number attribute UVOpacity (the folder's own is the fallback). In the eye view a part's Transparency is 1 - k x UVOpacity on
-- this client only; outside it, 1. The folder is looked up at most every lookupSeconds until it exists.
Eyes.uv = { folder = { "Decor", "UVLayer" }, opacityAttribute = "UVOpacity", lookupSeconds = 1 }

-- ---------------------------------------------------------------- where it lives
-- The overlay sits under the jump reticle, the prompts and the perception HUD (DisplayOrder 4): SpiderHud's screens have the default
-- order 0, so the overlay's is below that.
Eyes.overlay = { name = "EyeOverlay", displayOrder = -5 }
Eyes.effects = { grade = "EyeGrade", blur = "EyeBlur", dof = "MacroDOF" }

return Eyes
