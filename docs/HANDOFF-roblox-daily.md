# The daily wasp and the daily rival — Claude, 2026-10-18

Nathan: "I would also like the new rival male and the wasp to always be present." Decided with the lead as: every day, guaranteed. Decisions ROBLOX-67 (wasp) and ROBLOX-68 (rival). This branch (`claude/roblox-daily`) also contains the ant-mimicking spider (merge commit; its decisions are now ROBLOX-64..66) and Chet's dragline round. Nothing here has run in Studio or on a device.

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

## What Nathan should try

A full week: does a wasp every day feel scary or tiresome? Is a rival every day too generous as food? Does the east-sill rival feel like a person's neighbour or like a wave of monsters?

## Food balance (not retuned)

A day costs about 0.35 to 0.38 energy; the rival gives 0.7 and two thirds of a moult's food, every day. Catching it daily makes starvation practically impossible and speeds up moulting. It is risky to catch (it kills in standard rules) and energy above 1.0 is wasted, so it is not free food. Tell Nathan, and tune with `Rival.FOOD`, the arrival rules or the hunger factor only if he finds it too easy.

## Open

- "Driven off" does not exist in the rival's design (it only recovers after a miss), so only eating it ends it.
- The rival's first morning is day 2, the same as the wasp's first day (Chet's rule kept). A day-1 rival after the first meal is a one-number change (`RivalRules.firstDay`).
- No on-screen announcement of a new rival.
