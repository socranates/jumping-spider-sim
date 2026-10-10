# Jumping Spider Sim
## Claude's response to spec v0.1, and the build plan

**From:** Claude · **For:** Chet and Nathan · **Date:** October 4, 2026
**Status:** a response and a plan. No code exists yet. Nothing here reports a test, build, or playtest.

## Summary

- I accept spec v0.1 as the plan of record: Godot 4.x, typed GDScript, Windows first, the *P. audax* anchor, the windowsill slice, and every guardrail.
- Part A maps four ideas Nathan chose onto the spec and adds some of mine. Each carries a label. Nothing enters P0 unless marked **P0-compatible**, meaning it is cheap and changes no gate.
- Part B splits T00–T10 into eleven session-sized chunks. Nathan works within Claude Pro usage limits, so each chunk is one fresh session with one model and one goal.
- One practical constraint: my cloud workspace cannot download Godot. I can parse and lint GDScript there, but engine tests, play, and captures run on Nathan's PC. Part B handles this with three double-click scripts.

Three questions for Chet are at the end.

---

## Part A. Ideas

Labels follow the spec: **P0-compatible**, **P1**, **P2**, **Research**. Sources C1–C4 are new and listed at the end; B1–B4 are Chet's.

Two ideas borrow findings from other salticids (A1.2 from *Hasarius*, A4.3 from *Evarcha*). The spec warns against stacking every remarkable salticid ability onto one species (§0), so both stay Research until a *P. audax* source or an explicit, ledgered compromise exists.

### A1. Seeing like a spider → attention (spec §7)

The spec's two channels (peripheral motion, 30° forward inspection) and its split between truth, evidence, and memory already carry this idea. Additions:

1. **Visible gaze. P0-compatible (T06).** Show the inspection cone to the player as a narrow, soft beam from the principal eyes. Things inside it resolve in stages over the spec's 0.4 s: "movement" → "possible prey" → "fly". The beam shows where the animal is attending and reveals nothing the spider has not sensed. Toggleable. It is a picture of attention, with no claim about salticid vision (guardrail 6).
2. **Focus judges distance. P1 experiment, Research.** Some salticids judge distance from image defocus (C2, in *Hasarius adansoni*, not *P. audax*). Translation: during preparation, the landing patch starts off the aimed point by an amount that depends on distance, and slides onto it as the target is held in the beam (about 0.5 s). The patch is always the true prediction for the launch the spider would choose. The jump goes exactly there, so nothing is random and the preview never lies (§6.3). What improves with looking is the spider's estimate. Gate: only after M02 passes, only if playtests show a real decision instead of frustration, and an assist setting turns it off.
3. **The thing too large to see. P1.** A human face at the window, as one of §14's scheduled human events. It fills more than the 30° cone, so inspection returns "too large to resolve". That is literally true of the information model. The face is harmless and looks back. The looming response (B2) provides the warning cue. No dialogue.

### A2. Faith in the unseen → limited knowledge (spec §5, §7)

I agree with the spec: no *Portia* strategies (web invasion, aggressive mimicry) for *P. audax*. Detouring toward remembered prey is a separate thing. Hill (C1) studied *Phidippus* orienting toward prey during pursuit, including indirect routes. Research: confirm the out-of-view details from the full text. The spec's own five-minute story (§2) is already a detour.

1. **The last-seen mark. P0-compatible (T06).** When a classified target leaves sight, a faint mark stays at its remembered position and fades as confidence decays. It never follows the true target (§7). When you come around the pot and the fly is gone, the gap between the mark and the world is the event. You acted on a memory, and the world kept moving.
2. **The head remembers. P1, Research.** While walking a detour, the spider's cephalothorax briefly turns toward the remembered position every few seconds. Rig only, never the motor (§15). The player sees an animal holding a goal it cannot see.
3. **No drawn routes.** The game never shows a path. The player plans, and the only planning tool is looking.

### A3. The silk line → vulnerability and recovery (spec §9)

§9.1 is right as written for P0. Additions:

1. **Some surfaces refuse a line. P0-compatible (habitat data in T08).** The spec already requires a visible no-anchor state before committing. Make it matter: a few authored launch points (wet glass after watering, later a leaf in motion) will not hold silk. A jump from them has no way back. Per B3, the line steadies the body in the air and lets the spider brake, so jumping without one means less control and no recovery. It does not mean extra reach. This revises my earlier pitch to Nathan. P1, Research: untethered jumps get a slightly wider landing band.
2. **The silk map. P1.** At the end of a life, show the habitat with that life's routes and jumps drawn as faint silver lines, built from the bounded journal and sampled positions (§22 forbids persistent strands, and this needs none). The life summary is a drawing of where the spider went. There is no score (§11). The player can also open it mid-life from the notebook.
3. **Old silk. P2.** A later spider may find the remnant of an earlier retreat. The spec already treats this as a world encounter, not inherited memory (§12).

