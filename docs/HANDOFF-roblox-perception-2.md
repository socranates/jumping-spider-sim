# Perception part 2 — Chet, 2026-10-15

Small green milestone; flies are the next part of the same authorized round.

- Imported Claude's 77b426b and 8dd59b6, including sensor geometry and body-owned gaze.
- Wired sensor before movement; sill-only rays. TestTarget module has a pure path; PerceptionStage draws a labeled magenta marker, screen and 2 WU west ledge. Workspace.TestTarget gates it.
- Pure PerceptionText/PerceptionView adapters draw only remembered evidence; thin pooled HUD draws cues, category labels, four Focus ticks and fading dashed marks.
- Focus toggle uses Player.FocusToggle (default false). Surface departure clears it; aim/line retain cancel priority. Reset clears both sensor and memory.
- P01 F1–F8 run in Studio with real rays. The live client checks the actual target contact, avoiding an older anonymous cue record.
- Test report collector accepts separate client result rows so Studio's long-line truncation cannot silently lose tests.

Evidence: docs/verification/roblox-perception-2/. Studio 0.743.0.7431133, evidence 8b45f28cf2cca2ba: 58/58 engine, 9/9 client. src strict analysis clean. Physical tablet/controller not run; none available. Stage screenshot is a test-fixture view, not the final fly presentation.

Next: port flies from the frozen Godot reference; replace the marker in the playable place, retain the fixture in tests, and measure sensor cost in Studio with 3–6 flies. LIFE/checkpoints remain optional and unimplemented.
