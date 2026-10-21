--!strict
-- The quiet HUD (ROBLOX-113, W5 of docs/OPEN_WORLD_DESIGN.md): what the screen may say in Normal. Nathan: "minimal HUD", "no hand holding", "Normal mode should feel
-- like it doesn't want you to survive". Every string the game can put on the screen during play is one of the kinds below, and each kind has a class:
--
--   needed   always shown: the hunger bar, the day line, what the senses report (the sound captions), the answer to a press, a state the world cannot show
--   day_one  in Normal only on the life's first day (the first day of a new life, or of a spiderling's generation); the gentle modes always
--   gentle   never in Normal; Easy and Free play as before
--   removed  never shown in any mode (none at present: the gentle modes keep every word they had)
--
-- Easy and Free play keep their helpfulness: in the gentle rules every kind shows, as it did. The player's own settings still apply on top ("Show control hints",
-- Captions, "Show what the spider notices", the notebook's notes). Nothing is added for the garden: the day line does not name the region (the decision is
-- ROBLOX-113's: the regions are seamless, their names are the map's, and a label on the world is what Nathan's minimal HUD leaves out).
-- The perception HUD's labels are calmed here too (`calmLabels`): one at a time in an area of the screen, the newest winning, and "lost sight" gone in a breath.
-- Pure: checked in tests/quiet.luau, which also drives the real client. docs/HUD_AUDIT.md lists every string with its kind.
local QuietHud = {}

export type Class = "needed" | "day_one" | "gentle" | "removed"
export type Context = { normal: boolean, dayOne: boolean }

QuietHud.game = {
	labelAreaPx = 120, -- two perception labels whose rings are closer than this on the screen are one area: only one is drawn
	lostSeconds = 1.0, -- "lost sight" fades out over this (the view's own fade is 2.5 s, Godot's; the calm makes it a breath)
}