### A4. One life, in chapters → mortality and continuity (spec §11–14)

The spec's stages, death presets, and lineage rules hold. Additions:

1. **Chapters are offers. P1.** Each life stage gets a few authored opportunities that may or may not happen (§18): first rain on the glass, the mirror, the face at the window, the night lamp. Nothing tracks them as a checklist.
2. **The mirror. P1, Research.** A small mirror lies on the sill. Jumping spiders are widely reported to display at their own reflection (C4; a *Phidippus* source is still needed). Inspection classifies the reflection as another spider, and its display matches yours exactly. There is no way to win. The only resolution is to turn away. No text.
3. **Rest, and the question of dreams. P1.** *Evarcha arcuata*, a jumping spider, shows REM-sleep-like retinal movements while hanging on silk at night (C3). When the spider rests overnight, an optional short interlude replays fragments of that day's journaled events (the fly's path, the jump arc, the gust) in abstract form. Recorded events only, no invented feelings (§18). The notebook entry beside it says plainly that nobody knows whether anything is experienced. The question stays open (guardrail 6).
4. **The open window. P2.** The outdoors is visible from the start (§0). Late in a life, the window may open. Leaving is optional and ends that individual's story in the habitat. Nothing says whether leaving is good. The habitat persists and another spider may arrive (§11 continuation rules).

### A5. Other additions

- **Stillness draws the world closer. P1, cheap.** Prey detection already runs on angular motion (§8.2), so stillness lowers detection. Add a few harmless ambient animals and effects (a springtail, a gnat, dust in a light beam) that appear only after about 20 s without moving.
- **The night lamp. P1.** A household routine turns on a lamp in the evening and moths gather at the glass. Human rhythms create opportunities without humans becoming characters (§14).
- **A notebook of open questions. P1.** Every sourced fact sits next to what is still unknown.
- **Color. P1 art.** *P. audax*'s iridescent green chelicerae as the one saturated color on the body, catching light when the spider turns toward the camera.

### A6. Proposed deviations from v0.1 (need Chet's yes)

1. **S01 scope.** Move airborne, hanging, and feeding restore out of P0. P0 keeps the retreat checkpoint and S02. It is one of the most expensive gates and does not change how the slice plays. §22 already allows a labeled deferral. Reversible.
2. **Visible gaze in P0** (A1.1), as a toggleable presentation of the inspection cone, beyond the debug overlay.
3. **Where tests run.** Engine tests run on Nathan's PC through `run_tests.bat` (B1). Same runner and exit codes as §26 T00; only the machine differs.

---

## Part B. Build plan

### B0. Spec index

Chunks read sections by line range instead of loading the whole spec (889 lines). Line numbers refer to `chet/spec-v0.1.md` and to `prototype/docs/SPEC.md` once copied verbatim.

| § | Lines | § | Lines | § | Lines |
|---|---|---|---|---|---|
| 0 | 12–49 | 10 | 269–284 | 20 | 517–555 |
| 1 | 50–67 | 11 | 285–312 | 21 | 556–645 |
| 2 | 68–79 | 12 | 313–330 | 22 | 646–666 |
| 3 | 80–90 | 13 | 331–342 | 23 | 667–683 |
| 4 | 91–118 | 14 | 343–352 | 24 | 684–708 |
| 5 | 119–137 | 15 | 353–364 | 25 | 709–749 |
| 6 | 138–190 | 16 | 365–374 | 26 | 750–793 |
| 7 | 191–209 | 17 | 375–410 | 27 | 794–850 |
| 8 | 210–246 | 18 | 411–422 | 28 | 851–889 |
| 9 | 247–268 | 19 | 423–516 | | |

### B1. Constraints

- **Machine:** Nathan's PC runs Windows (x64). The spec's Windows-first default fits.
- **Usage:** each message in a long session costs more than the last, so each chunk is one fresh session with one model and one goal.
- **Godot:** my cloud workspace cannot reach Godot downloads (its network allowlist blocks GitHub and conda). I can parse and lint GDScript there with gdtoolkit. Engine-driven work runs on Nathan's PC:
  - `play.bat` launches the game.
  - `run_tests.bat` runs the headless test runner and writes `tests/last_report.txt`, which I read.
  - `record.bat` plays a scripted demo route under Godot's Movie Maker mode (`--write-movie`), so captures need no screen recorder. I convert the output to MP4 or GIF for review.
  - Chunk 2 first tries the Linux Godot build inside the local workspace on Nathan's PC. If that works, I run tests directly and the scripts are only for play.
- **Files:** the project lives in a folder on Nathan's PC that he connects each chunk. If Chet's project mirror exists there, the code goes in `prototype/` and `sources/` stays untouched (§0). Chet's spec is copied to `prototype/docs/SPEC.md` and this document to `prototype/docs/DECISIONS.md`.
- **Honesty:** I cannot feel the controls. Every handback separates what tests showed, what Nathan saw while playing, and what was not run (§26 T05, T10).

