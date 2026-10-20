# The quiet HUD: every string the play screen can show, and when (ROBLOX-113, W5)

Nathan's direction (`docs/OPEN_WORLD_DESIGN.md`): "minimal HUD", "no hand holding", "Normal mode should feel like it doesn't want you to survive"; the HUD
stays the hunger bar, the day line and a caption, hints only on the first day, captions sparing, the world as the reminder. This is the audit of everything
the play screen can say, from `src/Shared/UI/*Text` and `src/Client/SpiderClient.client.luau`, each with its class. The classes live in code as
`src/Shared/UI/QuietHud.luau` (`KINDS` and `NOTICES`), which the client asks before it shows anything; `tests/quiet.luau` checks them. This table was printed
from that module; if they ever disagree, the module is what the game does.

- **needed**: always shown. The hunger bar, the day line, what the spider's senses report (the sound captions), the answer to something the player pressed,
  a state the world cannot show (a rest kept, the line letting go).
- **first day only**: in Normal only on the life's first day (a new life's day 1, or a spiderling generation's first day, counted as the wasp and the rival
  count it); in Easy and Free play always.
- **Easy and Free play only**: never in Normal.
- **removed**: never shown in any mode. None: Easy and Free play keep every word they had ("Easy and Free keep their helpfulness").

The player's own settings still apply on top of this: "Show control hints" (the card at the start and the walking reminder), Captions (off, normal, large),
"Show what the spider notices" (the perception HUD) and the notebook's notes. The controls card stays reachable at any time: H on a keyboard, Menu then
Controls everywhere.

**The garden adds nothing.** The day line does not name the region. Decided in ROBLOX-113: the regions are seamless and their names are the map's
(`bed_a`, `shrub_west_3`), not a player's; a place name on the screen is a label on the world, which is what the minimal HUD leaves out; the notebook is where
places get names when the map round comes.

## The play screen, kind by kind

