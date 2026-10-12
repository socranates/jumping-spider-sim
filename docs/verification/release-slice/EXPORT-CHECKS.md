# Export checks - tested 2026-10-11, packaged 2026-10-12

Both release exports use unmodified game source **48b84a0**, evidence
**db112e2fa006**, Godot 4.7.2 official standard templates. No editor required
for the Windows executable. See `artifacts.json` for exact file/ZIP hashes.

| Check | Windows release executable | Web release, Codex Chromium browser |
|---|---|---|
| Starts and renders windowsill | Passed: native AMD/OpenGL, both views | Passed: localhost HTTP, 1280 x 720 canvas |
| Eye shader | Green weighting, soft surround and retinal fields observed, `windows-export-eye.jpg` | Same visual features, `web-export-eye.jpg` |
| Slow motion | 50% HUD shown from isolated persisted settings | T toggled 50% and returned to normal |
| Walking/jumping | Physical-key automation blocked; see below | W held for two seconds moved; Space hop left silk visible |
| Pause | Not verified through physical native input | Escape opened settings and resumed |
| Settings reload | Isolated eye-view preference loaded | Eye-view preference survived browser reload |
| Sound | Source benchmark master audio had nonzero samples, peak 0.8913; actual exported speaker output not independently recorded/listened to | Sound captions observed. Audible output not independently recorded/listened to; browser audio needs a user gesture |
| Controller | Not run with physical hardware | Not run with physical hardware |

The native automation tool sends V and Escape with the same incorrect
physical code **4194313**, while their logical codes differ (86 and
4194305). `input-probe.log` reproduces this in the source runtime too.
The game binds physical keys. Therefore native input attempts are
**inconclusive**, not a verified game defect or a completed native human
playthrough. The test did not change the shipping key bindings to work
around the tool. Windows eye/slow-motion screenshots used a separate
APPDATA test profile; Nathan's own settings and checkpoints were untouched.

The browser logged Chromium `UnknownError: If you see this error we have a
bug. Please report this bug to chromium.` at startup and during play.
Rendering, input and the tested preference persisted despite it. Cause is
unresolved; do not describe the web run as error-free or infer all saves
are reliable from one preference reload. Test an ordinary browser and
hosted build before public release. Cold load time was not measured (the
first browser observation timed out during startup); subsequent loads ran.

Web differences: needs an HTTP/HTTPS host, canvas focus/user gesture for
input/audio, browser/site-scoped persistence, and browser Escape/pointer-lock
behavior. The web ZIP is a hosting bundle, not a file:// application.
Native and browser eye pictures showed no obvious shader failure in the
views inspected; this is not pixel equality or exhaustive clipping coverage.

## Rebuild

Install the official Godot 4.7.2 export templates, import the project, then:

```text
godot --headless --path . --export-release "Windows Desktop" <output>/TheWindowsill.exe
godot --headless --path . --export-release Web <output>/index.html
```

Use separate output directories. Include generated companion files,
READ-ME.txt and GODOT-LICENSES.txt; ZIP directory contents with index.html
at the web archive root. Keep large build binaries out of source Git.
The fixture's `--licenses-only` option writes engine/third-party notices.
No itch.io upload, publication or external sharing was performed.
