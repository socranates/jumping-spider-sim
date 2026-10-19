# The web-slinger — a spider that swings (proposed, not scheduled)

Nathan, 2026-10-19, in his words: "A new spider called spider-man-spider. He's a spider but he webs around with spider man game
mechanics. After main game unlock or purchase depending on later decisions." And, the same day: "Only honest play through should even
be allowed to purchase. Works everywhere. Whatever you think for the name and design." This is the idea recorded as a design so nothing
about it is lost; it is **not built, not scheduled and not in W3–W5** (`docs/OPEN_WORLD_DESIGN.md`). It comes after the open-world
rounds. The name is Claude's call: in the game it is **the web-slinger** (the working name "spider-man-spider" stays in the documents).

## What it is

A sixth spider in the picker (`Rig/SpiderChoice`, after the first spider, the peacock, the ant mimic and the two tarantulas), and the
first one that changes how the game *plays*, not only how the spider looks. The others are costumes on one body with the same honest
movement; this one webs around the way a superhero does:

- **Swing.** Aim at a point above and ahead (a leaf, the sash rail, a brick, a stem) and fire a line to it; the spider swings under the
  anchor as a pendulum, release at the bottom of the arc to fly forward, fire the next line in the air and chain swings across the
  garden. The sill's and the garden's boxes are the anchors; the open window and the 90 cm wall are the first playground.
- **Zip.** A line fired at a wall pulls the spider to it fast (the reel, but at a run).
- **Web the prey.** A line fired at a fly sticks it to the spot for a moment: the catch becomes a jump onto a held fly, easier than the
  honest chase.
- **Fall further.** The fall-off floor is the same (the bed), but a line fired mid-fall catches.

Everything else stays the life sim: hunger, the day, the wasp, the rival, the rests, the saves. The web-slinger is the same spider with
the superhero's toolkit, so the world and its rules do not fork.

## How it sits on what exists

- The dragline is already a real line: `Movement/SilkController` and `TetherMath` (Godot goldens, bit-identical) do the attach, the hang,
  the reel and the let-down, and `LineFraming` frames a spider on a line. The swing is a pendulum on that same line with the anchor
  above instead of behind: a new game-side module (`Movement/Swing.luau`, in `X.game` style) that drives the existing line, never a
  change to the goldens. The aim is the jump aim (`JumpInput`, the left stick) pointed up.
- Anchors come from the world: a raycast along the aim against `Workspace.World` (every region's boxes, as every ray already uses),
  so the swing works on the sill, through the opening, down the wall and over the bed without authoring.
- The catch-by-web is `Feeding` with a held fly: the fly's `state` gains a short `HELD` the honest spiders never use.
- Nothing in it is science. The notebook keeps its sourced pages; the web-slinger's page (if it has one) says plainly that real
  jumping spiders do not swing on silk and that this is the superhero's spider, not nature's. The HUD says which spider is in use
  as it does now; the Inspect card's text lives in `Shared/UI/*Text`.
- Part budget: the body is the first spider's rig in a red-and-blue coat (the pattern layer, as the peacock's is), no new anatomy.

## Unlock, then purchase (Nathan's rule, 2026-10-19)

"Only honest play through should even be allowed to purchase." So two gates in series, not a choice between them:

1. **Earned first**: the web-slinger does not appear for sale until the player has completed an honest life in Normal (a spider that
   reaches adulthood and comes to the mating; W4 decides what "a complete life" is and whether a failed mating counts). The proof is a
   progress flag in the save (`SaveProgress`, schema unchanged: an optional boolean set by the server's rest flow, never by the
   client), so it cannot be bought on a fresh account and it survives between visits.
2. **Then bought**: a Game Pass, priced when sales are implemented (the peacock's intended ~US$0.99, ROBLOX-48, is the reference; the
   tarantula pass, ROBLOX-81, is the other). `SpiderChoice.locked` already skips a locked spider in the picker (ROBLOX-71); the row in
   Settings shows it locked with one line saying why ("Finish a life first" / "A pass unlocks the web-slinger"), words in
   `Shared/UI/*Text`. Nothing is charged until Nathan turns sales on himself; the first spider and the full game stay free.

The pass is checked on the server (`MarketplaceService:UserOwnsGamePassAsync`) at join and when the picker asks; the client never
decides ownership.

## Open for Nathan

- **The name** is settled as the web-slinger. "Spider-Man" is Marvel's trademark: Roblox moderation can refuse a Game Pass or an
  experience text that uses it, and a public experience that trades on it is a takedown risk. The coat is red and blue with a web
  pattern of our own drawing, no mask, no logo.
- **When.** After W5 at the earliest; it is a round of its own (the swing, the aim, the web catch, the coat, the unlock, the page, the
  tests) — about the size of a world round.
- **Where it may be used.** Everywhere (Nathan, 2026-10-19): the sill, the garden and whatever comes after.
- **Free play.** Does the web-slinger count as a gentle-rules spider (open in Free play from the start for the kids) or is it the
  reward for the honest life?

## Not decided, not built

No code, test, decision number or text in the game refers to this yet. When Nathan schedules it, it gets a ROBLOX decision, a round
brief like W2's and W3's, and its own handoff section.