-- Every kind of thing the play screen can say, its class, and where it shows (for the audit, docs/HUD_AUDIT.md, and the tests).
QuietHud.KINDS = {
	-- the top column: the hunger bar and the day box
	hunger = { class = "needed", where = "hunger bar", what = "Hunger 72% (· hungry, · starving, · gentle)" },
	day = { class = "needed", where = "day line", what = "Day 2, afternoon | Juvenile (| EASY, | FREE PLAY, | Generation 2)" },
	growth_count = { class = "needed", where = "day box", what = "Next moult: 2 of 5 meals; Ready to moult" },
	growth_rule = { class = "day_one", where = "day box", what = "· 3 gnats = 1 housefly; Ready to moult: rest in the crack.; Moulting: stay in the crack.; Adult: keep your hunger bar full." },
	starving_weak = { class = "needed", where = "day box", what = "Starving: your spider will not last another day. Too hungry to sleep; find food." },
	hunger_words = { class = "day_one", where = "day box", what = "Starving: your spider's reserve is gone. It must eat soon.; Hungry: time to hunt." },
	dusk_words = { class = "day_one", where = "day box", what = "Evening. Jumping spiders go into their silk retreat before dark.; It is dark, and your eyes reach only a little way. Home is ..." },
	soft_skin = { class = "gentle", where = "day box", what = "Soft new skin: slower steps and shorter jumps until it hardens." },
	notebook_note = { class = "needed", where = "day box", what = "New in your notebook: <page>" },
	notebook_open_hint = { class = "day_one", where = "day box", what = "(N to read)" },
	prey_note = { class = "needed", where = "day box", what = "The moth slipped free, leaving scales in your fangs.; A foul fluid wells from the ladybird's leg joints. You let it go. ..." },
	-- the top column: the status lines
	wasp_line = { class = "gentle", where = "status", what = "A deep hum outside: a wasp is coming ... Hide in the crack ...; The wasp has seen you! Get away ...; The wasp is leaving." },
	save_broken = { class = "needed", where = "status", what = "Saving is off" },
	court_line = { class = "gentle", where = "status", what = "A visitor is on the sill. Walk close to it.; Courting: dance in front of it (X); Courting 45%: face it and keep still" },
	skip_line = { class = "needed", where = "status", what = "Space or Q: part (the mating scene, once it can be skipped)" },
	guard_line = { class = "gentle", where = "status", what = "Guarding the eggs: day 1 of 2. Rest in the crack to pass the nights." },
	feeding_lines = { class = "day_one", where = "status", what = "Caught — tap Space to keep your grip; Feeding — move to stop; Meal paused — E to eat; Holding the rival — tap Space ...; Eating rival — stay still (2 meals)" },
	display_status = { class = "day_one", where = "status", what = "COURTSHIP DANCE    X or move: stop; ANTENNAE UP ...; THREAT DISPLAY ..." },
	focus_status = { class = "needed", where = "status", what = "FOCUS ON    Right mouse again to stop / Q (the Focus toggle setting)" },
	eye_status = { class = "day_one", where = "status", what = "SPIDER-EYE VIEW    V: back" },
	slow_status = { class = "needed", where = "status", what = "SLOW MOTION 50%    T: normal speed" },
	-- the top column: captions and notices
	eye_caption = { class = "day_one", where = "caption", what = "the spider-eye view's explanation, the first time it is opened" },
	sound_captions = { class = "needed", where = "caption", what = "[a deep, heavy hum outside, ahead-left, coming closer]; [a fine buzzing through your feet]; the mating and hatching scenes' captions (the Captions setting)" },
	notice = { class = "needed", where = "notice", what = "the life's notices not listed in NOTICES: Last rest kept.; Moulted: now a ...; the mate's and the rival's events; A cold night in the open ...; Your spider is an adult! ..." },
	-- toasts: what a jump or the line did (the kinds Motor and JumpInput report)
	["toast:refused"] = { class = "day_one", where = "toast", what = "Jump cancelled: too far or too high (the aim's words said it before the release)" },
	["toast:hop_refused"] = { class = "day_one", where = "toast", what = "No hop: nothing to land on ahead" },
	["toast:cancelled"] = { class = "day_one", where = "toast", what = "Jump cancelled" },
	["toast:out_of_bounds"] = { class = "needed", where = "toast", what = "Out of bounds: back to the last safe spot" },
	["toast:caught"] = { class = "day_one", where = "toast", what = "Caught by your line" },
	["toast:drop_walk"] = { class = "day_one", where = "toast", what = "To the edge, to let yourself down" },
	["toast:dropped"] = { class = "day_one", where = "toast", what = "Letting yourself down: hold F to lower, W to climb" },
	["toast:drop_refused"] = { class = "needed", where = "toast", what = "Nothing below to let yourself down into from here; This surface won't hold your silk; Couldn't get to the edge" },
	["toast:completed"] = { class = "day_one", where = "toast", what = "Holding on again. The line stays behind for a moment" },
	["toast:released"] = { class = "day_one", where = "toast", what = "You let go of the line" },
	["toast:lost"] = { class = "needed", where = "toast", what = "Your line came loose: its anchor is gone" },
	["toast:blocked"] = { class = "needed", where = "toast", what = "Can't reel in: something is in the way. Lower, or let go; Reeled in as far as it goes" },
	["toast:snagged"] = { class = "needed", where = "toast", what = "The line is caught on a second edge and can't be reeled in. Lower, or let go" },
	toast_answer = { class = "needed", where = "toast", what = "the answer to a press or a choice: You are the peacock spider now; Stand still on a surface to dance; the close look's refusals and framings; the save's status; the returns to a rest; Generation 2 — hatched on day 5; The dry leaf tip gave way ..." },
	-- the prompt panel at the bottom
	line_panel = { class = "day_one", where = "prompt", what = "On your line / W: reel in    S: lower    hold Q: let go" },
	line_cue = { class = "needed", where = "prompt", what = "Letting go... 40%; the line's blocks and snags" },
	edge_walk_hint = { class = "day_one", where = "prompt", what = "To the edge, to let yourself down    Q or move: stop" },
	rest_state = { class = "needed", where = "prompt", what = "Asleep in the silk-lined crack; Resting under the stone; Moulting in the silk-lined crack; Ready to moult (the titles)" },
	rest_prompt = { class = "day_one", where = "prompt", what = "The silk-lined crack / E: rest; the hints under the titles (Move, E or Q to wake; C: become ...; the display key)" },
	home_line = { class = "day_one", where = "prompt", what = "Home: the silk-lined crack / Walk through the silk-framed opening under the wooden roof, then stop to rest." },
	walk_hint = { class = "day_one", where = "prompt", what = "Tap Space: hop    hold Space: aim a leap    F: let yourself down on silk (and the setting Show control hints)" },
	controls_card_start = { class = "day_one", where = "card", what = "the controls card for 20 s at the start (and the setting Show control hints)" },
	controls_card_asked = { class = "needed", where = "card", what = "the controls card when asked for: H, or Menu then Controls" },
	close_look = { class = "needed", where = "prompt", what = "the close look's name line and its one line of controls (the player opened it)" },
	-- the words at the aim
	aim_title = { class = "needed", where = "aim", what = "Reachable; Out of reach: too far or too high; No surface in view" },
	aim_hint = { class = "day_one", where = "aim", what = "release to leap    Q: cancel the jump" },
	anchor_ok = { class = "day_one", where = "aim", what = "Safety line: anchored here" },
	anchor_warning = { class = "needed", where = "aim", what = "No safety line: this surface won't hold silk; No safety line: this jump needs more line than you have" },
	-- the perception HUD (its own setting, Show what the spider notices)
	perception = { class = "needed", where = "perception", what = "the rings, last-seen marks and edge chevrons; possible prey; fly-like prey; lost sight (one label to an area of the screen)" },
} :: { [string]: { class: Class, where: string, what: string } }