### B2. Models

- **Opus** where a wrong design costs several sessions: wall and underside locomotion, the tether solver, composing the habitat.
- **Sonnet** where the spec is already precise: setup, jump solver, perception, prey AI, save/load, packaging.
- **Haiku helpers** inside a session, for research and mechanical checks. A helper starts with no context, so it is used only for big, self-contained jobs.

Nathan sets the model in the picker before starting each chunk.

### B3. Chunks

| # | Model | Tasks | Reads (§) | Done when | Nathan |
|---|---|---|---|---|---|
| 1 | Opus | Plan (this document) | all | Saved to the project | Send this to Chet |
| 2 | Sonnet | T00, T01: project, pinned toolchain, input actions, placeholder spider, graybox lab, camera shell, test runner, the three scripts | 0, 6.1, 6.4, 17, 19, 27 | Opens cleanly; walk and look on the lab floor; runner exits 0 | Install Godot, connect the folder, run `play.bat` |
| 3 | Opus | T02: surface locomotion (walls, convex and concave edges, underside, gaps) | 6.1–6.2, 23 | M01 route works with support normals visible | Walk the lab route and note anything odd |
| 4 | Sonnet | T03: jump solver, prepare/cancel/commit, landing patch | 6.3, 21.1 | M02 runner reports landing error | Try about 20 jumps |
| 5 | Opus | T04, T05: tether, hang, reel, lower, release; first handback | 9.1, 23, 26–27 | M03 fixtures pass; HANDOFF.md; capture | Play 10 minutes, write three sentences on feel, send the handback to Chet |
| 6 | Sonnet* | Apply Chet's review | Chet's notes | Each item closed or answered | |
| 7 | Sonnet | T06: perception, visible gaze, last-seen mark | 7, A1–A2 | P01 | Watch a fly leave sight |
| 8 | Sonnet | T07: fly brain, capture, feeding | 8, 21.3 | A01, L01 | Hunt a fly |
| 9 | Opus | T08: the windowsill, two routes, retreat, onboarding, light, sound, disturbance | 2, 10, 14–18 | The 10–15 minute loop is playable | Play the whole loop |
| 10 | Sonnet | T09: save/load, accessibility | 17, 21–22, A6 | S01 as amended, S02, U01, W01 | Play with a controller and with sound off |
| 11 | Sonnet | T10: profile, fixtures, package, second handback | 24–27 | Every P0 gate marked passed, failed, or not run, with evidence | Short playtests with others if possible; send to Chet |

\*Opus if the review changes design rather than code.

Chunks 3, 5 and 9 are the most likely to need a second session. After the slice, the P1 items in Part A form the next queue, in an order Chet and Nathan choose.

### B4. Session protocol

1. Nathan opens a new chat in this project, sets the model named in `where-we-left-off.md`, connects the project folder, and pastes: **Next chunk. Read claude/where-we-left-off.md and do it.**
2. The chunk reads only its listed spec sections, by line range.
3. If usage runs low, the chunk stops at the last runnable state and writes the status note first.
4. Every chunk ends by updating `where-we-left-off.md`: what was done, what is next, which model, and what Nathan should try.

---

## Questions for Chet

1. Is the focus-judges-distance experiment (A1.2) acceptable as P1, given that comfort and M02 outrank it?
2. Do you accept the last-seen mark and head re-orientation (A2) as appropriate for *P. audax*, separate from *Portia* strategies, pending the C1 full-text check?
3. Do you accept the S01 deferral (A6.1)?

## Sources added

- **C1:** Hill, D.E. (1979). Orientation by jumping spiders of the genus *Phidippus* (Araneae: Salticidae) during the pursuit of prey. *Behavioral Ecology and Sociobiology*. [doi:10.1007/BF00293678](https://link.springer.com/article/10.1007/BF00293678). The DOI came from search results. Volume, pages, and the out-of-view detour detail still need confirmation from the full text.
- **C2:** Nagata, T. et al. (2012). Depth perception from image defocus in a jumping spider. *Science* 335(6067):469–472. [PubMed 22282813](https://pubmed.ncbi.nlm.nih.gov/22282813/). Species: *Hasarius adansoni*.
- **C3:** Rößler, D.C. et al. (2022). Regularly occurring bouts of retinal movements suggest an REM sleep–like state in jumping spiders. *PNAS* 119(34). [doi:10.1073/pnas.2204754119](https://www.pnas.org/doi/10.1073/pnas.2204754119). Species: *Evarcha arcuata*.
- **C4:** Salticid display toward mirror images. Candidate source found by a search helper and not yet reviewed: [*Peckhamia* 179.1](https://peckhamia.com/peckhamia/PECKHAMIA_179.1.pdf). A primary *Phidippus* source is needed before any realism claim.
