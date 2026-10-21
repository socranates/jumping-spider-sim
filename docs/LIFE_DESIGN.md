# One whole life: the plan

Claude, 2026-10-12. This is ROADMAP "The goal", step 2 (spec phase 4, spec sections 11 and 13). It is a plan for Nathan, Chet and Claude: Nathan decides the open questions at the end. Update it as rounds finish.

## What Nathan has decided

- **LIFE-01:** "death can be real and jarring. not sensationalized but my kids are allowed to encounter reality."
  - Natural is the default: a spider can die, and the player goes on as another spider or back to the last rest.
  - Gentle is a separate choice, not part of Most help.
  - A death is shown plainly and briefly, then a short summary of the life. No gore, no lingering, no score.
- **RELEASE-01:** the first release is one windowsill, one species, one whole life, the notebook, calm by default.

## What the biology says

The sources were found by a web search, but most papers could not be opened, so many numbers come from abstracts or quoted excerpts. Each should be read before any of it is presented as fact in the game (LEARN-03).

**Ratings:**
- **Strong:** a study of *Phidippus audax* or another *Phidippus*.
- **Weak:** another jumping spider, or spiders in general.
- **Missing:** no source found.

| Topic | What we found | Strength | Source |
|---|---|---|---|
| Moults to adult | Males 5–7 in the lab and 6–8 in the field; females 6–8 in the lab and 7–9 in the field (*P. johnsoni*; the field figures are estimates from measurements, "probably" in the abstract, and only the lab figures are counts) | Strong (relative) | Jackson 1978, *J. Arachnol.* 6: 1–29 |
| Life length | One generation a year. *P. audax* overwinters as a juvenile, often in the instar before adult, and matures in spring | Strong | Taylor & Peck 1975, *J. Arachnol.* 2: 89–99; Jackson 1978; Penn State Extension |
| Adult life | About 3–4 months in the lab (*P. johnsoni*) | Strong (relative), excerpt | Jackson 1978 |
| Moulting | Inside a dense silk nest; about 6 days in the nest before a moult and 2 after (*P. johnsoni*) | Strong (relative), excerpt | Jackson 1979, *J. Arachnol.* 7: 47–58 |
| Hunting around a moult | Stops for about 12 days around a moult; failed catches before it (*Trite auricoma*) | Weak | Forster 1977, *NZ J. Zool.* 4: 435–443 |
| Moult duration, soft period | — | Missing | — |
| Hunger and activity | *P. audax* switches between staying in the nest and going out to hunt by how hungry it is; spiders in nests were hungrier | Strong | Okuyama 2011, *Naturwissenschaften* 98: 15–22 |
| Going without food | Juveniles in the cold last months (*P. johnsoni*). The "adult female kept 25–31 days unfed" this row used to give could not be found when Jackson 1978's PDF was searched on 2026-10-19, so it is not relied on (docs/NOTEBOOK_SOURCES.md) | Strong (relative) for the cold; the days not found | Jackson 1978 (1980 not seen) |
| Starvation limit | Other spider families: 208–276 days | Weak | Anderson 1974, *Ecology* 55: 576–585 |
| Body condition | Abdomen size against the carapace is the usual measure of how well fed a spider is | Weak (general) | Jakob, Marshall & Uetz 1996, *Oikos* 77: 61–67 |
| Hunger and hunting skill | Food-restricted spiders spent more time out, noticed prey sooner and caught more (*Phintelloides versicolor*) | Weak | Li et al. 2021, *Ecology and Evolution* |
| Drinking | Wolf spiders try to drink after losing about 10 % of their weight; jumping spiders unknown | Weak / missing | Parry 1954 |
| Predator | The black-and-yellow mud dauber (*Sceliphron caementarium*) nests on houses and window frames. It stocks each cell with paralysed spiders, jumping spiders among them. It finds a spider by sight, checks it by touch, stings it and carries it off. The spider is paralysed, not killed, and the wasp's larva eats it | Strong for jumping spiders; missing for *P. audax* itself | Powell & Taylor 2017, *Behav. Ecol.* 28: 890–898; Uma et al. 2013, *PLoS ONE* 8: e79660; UF/IFAS |
| Cellar spider | Eats other spiders in or near its web. In tests, jumping spiders were more often the predators of cellar spiders | Weak | Jackson & Brassington 1987; Jackson 1990 |
| Escaping | *P. audax* backs away from something looming toward it, often with its front legs raised; its side eyes drive this | Strong | Spano, Long & Jakob 2012, *Biol. Lett.* |
| Night | *Phidippus* goes into its silk nest before dark and stays overnight and in bad weather | Strong (relative) | Jackson 1978, 1979 |