-- The life's notices (LifeLoop's, the mate's, the rival's, the client's own), line by line: a line matching `find` has the kind's class; `short` (a pattern with one
-- capture) is what Normal shows of it after the first day instead of the whole line. A line no entry matches is the kind `notice` (needed): so a new notice shows
-- until it is classified here. LifeLoop's words are Godot's and are not changed; only what is shown of them is.
QuietHud.NOTICES = {
	{ find = "^Ready to moult%. Rest in the silk%-lined crack%.", short = "^(Ready to moult%.)", class = "needed" },
	{ find = "^Moulting in the crack%.", class = "gentle" }, -- (the prompt's title says it: Moulting in the silk-lined crack)
	{ find = "^Morning, day %d+%. Rested through the night", class = "day_one" }, -- (the day line says it; the rest's kept line after it stays)
	{ find = "^Awake before morning", class = "day_one" },
	{ find = "^Returned to your last rest: the sill as it was when you rested", class = "gentle" }, -- (Normal's end card said what a return is)
	{ find = "^Another young spider, somewhere new on the sill", class = "day_one" },
	{ find = "^A visitor: ", short = "^(A visitor: [^.]*%.)", class = "needed" }, -- (not how to court: the notebook's page says that)
	{ find = "^Caught the rival! It fights back%.", short = "^(Caught the rival! It fights back%.)", class = "needed" },
	{ find = "^The rival goes still%.", short = "^(The rival goes still%.)", class = "needed" },
	{ find = "^It bit back!", short = "^(It bit back!)", class = "needed" },
	{ find = "^The other spider crouches to jump", class = "gentle" }, -- (its crouch and the spider's own alarm are the warning)
} :: { { find: string, short: string?, class: Class } }

-- The context for a frame: Normal (the standard rules: not Easy, not Free play) and whether it is the life's first day. `day` is the clock's day and `born` the
-- day before the generation began (0 for the first; Life/Mating.grace), as the wasp and the rival count a first day.
function QuietHud.context(rules: string, day: number, born: number?): Context
	return { normal = rules == "standard", dayOne = day - (born or 0) <= 1 }
end

-- Whether a class shows in this context.
function QuietHud.classShows(class: Class, ctx: Context): boolean
	if class == "removed" then return false end
	if not ctx.normal or class == "needed" then return true end
	if class == "day_one" then return ctx.dayOne end
	return false -- gentle
end

-- Whether a kind shows. An unknown kind shows (a new string is never silently hidden: tests/quiet.luau lists every kind the client asks for).
function QuietHud.shows(kind: string, ctx: Context): boolean
	local k = QuietHud.KINDS[kind]
	return k == nil or QuietHud.classShows(k.class, ctx)
end

-- Whether Normal's quiet is on now: the standard rules after the first day (every day_one and gentle kind is hidden).
function QuietHud.quiet(ctx: Context): boolean
	return ctx.normal and not ctx.dayOne
end

-- What a notice shows: each line by its entry in NOTICES (or as the kind `notice`), the lines kept joined; nil when nothing is left.
function QuietHud.notice(text: string?, ctx: Context): string?
	if text == nil or text == "" then return nil end
	local out: { string } = {}
	for line in string.gmatch(text, "[^\n]+") do
		local kept: string? = line
		for _, n in QuietHud.NOTICES do
			if string.find(line, n.find) then
				if not QuietHud.classShows(n.class, ctx) then
					kept = nil
				elseif n.short ~= nil and QuietHud.quiet(ctx) then
					kept = string.match(line, n.short) or line
				end
				break
			end
		end
		if kept ~= nil then table.insert(out, kept) end
	end
	return if #out > 0 then table.concat(out, "\n") else nil
end

-- The kind of a notice line ("notice" when no entry matches), for the audit and the tests.
function QuietHud.noticeKind(line: string): (Class, boolean)
	for _, n in QuietHud.NOTICES do
		if string.find(line, n.find) then return n.class, n.short ~= nil end
	end
	return "needed", false
end

-- The perception HUD's labels, calmed (Nathan saw three "lost sight" labels piled on the soil): "lost sight" fades over `lostSeconds` instead of the view's 2.5 s,
-- and in any area of the screen (rings closer than `labelAreaPx`) one label is drawn: a live one (what the principal eyes hold now) before a lost one, the newest
-- lost one before an older. `labels` is PerceptionView's list ({ pos, offset, text, alpha }); `lost` its "lost sight" words; `out` a list to fill (cleared first).
function QuietHud.calmLabels(labels: { any }, lost: string, out: { any }): { any }
	table.clear(out)
	local fade = 2.5 / QuietHud.game.lostSeconds -- (the view's alpha is 1 - age / 2.5: the age read back from it, run out over lostSeconds)
	local area = QuietHud.game.labelAreaPx
	-- the candidates, best first: the live ones in the view's order, then the lost ones, the newest first
	local order: { any } = {}
	local gone: { any } = {}
	for _, l in labels do
		if l.text ~= lost then
			table.insert(order, l)
		else
			local alpha = 1 - (1 - l.alpha) * fade
			if alpha > 0 then table.insert(gone, { pos = l.pos, offset = l.offset, text = l.text, alpha = alpha }) end
		end
	end
	if #gone > 1 then table.sort(gone, function(a: any, b: any): boolean return a.alpha > b.alpha end) end
	for _, l in gone do table.insert(order, l) end
	for _, l in order do
		local free = true
		for _, k in out do
			if (k.pos - l.pos).Magnitude < area then free = false; break end
		end
		if free then table.insert(out, l) end
	end
	return out
end

return QuietHud