| where | kind | class | what it says |
| --- | --- | --- | --- |
| hunger bar | `hunger` | needed | Hunger 72% (· hungry, · starving, · gentle) |
| day line | `day` | needed | Day 2, afternoon \| Juvenile (\| EASY, \| FREE PLAY, \| Generation 2) |
| day box | `dusk_words` | first day only | Evening. Jumping spiders go into their silk retreat before dark.; It is dark, and your eyes reach only a little way. Home is ... |
| day box | `growth_count` | needed | Next moult: 2 of 5 meals; Ready to moult |
| day box | `growth_rule` | first day only | · 3 gnats = 1 housefly; Ready to moult: rest in the crack.; Moulting: stay in the crack.; Adult: keep your hunger bar full. |
| day box | `hunger_words` | first day only | Starving: your spider's reserve is gone. It must eat soon.; Hungry: time to hunt. |
| day box | `notebook_note` | needed | New in your notebook: <page> |
| day box | `notebook_open_hint` | first day only | (N to read) |
| day box | `prey_note` | needed | The moth slipped free, leaving scales in your fangs.; A foul fluid wells from the ladybird's leg joints. You let it go. ... |
| day box | `soft_skin` | Easy and Free play only | Soft new skin: slower steps and shorter jumps until it hardens. |
| day box | `starving_weak` | needed | Starving: your spider will not last another day. Too hungry to sleep; find food. |
| status | `court_line` | Easy and Free play only | A visitor is on the sill. Walk close to it.; Courting: dance in front of it (X); Courting 45%: face it and keep still |
| status | `display_status` | first day only | COURTSHIP DANCE    X or move: stop; ANTENNAE UP ...; THREAT DISPLAY ... |
| status | `eye_status` | first day only | SPIDER-EYE VIEW    V: back |
| status | `feeding_lines` | first day only | Caught — tap Space to keep your grip; Feeding — move to stop; Meal paused — E to eat; Holding the rival — tap Space ...; Eating rival — stay still (2 meals) |
| status | `focus_status` | needed | FOCUS ON    Right mouse again to stop / Q (the Focus toggle setting) |
| status | `guard_line` | Easy and Free play only | Guarding the eggs: day 1 of 2. Rest in the crack to pass the nights. |
| status | `save_broken` | needed | Saving is off |
| status | `skip_line` | needed | Space or Q: part (the mating scene, once it can be skipped) |
| status | `slow_status` | needed | SLOW MOTION 50%    T: normal speed |
| status | `wasp_line` | Easy and Free play only | A deep hum outside: a wasp is coming ... Hide in the crack ...; The wasp has seen you! Get away ...; The wasp is leaving. |
| caption | `eye_caption` | first day only | the spider-eye view's explanation, the first time it is opened |
| caption | `sound_captions` | needed | [a deep, heavy hum outside, ahead-left, coming closer]; [a fine buzzing through your feet]; the mating and hatching scenes' captions (the Captions setting) |
| notice | `notice` | needed | the life's notices not listed in NOTICES: Last rest kept.; Moulted: now a ...; the mate's and the rival's events; A cold night in the open ...; Your spider is an adult! ... |
| toast | `toast:blocked` | needed | Can't reel in: something is in the way. Lower, or let go; Reeled in as far as it goes |
| toast | `toast:cancelled` | first day only | Jump cancelled |
| toast | `toast:caught` | first day only | Caught by your line |
| toast | `toast:completed` | first day only | Holding on again. The line stays behind for a moment |
| toast | `toast:drop_refused` | needed | Nothing below to let yourself down into from here; This surface won't hold your silk; Couldn't get to the edge |
| toast | `toast:drop_walk` | first day only | To the edge, to let yourself down |
| toast | `toast:dropped` | first day only | Letting yourself down: hold F to lower, W to climb |
| toast | `toast:hop_refused` | first day only | No hop: nothing to land on ahead |
| toast | `toast:lost` | needed | Your line came loose: its anchor is gone |
| toast | `toast:out_of_bounds` | needed | Out of bounds: back to the last safe spot |
| toast | `toast:refused` | first day only | Jump cancelled: too far or too high (the aim's words said it before the release) |
| toast | `toast:released` | first day only | You let go of the line |
| toast | `toast:snagged` | needed | The line is caught on a second edge and can't be reeled in. Lower, or let go |
| toast | `toast_answer` | needed | the answer to a press or a choice: You are the peacock spider now; Stand still on a surface to dance; the close look's refusals and framings; the save's status; the returns to a rest; Generation 2 — hatched on day 5; The dry leaf tip gave way ... |
| prompt | `close_look` | needed | the close look's name line and its one line of controls (the player opened it) |
| prompt | `edge_walk_hint` | first day only | To the edge, to let yourself down    Q or move: stop |
| prompt | `home_line` | first day only | Home: the silk-lined crack / Walk through the silk-framed opening under the wooden roof, then stop to rest. |
| prompt | `line_cue` | needed | Letting go... 40%; the line's blocks and snags |
| prompt | `line_panel` | first day only | On your line / W: reel in    S: lower    hold Q: let go |
| prompt | `rest_prompt` | first day only | The silk-lined crack / E: rest; the hints under the titles (Move, E or Q to wake; C: become ...; the display key) |
| prompt | `rest_state` | needed | Asleep in the silk-lined crack; Resting under the stone; Moulting in the silk-lined crack; Ready to moult (the titles) |
| prompt | `walk_hint` | first day only | Tap Space: hop    hold Space: aim a leap    F: let yourself down on silk (and the setting Show control hints) |
| aim | `aim_hint` | first day only | release to leap    Q: cancel the jump |
| aim | `aim_title` | needed | Reachable; Out of reach: too far or too high; No surface in view |
| aim | `anchor_ok` | first day only | Safety line: anchored here |
| aim | `anchor_warning` | needed | No safety line: this surface won't hold silk; No safety line: this jump needs more line than you have |
| card | `controls_card_asked` | needed | the controls card when asked for: H, or Menu then Controls |
| card | `controls_card_start` | first day only | the controls card for 20 s at the start (and the setting Show control hints) |
| perception | `perception` | needed | the rings, last-seen marks and edge chevrons; possible prey; fly-like prey; lost sight (one label to an area of the screen) |

## The life's notices, line by line

A notice can be several lines (the morning and the rest kept). Each line is matched against these patterns (Lua patterns, first match wins); a line that
matches none is the kind `notice` and is shown. Where a short form is given, Normal shows only that much of the line after the first day. LifeLoop's words are
Godot's and are not changed; only what is shown of them is.

| line (pattern) | class | in Normal after the first day |
| --- | --- | --- |
| `Ready to moult%. Rest in the silk%-lined crack%.` | needed | after the first day: `(Ready to moult%.)` |
| `Moulting in the crack%.` | Easy and Free play only |  |
| `Morning, day %d+%. Rested through the night` | first day only |  |
| `Awake before morning` | first day only |  |
| `Returned to your last rest: the sill as it was when you rested` | Easy and Free play only |  |
| `Another young spider, somewhere new on the sill` | first day only |  |
| `A visitor: ` | needed | after the first day: `(A visitor: [^.]*%.)` |
| `Caught the rival! It fights back%.` | needed | after the first day: `(Caught the rival! It fights back%.)` |
| `The rival goes still%.` | needed | after the first day: `(The rival goes still%.)` |
| `It bit back!` | needed | after the first day: `(It bit back!)` |
| `The other spider crouches to jump` | Easy and Free play only |  |

## The perception HUD's labels

Not a class but a rule, in every mode (`QuietHud.calmLabels`): in any area of the screen (rings within 120 px of each other) one label is drawn, a live one
(what the principal eyes hold now) before a lost one and the newest lost one before an older; "lost sight" fades out over 1 s instead of the view's 2.5 s
(Godot's, kept in the pure view). Nathan saw three "lost sight" labels piled on the soil; now there is one, and it is gone in a breath.

## Not the play screen

The menus and cards the player opens or that end a life are not part of this audit and are unchanged: the title card and the intro, the life menu, the
notebook, Settings, the catch screen and the end cards (Normal's end card keeps its line on what "Back to your last rest" costs), the ending of a
generation. The touch buttons' labels (Eat, Grip, Rest, Sleep, Lock, Skip) are controls, not words on the screen, and are unchanged.
