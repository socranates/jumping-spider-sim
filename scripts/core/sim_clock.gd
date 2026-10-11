extends RefCounted
## One game clock (ROADMAP step 2; DECISIONS T9e-01, CLOCK-01). The simulation always advances in identical ticks of DT (1/60 s of game
## time), and every system counts in those ticks (HZ), never in Engine.physics_ticks_per_second. Game speed changes only how many ticks run
## in a real second: set_speed() sets Engine.physics_ticks_per_second to HZ x speed and Engine.time_scale to speed, so the delta every
## physics tick receives (the engine passes 1 / ticks x time_scale) is still DT. Jumps, the line, the senses, the flies and the needs
## therefore play out exactly as at full speed, tick for tick, only more slowly. Rendering stays smooth through physics interpolation.
## The player's own controls that are not part of the simulation (looking about with a stick, easing the camera back) use real time,
## through real_delta().

const HZ := 60
const DT := 1.0 / 60.0
## The speeds a player can pick for slow motion (spec 7: "optional slow-time assist"). Each gives a whole number of ticks a second.
const SLOW_SPEEDS: Array[float] = [0.25, 0.5, 0.75]

## The engine reads time_scale once, when a frame begins. A change made during a frame (a menu, a script) applies from the next one,
## so for the rest of that frame real_delta() must still divide by the old scale, or a control would jump by the ratio for one frame.
static var _old_scale: float = 1.0
static var _changed_on_frame: int = -1


## Runs the game at `speed` (1.0: normal; 0.25 to 1.0). Played worlds call it; tests reset it to 1.0 afterwards.
static func set_speed(speed: float) -> void:
	var s := clampf(speed, 0.25, 1.0)
	_old_scale = Engine.time_scale
	_changed_on_frame = Engine.get_process_frames()
	Engine.physics_ticks_per_second = maxi(1, roundi(float(HZ) * s))
	Engine.time_scale = float(Engine.physics_ticks_per_second) / float(HZ)
	AudioServer.playback_speed_scale = Engine.time_scale  # T12a: the world's sounds slow (and drop in pitch) with it


static func speed() -> float:
	return Engine.time_scale


## A process-frame delta (scaled by the game speed) turned back into real seconds, for controls that must not slow down.
static func real_delta(delta: float) -> float:
	var scale := _old_scale if Engine.get_process_frames() == _changed_on_frame else Engine.time_scale
	return delta / maxf(scale, 1.0e-3)
