# Handoff: the sill round (ROBLOX-71..83) — spider picker, feel tuning, a living sill, the mating cycle, the tarantula pack

Claude → Chet, 2026-10-18. Branch **claude/roblox-sill** (on top of `claude/roblox-daily` d2fc73d, which is still
unmerged — this branch contains it, so importing this one bundle gives you everything since main ce64498).
Bundle: `claude-playtest/claude-sill.bundle`. Import:

    git fetch claude-playtest/claude-sill.bundle claude/roblox-sill:claude/roblox-sill
    git push origin claude/roblox-sill

Build evidence `d865b73033b37e93` (places rebuilt at the closing commit). CLI state at that commit: strict analyze
clean, 132/132 compile, every suite green (the big ones: life 20,878; wasp 16,884; rival 3,619; perception 4,669;
prey 1,646; settings 1,081; notebook 874; look 851; plus new suites `tarantula` 86, `mating` 545, `client_mating` 12).
Nothing in this round has run in Studio — the publishes below were Rojo syncs with command-bar spot checks only.

**Published while you were out** (Nathan asked): **v24** (the daily build d2fc73d), **v25** (ROBLOX-71..73), and
**v26** (the whole branch) — all to the playtest place 120119801868085 only, via your route (Rojo serve from a
separate clone `C:\Users\natha\windowsill-publish`, never Publish As). Your working copy was not touched.

## What is in the round (one decision each, tail of docs/DECISIONS.md)

- **ROBLOX-71 — spider picker.** A live "Your spider" Settings row (not a saved setting) changes spider anywhere the
  spider stands safely; crack key unchanged; `SpiderChoice.locked` is the single ownership hook for the future passes.
- **ROBLOX-72 — easier fly taps.** `Data/Catch.game` (startGrip .5, tap .12, jerks ×.8) via `Feeding:useGameRules`;
  Godot defaults bit-identical.
- **ROBLOX-73 — the rival contests the strike.** Aware rival: 55% caught / 25% springs clear / 20% counter-bite
  (0.25 energy; gentle free). Seeded own stream, `contests` in the record. Initiative up: reach 3.2, remember 5 s,
  stalk notice 0.45.
- **ROBLOX-74 — the sill dressed.** +192 parts full / +85 low (grass to 150 blades, moss, pebbles, bark, fallen
  leaves, 56 morning dew drops fading 07:30–09:30). All non-collidable/queryable; `WindowsillLayout.PIECES`
  untouched (a test raycasts through the decor and checksums the 28 boxes).
- **ROBLOX-75 — the wasp twice a day.** Morning 09:30–12:00 and afternoon 13:30–16:30, seeded, ≥2 h apart,
  `last_visit_slot` in the record; every old protection per window; takesRival per visit.
- **ROBLOX-76 — ambient music.** Original 64 s seamless loop `assets/audio/sill_music.wav` (synth:
  `tools/make_sill_music.py`; Nathan approved the piece). **Needs you**: upload the WAV, grant it to universe
  10771103250, paste the id into `Soundscape.IDS.music`, update the manifest entry. Until then the voice is silent
  by design. MusicVolume slider added (settings now 23); ducks to 40% while the wasp is on the sill.
- **ROBLOX-77 — the struggle scales with the meal.** Fruit fly 0.7 difficulty, house fly exactly ROBLOX-72, and the
  rival is a real fight (`Predator/RivalGrip`: ~4 taps/s wins in 6–9 s, no cap, grip 0 = it tears free to recover,
  same rival, no early respawn).
- **ROBLOX-78 — the hunger bar.** "Hunger", full when fed; game drain factor 1.1 → 1.55 (a day ≈ 0.5 energy), so
  the daily rival no longer makes starving impossible. Dial: `NeedsModel.game.drain`.
- **ROBLOX-79/80 — the mating cycle and the new generation.** Full-grown + fed → a mate arrives next morning
  (rival's arrival rules, rival's motor/route, never the crack); court it standing close, still, facing — the
  peacock dances; 8 s meter; strike drives it off (3 mornings max). Mated → next sleep builds the egg sac in the
  crack → 2 guard days → hatch morning: a 26 s seeded scene (spiderlings balloon away), ending card "The sill
  continues", sourced notebook page `eggs_and_wind`, then the player carries on as generation+1 (young juvenile,
  same sill, days continue, saves keep `generation` and the `mating` record; old saves restore as stage none).
- **ROBLOX-81..83 — the tarantula pack** (design by Perplexity, adapted). Mexican redknee and greenbottle blue as
  cosmetic appearances (88/124 parts full, 78/78 low; ocular tubercle, orthognath chelicerae, spinnerets, banding,
  the greenbottle's bars fading at the last stage), a 6 s threat & silk-mat display on the display key, and the
  sourced page `tarantula_cousins`. Free like the peacock and ant mimic (ROBLOX-66); `pack = "tarantula_pack"` on
  both profiles; **Nathan's open call: both in one ~US$0.99 pass vs one each**.
- **Designs only, no code:** `docs/TWO_PLAYER_DESIGN.md` (player 2 is the rival) and `docs/EXPANSION_DESIGN.md`
  (the garden, the species roster, the Steam road).

## Your Studio checklist

1. Import, push, merge judgment as usual. The branch is one line on top of roblox-daily; your v23 Studio evidence
   still covers nothing of this round.
2. Settings panel: 23 settings + the live Spider row (now five spiders); `tests/studio/SettingsSpec.luau` updated —
   run it. `PromptSpec` was NOT re-checked for the new help-card line (controls card may exceed ten lines on a
   phone) — check it.
3. Tarantulas: look at both under sill lighting (dark velvet may crush; rim/tubercle eyes at distance; rear angle
   32° on a flat body; sweep speed). `tests/studio/` has no TarantulaSpec — judgment call whether you add one.
4. Feel pass on a pad: fly taps (easier), fruit fly (easy), the rival fight (~29 taps at 4/s — too much on touch?),
   the rival counter-bite, hunger pace (a day ≈ 0.5), the wasp twice daily, music duck (after you upload the id).
5. The mating cycle end to end in Studio (use the Workspace attribute overrides/time controls you use for the wasp;
   `client_mating.luau` shows the beats): mate arrival day, courting with and without the dance, drive-off, sac
   night, two guard days, the hatch scene (frame time during 12 spiderlings), the ending card, generation 2 save
   round-trip on the real DataStore test place.
6. Dew and decor on the low tier (phone): part counts are tested, frame time is not.
7. Upload `sill_music.wav` (step in ROBLOX-76 above) — the one asset task this round.
8. Publish as you see fit — v26 is already the whole branch, so a re-publish after your pass is only needed if you
   change anything.

Open for Nathan: tarantula pass bundling (one vs each), the rival-fight tap count on touch, hunger pace feel, and
whether the hatch scene should be skippable.
