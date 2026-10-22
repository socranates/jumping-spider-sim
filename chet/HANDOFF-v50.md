# Windowsill v50 handoff - verification in progress

**Not published yet.** Continue from `codex/v50-feeding-survival`, currently
`a772d2bb24f3141f7c9c5618cf861a947cd1b807`, evidence `c151f1719bee5c60`.
The existing published baseline is v49/place138. The accepted six-part prompt is
preserved at `docs/reference/chet-prompt-v49.md`; its requested release name was
stale, so this is v50. Active work is Roblox; Godot remains frozen.

## Player-facing changes

- E / Xbox left-stick click / PlayStation L3 / touch Grip-Eat explains a caught
  meal. Taps keep grip, then open a 0.38-second bite window. Faster valid taps
  renew that window and pulse the bite, without banking food or exceeding the
  original nutrition rate. Moving or leaving support pauses eating.
- The fly follows the animated jaws, its drawn body empties, and a bounded
  three-part noninteractive husk drops and fades. Reduced Motion reduces chewing.
  A quiet built-in sound supplies bite/end feedback without another asset grant.
- AutomaticGrip also supports automatic eating, default off. ControlHints
  covers the new prompts in every mode. The wordless150x6 hunger bar and2px dot
  remain. No future unlock is advertised; seven/ten full-fly moults and earned
  Run/lock, controls, aim, jumps, nutrition credit and lighting are preserved.
- At dusk, a brief reminder names the local home (the Crack at the sill), then
  the actual rest button there. Rest clears it; the next night returns it.
- Normal weakens after6 empty-reserve game hours and dies after12. A fresh
  unfed life is bounded by three game days even using sleeping drain. Easy and
  Free remain nonfatal. Old pure/Godot references retain24/48 defaults.
- Restore supplies missing bite fields from pre-v50 saves. ObjectRecord clears
  constructor defaults; future optional fields need the same compatibility care.
- Held prey no longer draws its perched shadow in midair. Shelf and floorA
  fallback spawns clear books/boots. Their geometry and existing saved positions
  are unchanged. Distant cat pose specs are reused at10Hz beyond180 studs, while
  her body frame still moves every render; behavior/audio keep their rates.

## Evidence and pending work

- Current focused checks: meals88/0, spawn clearance20/0, flies283/0,
  settings1163/0. Strict analysis clean;211 source modules compiled before the
  final compatibility/text changes (repeat final compile/type receipt).
- Candidate A full native SelfTest273/0/0. It predates the smooth cat carry,
  faster tap response, shadow/fallback/old-save fixes. Its source manifest is
  `docs/verification/v50/native-candidate-A-source.json`.
- Candidate B full native meal fixture proved jaw distance0, body depletion,
  device prompts, a three-part husk, built-in audio loaded, dusk and E rest.
  Full233-region walk/hop/camera survey had no missing regions, stayed within
  the1500-part scenery budget, and found six camera observations at the two
  fallback points subsequently fixed. Raw files are retained, not overwritten.
- A frozen Windows57-suite run of B=`9e60bba` is active in
  `C:/Users/natha/claude-xfer/v50-cli-9e60bba`. Its known settings-note length
  failure is fixed and rerun green. Keep its actual source scope in the report.
- Final source GitHub58-suite CI:
  https://github.com/socranates/jumping-spider-sim/actions/runs/39704486074
- Final-source low native SelfTest is active. It now includes the fallback
  camera guard, so274 checks are expected. Do not restart a quiet live run.
- Still required: finish those runs, low233-region survey and native final
  shadow/fallback/tight-space/leaf checks; labelled touch emulator if available;
  foreground full/low after profiles with **no concurrent CLI**; decide whether
  to retain the cat optimization from measurements; final source fingerprints,
  cleanup and publication to the existing place, Dashboard proof, report/package.

Baseline profiles and rendering audit are in `docs/verification/v50`. Initial
pond_a2 profiling was an underwater view; corrected bank samples use deck_n2.
Do not claim the temporary black doorway view was a fixed camera bug. The final
performance receipt must exclude CLI-loaded samples from the native self-test.

## Working locations and publication guardrails

Writable clone: `C:/Users/natha/windowsill-publish`. Shared OneDrive and Project
`sources/` remain read-only. Remote `github` is socranates/jumping-spider-sim;
do not push the OneDrive `origin`, main, or a Claude branch.

Local Studio36441252 is a PlaceId0 review file connected to Rojo34872. Cloud
Studio4131012 is the existing place120119801868085/universe10771103250, stopped
and disconnected on v49. Publish only that existing place after exact-source
comparison. Remove SilkPlayback and SelfTest/Detail/Cat/Wasp/TestTarget overrides;
verify gravity35, streaming and liked Future lighting. Do not publish the local
review file or a new experience, and do not change audience/access settings.

The requested `chet/review-5.md` already holds the v47 report. Preserve that old
report under its verification directory before replacing it with the final v50
receipt. Provide an active-Roblox-only source package and exact path/hash, rather
than a PC-only link or the whole frozen Godot history.

No messages or emails were sent. Recent inbox alerts linked older GitHub failures;
the preceding v49 source CI was already green. Do not copy private mail headers
or unsubscribe links into the repository.
