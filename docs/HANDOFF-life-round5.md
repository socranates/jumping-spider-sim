# One whole life, round 5: death and continuing (Claude, 2026-10-13)

Built from `main` 5c56ef8 (Chet's wasp presentation, 632/632 on Linux too). Plan: `docs/LIFE_DESIGN.md` section 5. Decisions: LIFE-19 to LIFE-24.

## What changed
- **Rules** (`main.mode`, `main.rules`):
  - Standard (the main life) can kill. Gentle (Easy and free play) cannot.
  - Under Gentle, the wasp's strike becomes a touch, then it leaves (`WaspDirector._spare`), and hunger drains at half the rate and stops at 0.1 (`NeedsModel.gentle`).
  - Checkpoint schema 7 keeps `life_rules`.
- **Starving** (`HabitatLoop`, `NeedsModel.starving_streak_h`):
  - The top line shows "Starving" at zero, "will not last another day" after 24 h (too hungry to sleep), then death at 48 h.
  - A notebook page, "Going without food".
- **The end** (`main.end_life`, `caught_panel.gd show_end`): a plain line, a summary without a score, back to the last rest, on as another spider, or the notebook.
- **Another spider** (`main.continue_as_another`): a young juvenile somewhere new, said to be unrelated; the old life is kept in progress and its saves are put away; the notebook goes on.
- **Progress** (`scripts/life/progress.gd`, `user://progress.cfg` when settings save): the main life finished, deaths and lives. An adult of the main life on Standard opens Easy.
- **Start menu** (`scripts/presentation/start_menu.gd`):
  - At launch: Continue, Begin a new life, Easy (once earned), Free play (its own save in `saves/free`), Notebook and Quit.
  - It is also reachable from the pause menu ("Start menu").

## For Chet
1. **Windows check of the start menu:**
   - keyboard, mouse and controller (focus moves with the D-pad and stick; A presses);
   - large text;
   - the web build (Quit is hidden there).
2. **A whole life's turns in play:**
   - Starving to the end (time can be helped along with the developer views).
   - The wasp's catch, then "Continue as another spider". The new spider appears somewhere new with the unrelated line.
   - "Back to your last rest".
   - Free play, where the wasp only touches.
   - Finishing to adult, which opens Easy.
3. **The wasp's first-arrival hitch** (184 ms in your battery run). If it is the wasp's materials compiling on first draw, a pre-warm (drawing it once, out of sight, at load) may cure it. Please measure before and after.
4. **The end screen and start menu at 1080p and with large text**, and the controller focus on both.
5. Rebuild the friend ZIPs if there is time, so friends get the whole life.

**Next:** round 6 is Nathan, his son and friends playing a whole life.

## Verification
Stills: `docs/verification/life05/`. Evidence: DECISIONS LIFE-24 and SESSION_LOG.