**Missing, and needed before we claim them:**
- *P. audax*'s own instar count, time to maturity and lifespan (Bailey 1968, a thesis, probably has them).
- How long a moult takes, and how long the spider stays soft afterwards.
- Whether hunger makes a jumping spider bolder near predators.
- Whether jumping spiders recognise wasps.

## The design

### 1. Three clocks, and time passing at rest (spec 13)

Three clocks run separately:
- **The action clock:** SimClock, unchanged; jumps are never shortened.
- **The time of day:** morning to evening light on the sill.
- **The spider's age in days.**

Time passes slowly while the spider is active. **Resting in the retreat** can pass the night, or wait out a moult, in bounded steps that stop if anything important happens. Pausing never passes time, and menus never starve the spider.

The game compresses time on purpose. A real *P. audax* lives about a year; one life in the game should take a few hours to play. The notebook says so.

### 2. Hunger you can see

- **Reserve:** energy keeps its role. It now drains with the days, not just the minutes.
- **Body condition you can see:** the abdomen is plumper when well fed and thinner when hungry (Jakob et al. 1996). There is no hunger bar to watch; the existing small energy bar stays for those who want it.
- **Behaviour:** a hungry spider is not made weaker at jumping, since there is no evidence for that. It must hunt to moult, and starvation is possible only after many days without food, with clear signs on the way.
- **Settling:** a well-fed spider may prefer to stay in its nest (Okuyama 2011). A gentle prompt could say so; it never forces anything.

### 3. Moulting

1. After enough meals in an instar, the spider shows it is getting ready: it stops hunting and wants the retreat.
2. The moult happens in the retreat, as time passes at rest. Following Jackson 1979, it takes some days there, compressed.
3. Afterwards the spider is bigger, and stays soft for a while, with shorter jumps and more caution.
   - The soft period is a **design assumption** until a source is found, and the notebook says so.
4. A few moults take the spider from a mid-sized juvenile to an adult over one life.

### 4. One predator: the mud dauber wasp

