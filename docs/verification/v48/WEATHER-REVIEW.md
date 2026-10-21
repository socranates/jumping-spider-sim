# Native weather sampling and streamed-shelter repair

Unpublished v48 review, 2026-10-21. The accepted native samples use source `7236420a5403935e7eb9b649cbde90d40eca73e5`, before the subsequent rain-cache repair below.

`studio-weather-review.luau` drives the actual client at dawn, noon, dusk, night, daytime heavy rain, the station floor during that rain, then back outdoors. Seven samples complete at each detail tier. The diagnostic selects Free play and places the observer; it proves rendering integration, not ordinary survival or traversal. Playback also suppresses some predators as documented by the client. No frame-performance claim is made: the immutable CLI regression was running concurrently.

## Accepted native evidence

Use only the `CHET_WEATHER_V3_SAMPLE`/`DONE` records in `weather-native.txt`. All fourteen samples complete. The first diagnostic versions mistakenly compared different update instants, then encountered the normal night-death screen, which pauses the environment. Those earlier records are not passing evidence. The final probe compares native sun/wind to the last applied lighting state and refuses stale samples or a showing death panel.

- Maximum native sun-direction error: 0.02798 degrees. Wind error against the applied state: zero in every sample.
- Dawn solar altitude about 8 degrees, noon about 59.83, dusk about -3.25, night about -34.85. Night drops the lighting brightness to about 0.513 and exposure to -0.25; heavy rain dims daylight to brightness 1.6055 and exposure -0.155.
- At heavy rain 0.85, full detail draws 23 local streaks, low draws seven/eight. Neither tier draws rain on the station floor. No visible streak centre is below its cached support cutoff.
- Player remains alive and attached at every accepted sample. Full detail stays at 294 close parts outdoors / 339 indoors; low at 136 / 145, within 420 / 150.
- Storm views are saved in `weather-full-storm.jpg` and `weather-low-storm.jpg`. These are normal camera views, not close-up renders. Low detail visibly has much sparser vegetation; neither screenshot alone proves a richly populated journey.
- `[CHET_WEATHER_REVIEW_CLEAN]` confirms the temporary playback and forced detail tier were removed from Studio.

## Streamed-shelter repair after sampling

Code inspection found that rain's ground cache refreshed only after observer movement. A newly arriving roof could remain invisible to rain while the player stood still. A real-parts regression reproduces this at both tiers: before repair 3,942 pass / six fail. The six failures include stationary roof discovery and unnecessary rain probes during fair weather/Reduced Motion.

Active stationary rain now refreshes two probes/full or one/low per 20 Hz update. An entire pool refresh takes at most 0.8 simulation seconds (0.5 at low detail), without a simultaneous stationary 32-cast burst. The existing immediate recenter refresh remains. Fair weather, hidden indoor rain and Reduced Motion perform no rain-ground probes. No new parts, collision surfaces, save fields or gameplay rules are introduced.

After repair: living-world suite 3,948 pass / zero fail, strict analysis clean, 207/207 source compile. Raw evidence is `rain-cache-before.txt`, `rain-cache-cli.txt`, `rain-cache-types.txt`, `rain-cache-compile.txt`. The case also removes the roof and verifies return to the actual floor while standing still.

## Remaining gates

The cache repair still needs native streamed-roof inspection and uncontended profiling. Sampled weather states do not establish a naturally observed full front transition; that remains open along with wind/cover inspection, broader ordinary hunts/travel and whole-build native gates. The full immutable regression of `7236420` is still running and cannot cover the later cache repair. Finish that run rather than restarting it, then validate the final source snapshot before release. No v48 publication claim.
