# Sound and the spider's other senses — Claude, 2026-10-11 (T12a)

ROADMAP step 3, built on T11b (`main` at fda7566). Nathan: "get done what you want to work on next and then chet can have the next round". Decisions SOUND-01 … SOUND-05. **Chet has the next round** (see the end).

## For the player

- **The room.** A refrigerator's hum and soft room tone, a thud somewhere in the house now and then, and air stirring when the shadow passes the window.
- **The flies.** Each flying fly buzzes from where it is, at its own slightly different note. A fly taking off whirrs. A fly struggling in the jaws buzzes louder and higher. Perched flies are silent.
- **What the spider feels.** When a fly lands, takes off or walks on a surface joined to the spider's, the spider feels it through its feet. You get three cues:
  - a low thrum from that direction;
  - a ripple on that side of the screen;
  - a caption, such as "[felt: footsteps, behind-left]".

  The ripple shows only a direction, never a place. It reaches the spider only through solid pieces that touch, it fades with distance and at each joint, and nothing crosses an air gap. A spider in the air or hanging on its line feels nothing.
- **Captions.** Every cue that matters gets a short line with its direction ("[buzzing, above, ahead-left]", "[a shadow sweeps over the sill]"), so the game is fully playable muted.
- **Esc menu.** Volume, Room sounds, and Flies and vibrations sliders, plus switches for captions and controller rumble.
- **Slow motion** slows the sounds too: they play slower and lower.

## The science, and what is translation

- The buzz is a house fly's wingbeat note, about 190–200 Hz (Wigglesworth 1972, as cited). *Phidippus audax*'s auditory neurons answered to 80–380 Hz from over 3 m, and the spiders froze at 80 Hz (Shamble et al. 2016, *Current Biology*), so a fly's buzz is plausibly heard by the spider too. The game does not claim the player hears what the spider hears (spec 16).
- Spiders feel substrate vibration through slit sensilla in their legs, mostly at tens to hundreds of hertz. The detailed studies are on *Cupiennius*; salticids have the same kind of organs. The thrum and the ripple are translations of that feeling, not recordings.
- All sounds are made in code (`scripts/audio/sound_bank.gd`). There are no audio files, so nothing needs licensing.

## Code

- `scripts/audio/sound_bank.gd` (new): six sounds generated once per run as `AudioStreamWAV` (22 050 Hz, 16-bit). The loops join cleanly.
- `scripts/audio/soundscape.gd` (new): buses Ambience and Cues, volumes from settings, the room, thuds, the shadow's whoosh, each fly's buzz (`AudioStreamPlayer3D`, heard at the camera), take-offs, thrums, and captions. It is created in played worlds only.
- `scripts/perception/vibration_sense.gd` (new):
  - It runs in every world, so tests can use it.
  - It watches flies for landings, take-offs and footsteps (one every 0.3 s while walking).
  - It finds the piece under the fly and the piece under the spider (new `SpiderMotor.get_support_body()`), then counts joints through touching habitat boxes, breadth-first.
  - Strength is `kind × e^(−distance / 4 WU) × 0.5^joints`. Anything under 0.08 is not felt.
  - A felt event goes out as the `felt` signal, with a bearing and a direction word. Controller rumble is optional.
- `scripts/presentation/sense_hud.gd` (new): up to three captions (3 s each) and the ripple arcs.
- `SimClock.set_speed` also sets `AudioServer.playback_speed_scale`.
- Settings (`volume_master`, `volume_ambience`, `volume_cues`, `captions`, `haptics`), pause menu, field notes and `main.gd` wiring.
- Tests: `tests/integration/test_t12a_senses.gd` (8).

## Verification

- **Evidence 4daaf055b746**: 565 / 565 (Linux headless, fixed 60 fps), including 8 new tests (`docs/verification/t12a/full_report_t12a.txt`).
- The sense, slow-motion, struggle, U01 and A01 tests pass at fixed 30 and 144 fps, 24 / 24 each.
- The tests check that:
  - the buzz's note is 195 Hz and the hum's is 60 Hz, and the loops join;
  - the buses follow the settings;
  - flies buzz only in flight or while struggling;
  - vibration is felt through the same floor and through a block standing on it (one joint), but not through a slab across an air gap, nor 20 WU away, nor with the spider in the air;
  - a real walking fly is felt as footsteps from behind;
  - muted play shows captions and a ripple on the right side;
  - slow motion slows the sounds.
- Smoke run clean. Still: `t12a_felt_vibration_and_captions.png`.
- **Not run on Windows, and the sounds have not been heard by a person yet.** Headless runs use a silent audio driver, so loudness and mix balance are untested. Nathan's ears are the check.

## Not done / for later

- Felt vibrations do not yet feed the spider's memory or the flies' decisions; they are presentation only. A next step could let a felt landing create a "possible prey" cue in the perception system.
- Silk: vibration along the safety line (spiders do feel through silk), and through the dragline while hanging.
- The spider's own footfalls shaking the leaf a fly is on (flies feeling the spider coming).
- A sound for the strike and the bite. Real ones are near silent; it could be a soft tick.
- Real recordings could replace the generated sounds later.

## Next round: Chet (ROADMAP step 4, movement realism part 2)

- Feet that plant and stay on the surface.
- Steps when turning in place.
- The back legs (pairs 3 and 4) pushing at take-off.
- The dragline fixed before every jump.
- A crouch and absorb on landing.

Keep the twitch. Slow motion is a good way to check the gait (T / right trigger). Start from `main`, finish into `main`, then run `update.bat`.
