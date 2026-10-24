# Integrated candidate source map

Exact clean model SHA256 `bf77f6c885237f14fd274cf4c419300a88507d876c3cf780824b18d9ca2577d9`; 273 staged sources, including the qualified save owner, scenery cache and title fix. Production remains unchanged.

This index supersedes the older 222-file lexical map for this private candidate. It records file size, purpose, side, inferred consumers/direct standard tests, and runtime call sites. A direct import is not a coverage percentage. Modules without a direct standard-suite import may have indirect or separately qualified private protocol tests. Unresolved/ambiguous imports remain explicit; no cycle-free claim is made.

273 files / 65,161 lines; 13 files over 800 lines; 64 without a direct standard test import; 0 without a strict directive.

| Source | Lines | Side | Purpose | Inferred consumers | Direct standard imports | Flags |
|---|---:|---|---|---|---|---|
| `Client/BirdBody.luau` | 208 | Client | The robin in the world (ROBLOX-120): Predator/Bird's American robin drawn at its true size, 25 cm from bill to tail (Bird.LENGTH), from `parts` (pure: | Client/SpiderClient.client.luau | bodies.luau, preserve.luau |  |
| `Client/BugBodies.luau` | 767 | Client | The drawn woodlice (ROBLOX-96, Prey/Woodlouse): a grey segmented body about a centimetre long, made of seven overlapping plates over the back, a small | Client/SelfTest.luau, Client/SpiderClient.client.luau | bodies.luau, garden_life.luau |  |
| `Client/CatBody.luau` | 121 | Client | The ranger's cat in the world (ROBLOX-118): Rig/CatPose's parts, built once and moved each frame from Predator/Cat (where it is, which way it faces, w | Client/SpiderClient.client.luau | feeding_survival.luau |  |
| `Client/CaughtPanel.luau` | 191 | Client | Plain end/start screens. Scroll within the safe area; the selected button owns accept, | Client/SpiderClient.client.luau | menu_overflow.luau, title.luau |  |
| `Client/CrabBody.luau` | 117 | Client | The crab spiders in the world (ROBLOX-119): each of Predator/CrabSpider's drawn at true size on its flower, a female goldenrod crab spider about 9 mm  | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/FlyBodies.luau` | 650 | Client | The drawn fly: a house fly (Data/FlyLook has every number) 0.7 cm long, made of ellipsoids and rods: a head with two big red-brown | Client/SpiderClient.client.luau | bodies.luau, feeding_survival.luau, flies.luau, garden_life.luau |  |
| `Client/FrameProfile.luau` | 135 | Client | The client's frame, timed by part (ROBLOX-111): what the self-test prints when it samples the frame time, so a Studio run says where a slow frame's ti | Client/SpiderClient.client.luau, Client/WorldClient.luau |  | no direct standard import |
| `Client/HutLife.luau` | 249 | Client | The ranger hut's own life on this client (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B): the window's sash, shut through the nursery and propped open | Client/WorldClient.luau |  | no direct standard import |
| `Client/LivingWorld.luau` | 483 | Client | The close world: bounded local detail, ambient animals, and weather. No movement/save/attack rules live here. | Client/WorldClient.luau | living_world.luau |  |
| `Client/LookStream.luau` | 276 | Client | The drawn looks of the regions outside the window, built on this client near the spider and destroyed far from it (ROBLOX-108). | Client/WorldClient.luau | world_client.luau |  |
| `Client/MateStage.luau` | 348 | Client | What the mating cycle looks like (ROBLOX-80). Display only: the cycle itself is Life/Mating and Predator/Mate (what is true), and nothing here feeds b | Client/SpiderClient.client.luau | client_mating.luau |  |
| `Client/MealPresentation.luau` | 68 | Client | Drawing only: one held-body override and one short-lived, noninteractive husk. | Client/SpiderClient.client.luau | feeding_survival.luau |  |
| `Client/NotebookArt.luau` | 32 | Client | Small authored vector sketches, deliberately diagrams rather than photographs or eye-view claims. |  |  | no direct standard import |
| `Client/NotebookPanel.luau` | 497 | Client | The naturalist's notebook on screen (ROBLOX-37), from Godot's notebook_panel.gd: the pages found so far on the left, in the order they | Client/SpiderClient.client.luau | notebook.luau |  |
| `Client/OldSkins.luau` | 39 | Client | At most three pale, empty skins in the retreat. Presentation only, never queried by movement or senses. | Client/SpiderClient.client.luau | growth.luau |  |
| `Client/PerceptionHud.luau` | 234 | Client | Thin drawer for the pure memory view (Shared/UI/PerceptionView). Reuses widgets rather than creating Instances every frame. | Client/SpiderClient.client.luau | hud.luau |  |
| `Client/PerceptionStage.luau` | 39 | Client | Temporary D-038 stage, away from spawn, crevice and recovery routes. Physical screen/ledge belong to WORLD. | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/PondBodies.luau` | 188 | Client | The pond's bigger animals in the world (ROBLOX-122): the green frog of Predator/Frog on its seat, and the green darner (World/Pond.darner) patrolling  | Client/SpiderClient.client.luau | bodies.luau, preserve.luau |  |
| `Client/RareBody.luau` | 86 | Client | One bounded local animal. Supports join the custom motor's world query root; | Client/SpiderClient.client.luau | rare_sightings.luau |  |
| `Client/RecoveryApplication.luau` | 155 | Client | Application ownership around the negotiated recovery/replacement adapters. | Client/SpiderClient.client.luau | recovery_application.luau |  |
| `Client/RecoveryGameEntryPrototype.luau` | 134 | Client | Private actual-game adapter. Caller installs these callbacks only after safe | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/RecoveryOfferValidation.luau` | 25 | Client | Incoming protected observations may describe a recorded habitat. They are | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/ReplacementClientPrototype.luau` | 220 | Client | Optional adapter over the actual SaveClient/Continuation. A failed or timed | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/SaveClient.luau` | 335 | Client | The client's side of persistent saves (ROBLOX-39). It looks for the server's remotes, says hello, hears the saved state, and sends the | Client/ReplacementClientPrototype.luau, Client/SpiderClient.client.luau | local_rest.luau, save_continuation.luau, state.luau, state_client.luau, state_offline.luau, title.luau |  |
| `Client/SaveContinuation.luau` | 345 | Client | Opt-in protocol3 state. No engine waits or DataStore access. The game supplies | Client/ReplacementClientPrototype.luau, Client/SaveClient.luau | save_continuation.luau, save_offers.luau |  |
| `Client/SaveRestore.luau` | 48 | Client | One private preparation at a time. prepare owns a stable record and returns | Client/SpiderClient.client.luau | save_restore.luau |  |
| `Client/SelfTest.luau` | 1809 | Client | The live place's self-test (ROBLOX-104): a run of the real client inside a real Studio Play session, which prints what it finds to Output, so every pu | Client/SpiderClient.client.luau | selftest.luau, selftest_preserve.luau, title.luau | over800 |
| `Client/SettingsPanel.luau` | 695 | Client | The settings on screen (ROBLOX-49): a list of sections (Sound, Camera, Comfort and accessibility, Help and hints), each setting a row with | Client/SpiderClient.client.luau | settings.luau |  |
| `Client/Soundscape.luau` | 195 | Client | Original procedural recordings from the frozen Godot sound_bank.gd. Presentation only: | Client/SpiderClient.client.luau | client_smoke.luau, feeding_survival.luau, growth.luau, settings.luau |  |
| `Client/SpiderCamera.luau` | 724 | Client | The spider's camera: a Roblox port of the frozen Godot rig, scripts/movement/camera_rig.gd (c87ce00). | Client/SpiderClient.client.luau | eyes.luau, gaze.luau, growth.luau, scenarios.luau, spawn_clearance.luau |  |
| `Client/SpiderClient.client.luau` | 2783 | Client | The playable spider. Wires one control scheme (SpiderInput: keyboard and mouse, controller and touch together) to the |  | client_ant.luau, client_mating.luau, client_rival.luau, client_smoke.luau, continuation_menu.luau, eyes.luau, feeding_survival.luau, inspect.luau, local_rest_client.luau, local_return.luau, lock.luau, minimal_hud.luau, nature_client.luau, navigation_startup.luau, notebook.luau, outdoor_life_reset.luau, perception_client.luau, quiet.luau, rare_sightings.luau, save_notice.luau, selftest.luau, selftest_preserve.luau, settings.luau, state_client.luau, state_offline.luau, title.luau, world_client.luau | over800, unresolved imports |
| `Client/SpiderEyes.luau` | 460 | Client | The spider-eye picture (ROBLOX-20): what the eye view looks like, drawn on this client from the pure rules of Shared/UI/EyeOptics | Client/SpiderClient.client.luau | eyes.luau |  |
| `Client/SpiderHud.luau` | 434 | Client | The spider's screen: the centre dot and Focus ticks, the aim's words under them (Godot jump_hud.gd), a status line and | Client/SpiderClient.client.luau | feeding_survival.luau, hud.luau, minimal_hud.luau, save_notice.luau |  |
| `Client/SpiderInput.luau` | 263 | Client | One action path for keyboard, mouse, gamepad and held on-screen touch buttons, all at once. | Client/SpiderClient.client.luau | client_smoke.luau, lock.luau, notebook.luau |  |
| `Client/StationMouseBody.luau` | 40 | Client | Presentation only. Shapes are anchored and non-queryable like other animals. | Client/SpiderClient.client.luau | station_debug.luau |  |
| `Client/TitleCard.luau` | 261 | Client | The title card's camera and the intro of a new life (ROBLOX-109). The words are UI/TitleText's, the shots Movement/TitleShots'; this module draws them | Client/SpiderClient.client.luau |  | no direct standard import |
| `Client/TrainPass.luau` | 137 | Client | The trains beyond the preserve's north fence, drawn (ROBLOX-115): a silhouette of cars that runs along the railway's track when World/PreserveTrain's  | Client/WorldClient.luau |  | no direct standard import |
| `Client/WaspBody.luau` | 226 | Client | The drawn mud dauber wasp (Data/WaspLook has every number): about 2.5 cm long, built from ellipsoids and rods as the fly is | Client/SpiderClient.client.luau | wasp.luau |  |
| `Client/WorldClient.luau` | 364 | Client | The client's side of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). The spider, the flies, the wasp, the rival and the mate are all simulated here, | Client/SpiderClient.client.luau | world_client.luau |  |
| `Client/WorldDetail.luau` | 35 | Client | The low-detail tier of the world, applied on one client: phones and tablets drop what the server built for the full tier | Client/SpiderClient.client.luau | world.luau |  |
| `Client/WorldShadows.luau` | 186 | Client | The walkable boxes' shadows, kept to the ones an eye at the spider could see (ROBLOX-121). | Client/WorldClient.luau | shadows.luau |  |
| `First/Splash.client.luau` | 10 | First | ReplicatedFirst's one script (ROBLOX-109): the game's own loading screen, First/SplashScreen. Whatever happens in it, it ends: SplashScreen.run is |  |  | no direct standard import, unresolved imports |
| `First/SplashScreen.luau` | 243 | First | The startup veil/title drift (ROBLOX-109). Healthy TitleReady fades into the |  | title.luau | unresolved imports |
| `Server/DataStoreBackend.luau` | 81 | Server | Roblox DataStore adapter (read and update, neither raises). An optional storage codec handles only R_ rest keys; | Server/Persistence.server.luau, Server/RecoveryRawBackendPrototype.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `Server/Main.server.luau` | 72 | Server | Builds the world: the windowsill (scripts/habitat/windowsill.gd) as region 0 of the map (World/WorldBuild, ROBLOX-94: every region's physical boxes un |  |  | no direct standard import |
| `Server/Persistence.server.luau` | 83 | Server | The sole engine save entry point. It installs the complete Preserve owner at |  |  | no direct standard import |
| `Server/RecoveryAccountLifetimes.luau` | 191 | Server | Server-owned account visits. Closed initial-load cleanup has metadata-only | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryCommitControllerPrototype.luau` | 273 | Server | Private post-archive coordinator. begin requires the archive controller's | Server/RecoveryPipelinePrototype.luau |  | no direct standard import |
| `Server/RecoveryCurrentWriterPrototype.luau` | 329 | Server | Private schema3 continuation writer. Requires an already granted actual life | Server/RecoverySaveLoopPrototype.luau |  | no direct standard import |
| `Server/RecoveryDeparturePrototype.luau` | 167 | Server | Private recovery-only departure. Atomically preserve three-way local P | Server/RecoveryRuntimePrototype.luau |  | no direct standard import |
| `Server/RecoveryEntryPrototype.luau` | 233 | Server | Private server half of schema3 entry. A client-applied receipt is a solo-game | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryIdlePrototype.luau` | 148 | Server | Private terminal-held lease maintenance, separate from accepted recovery's | Server/RecoveryRuntimePrototype.luau |  | no direct standard import |
| `Server/RecoveryNewLifePolicyPrototype.luau` | 281 | Server | Explicit protected New, before playable adoption. Complete originals are | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryOfferReaderPrototype.luau` | 209 | Server | Private read-only legacy/pending-import discovery. Publishes only protected | Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryRuntimePrototype.luau |  | no direct standard import |
| `Server/RecoveryPacketPrototype.luau` | 135 | Server | Private schema/immutable proposal only. No store calls, source replacement, | Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRestWriterPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoverySessionRebindPrototype.luau |  | no direct standard import |
| `Server/RecoveryPipelinePrototype.luau` | 276 | Server | Private accepted-intent owner: archive -> commit -> fresh witnesses -> local | Server/RecoveryProfileOwnerPrototype.luau, Server/RecoveryRuntimePrototype.luau |  | no direct standard import |
| `Server/RecoveryProfileAdmissionOptions.luau` | 20 | Server | Copy server profile dependencies while retaining one pre-load account lane. | Server/RecoveryProfileOwnerPrototype.luau |  | no direct standard import |
| `Server/RecoveryProfileOwnerPrototype.luau` | 343 | Server | Server-authored profiles over ONE session/worker/quota. This remains private: | Server/ReplacementOwnerPrototype.luau |  | no direct standard import |
| `Server/RecoveryProgressBaselinePrototype.luau` | 175 | Server | Private backend sidecar. Capture the session's acknowledged P baseline before | Server/RecoveryRuntimePrototype.luau |  | no direct standard import |
| `Server/RecoveryProgressWriterPrototype.luau` | 144 | Server | Private P absorption only. No life/gameplay grant or cross-key atomicity. | Server/RecoveryCommitControllerPrototype.luau |  | no direct standard import |
| `Server/RecoveryProposalStorePrototype.luau` | 124 | Server | Private immutable M1 publication only. A caller must separately verify A1 and | Server/RecoveryCommitControllerPrototype.luau |  | no direct standard import |
| `Server/RecoveryRawBackendPrototype.luau` | 19 | Server | Private recovery adapter. Reuse the production protected UpdateAsync boundary | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryReadLeasePrototype.luau` | 132 | Server | Private lease-only routing for read/entry phases, outside an accepted recovery | Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryProfileOwnerPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoveryRuntimePrototype.luau, Server/RecoverySaveLoopPrototype.luau |  | no direct standard import |
| `Server/RecoveryRequestAdmission.luau` | 86 | Server | Private bridge for a polled worker. One lane is owned by the server/account | Server/RecoveryEntryPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryReadLeasePrototype.luau |  | no direct standard import |
| `Server/RecoveryRestFormatPrototype.luau` | 144 | Server | Private schema-3 readers/preparation, not an entry/storage authority grant. | Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryRestWriterPrototype.luau` | 116 | Server | Private exact selected-R CAS, not a complete multi-key transaction. Verified | Server/RecoveryCommitControllerPrototype.luau |  | no direct standard import |
| `Server/RecoveryRoutineProgressPrototype.luau` | 184 | Server | Private recovered progress worker. Never invokes the ordinary whole-snapshot | Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoverySaveLoopPrototype.luau |  | no direct standard import |
| `Server/RecoveryRuntimePrototype.luau` | 405 | Server | Private single session owner. Factory/load/tick/selection/departure routing; | Server/RecoveryServiceOwnerPrototype.luau |  | no direct standard import |
| `Server/RecoverySaveLoopPrototype.luau` | 155 | Server | Private single scheduler for recovered progress/rest/lease ownership. | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RecoveryServiceOwnerPrototype.luau` | 122 | Server | Private selection-scoped SaveService owner. Engine/menu installation remains gated. | Server/RecoveryProfileOwnerPrototype.luau |  | no direct standard import |
| `Server/RecoverySessionRebindPrototype.luau` | 85 | Server | Private local adoption after storage verification. No backend calls, schema-3 | Server/RecoveryPipelinePrototype.luau |  | no direct standard import |
| `Server/RecoveryStartup.luau` | 35 | Server | Cold Preserve startup only. One physical-account ledger owns every save path. | Server/Persistence.server.luau |  | no direct standard import |
| `Server/RecoveryStartupBudgetPrototype.luau` | 106 | Server | Private bounded startup lane. One shared owner per server; never changes |  |  | no direct standard import |
| `Server/RecoveryTemplates.luau` | 147 | Server | Server-authored, unplayed recovery destinations. No client record, live life, | Server/Persistence.server.luau | recovery_templates.luau |  |
| `Server/ReplacementOwnerPrototype.luau` | 100 | Server | Adds quiescence to the private all-slot owner; never silently swaps a Session. | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/ReplacementServicePrototype.luau` | 266 | Server | Optional adapter over the actual SaveService. The old owner is removed and | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RequestAdmissionFacade.luau` | 60 | Server | Private polling facade. Waiting for admission makes no provider request and | Server/RecoveryRequestAdmission.luau |  | no direct standard import |
| `Server/RequestAdmissionGate.luau` | 231 | Server | Private server admission candidate. No production caller installs this yet. | Server/RecoveryStartup.luau |  | no direct standard import |
| `Server/RestCompression.luau` | 128 | Server | Storage only: independently compressed current/backup cores retain their original canonical checksums. | Server/Persistence.server.luau, Server/RecoveryPacketPrototype.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `Server/SaveService.luau` | 317 | Server | The server's persistence service (ROBLOX-39): one SaveSession per player, and the only place a client's message is turned into anything | Server/Persistence.server.luau, Server/ReplacementServicePrototype.luau | state.luau |  |
| `Server/WorldFocus.luau` | 116 | Server | Where the server streams the world to (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). With Workspace.StreamingEnabled the server sends each client only the in | Server/Main.server.luau | world.luau |  |
| `Shared/Data/AntMimic.luau` | 61 | Shared | The ant-mimicking jumping spider's walk and antennae (ROBLOX-64): every number the pose needs, each marked DOC (reported in the | Shared/Learning/NotebookWatch.luau, Shared/Rig/AntMimicPose.luau | antmimic.luau, notebook.luau |  |
| `Shared/Data/Appearances.luau` | 844 | Shared | Artist-directed appearance, independent of species tuning, growth and physics. | Client/MateStage.luau, Shared/Rig/SpiderChoice.luau, Shared/Rig/SpiderRig.luau | antmimic.luau, idle.luau, look.luau, peacock.luau, run.luau, state.luau, tarantula.luau | over800 |
| `Shared/Data/Catch.luau` | 81 | Shared | The catch struggle as the game plays it (ROBLOX-72, ROBLOX-77). Game tuning, not measurements; Godot's values (Prey/Feeding's defaults, checked | Shared/Prey/Feeding.luau | garden_life.luau, preserve.luau, prey.luau, rival.luau |  |
| `Shared/Data/Detail.luau` | 20 | Shared | Which detail tier a device runs: "full" for computers and consoles, "low" for touch-only phones and tablets. The tier | Client/SpiderClient.client.luau | world.luau |  |
| `Shared/Data/Eyes.luau` | 160 | Shared | The numbers of the spider-eye picture (ROBLOX-20): how each way of seeing looks, how the two retinae move, how the lateral | Client/SpiderEyes.luau, Shared/UI/EyeOptics.luau | eyes.luau |  |
| `Shared/Data/Flora.luau` | 213 | Shared | The plants of the drawn world: the Pilea on the sill, the trough's planting, and the garden outside the window. Numbers and | Shared/Habitat/DayLight.luau, Shared/Habitat/Dressing.luau, Shared/Habitat/Plants.luau, Shared/Habitat/Scenery.luau, Shared/World/Garden.luau | world.luau |  |
| `Shared/Data/FlyLook.luau` | 482 | Shared | How a fly looks: numbers and names only; Client/FlyBodies builds the parts and places them each frame. A house fly (Musca | Client/BugBodies.luau, Client/FlyBodies.luau | bodies.luau, flies.luau |  |
| `Shared/Data/Graphics.luau` | 228 | Shared | How the world looks, apart from the spider (whose look is Data/Appearances). Numbers and names only, so the whole look can | Client/WorldDetail.luau, Shared/Habitat/DayLight.luau, Shared/Habitat/Dressing.luau, Shared/Habitat/Lit.luau, Shared/Habitat/Patina.luau, Shared/Habitat/Plants.luau, Shared/Habitat/Scenery.luau | life.luau, world.luau |  |
| `Shared/Data/MatingRules.luau` | 85 | Shared | The mating cycle's numbers (ROBLOX-79). Game tuning, not measurements: Predator/Mate and Life/Mating read these and nothing else decides them. | Client/MateStage.luau, Client/SpiderClient.client.luau, Shared/Life/Mating.luau, Shared/Life/MatingScene.luau, Shared/Predator/Mate.luau | client_mating.luau, mating.luau, nature.luau |  |
| `Shared/Data/Meshes.luau` | 36 | Shared | The preserve's first meshes (ROBLOX-126; docs/MESHES.md, assets/meshes/manifest.json): original Blender studies by Chet, uploaded by socranates and ve | Client/LivingWorld.luau, Shared/Habitat/Scenery.luau | preserve.luau |  |
| `Shared/Data/NotebookPages.luau` | 665 | Shared | The naturalist's notebook pages (LEARN-01), GENERATED by tools/gen_notebook_pages.py from the frozen Godot | Client/SpiderClient.client.luau, Shared/Learning/FieldNotebook.luau, Shared/Learning/NotebookWatch.luau | antmimic.luau, client_mating.luau, notebook.luau |  |
| `Shared/Data/Peacock.luau` | 74 | Shared | The peacock spider's courtship dance (ROBLOX-29): every number the dance needs, each marked DOC (reported in the paper) or ART | Shared/Rig/PeacockDance.luau, Shared/UI/PeacockText.luau | peacock.luau |  |
| `Shared/Data/RareSightings.luau` | 12 | Shared | Only finished encounters are registered. The thirteen-creature roadmap is | Shared/Life/RareDirector.luau | rare_sightings.luau |  |
| `Shared/Data/RivalRules.luau` | 57 | Shared | When the brown rival spider arrives (ROBLOX-68). Game tuning, not measurements. Predator/RivalSpider reads these; nothing else decides it. | Shared/Predator/RivalDrive.luau, Shared/Predator/RivalRoute.luau, Shared/Predator/RivalSpider.luau, Shared/World/Region.luau | mating.luau, nature.luau, rival.luau, rivalnav.luau, worldmap.luau |  |
| `Shared/Data/SaveRules.luau` | 77 | Shared | Every number and name the persistent saves use (ROBLOX-39): store names, key prefixes, sizes, timings, limits. The logic is in | Client/RecoveryGameEntryPrototype.luau, Client/RecoveryOfferValidation.luau, Client/SpiderClient.client.luau, Server/Persistence.server.luau, Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProfileOwnerPrototype.luau, Server/RecoveryProgressBaselinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoveryRuntimePrototype.luau, Server/RecoverySaveLoopPrototype.luau, Server/RecoveryServiceOwnerPrototype.luau, Server/RecoverySessionRebindPrototype.luau, Server/RecoveryStartupBudgetPrototype.luau, Server/RecoveryTemplates.luau, Server/ReplacementOwnerPrototype.luau, Server/ReplacementServicePrototype.luau, Server/SaveService.luau, Shared/Persistence/MemoryBackend.luau, Shared/Persistence/OrdinaryRequestAdmission.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/RecoveryEntryClientPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau, Shared/Persistence/RecoverySessionFencePrototype.luau, Shared/Persistence/RecoverySourceCollectorPrototype.luau, Shared/Persistence/ReplacementProtocolPrototype.luau, Shared/Persistence/SaveEnvelope.luau, Shared/Persistence/SaveIntent.luau, Shared/Persistence/SaveObservation.luau, Shared/Persistence/SaveProgress.luau, Shared/Persistence/SaveRest.luau, Shared/Persistence/SaveScheduler.luau, Shared/Persistence/SaveSession.luau, Shared/Persistence/SaveStores.luau | client_ant.luau, continuation_menu.luau, local_rest.luau, recovery_templates.luau, rest_storage.luau, save_continuation.luau, save_intent.luau, save_notice.luau, save_observation.luau, save_offers.luau, settings.luau, state.luau, state_client.luau |  |
| `Shared/Data/SettingsSpec.luau` | 102 | Shared | Every setting the player can change (ROBLOX-49): its id, words, kind, default and range. One table, no logic: Shared/UI/SettingsModel | Client/SettingsPanel.luau, Client/SpiderClient.client.luau, Shared/UI/SettingsModel.luau | lock.luau, settings.luau |  |
| `Shared/Data/Species.luau` | 592 | Shared | GENERATED by tools/json_to_luau.py from data/species/*.json. Do not edit by hand. | Client/SelfTest.luau, Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Data/Catch.luau, Shared/Life/Growth.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/SaveRest.luau, Shared/Prey/PreyDirector.luau, Shared/Prey/PreyKinds.luau, Shared/Prey/PreyWorld.luau | bodies.luau, checkpoint.luau, compact_layout.luau, continuation_menu.luau, feeding_survival.luau, flies.luau, garden_life.luau, gaze.luau, lock.luau, mating.luau, nature.luau, perception.luau, preserve.luau, prey.luau, rare_sightings.luau, rest_storage.luau, rival.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, sensor.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau, world_client.luau |  |
| `Shared/Data/Surfaces.luau` | 97 | Shared | GENERATED by tools/json_to_luau.py from data/surfaces/*.json. Do not edit by hand. | Client/SpiderClient.client.luau, Shared/Habitat/Scenery.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, gaze.luau, lock.luau, mating.luau, nature.luau, preserve.luau, rare_sightings.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau |  |
| `Shared/Data/Tarantula.luau` | 50 | Shared | The tarantulas' threat display and silk mat (ROBLOX-82): every number the pose needs. The pose is presentation only: it bends and | Shared/Rig/TarantulaPose.luau | look.luau, tarantula.luau |  |
| `Shared/Data/Wasp.luau` | 136 | Shared | The mud dauber wasp's rules: every number of scripts/predator/wasp_director.gd (LIFE round 4, LIFE-14 to LIFE-17), unchanged, in | Shared/Predator/WaspDirector.luau, Shared/UI/Heard.luau, Shared/UI/WaspText.luau | mating.luau, nature.luau, wasp.luau |  |
| `Shared/Data/WaspLook.luau` | 75 | Shared | How the mud dauber wasp looks: numbers and names only; Client/WaspBody builds the parts and poses them each frame. A black-and-yellow | Client/WaspBody.luau | wasp.luau |  |
| `Shared/Data/Wear.luau` | 87 | Shared | What age and use have done to the sill, the glass and the retreat, and the few small things left lying about: numbers and names | Shared/Habitat/Dressing.luau, Shared/Habitat/Patina.luau | world.luau |  |
| `Shared/Habitat/Breakaway.luau` | 71 | Shared | Godot windowsill.gd T09b: the pale east leaf tip falls on a committed jump. | Client/SpiderClient.client.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, world.luau |  |
| `Shared/Habitat/DayLight.luau` | 142 | Shared | The light of the hour on the sill (ROBLOX-24, after Godot's LIFE-06 set_daylight): the life clock's daylight, 0 (night) to 1 | Client/LivingWorld.luau, Client/LookStream.luau, Client/SpiderClient.client.luau | life.luau, world.luau |  |
| `Shared/Habitat/Dressing.luau` | 221 | Shared | Dresses the sill (ROBLOX-74, "more grass and detail"), from Data/Flora, on top of what Plants and Patina already draw: moss on the shaded | Shared/Habitat/Scenery.luau | world.luau |  |
| `Shared/Habitat/Lit.luau` | 125 | Shared | The lighting, sky and screen effects (Data/Graphics): a soft warm sun picked by SunPick so that it shines in through the | Server/Main.server.luau | world.luau |  |
| `Shared/Habitat/Materials.luau` | 32 | Shared | Material names (as Data/Graphics spells them) to Roblox's Enum.Material, so the data stays plain text and a typo is caught by | Client/TrainPass.luau, Shared/Habitat/Scenery.luau, Shared/Habitat/Shapes.luau | preserve.luau, world.luau |  |
| `Shared/Habitat/Patina.luau` | 118 | Shared | Builds what age and use have done to the sill, the glass and the retreat, from Data/Wear: a worn strip along the front lip, grime | Shared/Habitat/Scenery.luau |  | no direct standard import |
| `Shared/Habitat/Plants.luau` | 520 | Shared | Builds the plants of the drawn world from Data/Flora: the Pilea that replaces the leaf and stem pieces of the sill, the trough's | Shared/Habitat/Dressing.luau, Shared/Habitat/Scenery.luau | world.luau |  |
| `Shared/Habitat/Scenery.luau` | 540 | Shared | Builds the drawn world from Data/Graphics: the sill's physical pieces (looks only), and a "Decor" model (a persistent one, ROBLOX-94) with the window  | Client/LookStream.luau, Server/Main.server.luau, Shared/World/WorldBuild.luau | minimal_hud.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, save_notice.luau, selftest_preserve.luau, shadows.luau, world.luau, world_client.luau |  |
| `Shared/Habitat/Shapes.luau` | 145 | Shared | Drawn-only parts for the decor builders (Habitat/Scenery, Plants, Patina) and the fly (Client/FlyBodies): every part is anchored, nothing collides wit | Client/BirdBody.luau, Client/BugBodies.luau, Client/CatBody.luau, Client/CrabBody.luau, Client/FlyBodies.luau, Client/LivingWorld.luau, Client/PondBodies.luau, Client/RareBody.luau, Client/StationMouseBody.luau, Client/WaspBody.luau, Shared/Habitat/Dressing.luau, Shared/Habitat/Patina.luau, Shared/Habitat/Plants.luau, Shared/Habitat/Scenery.luau | world.luau |  |
| `Shared/Habitat/SunPick.luau` | 68 | Shared | Finds a sun that shines in through the window: behind the back wall (-Z), standing between a low and a middling height, | Shared/Habitat/Lit.luau | world.luau |  |
| `Shared/Habitat/TestTarget.luau` | 32 | Shared | Godot test_target.gd: a labelled prop, never prey. Path stepping is independent of rendering. | Client/PerceptionStage.luau | perception_view.luau |  |
| `Shared/Habitat/WindowsillLayout.luau` | 95 | Shared | The windowsill of scripts/habitat/windowsill.gd ("windowsill-v1"), box for box. Coordinates are studs = Godot WU = cm, | Server/RecoveryTemplates.luau, Shared/Habitat/Plants.luau, Shared/Habitat/Scenery.luau, Shared/Habitat/Shapes.luau, Shared/World/Region.luau, Shared/World/WorldMap.luau | checkpoint.luau, client_ant.luau, client_mating.luau, client_rival.luau, client_smoke.luau, continuation_menu.luau, eyes.luau, feeding_survival.luau, gaze.luau, inspect.luau, life.luau, local_rest_client.luau, local_return.luau, lock.luau, mating.luau, nature.luau, notebook.luau, perception_client.luau, preserve.luau, quiet.luau, rival.luau, rivalnav.luau, scenarios.luau, settings.luau, state.luau, state_client.luau, state_offline.luau, title.luau, wasp.luau, world.luau, world_client.luau, worldmap.luau |  |
| `Shared/Learning/FieldNotebook.luau` | 193 | Shared | The naturalist's notebook (LEARN-01), a port of the frozen scripts/learning/field_notebook.gd without the file and the node. | Client/SpiderClient.client.luau | antmimic.luau, notebook.luau, rare_sightings.luau |  |
| `Shared/Learning/NotebookWatch.luau` | 230 | Shared | Watches play for the moments the naturalist's notebook opens pages on: a port of the frozen scripts/learning/notebook_watch.gd. | Client/SpiderClient.client.luau | antmimic.luau, notebook.luau |  |
| `Shared/Life/Ballooning.luau` | 153 | Shared | Ballooning, the lineage moves (ROBLOX-120, docs/PARK_WORLD_DESIGN.md section 5: "the spiderlings balloon. The player chooses one to follow: where it l | Client/SelfTest.luau, Client/SpiderClient.client.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau | checkpoint.luau, preserve.luau, selftest_preserve.luau |  |
| `Shared/Life/Growth.luau` | 117 | Shared | Frozen Godot scripts/life/growth.gd, LIFE-10..12. Durations and scales are game tuning, not measured instars. | Client/MateStage.luau, Client/SpiderClient.client.luau, Shared/Life/LifeLoop.luau, Shared/Life/Mating.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Rig/SpiderRig.luau | gaze.luau, growth.luau, life.luau, mating.luau, minimal_hud.luau, nature.luau, quiet.luau |  |
| `Shared/Life/LifeClock.luau` | 193 | Shared | The life clock: a port of the frozen scripts/life/life_clock.gd (LIFE-04). The windowsill's time of day and the spider's | Client/SpiderClient.client.luau, Client/WorldClient.luau, Shared/Life/LifeLoop.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/UI/ContextPrompts.luau | feeding_survival.luau, life.luau, mating.luau, world_client.luau |  |
| `Shared/Life/LifeLoop.luau` | 304 | Shared | LifeLoop: the rest, sleep and day of the frozen scripts/habitat/habitat_loop.gd (T08, LIFE-04 to LIFE-06), without the | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, continuing.luau, feeding_survival.luau, growth.luau, life.luau, local_rest.luau, mating.luau, nature.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `Shared/Life/LifeSession.luau` | 43 | Shared | LIFE-19..23: player progress lives outside world checkpoints. Session only until server saves are ported. | Client/SpiderClient.client.luau | continuing.luau, growth.luau, nature.luau |  |
| `Shared/Life/Mating.luau` | 336 | Shared | The mating cycle and the new generation (ROBLOX-79). One plain record, life.mating, in LifeLoop's checkpoint graph beside life.mate (the mate's body, | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau | client_mating.luau, mating.luau, nature.luau, selftest_preserve.luau, tarantula.luau |  |
| `Shared/Life/MatingScene.luau` | 162 | Shared | The mating scene (ROBLOX-89): what happens between "the meter is full" and "they part", as a pure plan. About fifteen seconds, in four beats, with a c | Client/SpiderClient.client.luau | client_mating.luau, mating.luau |  |
| `Shared/Life/Nature.luau` | 165 | Shared | Nature's rules (ROBLOX-106, W4 of docs/OPEN_WORLD_DESIGN.md; the design called it "ROBLOX-97", a number never used). Nathan: "Normal mode should feel  | Client/SpiderClient.client.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau | lock.luau, nature.luau, nature_client.luau, preserve.luau |  |
| `Shared/Life/NeedsModel.luau` | 370 | Shared | NeedsModel: a port of the frozen scripts/needs/needs_model.gd (spec 11, 19.3, 21.3 NeedState; LIFE-05). The spider's | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryMealsPrototype.luau, Shared/Prey/Feeding.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, continuing.luau, feeding_survival.luau, growth.luau, life.luau, local_rest.luau, mating.luau, nature.luau, nature_client.luau, rest_storage.luau, rival.luau, state.luau, state_client.luau |  |
| `Shared/Life/Nursery.luau` | 42 | Shared | The nursery rule (ROBLOX-116, docs/PARK_WORLD_DESIGN.md: Nathan's "born on the sill, the sash shut until ready"). In the preserve's first life the ran | Client/HutLife.luau | preserve.luau |  |
| `Shared/Life/RareDirector.luau` | 74 | Shared | Optional life fields are part of the existing checkpoint object graph. | Client/SpiderClient.client.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryLifePrototype.luau | rare_sightings.luau |  |
| `Shared/Life/RareLedger.luau` | 70 | Shared | Player progress, outside rests. High-water marks prevent a rewound rest | Client/SpiderClient.client.luau, Shared/Life/RareDirector.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/SaveProgress.luau | rare_sightings.luau |  |
| `Shared/Life/Water.luau` | 151 | Shared | The water (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "water (drowning)"): the pond's surface is not a place a jumping spider can live on. The sour | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, preserve.luau |  |
| `Shared/Movement/CameraMath.luau` | 292 | Shared | Pure camera and stick math, ported from the frozen Godot reference (c87ce00): | Client/SpiderCamera.luau, Shared/Movement/LineFraming.luau, Shared/Movement/LockOn.luau | lock.luau, run.luau, settings.luau |  |
| `Shared/Movement/FocusState.luau` | 17 | Shared | D-041: toggle is optional, grounded only, and Cancel belongs to other actions first. | Client/SpiderClient.client.luau | perception_view.luau |  |
| `Shared/Movement/InputState.luau` | 87 | Shared | Pure input state: test without Studio. +Y is forward on the control pad; look +X is right, +Y is down | Client/SpiderInput.luau | run.luau |  |
| `Shared/Movement/InspectView.luau` | 147 | Shared | Inspect mode's view, as numbers (ROBLOX-90): an orbit of the spider by yaw, elevation and distance in body-lengths, the auto-orbit when the player is | Client/SpiderCamera.luau, Client/SpiderClient.client.luau | inspect.luau |  |
| `Shared/Movement/JumpInput.luau` | 165 | Shared | Jump input: a port of the frozen Godot scripts/movement/jump_controller.gd (c87ce00, hold mode). Pure: the motor is passed | Client/SpiderClient.client.luau | run.luau, scenarios.luau |  |
| `Shared/Movement/JumpMath.luau` | 152 | Shared | Port of scripts/movement/jump_math.gd (spec 6.3, 27). Pure math, no Instances, so it runs in tests/run.luau too. | Shared/Movement/SpiderMotor.luau | run.luau |  |
| `Shared/Movement/LineFraming.luau` | 95 | Shared | The camera's line framing at a catch: a port of the frozen Godot camera_rig.gd (c87ce00; A-017, chunk 6A, capped in 6B). | Client/SpiderCamera.luau | run.luau |  |
| `Shared/Movement/LockOn.luau` | 182 | Shared | Lock-on and the sidestep (ROBLOX-110). Nathan: "a lock on so you can track prey without the visual cues and the ability to side step". | Client/SpiderCamera.luau, Client/SpiderClient.client.luau | lock.luau |  |
| `Shared/Movement/SilkController.luau` | 334 | Shared | Engine adapter for the frozen safety line. One local-space anchor, at most one bend. | Shared/Movement/SpiderMotor.luau | rare_sightings.luau, scenarios.luau |  |
| `Shared/Movement/SpiderMotor.luau` | 811 | Shared | The spider's body on the windowsill: a kinematic port of the frozen Godot motor's core (scripts/movement/spider_motor.gd, | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Predator/RivalDrive.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, gaze.luau, lock.luau, mating.luau, nature.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau | over800 |
| `Shared/Movement/StickCarry.luau` | 54 | Shared | The carry over an edge: a port of the frozen Godot scripts/movement/player_controller.gd _carry (c87ce00). | Client/SpiderClient.client.luau | run.luau, scenarios.luau |  |
| `Shared/Movement/SupportMath.luau` | 76 | Shared | Port of scripts/movement/support_math.gd (spec 6.1, 6.2). Pure geometry for supported locomotion; unit vectors in world space. | Client/MateStage.luau, Client/SpiderCamera.luau, Client/SpiderClient.client.luau, Shared/Movement/LockOn.luau, Shared/Movement/SpiderMotor.luau, Shared/Predator/RivalDrive.luau | gaze.luau, idle.luau, lock.luau, look.luau, run.luau |  |
| `Shared/Movement/TetherMath.luau` | 62 | Shared | Pure safety-line operations from frozen Godot tether.gd / spider_motor.gd. | Shared/Movement/SilkController.luau | run.luau |  |
| `Shared/Movement/TitleShots.luau` | 166 | Shared | The camera of the first minute (ROBLOX-109), as pure functions of time: the drift the splash (First/SplashScreen) and the title card (Client/TitleCard | Client/TitleCard.luau | preserve.luau, title.luau |  |
| `Shared/Perception/Observation.luau` | 151 | Shared | Observation (spec 21.3): one piece of sensed evidence, as the sensor makes it and the memory keeps it. A port of the frozen | Shared/Movement/LockOn.luau, Shared/Perception/ObservationMemory.luau, Shared/Perception/PerceptionMath.luau, Shared/Perception/SensorCore.luau, Shared/Persistence/Checkpoint.luau | perception.luau, sensor.luau |  |
| `Shared/Perception/ObservationMemory.luau` | 448 | Shared | ObservationMemory (spec 7, 21.3): what the observer remembers of what it sensed. A port of the frozen Godot | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Perception/Sensor.luau, Shared/Perception/SensorCore.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, garden_life.luau, mating.luau, nature.luau, perception.luau, rest_storage.luau, sensor.luau, state.luau, state_client.luau |  |
| `Shared/Perception/PerceptionMath.luau` | 171 | Shared | Pure helpers for the perception layer (spec 7): angles, apparent size, the exposure a classification needs, the evidence's | Shared/Perception/ObservationMemory.luau, Shared/Perception/Sensor.luau, Shared/Perception/SensorCore.luau, Shared/Prey/FlySenses.luau | perception.luau, sensor.luau |  |
| `Shared/Perception/Sensor.luau` | 414 | Shared | Sensor: the world half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00). SensorCore keeps what needs no world (which | Client/SpiderClient.client.luau, Client/SpiderEyes.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, eyes.luau, garden_life.luau, mating.luau, nature.luau, rest_storage.luau, sensor.luau, state.luau, state_client.luau |  |
| `Shared/Perception/SensorCore.luau` | 437 | Shared | SensorCore: the half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00) that needs no world. The sensor turns world | Shared/Perception/Sensor.luau, Shared/Persistence/Checkpoint.luau | perception.luau, sensor.luau |  |
| `Shared/Perception/Signal.luau` | 34 | Shared | A minimal in-process signal, the stand-in for a Godot `signal`: handlers run synchronously, in the order they were connected, when | Shared/Learning/FieldNotebook.luau, Shared/Perception/ObservationMemory.luau, Shared/Perception/SensorCore.luau |  | no direct standard import |
| `Shared/Persistence/Checkpoint.luau` | 642 | Shared | The retreat checkpoint (S01-C; Godot's scripts/persistence/checkpoint.gd, T09; ROBLOX-25). A checkpoint is the whole world | Client/SpiderClient.client.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryTemplates.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryEntryClientPrototype.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/SaveRest.luau | checkpoint.luau, client_smoke.luau, compact_layout.luau, continuation_menu.luau, local_return.luau, mating.luau, nature.luau, recovery_templates.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `Shared/Persistence/CheckpointStore.luau` | 231 | Shared | Where checkpoints live (S02; Godot's scripts/persistence/checkpoint_store.gd; ROBLOX-25), behind a DataStore-shaped | Client/SpiderClient.client.luau | checkpoint.luau, continuation_menu.luau, local_rest.luau, local_rest_client.luau |  |
| `Shared/Persistence/CompactMigration.luau` | 108 | Shared | preserve-2 -> preserve-3: relocate habitats, not spider scale or progress. | Shared/Persistence/Checkpoint.luau |  | no direct standard import |
| `Shared/Persistence/Json.luau` | 148 | Shared | What a Roblox DataStore can hold, checked without the engine (ROBLOX-25), and the canonical text a checksum is taken over | Client/RecoveryGameEntryPrototype.luau, Client/RecoveryOfferValidation.luau, Client/ReplacementClientPrototype.luau, Client/SpiderClient.client.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProfileOwnerPrototype.luau, Server/RecoveryProgressBaselinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRestWriterPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoverySessionRebindPrototype.luau, Server/ReplacementServicePrototype.luau, Shared/Persistence/CheckpointStore.luau, Shared/Persistence/MemoryBackend.luau, Shared/Persistence/RecoveryArchivePrototype.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryEntryClientPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau, Shared/Persistence/RecoverySessionFencePrototype.luau, Shared/Persistence/SaveEnvelope.luau, Shared/Persistence/SaveIntent.luau, Shared/Persistence/SaveObservation.luau, Shared/Persistence/SaveRest.luau, Shared/Persistence/SaveSession.luau | checkpoint.luau, client_mating.luau, compact_layout.luau, continuation_menu.luau, json_encoding.luau, local_rest.luau, local_rest_client.luau, local_return.luau, mating.luau, nature.luau, rare_sightings.luau, recovery_templates.luau, rest_compression.luau, rest_storage.luau, save_continuation.luau, save_observation.luau, save_offers.luau, save_restore.luau, save_work.luau, state.luau, state_client.luau, world_client.luau |  |
| `Shared/Persistence/MemoryBackend.luau` | 101 | Shared | The in-memory store backend (ROBLOX-39): the same interface as the real DataStore backend, with a Roblox DataStore's rules (values |  | state.luau |  |
| `Shared/Persistence/ObjectRecord.luau` | 335 | Shared | ObjectRecord (ROBLOX-25): the state of a few live objects as one plain record that a DataStore could hold, and back. | Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/RecoveryMealsPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau | checkpoint.luau, client_smoke.luau, compact_layout.luau, feeding_survival.luau, mating.luau, rare_sightings.luau, recovery_templates.luau, save_work.luau |  |
| `Shared/Persistence/OrdinaryRequestAdmission.luau` | 210 | Shared | Private ordinary Session request bridge. Only its own admission yield may be | Server/RecoveryAccountLifetimes.luau, Server/ReplacementOwnerPrototype.luau, Shared/Persistence/SaveSession.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryArchivePrototype.luau` | 133 | Shared | Private archive preparation only. Inputs must come from raw server-owned reads, | Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryRestWriterPrototype.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoverySourceCollectorPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryArchiveStorePrototype.luau` | 254 | Shared | Private server-side publication protocol. Every step makes at most one backend | Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryControllerPrototype.luau` | 303 | Shared | Private archive-only controller. The server must call this INSTEAD OF the | Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryPipelinePrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryDestinationPrototype.luau` | 104 | Shared | Private checkpoint assembly. Requires a freshly authored, validated Preserve | Server/RecoveryPacketPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryEntryClientPrototype.luau` | 56 | Shared | Private client entry preparation. Caller pauses simulation until the matching | Client/RecoveryGameEntryPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryLifePrototype.luau` | 121 | Shared | Private life-state projection. Produces data, never a destination world or | Client/RecoveryOfferValidation.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryMealsPrototype.luau` | 124 | Shared | Private portable-meal preparation, after recorded-world inspection. No ecology, | Shared/Persistence/RecoveryLifePrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryOperationAdmission.luau` | 99 | Shared | Private nested-operation bridge. Explicit method bindings preserve raw-write | Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryRestWriterPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Shared/Persistence/OrdinaryRequestAdmission.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/RecoverySourceCollectorPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryProgressPrototype.luau` | 127 | Shared | Private global progress projection. Pure preparation, never a lease grant, | Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoverySessionRebindPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoveryProgressReconcilePrototype.luau` | 48 | Shared | Shared pure three-way global progress reconciliation. No lease/authority or | Server/RecoveryDeparturePrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoverySessionRebindPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoverySessionFencePrototype.luau` | 70 | Shared | Private recovery admission only. Never grants a life credential, writes a key, | Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoverySessionRebindPrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau |  | no direct standard import |
| `Shared/Persistence/RecoverySourceCollectorPrototype.luau` | 187 | Shared | Private server-side raw collection. No original/archive writes, decoding, | Shared/Persistence/RecoveryControllerPrototype.luau |  | no direct standard import |
| `Shared/Persistence/ReplacementProtocolPrototype.luau` | 18 | Shared | Private optional transport capability; ordinary peers keep their protocol. | Client/ReplacementClientPrototype.luau, Server/ReplacementServicePrototype.luau |  | no direct standard import |
| `Shared/Persistence/RequestAdmissionFacade.luau` | 60 | Shared | Private polling facade. Waiting for admission makes no provider request and | Shared/Persistence/RecoveryOperationAdmission.luau |  | no direct standard import |
| `Shared/Persistence/SaveEnvelope.luau` | 153 | Shared | The versioned envelope every stored save travels in (ROBLOX-39), and how it is opened without ever guessing. | Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau, Shared/Persistence/SaveProgress.luau, Shared/Persistence/SaveRest.luau, Shared/Persistence/SaveSession.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `Shared/Persistence/SaveIntent.luau` | 66 | Shared | Transient server decisions. Identity/lease validation and durable retirement | Shared/Persistence/SaveSession.luau | save_intent.luau |  |
| `Shared/Persistence/SaveObservation.luau` | 95 | Shared | Private server observations, independent of write credentials. The caller must | Shared/Persistence/SaveSession.luau | save_observation.luau |  |
| `Shared/Persistence/SaveProgress.luau` | 187 | Shared | The player's progress record (ROBLOX-39): the small precious part of a save, kept apart from the world's rests. | Client/ReplacementClientPrototype.luau, Client/SpiderClient.client.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau, Shared/Persistence/SaveSession.luau | continuation_menu.luau, preserve.luau, rare_sightings.luau, rest_storage.luau, save_notice.luau, settings.luau, state.luau, state_client.luau, title.luau |  |
| `Shared/Persistence/SaveRest.luau` | 123 | Shared | The last rest of a mode, as the server keeps it (ROBLOX-39): a retreat checkpoint (Checkpoint) in an envelope, one per mode. | Client/RecoveryOfferValidation.luau, Client/ReplacementClientPrototype.luau, Client/SpiderClient.client.luau, Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPacketPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProfileOwnerPrototype.luau, Server/RecoveryProgressBaselinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoverySaveLoopPrototype.luau, Server/RecoveryTemplates.luau, Server/ReplacementServicePrototype.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryEntryClientPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoveryProgressReconcilePrototype.luau, Shared/Persistence/SaveSession.luau | checkpoint.luau, continuation_menu.luau, recovery_templates.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `Shared/Persistence/SaveScheduler.luau` | 120 | Shared | When a save is written (ROBLOX-39): only decisions, no store and no clock of its own (the caller passes `now`, in seconds). It keeps, for | Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Shared/Persistence/OrdinaryRequestAdmission.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/SaveSession.luau | state.luau |  |
| `Shared/Persistence/SaveSession.luau` | 1033 | Shared | One player's save session (ROBLOX-39): loads their records through a store backend, keeps their progress and rests in memory, and writes | Server/RecoveryRuntimePrototype.luau, Server/SaveService.luau | rest_storage.luau, state.luau | over800 |
| `Shared/Persistence/SaveStores.luau` | 47 | Shared | Two small pure rules about the stores (ROBLOX-39): which store a build writes to, and what kind of failure a DataStore error is. | Server/Persistence.server.luau, Server/RecoveryAccountLifetimes.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/SaveSession.luau | state.luau |  |
| `Shared/Persistence/SaveWork.luau` | 69 | Shared | Cooperative preparation only. Callers must own/hold stable inputs and gate | Client/RecoveryGameEntryPrototype.luau, Client/SaveRestore.luau, Client/SpiderClient.client.luau, Server/RecoveryCommitControllerPrototype.luau, Server/RecoveryCurrentWriterPrototype.luau, Server/RecoveryDeparturePrototype.luau, Server/RecoveryEntryPrototype.luau, Server/RecoveryIdlePrototype.luau, Server/RecoveryNewLifePolicyPrototype.luau, Server/RecoveryOfferReaderPrototype.luau, Server/RecoveryPipelinePrototype.luau, Server/RecoveryProgressBaselinePrototype.luau, Server/RecoveryProgressWriterPrototype.luau, Server/RecoveryProposalStorePrototype.luau, Server/RecoveryReadLeasePrototype.luau, Server/RecoveryRestFormatPrototype.luau, Server/RecoveryRestWriterPrototype.luau, Server/RecoveryRoutineProgressPrototype.luau, Server/RecoveryRuntimePrototype.luau, Server/RecoverySaveLoopPrototype.luau, Server/RecoverySessionRebindPrototype.luau, Server/RecoveryStartupBudgetPrototype.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/CheckpointStore.luau, Shared/Persistence/Json.luau, Shared/Persistence/ObjectRecord.luau, Shared/Persistence/RecoveryArchivePrototype.luau, Shared/Persistence/RecoveryArchiveStorePrototype.luau, Shared/Persistence/RecoveryControllerPrototype.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Persistence/RecoveryEntryClientPrototype.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/Persistence/RecoveryMealsPrototype.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/RecoverySourceCollectorPrototype.luau, Shared/Persistence/SaveRest.luau | checkpoint.luau, json_encoding.luau, local_rest.luau, recovery_templates.luau, save_offers.luau, save_restore.luau, save_work.luau |  |
| `Shared/Predator/Bird.luau` | 387 | Shared | The robin of the open ground (ROBLOX-120, docs/PARK_WORLD_DESIGN.md sections 4 and 5: the bird is the danger of the hut garden, the meadow and the ope | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/Predator/Cat.luau` | 546 | Shared | The ranger's cat (ROBLOX-118, docs/PARK_WORLD_DESIGN.md section 10: "the cat and the game room live in the hut"): a house cat that lives in the ranger | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, feeding_survival.luau, preserve.luau, station_debug.luau |  |
| `Shared/Predator/CrabSpider.luau` | 154 | Shared | The crab spiders of the meadow's edge (ROBLOX-119, docs/PARK_WORLD_DESIGN.md zone 3; the notebook's page "The crab spider on the flower" says what is  | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/Predator/Frog.luau` | 177 | Shared | The green frog of the pond's edge (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "a frog's tongue"; the notebook's page "The green frog" says what is  | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/Predator/Mate.luau` | 370 | Shared | The mate (ROBLOX-79): a spider of the opposite sex that comes onto the sill when the played spider is full-grown and well fed, is courted by the | Client/SelfTest.luau, Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Life/Mating.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Predator/MateDrive.luau | client_mating.luau, mating.luau, nature.luau, rivalnav.luau |  |
| `Shared/Predator/MateDrive.luau` | 86 | Shared | The mate's legs (ROBLOX-79): the rival's own drive (Predator/RivalDrive: a SpiderMotor over the whole sill, the route graph, the keep-out around the | Client/SpiderClient.client.luau | mating.luau, rivalnav.luau |  |
| `Shared/Predator/RivalDisplay.luau` | 171 | Shared | The male rival's contest display (ROBLOX-127): how a male jumping spider meets another spider, drawn on top of the rival's rules. Pure, Vector3-free a | Client/SpiderClient.client.luau | look.luau, rival.luau |  |
| `Shared/Predator/RivalDrive.luau` | 499 | Shared | The rival spider's legs (ROBLOX-69): its own SpiderMotor, the player's proven surface-walking motor with the same collider, drives it over | Client/SpiderClient.client.luau, Shared/Predator/MateDrive.luau | checkpoint.luau, nature.luau, rivalnav.luau, route_preparation.luau, station_threats.luau, wasp.luau |  |
| `Shared/Predator/RivalGrip.luau` | 77 | Shared | The grip on a caught rival (ROBLOX-77): the same tapping struggle as the fly's (Prey/Feeding's grip math, so the HUD's grip bar and the Grip button | Client/SpiderClient.client.luau | checkpoint.luau, client_rival.luau, rival.luau, rivalnav.luau |  |
| `Shared/Predator/RivalRoute.luau` | 829 | Shared | Where the rival spider can walk, and the ways between (ROBLOX-69). A graph of a region's box faces (the sill's, ROBLOX-94; any region's, ROBLOX-95, be | Shared/Predator/RivalDrive.luau | checkpoint.luau, mating.luau, nature.luau, navigation_startup.luau, preserve.luau, rivalnav.luau, route_preparation.luau, station_threats.luau, wasp.luau, worldmap.luau | over800 |
| `Shared/Predator/RivalSpider.luau` | 281 | Shared | Intraguild predator: the preserve's resident ranger-station patrol, present | Client/SelfTest.luau, Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Predator/RivalGrip.luau | checkpoint.luau, client_rival.luau, growth.luau, mating.luau, nature.luau, rival.luau, rivalnav.luau, station_threats.luau, wasp.luau |  |
| `Shared/Predator/WaspDirector.luau` | 943 | Shared | WaspDirector: the black-and-yellow mud dauber's visits to the sill, without the engine. A port of the frozen | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau | checkpoint.luau, mating.luau, nature.luau, station_threats.luau, wasp.luau | over800 |
| `Shared/Prey/Ant.luau` | 134 | Shared | Ants (ROBLOX-119, the meadow's edge): ambient, not food. Small brown field ants of a hill in the meadow (World/Meadow.HILL, meadow_b4), out on its flo | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | preserve.luau |  |
| `Shared/Prey/Feeding.luau` | 89 | Shared | Frozen feeding_controller.gd: struggle after landing, then conserved nutrition grants. The energy itself belongs to the | Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryMealsPrototype.luau, Shared/Predator/RivalGrip.luau, Shared/Prey/PreyDirector.luau | feeding_survival.luau, preserve.luau, prey.luau, rival.luau |  |
| `Shared/Prey/Fly.luau` | 232 | Shared | Fly's evidence-owned decisions, reactions, flights, glances and surface bursts. | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyDirector.luau | feeding_survival.luau, flies.luau, preserve.luau |  |
| `Shared/Prey/FlyFlight.luau` | 59 | Shared | Frozen FlyFlight: accelerate, sweep every step, brake for landing, reserve the destination. | Shared/Persistence/Checkpoint.luau, Shared/Prey/Fly.luau |  | no direct standard import |
| `Shared/Prey/FlySenses.luau` | 56 | Shared | scripts/prey/fly_senses.gd, A-028. No controls, plans or velocity enter this interface. | Shared/Persistence/Checkpoint.luau, Shared/Prey/Fly.luau | prey.luau |  |
| `Shared/Prey/Harvestman.luau` | 141 | Shared | Harvestmen (ROBLOX-105, W3b part B): ambient, not food, not spiders: a small oval body high on eight very long legs. One walks the bed's soil and litt | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `Shared/Prey/Ladybird.luau` | 195 | Shared | Ladybirds (ROBLOX-105, W3b part B): ambient beetles, not food, that walk the bed's plants among the aphids (World/Garden.plants: one on the dock, one  | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `Shared/Prey/Millipede.luau` | 186 | Shared | Millipedes (ROBLOX-105, W3b part B): ambient, not food. A seeded few in the bed walk the soil slowly round what stands on it, as the woodlice do (Prey | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `Shared/Prey/PerchGraph.luau` | 47 | Shared | Geometry adapter for the frozen PerchGraph. Every planned leg and every flight tick is swept. | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyDirector.luau | preserve.luau |  |
| `Shared/Prey/PlantWalk.luau` | 66 | Shared | A walk along a list of points on surfaces (ROBLOX-105, W3b part B): the aphid's creep from one of its perches to another and the ladybird's rounds ove | Shared/Prey/Ladybird.luau, Shared/Prey/PreyKinds.luau, Shared/Prey/Snail.luau | garden_life.luau |  |
| `Shared/Prey/PreyDirector.luau` | 219 | Shared | Solo client world of perceivable flies. Godot order: sensor, prey, motor, capture/feeding. | Client/SpiderClient.client.luau, Server/RecoveryTemplates.luau, Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, compact_layout.luau, continuation_menu.luau, garden_life.luau, mating.luau, nature.luau, preserve.luau, rest_storage.luau, state.luau, state_client.luau, station_debug.luau, verge_litter.luau |  |
| `Shared/Prey/PreyKinds.luau` | 372 | Shared | The bestiary's prey behaviours (ROBLOX-101, W3b part A), kept out of the frozen fly model: Prey/Fly calls in here only for a profile whose body asks f | Client/SelfTest.luau, Client/SpiderClient.client.luau, Shared/Prey/Fly.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau, preserve.luau |  |
| `Shared/Prey/PreyMath.luau` | 84 | Shared | Frozen scripts/prey/prey_math.gd: explicit evidence, utility and swept-contact math. | Shared/Predator/Mate.luau, Shared/Predator/RivalSpider.luau, Shared/Prey/Fly.luau, Shared/Prey/FlyFlight.luau, Shared/Prey/FlySenses.luau, Shared/Prey/PerchGraph.luau, Shared/Prey/PreyDirector.luau | prey.luau |  |
| `Shared/Prey/PreyPopulation.luau` | 26 | Shared | Frozen prey_population.gd: delayed, twice-unseen vent entries; never teleport a replacement onto a perch. | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyDirector.luau |  | no direct standard import |
| `Shared/Prey/PreyRandom.luau` | 24 | Shared | A repeatable port stream (Park-Miller); Godot's random inputs are exported for parity fixtures. | Client/MateStage.luau, Shared/Life/Mating.luau, Shared/Life/MatingScene.luau, Shared/Life/Nature.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryMealsPrototype.luau, Shared/Predator/Mate.luau, Shared/Predator/RivalDisplay.luau, Shared/Predator/RivalDrive.luau, Shared/Predator/RivalGrip.luau, Shared/Predator/RivalSpider.luau, Shared/Predator/WaspDirector.luau, Shared/Prey/Ant.luau, Shared/Prey/Feeding.luau, Shared/Prey/Fly.luau, Shared/Prey/Harvestman.luau, Shared/Prey/Ladybird.luau, Shared/Prey/Millipede.luau, Shared/Prey/PreyPopulation.luau, Shared/Prey/Skater.luau, Shared/Prey/Snail.luau, Shared/Prey/Woodlouse.luau | feeding_survival.luau, garden_life.luau, nature.luau, preserve.luau, prey.luau, rival.luau |  |
| `Shared/Prey/PreyWorld.luau` | 396 | Shared | The prey of the whole world (ROBLOX-96, W3): one Prey/PreyDirector per region that has prey, run only where the spider is. The sill's director is the  | Client/SpiderClient.client.luau | checkpoint.luau, foundation.luau, garden_life.luau, rest_storage.luau |  |
| `Shared/Prey/Skater.luau` | 123 | Shared | Water striders (ROBLOX-122, the pond's edge): ambient, not the spider's food here. Common water striders (Gerridae) on the open water of the pond's ma | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | preserve.luau |  |
| `Shared/Prey/Snail.luau` | 194 | Shared | The garden snail (ROBLOX-105, W3b part B): ambient, not food, three times the spider's length. It crawls very slowly over the bed's soil and up the fo | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `Shared/Prey/StationMouse.luau` | 47 | Shared | One ambient house mouse: authored floor routes, seeded pauses, no prey or | Client/SpiderClient.client.luau | station_debug.luau |  |
| `Shared/Prey/Woodlouse.luau` | 190 | Shared | Woodlice (ROBLOX-96, W3): the garden's first ambient bugs, a seeded few in the bed that walk slowly about the soil, go under the big stone, the other  | Shared/Persistence/Checkpoint.luau, Shared/Prey/PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `Shared/Rig/Anatomy.luau` | 184 | Shared | Where the parts of the body sit, worked out from the appearance table alone: pure, Vector3 only, so tests/look.luau checks | Shared/Rig/Setae.luau, Shared/Rig/SpiderRig.luau | look.luau |  |
| `Shared/Rig/AntMimicPose.luau` | 114 | Shared | The ant-mimicking spider's antennae and walk as a pose (ROBLOX-64): pure and Vector3-free, display only. SpiderRig reads the pose, turns | Client/SpiderClient.client.luau | antmimic.luau, look.luau |  |
| `Shared/Rig/CatPose.luau` | 343 | Shared | The ranger's cat drawn (ROBLOX-118; its sim is Predator/Cat): a domestic cat at true size, a brown mackerel tabby, posed from what the cat is doing. P | Client/CatBody.luau | preserve.luau, station_debug.luau |  |
| `Shared/Rig/DogGait.luau` | 80 | Shared | Presentation only. Stance paws remain in world space; travel drives the | Client/LivingWorld.luau | dog_gait.luau |  |
| `Shared/Rig/Idle.luau` | 77 | Shared | Idle motion for the drawn spider (display only, never fed back into movement): a slow breathing bob, a small curious head | Shared/Rig/SpiderRig.luau | idle.luau, look.luau |  |
| `Shared/Rig/Living.luau` | 316 | Shared | Living motion for the drawn spider (ROBLOX-87): the small things an animal does when it is not being asked to do anything. Display only, full | Shared/Rig/SpiderRig.luau | idle.luau, look.luau |  |
| `Shared/Rig/PeacockDance.luau` | 166 | Shared | The peacock spider's courtship dance as a pose (ROBLOX-29): pure, Vector3-free, display only. Nothing here moves the body, the | Client/SpiderClient.client.luau | growth.luau, look.luau, peacock.luau |  |
| `Shared/Rig/Setae.luau` | 420 | Shared | Where the spider's hairs (setae) go: pure layout from the appearance table, Vector3 only, so tests/run.luau and | Shared/Rig/SpiderRig.luau | look.luau, run.luau |  |
| `Shared/Rig/SpiderChoice.luau` | 109 | Shared | Which spider the player is (ROBLOX-31, ROBLOX-64, ROBLOX-81): the first spider, the peacock spider, the ant-mimicking spider or one of the two | Client/SpiderClient.client.luau, Shared/UI/PeacockText.luau, Shared/UI/SettingsModel.luau | antmimic.luau, inspect.luau, look.luau, peacock.luau, settings.luau, state.luau, tarantula.luau |  |
| `Shared/Rig/SpiderRig.luau` | 1647 | Shared | The drawn spider for Roblox: a port of scripts/presentation/spider_body.gd and surface_legs.gd (VISUAL-01 look), made cuter in | Client/MateStage.luau, Client/SpiderClient.client.luau | feeding_survival.luau, growth.luau, idle.luau, inspect.luau, look.luau | over800 |
| `Shared/Rig/TarantulaPose.luau` | 168 | Shared | The tarantulas' threat display and silk mat as a pose (ROBLOX-82): pure and Vector3-free, display only. Nothing here moves the body, the | Client/SpiderClient.client.luau | look.luau, tarantula.luau |  |
| `Shared/UI/AntMimicText.luau` | 35 | Shared | The words of the ant-mimicking spider's display key for the screen (ROBLOX-64): the prompt, the status line, the touch button and the | Client/SpiderClient.client.luau, Shared/UI/PeacockText.luau | antmimic.luau |  |
| `Shared/UI/BirdText.luau` | 23 | Shared | The robin in words (ROBLOX-120; the robin is Predator/Bird): its death card, the notice when its bill misses (the gentle rules), and the captions of w | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/UI/CatText.luau` | 24 | Shared | The ranger's cat in words (ROBLOX-118; the cat is Predator/Cat): its death card, the notice when its pat only knocks the spider aside (the gentle rule | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/UI/ContextPrompts.luau` | 34 | Shared | Only the player-requested meal and dusk prompts enter the minimal play HUD. | Client/SpiderClient.client.luau | feeding_survival.luau |  |
| `Shared/UI/ControlText.luau` | 268 | Shared | Words on the screen, written for the device the player is using now: keyboard and mouse, a controller, or touch. | Client/NotebookPanel.luau, Client/SettingsPanel.luau, Client/SpiderClient.client.luau, Client/SpiderEyes.luau, Shared/UI/AntMimicText.luau, Shared/UI/ContextPrompts.luau, Shared/UI/InspectText.luau, Shared/UI/LifeText.luau, Shared/UI/MateText.luau, Shared/UI/NotebookText.luau, Shared/UI/PeacockText.luau, Shared/UI/SettingsText.luau, Shared/UI/TarantulaText.luau, Shared/UI/TitleText.luau, Shared/UI/WaspText.luau | antmimic.luau, client_mating.luau, eyes.luau, feeding_survival.luau, growth.luau, inspect.luau, lock.luau, notebook.luau, peacock.luau, run.luau, settings.luau, tarantula.luau, title.luau |  |
| `Shared/UI/CrabText.luau` | 11 | Shared | The crab spider in words (ROBLOX-119; the crab spider is Predator/CrabSpider): its death card and the notice when its lunge only knocks the spider off | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/UI/EyeOptics.luau` | 328 | Shared | EyeOptics: the pure half of the spider-eye picture (ROBLOX-20). From k (how much the principal eyes are in use, 0 to 1) and the | Client/SpiderEyes.luau | eyes.luau |  |
| `Shared/UI/FrogText.luau` | 11 | Shared | The green frog in words (ROBLOX-122; the frog is Predator/Frog): its death card and the notice when its tongue misses (the gentle rules). Pure: tests/ | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/UI/Heard.luau` | 19 | Shared | What the player can hear or see of something that is not at the spider (ROBLOX-92): a creature on the sill is told of (a notice, a caption, a status l | Client/SpiderClient.client.luau, Shared/UI/WaspText.luau | client_mating.luau |  |
| `Shared/UI/HudLayout.luau` | 154 | Shared | Where the on-screen controls and the prompt panel go, in the safe area (ScreenInsets.CoreUISafeInsets: clear of notches, | Client/SpiderClient.client.luau, Client/SpiderHud.luau, Client/SpiderInput.luau | lock.luau, notebook.luau, peacock.luau, run.luau, settings.luau |  |
| `Shared/UI/InspectText.luau` | 47 | Shared | The words of Inspect mode (ROBLOX-90): the Settings row's button (its label and note are in Data/SettingsSpec), the refusal, the name line on entering | Client/SpiderClient.client.luau, Shared/UI/SettingsModel.luau | inspect.luau, settings.luau |  |
| `Shared/UI/LifeText.luau` | 277 | Shared | The words of the life clock and the retreat for the screen (ROBLOX-24), from Godot's habitat_loop.gd caption(): the day and | Client/SpiderClient.client.luau, Client/SpiderHud.luau | checkpoint.luau, client_mating.luau, garden_life.luau, growth.luau, life.luau, minimal_hud.luau, nature.luau, nature_client.luau, peacock.luau, preserve.luau, quiet.luau |  |
| `Shared/UI/MateText.luau` | 186 | Shared | The words of the mating cycle for the screen (ROBLOX-80): the notices for each beat Life/Mating reports, the status line while courting and while | Client/SpiderClient.client.luau, Shared/UI/LifeText.luau | client_mating.luau, mating.luau, nature.luau, preserve.luau, quiet.luau |  |
| `Shared/UI/NotebookText.luau` | 145 | Shared | The notebook's words and its layout rules for the screen (ROBLOX-37), from Godot's notebook_panel.gd: the heading, the empty | Client/NotebookPanel.luau, Client/SpiderClient.client.luau, Shared/UI/SettingsText.luau | antmimic.luau, notebook.luau |  |
| `Shared/UI/PeacockText.luau` | 97 | Shared | The words of the peacock spider for the screen (ROBLOX-31): choosing the spider in the crack, the dance's prompts and status | Client/SpiderClient.client.luau, Shared/UI/InspectText.luau, Shared/UI/SettingsModel.luau | antmimic.luau, client_mating.luau, inspect.luau, lock.luau, peacock.luau, settings.luau, tarantula.luau |  |
| `Shared/UI/PerceptionShapes.luau` | 101 | Shared | PerceptionShapes: the geometry the perception HUD draws with (ROBLOX-20, the drawer's polish), pure. A last-seen ring is 12 short | Client/PerceptionHud.luau | hud.luau, lock.luau |  |
| `Shared/UI/PerceptionText.luau` | 10 | Shared | Frozen perception_text.gd: words belong to presentation, never the sensor. | Client/PerceptionHud.luau, Shared/UI/PerceptionView.luau | perception_view.luau |  |
| `Shared/UI/PerceptionView.luau` | 43 | Shared | Pure build_view from perception_hud.gd. Only memory and a camera adapter enter; never world actors. | Client/PerceptionHud.luau | hud.luau |  |
| `Shared/UI/PreyText.luau` | 41 | Shared | What the screen says when a prey gets out of the jaws by its own trick (ROBLOX-101, Prey/PreyKinds.grip, kept by Prey/PreyWorld as `event`): a moth wh | Client/SpiderClient.client.luau | garden_life.luau, preserve.luau |  |
| `Shared/UI/QuietHud.luau` | 190 | Shared | The quiet HUD (ROBLOX-113, W5 of docs/OPEN_WORLD_DESIGN.md): what the screen may say in Normal. Nathan: "minimal HUD", "no hand holding", "Normal mode | Client/PerceptionHud.luau, Client/SpiderClient.client.luau | quiet.luau |  |
| `Shared/UI/RivalText.luau` | 45 | Shared | The words of the brown rival's contest for the screen (ROBLOX-73): what the spider's strike did to a rival that had seen it coming. The | Client/SpiderClient.client.luau | client_rival.luau, growth.luau, quiet.luau, rival.luau |  |
| `Shared/UI/SaveText.luau` | 99 | Shared | The words about saving (ROBLOX-39): what the menu and a short toast say. Plain and honest: saved, saving, or off for this visit and why. | Client/SpiderClient.client.luau | save_notice.luau, state_client.luau, state_offline.luau |  |
| `Shared/UI/SettingsModel.luau` | 270 | Shared | The settings as logic (ROBLOX-49): looking one up, cleaning a value, stepping it, saying it in words, putting everything back to the | Client/SettingsPanel.luau, Client/SpiderClient.client.luau, Client/SpiderEyes.luau, Shared/Persistence/RecoveryProgressPrototype.luau, Shared/Persistence/SaveProgress.luau, Shared/UI/SettingsNav.luau | minimal_hud.luau, settings.luau, state.luau |  |
| `Shared/UI/SettingsNav.luau` | 105 | Shared | Moving about the settings panel without a mouse (ROBLOX-49): the rows in order (a header per section, the settings, then Reset and Back) | Client/SettingsPanel.luau | settings.luau |  |
| `Shared/UI/SettingsText.luau` | 119 | Shared | The settings panel's words for the device in use, and its layout rules for the screen (ROBLOX-49): sizes by kind, how a row is laid out | Client/SettingsPanel.luau | settings.luau |  |
| `Shared/UI/TarantulaText.luau` | 36 | Shared | The words of the tarantulas' display key for the screen (ROBLOX-82): the prompt, the status line, the touch button and the controls card's | Client/SpiderClient.client.luau, Shared/UI/NotebookText.luau, Shared/UI/PeacockText.luau | notebook.luau, tarantula.luau |  |
| `Shared/UI/TitleText.luau` | 72 | Shared | The words and the typeface of the first minute (ROBLOX-109): the splash while the world streams in (First/SplashScreen), the title card the start | Client/CaughtPanel.luau, Client/SpiderClient.client.luau, Client/TitleCard.luau | title.luau |  |
| `Shared/UI/WaspText.luau` | 128 | Shared | The words of the wasp's visit for the screen (ROBLOX-26): the sound captions, the status line while it visits and the plain screen | Client/CaughtPanel.luau, Client/SpiderClient.client.luau | quiet.luau, wasp.luau |  |
| `Shared/UI/WaterText.luau` | 13 | Shared | The water in words (ROBLOX-122; the water is Life/Water): the caption while the spider struggles at the surface, its death card, and the notices when  | Client/SpiderClient.client.luau | preserve.luau |  |
| `Shared/World/AntForage.luau` | 35 | Shared | Clock-derived ambient workers. The carried fragments are presentation, not | Client/LivingWorld.luau, Shared/World/LivedInSites.luau | living_world.luau |  |
| `Shared/World/DogGround.luau` | 42 | Shared | Cosmetic dog's ground LOD: an index of the same authored physical boxes the | Client/LivingWorld.luau | living_world.luau |  |
| `Shared/World/Environment.luau` | 144 | Shared | Habitat weather is reconstructed from the saved life clock, not rerolled on load. | Client/LivingWorld.luau, Shared/Life/RareDirector.luau, Shared/World/AntForage.luau, Shared/World/DogGround.luau, Shared/World/Verge.luau | dog_gait.luau, living_world.luau, rare_sightings.luau |  |
| `Shared/World/Garden.luau` | 2720 | Shared | The world outside the glass (ROBLOX-95, docs/OPEN_WORLD_DESIGN.md W2): the generators of the three regions under the window, as pure data. Region asks | Client/SelfTest.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Prey/Ladybird.luau, Shared/Prey/PreyKinds.luau, Shared/Prey/PreyWorld.luau, Shared/World/LookPlan.luau, Shared/World/Region.luau | checkpoint.luau, foundation.luau, garden_life.luau, living_world.luau, preserve.luau, verge_litter.luau, world.luau, worldmap.luau | over800 |
| `Shared/World/GardenPocket.luau` | 95 | Shared | A one-metre habitat directly below the window. Juvenile plants retain adult | Shared/World/Garden.luau, Shared/World/LivedInSites.luau | living_world.luau |  |
| `Shared/World/Hut.luau` | 2848 | Shared | The ranger hut and its garden, walkable (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B round 1): the preserve's first home ranges at full spider detai | Client/HutLife.luau, Client/LivingWorld.luau, Shared/Predator/Mate.luau, Shared/World/Garden.luau, Shared/World/GardenPocket.luau, Shared/World/Meadow.luau, Shared/World/Pond.luau, Shared/World/Region.luau, Shared/World/StationAir.luau, Shared/World/WorldMap.luau | compact_layout.luau, living_world.luau, preserve.luau, rivalnav.luau, station_debug.luau | over800 |
| `Shared/World/LivedInSites.luau` | 117 | Shared | Additive, stable landmarks. Existing pieces/retreats never move. One stud is one centimetre. | Client/LivingWorld.luau, Shared/World/Region.luau | living_world.luau |  |
| `Shared/World/LookPlan.luau` | 280 | Shared | Which regions' drawn looks a client holds, and at what detail, from where the spider is (ROBLOX-108). Pure: a plan is a function of the place, the tie | Client/LookStream.luau, Client/SelfTest.luau | preserve.luau, rest_storage.luau, world_client.luau, worldmap.luau |  |
| `Shared/World/Meadow.luau` | 1271 | Shared | The meadow's edge and the bench, bin and lamppost, walkable (ROBLOX-119, docs/PARK_WORLD_DESIGN.md Phase C round 1): home ranges 3 and 8 at full spide | Client/HutLife.luau, Client/SelfTest.luau, Shared/Predator/CrabSpider.luau, Shared/World/Garden.luau, Shared/World/PreserveLook.luau, Shared/World/Region.luau, Shared/World/WorldMap.luau | compact_layout.luau, preserve.luau, rivalnav.luau, shadows.luau | over800 |
| `Shared/World/NavigationPreparation.luau` | 59 | Shared | Owns bounded loading work, before the first simulation tick. Surface and air | Client/SpiderClient.client.luau | navigation_startup.luau |  |
| `Shared/World/Pond.luau` | 1305 | Shared | The pond's edge and the boardwalk, walkable (ROBLOX-122, docs/PARK_WORLD_DESIGN.md Phase D round 1): home range 4 at full spider detail where the boar | Client/SelfTest.luau, Client/SpiderClient.client.luau, Shared/Predator/Frog.luau, Shared/World/Garden.luau, Shared/World/PreserveLook.luau, Shared/World/Region.luau, Shared/World/WorldMap.luau | compact_layout.luau, preserve.luau | over800 |
| `Shared/World/Preserve.luau` | 150 | Shared | The preserve's map (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4 and 10): a nature preserve of 100 by 60 m in an American city, held between a rai | Client/SelfTest.luau, Shared/Life/Ballooning.luau, Shared/World/Hut.luau, Shared/World/Pond.luau, Shared/World/PreserveLook.luau, Shared/World/PreserveTrain.luau, Shared/World/WorldMap.luau | preserve.luau |  |
| `Shared/World/PreserveLook.luau` | 1003 | Shared | The preserve's backdrop (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4, 7 and 10): every zone of World/Preserve drawn, and nothing of it walkable.  | Shared/World/Region.luau | living_world.luau, preserve.luau | over800 |
| `Shared/World/PreserveTrain.luau` | 98 | Shared | The trains on the railway beyond the preserve's north fence (ROBLOX-115, docs/PARK_WORLD_DESIGN.md: "the railway's vibration", "trains every few minut | Client/TrainPass.luau | preserve.luau |  |
| `Shared/World/Region.luau` | 165 | Shared | What a region is made of (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): the generators. Each is pure and deterministic from the region (its kind and its | Client/LookStream.luau, Client/SelfTest.luau, Client/SpiderClient.client.luau, Client/WorldClient.luau, Client/WorldShadows.luau, Server/Main.server.luau, Server/RecoveryTemplates.luau, Shared/Predator/RivalRoute.luau, Shared/Prey/PreyWorld.luau, Shared/World/DogGround.luau, Shared/World/LookPlan.luau, Shared/World/StationAir.luau, Shared/World/WorldBuild.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, living_world.luau, preserve.luau, recovery_templates.luau, rest_storage.luau, rivalnav.luau, shadows.luau, station_debug.luau, station_threats.luau, title.luau, verge_litter.luau, world.luau, world_client.luau, worldmap.luau |  |
| `Shared/World/StationAir.luau` | 194 | Shared | Bounded air navigation over the station's actual collision boxes. Grid edges | Client/SpiderClient.client.luau, Shared/Predator/WaspDirector.luau | navigation_startup.luau, station_threats.luau |  |
| `Shared/World/StationTerritory.luau` | 29 | Shared | The inhabited ranger station, excluding its garden and exterior wall/eaves. | Client/SelfTest.luau, Client/WorldClient.luau, Shared/Predator/RivalDrive.luau, Shared/Predator/RivalSpider.luau, Shared/World/StationAir.luau, Shared/World/WorldBuild.luau | navigation_startup.luau, route_preparation.luau, station_debug.luau, station_threats.luau |  |
| `Shared/World/Verge.luau` | 232 | Shared | Walkable infill around the developed garden and its paths. Existing landmarks win | Shared/World/Garden.luau, Shared/World/Region.luau, Shared/World/WorldMap.luau | compact_layout.luau, living_world.luau, verge_litter.luau |  |
| `Shared/World/WorldBuild.luau` | 86 | Shared | Builds the physical world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): every region of the map, each as a folder of anchored boxes, all under one `World` f | Server/Main.server.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, living_world.luau, minimal_hud.luau, nature_client.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, rare_sightings.luau, recovery_templates.luau, rest_storage.luau, route_preparation.luau, save_notice.luau, scenarios.luau, selftest.luau, selftest_preserve.luau, shadows.luau, spawn_clearance.luau, station_debug.luau, station_threats.luau, verge_litter.luau, world.luau, world_client.luau |  |
| `Shared/World/WorldMap.luau` | 576 | Shared | The map of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): what regions there are, where each one is, where a life begins in it, where | Client/LookStream.luau, Client/MateStage.luau, Client/SelfTest.luau, Client/SpiderClient.client.luau, Client/WorldClient.luau, Server/Main.server.luau, Server/Persistence.server.luau, Server/RecoveryStartup.luau, Server/RecoveryTemplates.luau, Server/WorldFocus.luau, Shared/Life/Water.luau, Shared/Persistence/Checkpoint.luau, Shared/Persistence/CompactMigration.luau, Shared/Persistence/RecoveryDestinationPrototype.luau, Shared/Predator/CrabSpider.luau, Shared/Predator/Frog.luau, Shared/Predator/Mate.luau, Shared/Predator/RivalDrive.luau, Shared/Predator/RivalRoute.luau, Shared/Predator/RivalSpider.luau, Shared/World/Garden.luau, Shared/World/LookPlan.luau, Shared/World/Region.luau, Shared/World/StationAir.luau, Shared/World/StationTerritory.luau, Shared/World/WorldBuild.luau | checkpoint.luau, compact_layout.luau, foundation.luau, garden_life.luau, living_world.luau, minimal_hud.luau, nature.luau, nature_client.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, rare_sightings.luau, recovery_templates.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, save_notice.luau, scenarios.luau, selftest.luau, selftest_preserve.luau, shadows.luau, spawn_clearance.luau, station_debug.luau, station_threats.luau, title.luau, verge_litter.luau, world.luau, world_client.luau, worldmap.luau |  |
| `Shared/World/Worlds.luau` | 51 | Shared | The worlds the engine can run (ROBLOX-115, docs/PARK_WORLD_DESIGN.md). One engine, two worlds: | Client/WorldClient.luau, Server/Main.server.luau, Server/Persistence.server.luau, Shared/Persistence/RecoveryLifePrototype.luau, Shared/World/WorldMap.luau | preserve.luau |  |

## Runtime call sites

A match is a call site, not proof of execution frequency or ownership cleanup. Inspect its enclosing function before changing cadence or allocation.

| Source | Line | Site |
|---|---:|---|
| `Client/BirdBody.luau` | 104 | `local folder = Instance.new("Folder")` |
| `Client/BirdBody.luau` | 118 | `local s = Instance.new("Sound")` |
| `Client/BirdBody.luau` | 132 | `local model = Instance.new("Folder")` |
| `Client/BugBodies.luau` | 367 | `local folder = Instance.new("Folder")` |
| `Client/BugBodies.luau` | 387 | `local folder = Instance.new("Folder")` |
| `Client/BugBodies.luau` | 516 | `while s < target do` |
| `Client/CatBody.luau` | 22 | `local folder = Instance.new("Folder")` |
| `Client/CatBody.luau` | 52 | `local s = Instance.new("Sound")` |
| `Client/CaughtPanel.luau` | 29 | `local l=Instance.new("TextLabel")` |
| `Client/CaughtPanel.luau` | 37 | `local gui=Instance.new("ScreenGui")` |
| `Client/CaughtPanel.luau` | 40 | `local dim=Instance.new("Frame")` |
| `Client/CaughtPanel.luau` | 44 | `local shade=Instance.new("UIGradient")` |
| `Client/CaughtPanel.luau` | 48 | `local box=Instance.new("ScrollingFrame")` |
| `Client/CaughtPanel.luau` | 52 | `local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(880,10000);constraint.Parent=box` |
| `Client/CaughtPanel.luau` | 53 | `local list=Instance.new("UIListLayout");list.HorizontalAlignment=Enum.HorizontalAlignment.Center` |
| `Client/CaughtPanel.luau` | 63 | `list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:_align() end)` |
| `Client/CaughtPanel.luau` | 64 | `box:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:_align() end)` |
| `Client/CaughtPanel.luau` | 112 | `local b=Instance.new("TextButton");b.Name=c.id;b.Text=c.text` |
| `Client/CaughtPanel.luau` | 119 | `local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,if titleLook then 6 else 4);round.Parent=b` |
| `Client/CaughtPanel.luau` | 120 | `b.Activated:Connect(function() self:choose(c.id) end)` |
| `Client/CrabBody.luau` | 65 | `local folder = Instance.new("Folder")` |
| `Client/CrabBody.luau` | 72 | `local model = Instance.new("Folder")` |
| `Client/FlyBodies.luau` | 346 | `local folder = Instance.new("Folder")` |
| `Client/FlyBodies.luau` | 370 | `local folder = Instance.new("Folder")` |
| `Client/HutLife.luau` | 40 | `local p = Instance.new("Part")` |
| `Client/HutLife.luau` | 63 | `local folder = Instance.new("Folder")` |
| `Client/HutLife.luau` | 69 | `moment = nil :: number?, -- when the ranger's moment began (the clock's), while it runs` |
| `Client/HutLife.luau` | 74 | `local holder = Instance.new("Part")` |
| `Client/HutLife.luau` | 83 | `local light = Instance.new("PointLight")` |
| `Client/HutLife.luau` | 94 | `local street = Instance.new("Part")` |
| `Client/HutLife.luau` | 103 | `local sl = Instance.new("PointLight")` |
| `Client/LivingWorld.luau` | 32 | `local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh` |
| `Client/LookStream.luau` | 44 | `local folder = Instance.new("Folder")` |
| `Client/LookStream.luau` | 170 | `local f = Instance.new("Folder")` |
| `Client/LookStream.luau` | 187 | `while i <= #self.jobs do` |
| `Client/LookStream.luau` | 209 | `local model = Instance.new("Model")` |
| `Client/MateStage.luau` | 30 | `MateStage.LIFT_HEIGHT = 2.4 -- how far a spiderling rises while it is seen` |
| `Client/MateStage.luau` | 67 | `wx = (g:next() - 0.5) * 0.9, wz = (g:next() - 0.5) * 0.9, -- the drift of the air while it rises` |
| `Client/MateStage.luau` | 133 | `local p = Instance.new("Part")` |
| `Client/MateStage.luau` | 144 | `local p = Instance.new("Part")` |
| `Client/MateStage.luau` | 158 | `local folder = Instance.new("Folder")` |
| `Client/MealPresentation.luau` | 6 | `local folder=Instance.new("Folder");folder.Name="MealRemains";folder.Parent=parent` |
| `Client/MealPresentation.luau` | 22 | `local model=Instance.new("Model");model.Name="EmptyHusk";model.Parent=self.folder` |
| `Client/MealPresentation.luau` | 23 | `local p=Instance.new("Part");p.Name="DryBody";p.Shape=Enum.PartType.Ball` |
| `Client/MealPresentation.luau` | 28 | `local w=Instance.new("Part");w.Anchored=true;w.CanCollide=false;w.CanQuery=false;w.CanTouch=false;w.CastShadow=false;w.Color=p.Color;w.Material=p.Material;w.Name="EmptyWing";w.Size=Vector3.new(.1,.01,.17);w.Transparency=.65;w.Parent=model` |
| `Client/NotebookArt.luau` | 6 | `local p=Instance.new("Frame");p.Name="Ink";p.BorderSizePixel=0;p.BackgroundColor3=colour` |
| `Client/NotebookArt.luau` | 8 | `if round then local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=p end` |
| `Client/NotebookArt.luau` | 12 | `local centre=Instance.new("Frame");centre.Name="Sketch";centre.BackgroundTransparency=1` |
| `Client/NotebookPanel.luau` | 45 | `local l = Instance.new("TextLabel")` |
| `Client/NotebookPanel.luau` | 61 | `local f = Instance.new("ScrollingFrame")` |
| `Client/NotebookPanel.luau` | 70 | `local list = Instance.new("UIListLayout")` |
| `Client/NotebookPanel.luau` | 79 | `local b = Instance.new("TextButton")` |
| `Client/NotebookPanel.luau` | 88 | `local corner = Instance.new("UICorner")` |
| `Client/NotebookPanel.luau` | 96 | `local gui = Instance.new("ScreenGui")` |
| `Client/NotebookPanel.luau` | 103 | `local dim = Instance.new("Frame")` |
| `Client/NotebookPanel.luau` | 111 | `local paper = Instance.new("Frame")` |
| `Client/NotebookPanel.luau` | 119 | `local corner = Instance.new("UICorner")` |
| `Client/NotebookPanel.luau` | 122 | `local stroke = Instance.new("UIStroke")` |
| `Client/NotebookPanel.luau` | 126 | `local limit = Instance.new("UISizeConstraint")` |
| `Client/NotebookPanel.luau` | 129 | `local inner = Instance.new("Frame")` |
| `Client/NotebookPanel.luau` | 135 | `local heading = Instance.new("TextLabel")` |
| `Client/NotebookPanel.luau` | 143 | `local body = Instance.new("Frame")` |
| `Client/NotebookPanel.luau` | 161 | `local footer = Instance.new("Frame")` |
| `Client/NotebookPanel.luau` | 166 | `local controls = Instance.new("TextLabel")` |
| `Client/NotebookPanel.luau` | 188 | `tries.Activated:Connect(function() self:showChecklist() end)` |
| `Client/NotebookPanel.luau` | 189 | `close.Activated:Connect(function() self:close() end)` |
| `Client/NotebookPanel.luau` | 190 | `back.Activated:Connect(function() self:back() end)` |
| `Client/NotebookPanel.luau` | 191 | `gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)` |
| `Client/NotebookPanel.luau` | 192 | `page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:fitText() end)` |
| `Client/NotebookPanel.luau` | 276 | `local pad = Instance.new("UIPadding")` |
| `Client/NotebookPanel.luau` | 281 | `b.Activated:Connect(function() self:choose(id) end)` |
| `Client/OldSkins.luau` | 6 | `local folder=Instance.new("Folder");folder.Name="OldSkins";folder.Parent=parent` |
| `Client/OldSkins.luau` | 22 | `local part=Instance.new("Part");part.Name=name;part.Size=size;part.CFrame=cf` |
| `Client/OldSkins.luau` | 29 | `local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=shell` |
| `Client/PerceptionHud.luau` | 24 | `local c = Instance.new("UICorner")` |
| `Client/PerceptionHud.luau` | 30 | `local s = Instance.new("UIStroke")` |
| `Client/PerceptionHud.luau` | 38 | `local f = Instance.new("Frame")` |
| `Client/PerceptionHud.luau` | 72 | `local l = Instance.new("TextLabel")` |
| `Client/PerceptionHud.luau` | 87 | `local pad = Instance.new("UIPadding")` |
| `Client/PerceptionHud.luau` | 97 | `local gui = Instance.new("ScreenGui")` |
| `Client/PerceptionStage.luau` | 7 | `local folder = Instance.new("Folder")` |
| `Client/PerceptionStage.luau` | 11 | `local p = Instance.new("Part")` |
| `Client/PerceptionStage.luau` | 24 | `local sign = Instance.new("BillboardGui")` |
| `Client/PerceptionStage.luau` | 28 | `local label = Instance.new("TextLabel")` |
| `Client/PondBodies.luau` | 103 | `local folder = Instance.new("Folder")` |
| `Client/PondBodies.luau` | 110 | `local model = Instance.new("Folder")` |
| `Client/RareBody.luau` | 22 | `local model=Instance.new("Folder");model.Name="RareLuna";model.Parent=Workspace;self.model=model` |
| `Client/RareBody.luau` | 23 | `local supports=Instance.new("Folder");supports.Name="RareLunaSupport";supports.Parent=self.root;self.supports=supports` |
| `Client/RareBody.luau` | 38 | `local p=Instance.new("Part");p.Name="LunaWing"..sign;p.Anchored=true` |
| `Client/ReplacementClientPrototype.luau` | 21 | `self.rawRemotes.server:FireServer(message)` |
| `Client/ReplacementClientPrototype.luau` | 49 | `return raw.client.OnClientEvent:Connect(function(message: any)` |
| `Client/ReplacementClientPrototype.luau` | 54 | `return {server={FireServer=function(_remote: any, message: any) send(self, message) end},client={OnClientEvent=event}}` |
| `Client/SaveClient.luau` | 85 | `self.remotes.server:FireServer({kind="recovery_applied",v=self.cfg.rules.RECOVERY_PROTOCOL,id=o.id,epoch=o.epoch,mode=o.mode,serial=o.serial,revision=o.revision,` |
| `Client/SaveClient.luau` | 154 | `local ev = remotes.client.OnClientEvent` |
| `Client/SaveClient.luau` | 155 | `ev:Connect(function(msg: any)` |
| `Client/SaveClient.luau` | 299 | `self.remotes.server:FireServer({ kind = "hello", v = if self.bound then rules.OFFER_PROTOCOL else rules.PROTOCOL,` |
| `Client/SaveClient.luau` | 308 | `self.remotes.server:FireServer({ kind = "progress", progress = payload })` |
| `Client/SaveClient.luau` | 312 | `if not self.legacyTemporary then self.bound:update(t,function(msg:any) self.remotes.server:FireServer(msg) end) end` |
| `Client/SaveClient.luau` | 319 | `self.remotes.server:FireServer({kind="begin_life",mode=mode,serial=request.serial})` |
| `Client/SaveClient.luau` | 330 | `self.remotes.server:FireServer({ kind = "rest", mode = mode, record = record, life = self.lifeTokens[mode] })` |
| `Client/SelfTest.luau` | 146 | `while not cond() do` |
| `Client/SelfTest.luau` | 206 | `while #out > 5 do table.remove(out) end` |
| `Client/SelfTest.luau` | 228 | `local conn = RunService.RenderStepped:Connect(function(dt: number) table.insert(dts, dt) end)` |
| `Client/SelfTest.luau` | 443 | `while r.host.clock() < deadline do` |
| `Client/SelfTest.luau` | 473 | `if prof ~= nil then prof.start() end -- (and the frame by part while it lets down: the looks are planned again as it goes down)` |
| `Client/SelfTest.luau` | 476 | `while r.host.clock() < deadline do` |
| `Client/SelfTest.luau` | 600 | `while r.host.clock() < (r.bedAt :: number) + 2.0 do` |
| `Client/SelfTest.luau` | 659 | `say(r, string.format("INFO looks while settled: %d plans and %d parts made in the sample", looks.plans - plans0, looks.made - made0))` |
| `Client/SelfTest.luau` | 776 | `while train.schedule.pass(k).finish < now and k < 50 do k += 1 end` |
| `Client/SelfTest.luau` | 1355 | `need(not life.lifeOver, "the robin took the spider while it was held off")` |
| `Client/SelfTest.luau` | 1693 | `local probe=Instance.new("Part");probe.Anchored=true;probe.CanCollide=false;probe.CanQuery=false;probe.CanTouch=false` |
| `Client/SettingsPanel.luau` | 59 | `local c = Instance.new("UICorner")` |
| `Client/SettingsPanel.luau` | 65 | `local l: any = Instance.new(class)` |
| `Client/SettingsPanel.luau` | 79 | `local b = Instance.new("TextButton")` |
| `Client/SettingsPanel.luau` | 101 | `local gui = Instance.new("ScreenGui")` |
| `Client/SettingsPanel.luau` | 108 | `local dim = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 116 | `local paper = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 125 | `local limit = Instance.new("UISizeConstraint")` |
| `Client/SettingsPanel.luau` | 128 | `local inner = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 136 | `local list = Instance.new("ScrollingFrame")` |
| `Client/SettingsPanel.luau` | 145 | `local layout = Instance.new("UIListLayout")` |
| `Client/SettingsPanel.luau` | 153 | `local footer = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 169 | `resetButton.Activated:Connect(function() self.nav:select(#self.nav.rows - 1); self:_activate() end)` |
| `Client/SettingsPanel.luau` | 170 | `backButton.Activated:Connect(function() self.nav:select(#self.nav.rows); self:_activate() end)` |
| `Client/SettingsPanel.luau` | 171 | `gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)` |
| `Client/SettingsPanel.luau` | 172 | `UIS.InputChanged:Connect(function(input: InputObject)` |
| `Client/SettingsPanel.luau` | 178 | `UIS.InputEnded:Connect(function(input: InputObject)` |
| `Client/SettingsPanel.luau` | 209 | `local frame = Instance.new("TextButton")` |
| `Client/SettingsPanel.luau` | 219 | `local stroke = Instance.new("UIStroke")` |
| `Client/SettingsPanel.luau` | 234 | `w.value.Activated:Connect(function() pick(); self:_change(id, 1) end)` |
| `Client/SettingsPanel.luau` | 239 | `w.prev.Activated:Connect(function() pick(); self:_change(id, -1) end)` |
| `Client/SettingsPanel.luau` | 240 | `w.next.Activated:Connect(function() pick(); self:_change(id, 1) end)` |
| `Client/SettingsPanel.luau` | 241 | `w.value.Activated:Connect(function() pick(); self:_change(id, 1) end)` |
| `Client/SettingsPanel.luau` | 247 | `local bar = Instance.new("Frame") -- the hit area: as tall as a button, so a finger finds it` |
| `Client/SettingsPanel.luau` | 252 | `local track = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 260 | `local fill = Instance.new("Frame")` |
| `Client/SettingsPanel.luau` | 268 | `w.minus.Activated:Connect(function() pick(); self:_change(id, -1) end)` |
| `Client/SettingsPanel.luau` | 269 | `w.plus.Activated:Connect(function() pick(); self:_change(id, 1) end)` |
| `Client/SettingsPanel.luau` | 270 | `bar.InputBegan:Connect(function(input: InputObject)` |
| `Client/SettingsPanel.luau` | 279 | `frame.Activated:Connect(function()` |
| `Client/SettingsPanel.luau` | 687 | `while self.repeatT >= SettingsText.REPEAT_RATE do` |
| `Client/Soundscape.luau` | 36 | `local s = Instance.new("Sound")` |
| `Client/Soundscape.luau` | 52 | `task.spawn(function()` |
| `Client/Soundscape.luau` | 64 | `local root = Instance.new("Folder")` |
| `Client/Soundscape.luau` | 67 | `local emitter = Instance.new("Part")` |
| `Client/Soundscape.luau` | 145 | `local p = Instance.new("Part")` |
| `Client/SpiderCamera.luau` | 123 | `UIS.TouchPinch:Connect(function(_touches: any, scale: number, _velocity: number, state: Enum.UserInputState, processed: boolean)` |
| `Client/SpiderCamera.luau` | 130 | `UIS.InputChanged:Connect(function(input, processed)` |
| `Client/SpiderCamera.luau` | 243 | `while lengths[#lengths] < comfort and offset < roomDown - 1e-6 do` |
| `Client/SpiderCamera.luau` | 249 | `while lengths[#lengths] < comfort and offset < roomUp - 1e-6 do` |
| `Client/SpiderClient.client.luau` | 192 | `local arc = Instance.new("Folder")` |
| `Client/SpiderClient.client.luau` | 242 | `task.spawn(function()` |
| `Client/SpiderClient.client.luau` | 411 | `local lines = Instance.new("Folder")` |
| `Client/SpiderClient.client.luau` | 424 | `local p = Instance.new("Part")` |
| `Client/SpiderClient.client.luau` | 468 | `local d = Instance.new("Part")` |
| `Client/SpiderClient.client.luau` | 475 | `local patch = Instance.new("Part")` |
| `Client/SpiderClient.client.luau` | 479 | `local ring = Instance.new("Part")` |
| `Client/SpiderClient.client.luau` | 483 | `local cross = Instance.new("Part")` |
| `Client/SpiderClient.client.luau` | 922 | `local lastEnd: any=nil -- the summary of the life that just ended, while its end screen is up` |
| `Client/SpiderClient.client.luau` | 1220 | `menu:showChoices("Begin a new life?",if saveClient.newLifeEnabled and info and info.protected then "Your previous saved spider will be kept. The world stays paused while the new life is prepared." elseif saveState.application and saveState.application:choosing` |
| `Client/SpiderClient.client.luau` | 1288 | `local menuButton=Instance.new("TextButton")` |
| `Client/SpiderClient.client.luau` | 1291 | `menuButton.Parent=hud.safe;menuButton.Activated:Connect(function() openMenu() end)` |
| `Client/SpiderClient.client.luau` | 1323 | `local notebookButton=Instance.new("TextButton")` |
| `Client/SpiderClient.client.luau` | 1326 | `notebookButton.Parent=hud.safe;notebookButton.Activated:Connect(function() openNotebook("game") end)` |
| `Client/SpiderClient.client.luau` | 1340 | `hud.safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTopButtons)` |
| `Client/SpiderClient.client.luau` | 1638 | `if phase=="failed" then "This spider stays paused." elseif phase=="new" then "The world waits while your previous spider is kept safely." else "The world waits while the saved spider is checked.",` |
| `Client/SpiderClient.client.luau` | 1680 | `player:GetAttributeChangedSignal(key):Connect(function()` |
| `Client/SpiderClient.client.luau` | 1744 | `saveState.restoreError="That local rest changed while it was being prepared. Your current spider is kept; choose again."` |
| `Client/SpiderClient.client.luau` | 2055 | `restPrompt={title="Moulting in the silk-lined crack",hint="The spider pulls free of its old skin. Wait here while the hours pass."}` |
| `Client/SpiderClient.client.luau` | 2105 | `do -- the Lock button (ROBLOX-110): only while something can be locked, or a lock holds` |
| `Client/SpiderClient.client.luau` | 2138 | `RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)` |
| `Client/SpiderClient.client.luau` | 2177 | `while accumulator >= DT do` |
| `Client/SpiderClient.client.luau` | 2777 | `task.spawn(function()` |
| `Client/SpiderEyes.luau` | 52 | `local f = Instance.new("Frame")` |
| `Client/SpiderEyes.luau` | 64 | `local c = Instance.new("UICorner")` |
| `Client/SpiderEyes.luau` | 70 | `local s = Instance.new("UIStroke")` |
| `Client/SpiderEyes.luau` | 80 | `local g = Instance.new("UIGradient")` |
| `Client/SpiderEyes.luau` | 100 | `local gui = Instance.new("ScreenGui")` |
| `Client/SpiderEyes.luau` | 131 | `local grade = Instance.new("ColorCorrectionEffect")` |
| `Client/SpiderEyes.luau` | 135 | `local blur = Instance.new("BlurEffect")` |
| `Client/SpiderHud.luau` | 31 | `local c = Instance.new("UICorner")` |
| `Client/SpiderHud.luau` | 37 | `local p = Instance.new("UIPadding")` |
| `Client/SpiderHud.luau` | 45 | `local l = Instance.new("TextLabel")` |
| `Client/SpiderHud.luau` | 68 | `local l = Instance.new("TextLabel")` |
| `Client/SpiderHud.luau` | 89 | `local f = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 96 | `local list = Instance.new("UIListLayout")` |
| `Client/SpiderHud.luau` | 103 | `local limit = Instance.new("UISizeConstraint")` |
| `Client/SpiderHud.luau` | 112 | `local centre = Instance.new("ScreenGui")` |
| `Client/SpiderHud.luau` | 118 | `local reticle = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 126 | `local stroke = Instance.new("UIStroke")` |
| `Client/SpiderHud.luau` | 133 | `local t = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 143 | `local aimBox = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 150 | `local aimList = Instance.new("UIListLayout")` |
| `Client/SpiderHud.luau` | 161 | `local safe = Instance.new("ScreenGui")` |
| `Client/SpiderHud.luau` | 170 | `local food = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 179 | `local foodText = Instance.new("TextLabel")` |
| `Client/SpiderHud.luau` | 190 | `local track = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 200 | `local foodFill = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 207 | `local grip = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 209 | `local gripFill=Instance.new("Frame");gripFill.Name="Grip";gripFill.Size=UDim2.fromScale(.4,1);gripFill.BackgroundColor3=Color3.fromRGB(245,35,38);gripFill.BorderSizePixel=0;gripFill.Parent=grip` |
| `Client/SpiderHud.luau` | 211 | `local court = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 213 | `local courtFill=Instance.new("Frame");courtFill.Name="Courtship";courtFill.Size=UDim2.fromScale(0,1);courtFill.BackgroundColor3=Color3.fromRGB(226,128,164);courtFill.BorderSizePixel=0;courtFill.Parent=court` |
| `Client/SpiderHud.luau` | 226 | `local dayBox = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 232 | `local dayList = Instance.new("UIListLayout")` |
| `Client/SpiderHud.luau` | 246 | `local panel = Instance.new("Frame")` |
| `Client/SpiderHud.luau` | 251 | `local plist = Instance.new("UIListLayout")` |
| `Client/SpiderInput.luau` | 144 | `local gui = Instance.new("ScreenGui")` |
| `Client/SpiderInput.luau` | 163 | `local b = Instance.new("TextButton")` |
| `Client/SpiderInput.luau` | 176 | `local corner = Instance.new("UICorner")` |
| `Client/SpiderInput.luau` | 179 | `b.InputBegan:Connect(function(input)` |
| `Client/SpiderInput.luau` | 202 | `gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTouch)` |
| `Client/SpiderInput.luau` | 204 | `UIS.InputEnded:Connect(function(input)` |
| `Client/SpiderInput.luau` | 213 | `UIS.TouchStarted:Connect(function(input, processed)` |
| `Client/SpiderInput.luau` | 216 | `UIS.TouchEnded:Connect(function(input)` |
| `Client/SpiderInput.luau` | 220 | `UIS.TouchPinch:Connect(function(_touches: any, _scale: number, _velocity: number, state2: Enum.UserInputState)` |
| `Client/SpiderInput.luau` | 223 | `UIS.TouchMoved:Connect(function(input, processed)` |
| `Client/SpiderInput.luau` | 226 | `UIS.WindowFocusReleased:Connect(clear)` |
| `Client/SpiderInput.luau` | 227 | `UIS.TextBoxFocused:Connect(clear)` |
| `Client/SpiderInput.luau` | 228 | `UIS.GamepadDisconnected:Connect(clear)` |
| `Client/SpiderInput.luau` | 229 | `GuiService.MenuOpened:Connect(clear)` |
| `Client/SpiderInput.luau` | 230 | `UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(function() gui.Enabled = UIS.TouchEnabled end)` |
| `Client/SpiderInput.luau` | 233 | `UIS.LastInputTypeChanged:Connect(function(t: Enum.UserInputType) deviceHandler(t.Name) end)` |
| `Client/StationMouseBody.luau` | 8 | `local folder=Instance.new("Folder");folder.Name="StationMouse";folder.Parent=parent` |
| `Client/TitleCard.luau` | 47 | `local gui = Instance.new("ScreenGui")` |
| `Client/TitleCard.luau` | 54 | `local veil = Instance.new("Frame")` |
| `Client/TitleCard.luau` | 61 | `local caption = Instance.new("TextLabel")` |
| `Client/TitleCard.luau` | 75 | `local limit = Instance.new("UISizeConstraint")` |
| `Client/TitleCard.luau` | 78 | `local skip = Instance.new("TextLabel")` |
| `Client/TitleCard.luau` | 91 | `local tap = Instance.new("TextButton")` |
| `Client/TitleCard.luau` | 107 | `tap.Activated:Connect(function() self:skip() end)` |
| `Client/TrainPass.luau` | 28 | `local p = Instance.new("Part")` |
| `Client/TrainPass.luau` | 45 | `local folder = Instance.new("Folder")` |
| `Client/TrainPass.luau` | 51 | `local f = Instance.new("Folder")` |
| `Client/TrainPass.luau` | 60 | `local s = Instance.new("Sound")` |
| `Client/WaspBody.luau` | 83 | `local folder = Instance.new("Folder")` |
| `Client/WorldClient.luau` | 84 | `while not Worlds.known(named) and os.clock() < deadline and t ~= nil do` |
| `Client/WorldClient.luau` | 218 | `if remote == nil or not remote:IsA("RemoteEvent") then return false end` |
| `Client/WorldClient.luau` | 219 | `(remote :: RemoteEvent):FireServer(pos)` |
| `Client/WorldShadows.luau` | 137 | `while i <= #entries do` |
| `First/SplashScreen.luau` | 84 | `frame = function(): number return (game:GetService("RunService") :: any).RenderStepped:Wait() end,` |
| `First/SplashScreen.luau` | 101 | `local l = Instance.new("TextLabel")` |
| `First/SplashScreen.luau` | 114 | `local gui = Instance.new("ScreenGui")` |
| `First/SplashScreen.luau` | 120 | `local veil = Instance.new("Frame")` |
| `First/SplashScreen.luau` | 133 | `local dot = Instance.new("Frame")` |
| `First/SplashScreen.luau` | 142 | `local round = Instance.new("UICorner")` |
| `First/SplashScreen.luau` | 182 | `destroyConnection=ui.gui.Destroying:Connect(disconnect)` |
| `First/SplashScreen.luau` | 183 | `readyConnection=player:GetAttributeChangedSignal(SplashScreen.READY_ATTRIBUTE):Connect(ready)` |
| `First/SplashScreen.luau` | 203 | `while s.phase ~= "done" do` |
| `Server/DataStoreBackend.luau` | 16 | `local ok, value = pcall(function(): any return self.ds:GetAsync(key) end)` |
| `Server/DataStoreBackend.luau` | 31 | `local result = self.ds:UpdateAsync(key, function(stored: any): any` |
| `Server/DataStoreBackend.luau` | 58 | `local request=Instance.new("DataStoreGetOptions")` |
| `Server/DataStoreBackend.luau` | 60 | `return self.ds:GetAsync(key,request)` |
| `Server/Main.server.luau` | 67 | `local foci = Instance.new("Folder")` |
| `Server/Persistence.server.luau` | 24 | `local okay,value=pcall(function():any return DataStores:GetDataStore(storeName) end)` |
| `Server/Persistence.server.luau` | 27 | `read=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),` |
| `Server/Persistence.server.luau` | 28 | `write=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)} end` |
| `Server/Persistence.server.luau` | 32 | `function unavailable:GetAsync(...:any):any error("403: DataStore service unavailable") end` |
| `Server/Persistence.server.luau` | 33 | `function unavailable:UpdateAsync(...:any):any error("403: DataStore service unavailable") end` |
| `Server/Persistence.server.luau` | 41 | `local function sleep(seconds:number) task.wait(seconds) end` |
| `Server/Persistence.server.luau` | 42 | `local function spawn(fn:any,...:any) task.spawn(fn,...) end` |
| `Server/Persistence.server.luau` | 57 | `local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME` |
| `Server/Persistence.server.luau` | 58 | `local toServer=Instance.new("RemoteEvent");toServer.Name="ToServer";toServer.Parent=folder` |
| `Server/Persistence.server.luau` | 59 | `local toClient=Instance.new("RemoteEvent");toClient.Name="ToClient";toClient.Parent=folder` |
| `Server/Persistence.server.luau` | 62 | `send=function(player:any,message:any) toClient:FireClient(player,message) end}` |
| `Server/Persistence.server.luau` | 66 | `toServer.OnServerEvent:Connect(function(player:Player,message:any) service:onMessage(player,message) end)` |
| `Server/Persistence.server.luau` | 71 | `Players.PlayerAdded:Connect(function(player:Player) if not closing then service:addPlayer(player) end end)` |
| `Server/Persistence.server.luau` | 72 | `Players.PlayerRemoving:Connect(function(player:Player) service:removePlayer(player) end)` |
| `Server/Persistence.server.luau` | 75 | `local connection=Run.Heartbeat:Connect(function()` |
| `Server/RecoveryAccountLifetimes.luau` | 36 | `while true do` |
| `Server/RecoveryAccountLifetimes.luau` | 95 | `while s.busy or v.backend.activeUpdates>0 or s._ordinaryContext and s._ordinaryContext.phase~="done" do` |
| `Server/RecoveryAccountLifetimes.luau` | 107 | `while cleanable(self,v) and j.requests<6 do` |
| `Server/RecoveryDeparturePrototype.luau` | 138 | `if not live(self,j) then finish(self,j,"refused","departure changed while writing");return true end` |
| `Server/RecoveryDeparturePrototype.luau` | 151 | `if not live(self,j) then finish(self,j,"refused","departure changed while reading");return true end` |
| `Server/RecoveryRuntimePrototype.luau` | 377 | `while self.saveLoop:hasWork() and self.phase=="recovered" and self.session.now()<drainUntil do` |
| `Server/RecoveryRuntimePrototype.luau` | 388 | `while self.busy and self.session.now()<self.flushDeadline do self.config.sleep(math.min(.25,math.max(0,self.flushDeadline-self.session.now()))) end` |
| `Server/RecoveryRuntimePrototype.luau` | 396 | `while j.state=="pending" do` |
| `Server/RecoveryStartupBudgetPrototype.luau` | 28 | `query=function() return service:GetRequestBudgetForRequestType(readType),service:GetRequestBudgetForRequestType(writeType) end` |
| `Server/RecoveryStartupBudgetPrototype.luau` | 97 | `self.read-=1;self.write-=1 -- conservative worst case: UpdateAsync uses both` |
| `Server/ReplacementOwnerPrototype.luau` | 57 | `while self.busy or rt.busy or s.busy or rt.pipeline.busy or (s.backend.activeUpdates or 0)>0` |
| `Server/SaveService.luau` | 305 | `while (pending > 0 or self.departing > 0) and self.cfg.now() < deadline do` |
| `Server/WorldFocus.luau` | 31 | `local part = Instance.new("Part")` |
| `Server/WorldFocus.luau` | 87 | `function WorldFocus.listen(storage: Instance, parent: Instance): RemoteEvent` |
| `Server/WorldFocus.luau` | 89 | `if remote == nil or not remote:IsA("RemoteEvent") then` |
| `Server/WorldFocus.luau` | 90 | `local made = Instance.new("RemoteEvent")` |
| `Server/WorldFocus.luau` | 95 | `local event = remote :: RemoteEvent` |
| `Server/WorldFocus.luau` | 96 | `event.OnServerEvent:Connect(function(player: Player, at: any)` |
| `Server/WorldFocus.luau` | 107 | `players.PlayerAdded:Connect(function(player: Player)` |
| `Server/WorldFocus.luau` | 110 | `players.PlayerRemoving:Connect(function(player: Player)` |
| `Shared/Data/NotebookPages.luau` | 287 | `game = "Your spider is pale and its jumps shorter while its skin hardens. The ten game-hour timing is a design choice. The empty skin stays in the crack.",` |
| `Shared/Data/NotebookPages.luau` | 288 | `godotGame = "Your spider is paler and its jumps shorter while the new skin hardens. How long that takes for a jumping spider has not been measured; the game's timing is a guess. Look for the old skin in the crack.",` |
| `Shared/Data/NotebookPages.luau` | 433 | `text = "Leafhoppers (Cicadellidae) are small wedge-shaped bugs, a few millimetres long and often green, with the wings held like a tent over the back. They suck sap from leaves. Young and adults walk with a sideways sidestep; disturbed, the young often walk ro` |
| `Shared/Data/NotebookPages.luau` | 503 | `text = "Harvestmen, or daddy longlegs, are not spiders but opilionids. The body is one simple oval, head and abdomen fused, with only two eyes and no silk or venom glands. Disturbed, they give off a foul odour. A leg falls off easily and goes on twitching, whi` |
| `Shared/Data/NotebookPages.luau` | 525 | `text = "A house cat stands 23 to 25 cm at the shoulder and weighs 4 to 5 kg. It hunts small mammals and birds first, and invertebrates last. Free-ranging cats kill an estimated 1.3 to 4.0 billion birds and 6.3 to 22.3 billion mammals a year in the United State` |
| `Shared/Data/SettingsSpec.luau` | 56 | `note = "The view may turn to show the line while the spider hangs on it." },` |
| `Shared/Data/SettingsSpec.luau` | 80 | `note = "Change it anywhere you stand safely. Not while jumping, on silk, moulting or holding prey." },` |
| `Shared/Data/SettingsSpec.luau` | 83 | `note = "A slow, close look from every side. Only while you stand safely. Cancel leaves." },` |
| `Shared/Data/Wasp.luau` | 73 | `Wasp.scanDegS = 70.0 -- how fast it turns while it hovers` |
| `Shared/Habitat/Lit.luau` | 28 | `local made = Instance.new(className)` |
| `Shared/Habitat/Patina.luau` | 22 | `while x < L.x1 do` |
| `Shared/Habitat/Scenery.luau` | 31 | `local f = Instance.new("Folder")` |
| `Shared/Habitat/Scenery.luau` | 39 | `local p = Instance.new("Part")` |
| `Shared/Habitat/Scenery.luau` | 88 | `local p = Instance.new("Part")` |
| `Shared/Habitat/Scenery.luau` | 115 | `local sill = Instance.new("Folder")` |
| `Shared/Habitat/Scenery.luau` | 164 | `local mesh = Instance.new("SpecialMesh")` |
| `Shared/Habitat/Scenery.luau` | 168 | `local mesh = Instance.new("SpecialMesh")` |
| `Shared/Habitat/Scenery.luau` | 263 | `local motes = Instance.new("ParticleEmitter")` |
| `Shared/Habitat/Scenery.luau` | 340 | `local mesh = Instance.new("SpecialMesh")` |
| `Shared/Habitat/Scenery.luau` | 450 | `local a0 = Instance.new("Attachment")` |
| `Shared/Habitat/Scenery.luau` | 453 | `local a1 = Instance.new("Attachment")` |
| `Shared/Habitat/Scenery.luau` | 458 | `local beam = Instance.new("Beam")` |
| `Shared/Habitat/Scenery.luau` | 503 | `local decor = Instance.new("Model")` |
| `Shared/Habitat/Shapes.luau` | 26 | `local p = Instance.new("Part")` |
| `Shared/Habitat/Shapes.luau` | 46 | `local mesh = Instance.new("SpecialMesh")` |
| `Shared/Habitat/Shapes.luau` | 130 | `local f = Instance.new("Folder")` |
| `Shared/Learning/FieldNotebook.luau` | 97 | `while #list > FieldNotebook.MAX_ENTRIES do table.remove(list, 1) end` |
| `Shared/Life/LifeClock.luau` | 77 | `while self.hour >= 24.0 do` |
| `Shared/Life/LifeSession.luau` | 31 | `while #self.lives > 30 do table.remove(self.lives,1) end` |
| `Shared/Life/Mating.luau` | 47 | `guard_day = 0, -- 1 or 2 while the sac is guarded` |
| `Shared/Life/Nature.luau` | 29 | `coldSpeed = 0.6, -- the walk's speed while it lasts` |
| `Shared/Life/NeedsModel.luau` | 172 | `while total >= NeedsModel.UPDATE_PERIOD_S - 1e-9 do` |
| `Shared/Movement/InspectView.luau` | 11 | `InspectView.HOLD_SECONDS = 0.6 -- holding the choose key or button this long (while resting awake in the crack) starts the view` |
| `Shared/Movement/LineFraming.luau` | 44 | `while k * step <= maxTurn + 1e-6 do` |
| `Shared/Movement/LockOn.luau` | 37 | `holdGain = 2.0, -- the pull back to the kept distance while circling, per WU of error (clamped to a full step)` |
| `Shared/Movement/SpiderMotor.luau` | 49 | `local FREE_UP_RATE = math.rad(240) -- the drawn up turns to world up while falling or on the line (Godot VISUAL_TURN)` |
| `Shared/Movement/SpiderMotor.luau` | 89 | `local probe = Instance.new("Part")` |
| `Shared/Movement/SpiderMotor.luau` | 141 | `transitionSerial = 0, -- counts sharp support turns while walking (concave and convex edges)` |
| `Shared/Persistence/CheckpointStore.luau` | 35 | `function MemoryDataStore.GetAsync(self: any, key: string): any` |
| `Shared/Persistence/CheckpointStore.luau` | 57 | `function MemoryDataStore.SetAsync(self: any, key: string, value: any)` |
| `Shared/Persistence/CheckpointStore.luau` | 156 | `local ok, existing = try(function() return self.store:GetAsync(k) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 158 | `local wrote = try(function() self.store:SetAsync(k, entry) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 172 | `local wrote, err = try(function() self.store:SetAsync(tmp, entry) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 174 | `local readOk, back = try(function() return self.store:GetAsync(tmp) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 184 | `local curOk, current = try(function() return self.store:GetAsync(main) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 197 | `local moved, merr = try(function() self.store:SetAsync(bak, current) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 203 | `local put, perr = try(function() self.store:SetAsync(main, entry) end)` |
| `Shared/Persistence/CheckpointStore.luau` | 214 | `local ok, entry = try(function() return self.store:GetAsync(which[1]) end)` |
| `Shared/Persistence/Json.luau` | 133 | `while i0 <= n do` |
| `Shared/Persistence/ObjectRecord.luau` | 114 | `while q <= #queue and not problem do if pulse then pulse() end;` |
| `Shared/Persistence/OrdinaryRequestAdmission.luau` | 98 | `while true do` |
| `Shared/Persistence/OrdinaryRequestAdmission.luau` | 138 | `while c.phase~="done" do` |
| `Shared/Persistence/OrdinaryRequestAdmission.luau` | 185 | `while prior.phase~="done" and s.now()<limit do s.cfg.sleep(math.min(.025,math.max(0,limit-s.now()))) end` |
| `Shared/Persistence/SaveEnvelope.luau` | 84 | `while from < spec.current do` |
| `Shared/Persistence/SaveScheduler.luau` | 83 | `else -- changed while it was being written: still dirty, due once the interval has passed` |
| `Shared/Persistence/SaveSession.luau` | 259 | `if self.closed then return end -- departure can reach its deadline while a read yields` |
| `Shared/Persistence/SaveSession.luau` | 329 | `self:demote("other_session",false) -- another life won while ownership was unavailable; never relabel our queued world` |
| `Shared/Persistence/SaveSession.luau` | 357 | `self.restLoaded = {} -- read again: another session may have written a rest while this one could not` |
| `Shared/Persistence/SaveSession.luau` | 793 | `released = false -- UpdateAsync may invoke this callback more than once` |
| `Shared/Persistence/SaveSession.luau` | 977 | `while self.busy and self.now() < limit and sleep do sleep(0.25) end` |
| `Shared/Persistence/SaveSession.luau` | 985 | `while attempt < SaveRules.FLUSH_ATTEMPTS and self.state == "active" and self.now() < limit do` |
| `Shared/Persistence/SaveSession.luau` | 1017 | `while attempt < SaveRules.FLUSH_ATTEMPTS and self.now() < limit do` |
| `Shared/Predator/Bird.luau` | 141 | `while t < forage do` |
| `Shared/Predator/Cat.luau` | 110 | `while true do` |
| `Shared/Predator/Cat.luau` | 125 | `while n ~= nil do` |
| `Shared/Predator/Cat.luau` | 187 | `while t < 22.5 do` |
| `Shared/Predator/Cat.luau` | 279 | `look = nil :: Vector3?, -- the point its head follows, while it watches something` |
| `Shared/Predator/Cat.luau` | 360 | `while h < 0 do h += 24; dd -= 1 end` |
| `Shared/Predator/Cat.luau` | 361 | `while h >= 24 do h -= 24; dd += 1 end` |
| `Shared/Predator/RivalDrive.luau` | 28 | `while b ~= 0 do a, b = b, a % b end` |
| `Shared/Predator/RivalDrive.luau` | 58 | `while gcd(stride, math.max(#waypoints, 1)) ~= 1 do stride += 1 end` |
| `Shared/Predator/RivalDrive.luau` | 80 | `while gcd(stride, math.max(#self.waypoints, 1)) ~= 1 do stride += 1 end` |
| `Shared/Predator/RivalDrive.luau` | 231 | `while self.hop <= #route do` |
| `Shared/Predator/RivalRoute.luau` | 357 | `while i > 1 do` |
| `Shared/Predator/RivalRoute.luau` | 370 | `while true do` |
| `Shared/Predator/RivalRoute.luau` | 417 | `while #heap > 0 do` |
| `Shared/Predator/RivalRoute.luau` | 470 | `while stPrev[at] ~= 0 do` |
| `Shared/Predator/RivalRoute.luau` | 541 | `while #picked < math.min(k, #pool) do` |
| `Shared/Predator/RivalRoute.luau` | 759 | `while budget.left > 0 and os.clock() < budget.deadline do` |
| `Shared/Predator/WaspDirector.luau` | 470 | `while #self.recent > 3 do table.remove(self.recent, 1) end` |
| `Shared/Predator/WaspDirector.luau` | 806 | `while self.pathI <= #path and left > 0.0 do` |
| `Shared/Prey/Millipede.luau` | 70 | `while #m.trail > Millipedes.RINGS + 1 do table.remove(m.trail) end` |
| `Shared/Prey/PreyDirector.luau` | 206 | `local probe=Instance.new('Part');probe.Name='FlyClearanceProbe';probe.Shape=Enum.PartType.Ball;probe.Anchored=true;probe.CanCollide=false;probe.CanQuery=false;probe.CanTouch=false;probe.Transparency=1;probe.Parent=workspace` |
| `Shared/Prey/PreyPopulation.luau` | 10 | `while #self.owed>missing do table.remove(self.owed) end` |
| `Shared/Prey/PreyPopulation.luau` | 11 | `while #self.owed<missing do table.insert(self.owed,now+self.rng:draw(self.p.replenish_delay_s)) end` |
| `Shared/Prey/PreyWorld.luau` | 55 | `clock = 0, -- a running clock for the drawing (the directors' own stop while they wait)` |
| `Shared/Prey/Snail.luau` | 118 | `while #s.trail > 0 and now - s.trail[#s.trail].t > Snails.FADE_S do table.remove(s.trail) end` |
| `Shared/Prey/Snail.luau` | 142 | `while #s.trail > Snails.TRAIL do table.remove(s.trail) end` |
| `Shared/Rig/SpiderRig.luau` | 166 | `_lineDir: Vector3, -- the last direction up the line (it stays while the pose blends out)` |
| `Shared/Rig/SpiderRig.luau` | 191 | `local p = Instance.new("Part")` |
| `Shared/Rig/SpiderRig.luau` | 210 | `local mesh = Instance.new("SpecialMesh")` |
| `Shared/Rig/SpiderRig.luau` | 354 | `local model = Instance.new("Model")` |
| `Shared/Rig/SpiderRig.luau` | 824 | `local hl = Instance.new("Highlight")` |
| `Shared/UI/ControlText.luau` | 227 | `return `You can now run. Hold {ControlText.name(device, "run")} while moving.`` |
| `Shared/UI/EyeOptics.luau` | 259 | `while #list > maxCount do` |
| `Shared/UI/LifeText.luau` | 220 | `["the rival in the jaws is still struggling"] = "Not while a fight is on",` |
| `Shared/UI/LifeText.luau` | 221 | `["the spider is eating its rival"] = "Not while you are feeding",` |
| `Shared/UI/LifeText.luau` | 224 | `["the spider is feeding"] = "Not while you are feeding",` |
| `Shared/UI/LifeText.luau` | 225 | `["the prey in the jaws is still struggling"] = "Not while a fight is on",` |
| `Shared/UI/MateText.luau` | 46 | `MateText.REST_HATCHING = "Not while the brood is hatching"` |
| `Shared/UI/MateText.luau` | 80 | `if reason == "rest" then return "The visitor wandered off while you rested." end` |
| `Shared/UI/NotebookText.luau` | 132 | `{id="peacock_dance",text="Change to the peacock (in Settings, or while resting), then dance outside."},` |
| `Shared/UI/NotebookText.luau` | 133 | `{id="walking_like_an_ant",text="Change to the ant mimic (in Settings, or while resting), then stand still."},` |
| `Shared/UI/NotebookText.luau` | 135 | `{id="tarantula_cousins",text="Change to a tarantula (in Settings, or while resting), then rear up outside."},` |
| `Shared/UI/PeacockText.luau` | 19 | `PeacockText.NOT_RESTING = "You can change spider while resting in the silk-lined crack"` |
| `Shared/UI/SettingsModel.luau` | 163 | `while v < to do` |
| `Shared/UI/SettingsModel.luau` | 178 | `while digits < 6 and math.abs(step * 10 ^ digits - math.floor(step * 10 ^ digits + 0.5)) > 1e-9 do digits += 1 end` |
| `Shared/UI/SettingsText.luau` | 111 | `while size > 10 do` |
| `Shared/World/Environment.luau` | 111 | `while cycle>durations[leg] and leg<#route do cycle-=durations[leg];leg+=1 end` |
| `Shared/World/Garden.luau` | 879 | `while x < W.east do` |
| `Shared/World/Garden.luau` | 896 | `while y - K.height > W.foot - K.height do -- below the slab` |
| `Shared/World/Garden.luau` | 908 | `while y + K.height <= W.above do` |
| `Shared/World/Garden.luau` | 1016 | `while y + K.height <= W.above do y += course; c += 1 end` |
| `Shared/World/Garden.luau` | 1017 | `while y + K.height <= U.head do` |
| `Shared/World/Garden.luau` | 1021 | `while x < U.east do` |
| `Shared/World/Garden.luau` | 1113 | `while y + K.height <= U.head + L.h do y += course; c += 1 end` |
| `Shared/World/Garden.luau` | 1114 | `while y + K.height <= U.top - K.joint / 2 do` |
| `Shared/World/Garden.luau` | 1117 | `while x < U.east do` |
| `Shared/World/Garden.luau` | 1221 | `while yy > H.foot do yy -= course end` |
| `Shared/World/Garden.luau` | 1224 | `while yy < U.top do` |
| `Shared/World/Garden.luau` | 1425 | `while x < W.east do` |
| `Shared/World/Garden.luau` | 1441 | `while y - K.height > W.foot - K.height do` |
| `Shared/World/Garden.luau` | 1449 | `while y + K.height <= W.top - K.joint / 2 do` |
| `Shared/World/Hut.luau` | 774 | `while true do` |
| `Shared/World/Hut.luau` | 1508 | `while x < hi.X - 1 do` |
| `Shared/World/Hut.luau` | 2226 | `while z < U.z1 - 1 do` |
| `Shared/World/Hut.luau` | 2258 | `while x < hi.X - 1 do` |
| `Shared/World/Hut.luau` | 2343 | `while x < hi.X - 5 and k < 4 do` |
| `Shared/World/Meadow.luau` | 774 | `while x < (b :: number) - 1 do` |
| `Shared/World/Pond.luau` | 170 | `while x < x1 - 1e-6 do` |
| `Shared/World/Pond.luau` | 397 | `while s <= s1 + 1e-6 do` |
| `Shared/World/Pond.luau` | 761 | `while x < x1 - 1e-6 do` |
| `Shared/World/PreserveLook.luau` | 305 | `while y < EAVES - 4 do` |
| `Shared/World/PreserveLook.luau` | 547 | `while gx <= x1 + 3.1 do` |
| `Shared/World/PreserveLook.luau` | 549 | `while gz <= z1 + 3.1 do` |
| `Shared/World/PreserveLook.luau` | 850 | `while x < 104 do` |
| `Shared/World/PreserveLook.luau` | 899 | `while z < 64 do` |
| `Shared/World/PreserveTrain.luau` | 74 | `while self.pass(cursor).finish < t do cursor += 1 end` |
| `Shared/World/StationAir.luau` | 128 | `while i>1 do local parent=i//2;if heap[parent].cost<=cost then break end;heap[i],heap[parent]=heap[parent],heap[i];i=parent end` |
| `Shared/World/StationAir.luau` | 134 | `while i*2<=#heap do` |
| `Shared/World/StationAir.luau` | 145 | `while #heap>0 do` |
| `Shared/World/StationAir.luau` | 150 | `while at~=first do at=previous[at];table.insert(reversed,nodes[at]) end` |
| `Shared/World/StationAir.luau` | 156 | `while i<#path do` |
| `Shared/World/WorldBuild.luau` | 30 | `local model = Instance.new("Model")` |
| `Shared/World/WorldBuild.luau` | 49 | `local world = Instance.new("Folder")` |
| `Shared/World/WorldBuild.luau` | 64 | `local looks = Instance.new("Folder")` |
| `Shared/World/WorldBuild.luau` | 69 | `local model = Instance.new("Model")` |

## Unresolved imports

| Source | Line | Expression | Candidates |
|---|---:|---|---|
| `Client/SpiderClient.client.luau` | 2778 | `runtime/cast require: local run: any = (require :: any)(playback)` |  |
| `First/Splash.client.luau` | 7 | `runtime/cast require: local SplashScreen: any = (require :: any)(module)` |  |
| `First/SplashScreen.luau` | 96 | `runtime/cast require: return (require :: any)(text), (require :: any)(shots)` |  |
