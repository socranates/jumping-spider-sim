# The daily wasp and the daily rival — Claude, 2026-10-18

Nathan: "I would also like the new rival male and the wasp to always be present." Decided with the lead as: every day, guaranteed. Decisions ROBLOX-67 (wasp), ROBLOX-68 (rival), and for Nathan's two later requests ROBLOX-69 (the rival stalks the whole sill) and ROBLOX-70 (the wasp takes the rival about one visit in ten). This branch (`claude/roblox-daily`) also contains the ant-mimicking spider (merge commit; its decisions are now ROBLOX-64..66) and Chet's dragline round. Nothing here has run in Studio or on a device.

## What changed

- **Wasp:** a visit on every day from day 2, one a day, in the warm window (10:00 to 15:30; the hour is drawn per day from the world's seed). Full warning, never in a rest, all escape rules as before. No visit on day 1 and none before the first meal is finished. A rest through the whole window skips that day; a rest in the morning only delays the visit. Easy and Free get the same visit with their gentle outcome. The setting is `Data/Wasp.game` (applied by `WaspDirector:useGameRules()`, which also carries Chet's search 1.6, notice 1.2, inspect 0.8). Godot's numbers and the goldens are unchanged.
- **Rival:** present from day 2 once the first meal is finished (arrives from 07:00, only when the spider is not resting, the wasp is not visiting and the spider is not within 8 studs of the east end). When it is eaten, a new one arrives on a later morning at 07:00. One at a time, east sill only, never in the crack, never an attack there, pauses for the wasp, windup and lunge unchanged. `Data/RivalRules` holds the arrival rules; the eaten rival's day is saved in `life.rival.day`; old records (no day) still load and also get a new rival the next morning.
- Merge notes: the change-spider cycle (first spider, peacock, ant mimic) never offers the rival's look; `SpiderChoice` accepts only its ORDER, also for attributes and saves.

## Chet's Studio checklist

1. Start a new life: day 1 has no wasp and no rival. After the first meal and the next morning (day 2): the rival is on the east sill and the wasp's hum and caption come in the warm part of the day.
2. Wait through several days (or force the clock): a wasp every day at slightly different times; none while resting in the crack.
3. Eat the rival (jump on it, stay still for five seconds) and rest through the night: a new brown rival is on the east sill the next morning, not before. Eaten, then return to the last rest: you get that rest's state, not a second rival.
4. Old save: a record with an eaten rival and no `day` loads, and a new rival comes the morning after.
5. Easy/Free: wasp and rival touch and leave.
6. Run the usual full suites and Studio checks (111 engine, 29 client) on the rebuilt places; the client script is at Luau's 200 local limit, so any new client local needs another one removed or a table.

## Later the same day: the rival roams, the wasp sometimes takes it

Nathan: "The male should stalk the whole environment as well." and "The wasp should kill the rival male like 10 percent of the time."

