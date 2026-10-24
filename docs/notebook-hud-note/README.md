# Match the hunger notebook note to the current HUD

2026-10-24. hungry_at_home's game note still referred to hunger words under
the day. In the active Preserve, SpiderClient selects minimal view and
SpiderHud removes that day/hunger prose. The post-trace native screen showed
the small unlabelled meter and requested0/7 meal counter, with no day prose.

The generator's ADAPTED entry now describes the abdomen and small meter.
Biological text, original sources, godotGame, frozen JSON/reference files,
triggers and starvation rules are unchanged. Only one generated game-note line
changes; it is shorter than the previous line. No UI or mechanics source changed.

Existing suites passed: NOTEBOOK1519 + MINIMAL81 =1600,0 failures. The changed
module compiled, full-source strict analysis exited0 and both273-source normal/
self-test models rebuilt, evidence2b1c99cacf601b8f. Generator output repeats
byte-for-byte. receipt.json binds sources, generator, outputs and build receipt.
Logs are normalized to LF, not described as raw Windows console bytes.

The first verification wrapper finished all four commands with exit0, then
failed in its reporting regex because it expected MINIMAL_HUD rather than the
suite's actual MINIMAL label. run-status.json records the observed exit codes
from exec session67252 and hashes the unchanged output/input cohort. Fixing
that report parser and running verify.py --collect-only succeeded without
rerunning or modifying successful test evidence.

The completed native camera/30-minute trace in ../camera-handover precedes this
one-sentence note correction; its exact source cohort remains at Gitc6f8cf83.
No new native notebook layout test, publication, main merge or production/save
write is claimed. Game-generated Luau retains Windows line endings; check
whitespace with Git's cr-at-eol option rather than changing this evidence's
bytes solely to satisfy a line-ending warning.
