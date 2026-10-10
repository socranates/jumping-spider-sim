extends RefCounted
## What may be sensed (spec 7, 19.3). A node that can be perceived joins the group GROUP and answers get_percept() with
## a percept: the world's truth about itself, which only the SensorSystem reads, and only to decide what the observer's
## senses can pick up. The observer never keeps a percept: it keeps the Observation records the sensor makes from it.
##
## A percept is a Dictionary:
##   id           persistent id of the thing (the sensor files its evidence under an opaque track id, not this)
##   position     world position of its centre
##   radius       WU; its apparent size is the size of a sphere of this radius
##   velocity     WU/s, for the motion that makes a peripheral cue
##   max_category the finest category its appearance can ever be refined to (Observation.FLY_LIKE_PREY for something
##                that looks like easy prey up close, Observation.MOVEMENT for something that never looks like more)
## An empty Dictionary means the thing is not there to be sensed.

const Observation = preload("res://scripts/perception/observation.gd")

const GROUP := &"perceivable"


static func make(id: String, position: Vector3, radius: float, velocity: Vector3, max_category: StringName = Observation.FLY_LIKE_PREY) -> Dictionary:
	return {"id": id, "position": position, "radius": radius, "velocity": velocity, "max_category": max_category}
