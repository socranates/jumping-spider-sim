# Two-player design: the other person is the rival spider

Nathan (2026-10-18): "a two player mode would be amazing, the other person is the rival spider." This is a design,
not a build. Nothing here has been implemented. It is written so Chet and Claude can split the work when Nathan
calls for it.

## Why this is closer than it sounds

ROBLOX-69 gave the rival its own `SpiderMotor` over the whole sill: the same surface-walker the player uses, driven
by `RivalDrive` (an AI brain that feeds the motor ordinary inputs: a wish direction, a focus point). A second human
is, mechanically, a replacement for `RivalDrive`: their sticks produce the same inputs the brain does. The drawing
path for a second spider already exists (the rival's rig; the mate reuses it too). What the game does NOT have is
any server-side simulation: the whole sim (life clock, prey, wasp, rival) runs on the one player's client, and the
server only holds saves (ROBLOX-4x, the DataStore service). Two humans means crossing that line for the first time,
and doing it narrowly is the whole trick.

## Proposed shape (v1: play with someone you invited)

- One Roblox server, two players. The first to spawn is the **resident** (the full game, exactly as today). A second
  player joining an occupied sill is offered the **rival** role on a join card; declining spectates the resident
  (camera only) until a slot opens. No matchmaking, no public pairing: this is for Nathan and his kids, friends
  servers, and private servers first.
- **The resident's client stays the authority for the world**: clock, flies, wasp, saves. Nothing about the
  single-player sim moves. The rival player's client is authority for the rival's own motion only.
- **The rival player replaces the AI**: their input drives the rival motor on their machine; position, up, heading
  and pose replicate at 10 Hz with interpolation (the same quantities `RivalDrive` already maintains in the record:
  `position`, `up`, `heading`, `leg`). The AI (`RivalDrive`) stays as the fallback: when no second player is present,
  or they leave mid-day, the brain takes the motor back exactly where the human left it.
- **The rival player's screen**: the same first-person spider game (motor, camera, eye view) minus the life sim —
  no hunger, no notebook, no saves. Their goals are the rival's: stalk, lunge, eat the resident's flies (a stolen fly
  is real: the resident's prey director is told), and the lunge-contest with the resident. A simple session scorecard
  (meals stolen, strikes landed, days survived) instead of persistence.
- **Contested moments go through the server** (a thin RemoteEvent referee, the first server gameplay code):
  - the rival's lunge touching the resident (today: client-side `sweepClosest` within 0.6) — both clients report,
    the server stamps the outcome with the shared seed so neither side can cheat the draw;
  - the resident's strike-contest (ROBLOX-73's 55/25/20 draw) — the server draws it;
  - the wasp taking the rival (ROBLOX-70): a human rival gets what the AI never had — a 1.5 s dodge window
    (jump or drop breaks the take). The 10% draw stands; fairness is the window, not the odds.
- **The retreat rule holds absolutely**: the rival player cannot enter the crack (the motor refuses the keep-out
  the way `RivalDrive`'s guard does today). The resident's rest ends the rival player's day too (a "night falls"
  card; next morning respawn at the arrival point, like the AI's daily respawn).
- **Death**: a caught rival player watches the eating (their own "a hunter can become prey" card) and respawns
  next morning. A caught resident gets the existing death flow; the rival player is returned to the lobby card.

## What stays out of v1

- No two residents (two full life sims on one sill), no spider-vs-spider free-for-all, no cross-server play.
- No voice/chat beyond Roblox's own.
- No rival progression, cosmetics, or saves; the rival's look stays the brown `rival_spider` appearance.
- Gentle modes: in a gentle resident's world, the rival player's lunge is the "touch" outcome, exactly like the AI's.

## Honest risks, named now

- **Client authority**: the resident's client can, in principle, lie to the referee. Acceptable for invited play;
  revisit before any public pairing.
- **Clock coupling**: the rival player lives on the resident's clock (sleep skips the night). The join card says so.
- **Latency feel**: a 10 Hz interpolated stalker is fine; a lunge needs client-side prediction with server settle.
  The lunge is 0.4 s — the referee must answer inside ~150 ms or the lunge replays visually. Measure early.
- **The 200-local client**: the rival-player client should be its own LocalScript, not more weight in SpiderClient.

## Build order (when Nathan says go)

1. Server referee skeleton + role assignment + replication of the rival motor (AI unchanged, a human just watches
   through the rival's eyes). Playable test: two Studio clients.
2. Human input on the rival motor + fallback handback to `RivalDrive`.
3. The referee'd contests (lunge, strike-contest, wasp dodge window) + scorecard.
4. Cards, words (`RivalText`), gentle modes, Studio spec, FRIEND_PLAYTEST.md update.

Estimate: two to three of our usual rounds, with Studio two-client testing in every one of them (this cannot be
verified by the CLI suites alone; the referee logic can and must be).
