# v43 Windows release verification — 2026-10-21

## Identity and publish

- Incoming v43: 5f802ea5b4e7d1320c63f19531d5bda36db00eba.
- Frozen verification source: f014636e214495e8a829e4005987d06401131113.
- BuildInfo: 76c3d3822dfbddda.
- Existing place 120119801868085, universe 10771103250, preserve default.
- Game build v43 published successfully 2026-10-21T09:41:16Z; Roblox place version **53**. See publish-studio.txt.
- SelfTest cleared; StreamingEnabled retained; Rojo stopped; File > Publish, never Publish As.

## Results

- Frozen v43 full CLI: **351194 passed, 0 failed, 47 suites, exit 0**; see windows-v43-frozen-full-cli.txt.
- Native foreground Studio: **245 passed, 0 failed, 0 skipped**, 520 seconds. See windows-v43-foreground-studio.txt.
- Targeted v43: PRESERVE **1,133/1,133**, WORLD_CLIENT **30/30**.
- Source compile: **194/194** modules.
- Luau-lsp: exit 0, no source diagnostics. Informational definition loading and unsupported watcher registration notice are retained in windows-v43-types.txt.
- Mesh library: six native dimensions matched authored export within 0.00001 stud; six SpecialMesh preloads succeeded; six FBX hashes matched manifest. See mesh-and-sync-probes.txt, mesh-ids-and-dimensions.json and mesh-export-hashes.txt.

## Provenance and limits

The full CLI verification ran against a separate immutable git archive of f014636, not the changing publishing checkout. Source and tests in the final branch are identical to f014636; later changes add only mesh assets/tools and release documentation.

windows-transition-cli.txt is an earlier successful 351,194-check, 47-suite run that overlapped the v42-to-v43 source update. It is preserved as transition evidence and is not the frozen release result. windows-v42-background-studio.txt preserves the earlier 244-pass, 1-fail hut-descent timeout. The unchanged check passed in the foreground v43 run; no timeout or test was relaxed.

The foreground sill sample was 22.0 ms mean (45 fps), 32.8 ms worst, physics 60 fps in a small Studio viewport. Later sequential samples with far preserve or shadows removed were slower; this is not a controlled comparison. No phone, published-player performance, human feel, gamepad feel or new art integration approval is claimed.

## Remaining audio verification

Train 127788334000523, bell 78706177142395 and purr 81495950754571 are wired in published v43. Experience grants to 10771103250 remain unconfirmed. Manifest access flags remain false. Upload or owner-Studio loading is not grant evidence. Browser helper failed to identify the foreground process on both recovery attempts. Nathan requested help finding Permissions; instructions were provided. Confirmation of the three saved grants remains pending.

## Art and scope

Six original decorative mesh studies are uploaded, with editable Blender source and documented runtime sizing in docs/MESHES.md. Corrected model 105970842890511, texture 116765351721069. Oversized trial 131555390945988 is explicitly excluded. No imported sample was parented into Workspace. World source, sill pieces, collision and save IDs were untouched. Integration and published-client render checks remain Claude's next work.