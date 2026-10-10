extends "res://tests/test_case.gd"
## The words of the perception presentation (spec 17): plain, never a percentage, never a species, and kept apart from the
## sensor and the memory (19.3).

const Observation = preload("res://scripts/perception/observation.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const PerceptionText = preload("res://scripts/presentation/perception_text.gd")


func test_the_three_categories_have_their_words() -> void:
	check_eq(PerceptionText.category(Observation.MOVEMENT), "movement", "movement")
	check_eq(PerceptionText.category(Observation.POSSIBLE_PREY), "possible prey", "possible prey")
	check_eq(PerceptionText.category(Observation.FLY_LIKE_PREY), "fly-like prey", "fly-like prey")
	check_eq(PerceptionText.LOST, "lost sight", "and the words for a loss")


func test_an_unknown_category_is_called_movement_the_safest_thing_to_say() -> void:
	check_eq(PerceptionText.category(&"dragon"), "movement", "unknown")
	check_eq(PerceptionText.category(&""), "movement", "empty")


func test_no_word_has_a_number_or_a_species_in_it() -> void:
	var words: Array[String] = [PerceptionText.LOST, PerceptionText.SETTING_LAST_SEEN, PerceptionText.SETTING_GAZE]
	for c: StringName in [Observation.MOVEMENT, Observation.POSSIBLE_PREY, Observation.FLY_LIKE_PREY]:
		words.append(PerceptionText.category(c))
	for w in words:
		check(not PerceptionText.has_number(w), "\"%s\" has no digit or percent sign" % w)
		check(w.to_lower().find("fly") < 0 or w == "fly-like prey", "\"%s\" names no species" % w)
	check(PerceptionText.has_number("37%"), "the number check sees a percent sign")
	check(PerceptionText.has_number("prey 2"), "and a digit")
	check(not PerceptionText.has_number("possible prey"), "and lets plain words through")


func test_a_contacts_label_is_its_category_while_live_and_lost_sight_after() -> void:
	check_eq(PerceptionText.label_for(null), "", "nothing for no contact")
	var c := ObservationMemory.Contact.new()
	c.category = Observation.POSSIBLE_PREY
	check_eq(PerceptionText.label_for(c), "possible prey", "live")
	c.state = ObservationMemory.Contact.LOST
	check_eq(PerceptionText.label_for(c), "lost sight", "lost")