- **Roaming rival (ROBLOX-69).** The rival has its own `SpiderMotor` (same collider as the player's, own probe in `JumpArc`, never in the player's ray filter) and walks everywhere the player can: floor, leaves and stems, planter and rim, frames and back wall, cover pieces. `Predator/RivalRoute` makes a graph of all box faces from `Layout.PIECES` (seams as edges, box corners as stops so a straight walk never runs into a box) and `Predator/RivalDrive` is the brain between `RivalSpider` and the motor: about 100 patrol places (leg number `leg`, in the record), decisions at 10 Hz, the motor every tick while it walks and every tenth tick while it stands, a plan only when it needs one. It notices the spider by the same movement-only perception and line of sight (at any height, within 8 wu), stalks toward the spider's face at 1.1 wu/s, goes on to the last place it saw it for 3 s, winds up for 1 s when it is within 2.5 wu and on the same or an adjacent face, and the committed lunge goes to the spider's place and lands back on the surface it started from. Unchanged: never in or at the crack (keep-out box in every route, a last guard puts it back), pause for the wasp, jump-contact capture, 5 s eating, food value, daily respawn. Record: `up` and `leg` (older records mean the floor and none); a position outside the sill or in the crack is refused.
- **Cost (CLI shim, so the engine is faster):** the rival's motor uses 2.0 rays per tick while it walks and under 1.5 while it stands; one decision per 0.1 s; a plan costs 0.2 s in the CLI's Vector3 shim (a few ms natively) and happens once per leg, 4 in the first 90 s of patrol. `Rules.thinkSeconds`, `legSeconds` and the speeds are in `Data/RivalRules`.
- **Wasp takes the rival (ROBLOX-70).** In the game, each visit draws (own stream, `Data/Wasp.game.takesRival = 0.10`) whether it is for the rival. If so, and a free rival is on the sill out of the crack and reachable from above (91 of the 101 patrol places are), the wasp flies to it, hangs over it 0.8 s, strikes and carries it off hanging under it, the visit ends and the spider is not looked for. The rival is gone for the day (`fate = "taken by the wasp"`, no food), new one next morning. A caption in the sound style, the status line and a notice appear only if the wasp is within 18 wu of the spider or in sight within 24 wu. Not reachable (undersides, nooks) or no rival: the visit is the spider's search as before.
- Tests: `rivalnav.luau` 167, `client_rival.luau` 3 (the real client: arrival, walking, the wasp taking it), new cases in `checkpoint.luau` (a record mid-climb, a record under the wasp, the fate) and `wasp.luau` (the 10%, the visit for the rival, the refusals, reach, the words); Studio `RivalSpec` (new, not run).

### Studio checklist, additions

7. Watch the rival for a few minutes in the Test place: it walks over the floor, up the stems, onto leaves, the planter and the frames, and never into the crack or its mouth. Does it ever get stuck, spin or fall through a surface? (`RivalSpec` is the engine check; it has not run.)
8. Stalk: stand still on a leaf in its sight; it should creep over, crouch for a second and lunge. Hide behind a cover piece: it should go on toward where it saw you for about 3 s and then give up. Jump away during the crouch: it misses.
9. Force a wasp visit a few times (`WaspForce` attribute): about one in ten should be for the rival (a caption "[the deep hum drops toward something...]" if you are near, then the rival hanging under the wasp and gone). You should not be hunted on that visit.
10. Rest while the wasp holds the rival, then return to the rest: the rival is gone for that day, a new one comes next morning.

## What Nathan should try

A full week: does a wasp every day feel scary or tiresome? Is a rival every day too generous as food? Does the east-sill rival feel like a person's neighbour or like a wave of monsters?

## Food balance (not retuned)

A day costs about 0.35 to 0.38 energy; the rival gives 0.7 and two thirds of a moult's food, every day. Catching it daily makes starvation practically impossible and speeds up moulting. It is risky to catch (it kills in standard rules) and energy above 1.0 is wasted, so it is not free food. Tell Nathan, and tune with `Rival.FOOD`, the arrival rules or the hunger factor only if he finds it too easy.

## Open

- "Driven off" does not exist in the rival's design (it only recovers after a miss), so only eating it ends it.
- The rival's first morning is day 2, the same as the wasp's first day (Chet's rule kept). A day-1 rival after the first meal is a one-number change (`RivalRules.firstDay`).
- No on-screen announcement of a new rival.
- The rival walks the seams the player's motor walks; it does not hop between surfaces (the jump planner is not reused) and its "cover" use is routing around boxes plus the last-seen memory, not a hide-behind behaviour. It can fall off an edge it cannot hold and then plans again from where it lands.
- Patrol speed is 0.8 wu/s (it was 0.45 on the old east floor) so a leg across the sill takes 40 to 80 s; `Rules.patrolSpeed`.
- The wasp cannot reach a rival on an underside or in a nook (about one place in ten), and then the visit is the spider's.
- `client_smoke.luau` now takes about 175 s alone (it was about 161 s); the new `client_rival.luau` takes about 100 s alone.
- The rival's motor is not tuned in Studio: if its walking over leaf tips or the frame edges looks wrong, `Route` has the forbidden pieces (the dry leaf tip, the crack) and `bodyFits`.