The best-supported predator for a windowsill. It is a warning-rich, fair threat:
- **Warnings:** you hear its buzz before it arrives (a new sound), its shadow crosses the sill, and the spider feels it land.
- **Search:** it searches surfaces by sight, then checks what it finds.
- **Escape:** the player can stay still in cover, back away (as *P. audax* does from something looming), retreat into the crack, or jump clear.
- **If caught:** the wasp stings, the spider goes still, and the wasp carries it away. That is the death, shown plainly in a few seconds.
  - The notebook can say what happens next (the paralysed spider feeds the wasp's larva).
  - This is real and it is grim. It is written plainly, never dwelt on.
- **Pressure:** visits are rare and announced. It never appears during the first hunt, or while the player is learning (spec 11).

### 5. Death, the summary, and continuing

- **Natural (default):**
  1. When the spider dies, the world goes quiet for a moment and one plain line says what happened.
  2. Then a short summary: days lived, moults, meals, places it rested, times it escaped. No score or kill count, and the player can skip it.
  3. Then a choice: **go back to your last rest** (the checkpoint), or **continue as another spider**: a juvenile *P. audax* somewhere else on the sill.
     - The new spider is labelled honestly as unrelated: there are no offspring until courtship and eggs exist (phase 5).
     - The notebook carries over; the new spider's memory does not.
- **Gentle:** the wasp gives up or the spider drops free; starvation cannot kill.
- **Lineage challenge** (irreversible deaths) waits until there are generations.

### 6. What stays out of this phase

Courtship and eggs (phase 5), seasons and overwintering, drinking (no jumping-spider data), injuries and lost legs, and more predators.

## Modes (MODES-01, Nathan, 2026-10-12)

| Mode | World rules | Available | Counts toward finishing |
|---|---|---|---|
| The Windowsill (the main life) | Standard: hunger, the wasp, real death (LIFE-01) | From the start | Yes |
| The Windowsill on Easy | Gentle: no death, forgiving hunger | After finishing the main life once | No |
| Free play | Easy and relaxed, its own save | From the start | No |

Control helps (Most help and the other presets, slow motion, Reduced motion) stay available in every mode; only the world's rules are locked. "Finishing" is one spider reaching adulthood. Both confirmed by Nathan (MODES-01). Death and continuing (round 5) builds these modes and the unlock.

## Order of work

Each round is one handoff: start from `main` and finish into `main`.

0. **Chet, complete 2026-10-12: measure and rebuild.**
   - Results: `HANDOFF-eye-perf-windows.md`; six-read T13b retained, Windows 591/591; new notebook friend ZIPs delivered.
   - Time the cheaper eye shader (T13b) on the laptop against the previous one.
   - Try the mipmap variant noted in `docs/verification/eye-perf/results.txt`.
   - Rebuild the friend ZIPs with the notebook, so friends play the current game.
1. **Done (Claude, 2026-10-12, LIFE-04 to LIFE-08): clocks and hunger.** Time of day and age; the night passing at rest; energy over days; abdomen size from condition; a starvation timeline with no death yet; notebook pages. Tests at 30, 60 and 144 fps.
2. **Chet: Windows check complete (2026-10-12).** 600/600, day/night and abdomen checked; moving-sun p95 17.274 ms; friend ZIPs rebuilt. See `HANDOFF-life-round2.md`.
3. **Done (Claude, 2026-10-12, LIFE-10 to LIFE-13): moulting.** Readiness, the retreat, time passing, a soft and pale spider, old skins, tests. Drawn growth completed by Chet: four visual sizes, unchanged physics; Windows 618/618. See HANDOFF-drawn-growth.md.
4. **The wasp. Claude's part done (2026-10-13, LIFE-14 to LIFE-18):** its visits, warnings, search by sight, escapes, the catch and the screen after it, checkpoint schema 6, three notebook pages. **Chet's presentation complete:** jointed model, animation, hum, tucked spider and Windows checks (632/632). Human speaker listening and child comfort remain to playtest; battery timing misses F01. See `HANDOFF-wasp-presentation.md`.
5. **Done (Claude, 2026-10-13, LIFE-19 to LIFE-24): death and continuing.** Standard and Gentle rules; starving with every stage on the screen; the end of a life with its summary; back to the last rest or on as another spider; the player's progress, finishing the main life and Easy; the start menu and free play. See `HANDOFF-life-round5.md`.
6. **Nathan, his son and friends play a whole life.**

## Nathan's answers (2026-10-12, LIFE-03)

"your suggestions work great and your assumptions are accurate." All four proposals below are accepted:
1. One life takes about 2–3 hours to play, over roughly 10 game days, with 3 moults from juvenile to adult.
2. The mud dauber wasp is the first predator.
3. Continuing after a death: a young juvenile somewhere new on the sill, labelled honestly as unrelated.
4. The notebook tells the whole truth about the wasp, plainly: the spider is paralysed, not killed, and fed to the wasp's young.

## Questions for Nathan (answered above)

1. **How long should one life take to play?** Proposed: about 2–3 hours, over roughly 10 game days, with 3 moults from juvenile to adult.
2. **Which predator first?** Proposed: the mud dauber wasp. The cellar spider is less certain from the evidence.
3. **When you continue as another spider, where should it start?** Proposed: as a young juvenile somewhere new on the sill, labelled as unrelated.
4. **Should the notebook tell the whole truth about the wasp?** That the spider is paralysed, not killed, and fed to the wasp's young. Proposed: yes, plainly, since you said your kids are allowed to encounter reality.
