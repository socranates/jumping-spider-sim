# Foundation map
Current source `e315b3a048fddd1729461fb92502f73b7d8e2b94`, branch `codex/save-lease-cleanup`. All indexed production bytes match that commit. Last verified published baseline: v51 / place 140, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`; this index is not publication evidence.

See `../CURRENT.md` for current verification gaps; `../DATA.md` remains the historical schema discussion. This is a lexical index, not a line-by-line review.

Static index: 217 source files, 55,386 lines. Shared means available to either side; consumers determine execution. Direct test names are lexical matches, not coverage percentages. Requires inferred from literal module names; dynamic cases need manual review.
## Source inventory

| Source | Lines | Side | Purpose from source | Required by | Direct tests | Flags |
|---|---:|---|---|---|---|---|
| `roblox_port/src/Client/BirdBody.luau` | 208 | Client | The robin in the world (ROBLOX-120): Predator/Bird's American robin drawn at its true size, 25 cm from bill to tail (Bird.LENGTH), from `parts` (pure: the previewer | SpiderClient.client.luau | bodies.luau, preserve.luau |  |
| `roblox_port/src/Client/BugBodies.luau` | 767 | Client | The drawn woodlice (ROBLOX-96, Prey/Woodlouse): a grey segmented body about a centimetre long, made of seven overlapping plates over the back, a small head | SelfTest.luau, SpiderClient.client.luau | bodies.luau, garden_life.luau |  |
| `roblox_port/src/Client/CatBody.luau` | 121 | Client | The ranger's cat in the world (ROBLOX-118): Rig/CatPose's parts, built once and moved each frame from Predator/Cat (where it is, which way it faces, what it is | SpiderClient.client.luau | feeding_survival.luau |  |
| `roblox_port/src/Client/CaughtPanel.luau` | 181 | Client | Plain end/start screens. Scroll within the safe area; the selected button owns accept, | SpiderClient.client.luau | title.luau |  |
| `roblox_port/src/Client/CrabBody.luau` | 117 | Client | The crab spiders in the world (ROBLOX-119): each of Predator/CrabSpider's drawn at true size on its flower, a female goldenrod crab spider about 9 mm long: a broad | SpiderClient.client.luau | none | no direct test import |
| `roblox_port/src/Client/FlyBodies.luau` | 650 | Client | The drawn fly: a house fly (Data/FlyLook has every number) 0.7 cm long, made of ellipsoids and rods: a head with two big red-brown | SpiderClient.client.luau | bodies.luau, feeding_survival.luau, flies.luau, garden_life.luau |  |
| `roblox_port/src/Client/FrameProfile.luau` | 135 | Client | The client's frame, timed by part (ROBLOX-111): what the self-test prints when it samples the frame time, so a Studio run says where a slow frame's time goes. | SpiderClient.client.luau, WorldClient.luau | none | no direct test import |
| `roblox_port/src/Client/HutLife.luau` | 249 | Client | The ranger hut's own life on this client (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B): the window's sash, shut through the nursery and propped open by the | WorldClient.luau | none | no direct test import |
| `roblox_port/src/Client/LivingWorld.luau` | 482 | Client | The close world: bounded local detail, ambient animals, and weather. No movement/save/attack rules live here. | WorldClient.luau | living_world.luau |  |
| `roblox_port/src/Client/LookStream.luau` | 276 | Client | The drawn looks of the regions outside the window, built on this client near the spider and destroyed far from it (ROBLOX-108). | WorldClient.luau | world_client.luau |  |
| `roblox_port/src/Client/MateStage.luau` | 348 | Client | What the mating cycle looks like (ROBLOX-80). Display only: the cycle itself is Life/Mating and Predator/Mate (what is true), and nothing here feeds back. | SpiderClient.client.luau | client_mating.luau |  |
| `roblox_port/src/Client/MealPresentation.luau` | 68 | Client | Drawing only: one held-body override and one short-lived, noninteractive husk. | SpiderClient.client.luau | feeding_survival.luau |  |
| `roblox_port/src/Client/NotebookArt.luau` | 32 | Client | Small authored vector sketches, deliberately diagrams rather than photographs or eye-view claims. | entrypoint or no static consumer | none | no direct test import |
| `roblox_port/src/Client/NotebookPanel.luau` | 497 | Client | The naturalist's notebook on screen (ROBLOX-37), from Godot's notebook_panel.gd: the pages found so far on the left, in the order they | SpiderClient.client.luau | notebook.luau |  |
| `roblox_port/src/Client/OldSkins.luau` | 39 | Client | At most three pale, empty skins in the retreat. Presentation only, never queried by movement or senses. | SpiderClient.client.luau | growth.luau |  |
| `roblox_port/src/Client/PerceptionHud.luau` | 234 | Client | Thin drawer for the pure memory view (Shared/UI/PerceptionView). Reuses widgets rather than creating Instances every frame. | SpiderClient.client.luau | hud.luau |  |
| `roblox_port/src/Client/PerceptionStage.luau` | 39 | Client | Temporary D-038 stage, away from spawn, crevice and recovery routes. Physical screen/ledge belong to WORLD. | SpiderClient.client.luau | none | no direct test import |
| `roblox_port/src/Client/PondBodies.luau` | 162 | Client | The pond's bigger animals in the world (ROBLOX-122): the green frog of Predator/Frog on its seat, and the green darner (World/Pond.darner) patrolling over the water. | SpiderClient.client.luau | bodies.luau, preserve.luau |  |
| `roblox_port/src/Client/RareBody.luau` | 86 | Client | One bounded local animal. Supports join the custom motor's world query root; | SpiderClient.client.luau | rare_sightings.luau |  |
| `roblox_port/src/Client/SaveClient.luau` | 167 | Client | The client's side of persistent saves (ROBLOX-39). It looks for the server's remotes, says hello, hears the saved state, and sends the | SpiderClient.client.luau | state.luau, state_client.luau, state_offline.luau, title.luau |  |
| `roblox_port/src/Client/SelfTest.luau` | 1804 | Client | The live place's self-test (ROBLOX-104): a run of the real client inside a real Studio Play session, which prints what it finds to Output, so every publish can be | SpiderClient.client.luau | selftest.luau, selftest_preserve.luau, title.luau | over 800 lines |
| `roblox_port/src/Client/SettingsPanel.luau` | 695 | Client | The settings on screen (ROBLOX-49): a list of sections (Sound, Camera, Comfort and accessibility, Help and hints), each setting a row with | SpiderClient.client.luau | settings.luau |  |
| `roblox_port/src/Client/Soundscape.luau` | 195 | Client | Original procedural recordings from the frozen Godot sound_bank.gd. Presentation only: | SpiderClient.client.luau | client_smoke.luau, feeding_survival.luau, growth.luau, settings.luau |  |
| `roblox_port/src/Client/SpiderCamera.luau` | 724 | Client | The spider's camera: a Roblox port of the frozen Godot rig, scripts/movement/camera_rig.gd (c87ce00). | SpiderClient.client.luau | eyes.luau, gaze.luau, growth.luau, scenarios.luau, spawn_clearance.luau |  |
| `roblox_port/src/Client/SpiderClient.client.luau` | 2419 | Client | The playable spider. Wires one control scheme (SpiderInput: keyboard and mouse, controller and touch together) to the | entrypoint or no static consumer | client_ant.luau, client_mating.luau, client_rival.luau, client_smoke.luau, eyes.luau, feeding_survival.luau, inspect.luau, lock.luau, minimal_hud.luau, nature_client.luau, navigation_startup.luau, notebook.luau, outdoor_life_reset.luau, perception_client.luau, quiet.luau, rare_sightings.luau, save_notice.luau, selftest.luau, selftest_preserve.luau, settings.luau, state_client.luau, state_offline.luau, title.luau, world_client.luau | over 800 lines |
| `roblox_port/src/Client/SpiderEyes.luau` | 460 | Client | The spider-eye picture (ROBLOX-20): what the eye view looks like, drawn on this client from the pure rules of Shared/UI/EyeOptics | SpiderClient.client.luau | eyes.luau |  |
| `roblox_port/src/Client/SpiderHud.luau` | 431 | Client | The spider's screen: the centre dot and Focus ticks, the aim's words under them (Godot jump_hud.gd), a status line and | SpiderClient.client.luau | feeding_survival.luau, hud.luau, minimal_hud.luau, save_notice.luau |  |
| `roblox_port/src/Client/SpiderInput.luau` | 263 | Client | One action path for keyboard, mouse, gamepad and held on-screen touch buttons, all at once. | SpiderClient.client.luau | client_smoke.luau, lock.luau, notebook.luau |  |
| `roblox_port/src/Client/StationMouseBody.luau` | 40 | Client | Presentation only. Shapes are anchored and non-queryable like other animals. | SpiderClient.client.luau | station_debug.luau |  |
| `roblox_port/src/Client/TitleCard.luau` | 261 | Client | The title card's camera and the intro of a new life (ROBLOX-109). The words are UI/TitleText's, the shots Movement/TitleShots'; this module draws them. | SpiderClient.client.luau | none | no direct test import |
| `roblox_port/src/Client/TrainPass.luau` | 137 | Client | The trains beyond the preserve's north fence, drawn (ROBLOX-115): a silhouette of cars that runs along the railway's track when World/PreserveTrain's timetable | WorldClient.luau | none | no direct test import |
| `roblox_port/src/Client/WaspBody.luau` | 226 | Client | The drawn mud dauber wasp (Data/WaspLook has every number): about 2.5 cm long, built from ellipsoids and rods as the fly is | SpiderClient.client.luau | wasp.luau |  |
| `roblox_port/src/Client/WorldClient.luau` | 338 | Client | The client's side of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). The spider, the flies, the wasp, the rival and the mate are all simulated here, on this | SpiderClient.client.luau | world_client.luau |  |
| `roblox_port/src/Client/WorldDetail.luau` | 35 | Client | The low-detail tier of the world, applied on one client: phones and tablets drop what the server built for the full tier | SpiderClient.client.luau | world.luau |  |
| `roblox_port/src/Client/WorldShadows.luau` | 186 | Client | The walkable boxes' shadows, kept to the ones an eye at the spider could see (ROBLOX-121). | WorldClient.luau | shadows.luau |  |
| `roblox_port/src/First/Splash.client.luau` | 10 | First | ReplicatedFirst's one script (ROBLOX-109): the game's own loading screen, First/SplashScreen. Whatever happens in it, it ends: SplashScreen.run is | entrypoint or no static consumer | none | no direct test import |
| `roblox_port/src/First/SplashScreen.luau` | 243 | First | The startup veil/title drift (ROBLOX-109). Healthy TitleReady fades into the | entrypoint or no static consumer | title.luau |  |
| `roblox_port/src/Server/DataStoreBackend.luau` | 52 | Server | Roblox DataStore adapter (read and update, neither raises). An optional storage codec handles only R_ rest keys; | Persistence.server.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `roblox_port/src/Server/Main.server.luau` | 72 | Server | Builds the world: the windowsill (scripts/habitat/windowsill.gd) as region 0 of the map (World/WorldBuild, ROBLOX-94: every region's physical boxes under one `World` | entrypoint or no static consumer | none | no direct test import |
| `roblox_port/src/Server/Persistence.server.luau` | 91 | Server | Persistent saves, the server's side (ROBLOX-39). Wires the engine to SaveService: the DataStore, the two remotes, the players coming and | entrypoint or no static consumer | none | no direct test import |
| `roblox_port/src/Server/RestCompression.luau` | 128 | Server | Storage only: independently compressed current/backup cores retain their original canonical checksums. | Persistence.server.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `roblox_port/src/Server/SaveService.luau` | 216 | Server | The server's persistence service (ROBLOX-39): one SaveSession per player, and the only place a client's message is turned into anything | Persistence.server.luau | state.luau |  |
| `roblox_port/src/Server/WorldFocus.luau` | 116 | Server | Where the server streams the world to (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md). With Workspace.StreamingEnabled the server sends each client only the instances around | Main.server.luau | world.luau |  |
| `roblox_port/src/Shared/Data/AntMimic.luau` | 61 | Shared | The ant-mimicking jumping spider's walk and antennae (ROBLOX-64): every number the pose needs, each marked DOC (reported in the | NotebookWatch.luau, AntMimicPose.luau | antmimic.luau, notebook.luau |  |
| `roblox_port/src/Shared/Data/Appearances.luau` | 844 | Shared | Artist-directed appearance, independent of species tuning, growth and physics. | MateStage.luau, SpiderChoice.luau, SpiderRig.luau | antmimic.luau, idle.luau, look.luau, peacock.luau, run.luau, state.luau, tarantula.luau | over 800 lines |
| `roblox_port/src/Shared/Data/Catch.luau` | 81 | Shared | The catch struggle as the game plays it (ROBLOX-72, ROBLOX-77). Game tuning, not measurements; Godot's values (Prey/Feeding's defaults, checked | Feeding.luau | garden_life.luau, preserve.luau, prey.luau, rival.luau |  |
| `roblox_port/src/Shared/Data/Detail.luau` | 20 | Shared | Which detail tier a device runs: "full" for computers and consoles, "low" for touch-only phones and tablets. The tier | SpiderClient.client.luau | world.luau |  |
| `roblox_port/src/Shared/Data/Eyes.luau` | 160 | Shared | The numbers of the spider-eye picture (ROBLOX-20): how each way of seeing looks, how the two retinae move, how the lateral | SpiderEyes.luau, EyeOptics.luau | eyes.luau |  |
| `roblox_port/src/Shared/Data/Flora.luau` | 213 | Shared | The plants of the drawn world: the Pilea on the sill, the trough's planting, and the garden outside the window. Numbers and | DayLight.luau, Dressing.luau, Plants.luau, Scenery.luau, Garden.luau | world.luau |  |
| `roblox_port/src/Shared/Data/FlyLook.luau` | 482 | Shared | How a fly looks: numbers and names only; Client/FlyBodies builds the parts and places them each frame. A house fly (Musca | BugBodies.luau, FlyBodies.luau | bodies.luau, flies.luau |  |
| `roblox_port/src/Shared/Data/Graphics.luau` | 228 | Shared | How the world looks, apart from the spider (whose look is Data/Appearances). Numbers and names only, so the whole look can | WorldDetail.luau, DayLight.luau, Dressing.luau, Lit.luau, Patina.luau, Plants.luau, Scenery.luau | life.luau, world.luau |  |
| `roblox_port/src/Shared/Data/MatingRules.luau` | 85 | Shared | The mating cycle's numbers (ROBLOX-79). Game tuning, not measurements: Predator/Mate and Life/Mating read these and nothing else decides them. | MateStage.luau, SpiderClient.client.luau, Mating.luau, MatingScene.luau, Mate.luau | client_mating.luau, mating.luau, nature.luau |  |
| `roblox_port/src/Shared/Data/Meshes.luau` | 36 | Shared | The preserve's first meshes (ROBLOX-126; docs/MESHES.md, assets/meshes/manifest.json): original Blender studies by Chet, uploaded by socranates and verified | LivingWorld.luau, Scenery.luau | preserve.luau |  |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 665 | Shared | The naturalist's notebook pages (LEARN-01), GENERATED by tools/gen_notebook_pages.py from the frozen Godot | SpiderClient.client.luau, FieldNotebook.luau, NotebookWatch.luau | antmimic.luau, client_mating.luau, notebook.luau |  |
| `roblox_port/src/Shared/Data/Peacock.luau` | 74 | Shared | The peacock spider's courtship dance (ROBLOX-29): every number the dance needs, each marked DOC (reported in the paper) or ART | PeacockDance.luau, PeacockText.luau | peacock.luau |  |
| `roblox_port/src/Shared/Data/RareSightings.luau` | 12 | Shared | Only finished encounters are registered. The thirteen-creature roadmap is | RareDirector.luau | rare_sightings.luau |  |
| `roblox_port/src/Shared/Data/RivalRules.luau` | 57 | Shared | When the brown rival spider arrives (ROBLOX-68). Game tuning, not measurements. Predator/RivalSpider reads these; nothing else decides it. | RivalDrive.luau, RivalRoute.luau, RivalSpider.luau, Region.luau | mating.luau, nature.luau, rival.luau, rivalnav.luau, worldmap.luau |  |
| `roblox_port/src/Shared/Data/SaveRules.luau` | 75 | Shared | Every number and name the persistent saves use (ROBLOX-39): store names, key prefixes, sizes, timings, limits. The logic is in | SpiderClient.client.luau, Persistence.server.luau, SaveService.luau, MemoryBackend.luau, SaveEnvelope.luau, SaveProgress.luau, SaveRest.luau, SaveScheduler.luau, SaveSession.luau, SaveStores.luau | client_ant.luau, rest_storage.luau, save_notice.luau, settings.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Data/SettingsSpec.luau` | 102 | Shared | Every setting the player can change (ROBLOX-49): its id, words, kind, default and range. One table, no logic: Shared/UI/SettingsModel | SettingsPanel.luau, SpiderClient.client.luau, SettingsModel.luau | lock.luau, settings.luau |  |
| `roblox_port/src/Shared/Data/Species.luau` | 592 | Shared | GENERATED by tools/json_to_luau.py from data/species/*.json. Do not edit by hand. | SelfTest.luau, SpiderClient.client.luau, Catch.luau, Growth.luau, Checkpoint.luau, SaveRest.luau, PreyDirector.luau, PreyKinds.luau, PreyWorld.luau | bodies.luau, checkpoint.luau, compact_layout.luau, feeding_survival.luau, flies.luau, garden_life.luau, gaze.luau, lock.luau, mating.luau, nature.luau, perception.luau, preserve.luau, prey.luau, rare_sightings.luau, rest_storage.luau, rival.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, sensor.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau, world_client.luau |  |
| `roblox_port/src/Shared/Data/Surfaces.luau` | 97 | Shared | GENERATED by tools/json_to_luau.py from data/surfaces/*.json. Do not edit by hand. | SpiderClient.client.luau, Scenery.luau | checkpoint.luau, compact_layout.luau, gaze.luau, lock.luau, mating.luau, nature.luau, preserve.luau, rare_sightings.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau |  |
| `roblox_port/src/Shared/Data/Tarantula.luau` | 50 | Shared | The tarantulas' threat display and silk mat (ROBLOX-82): every number the pose needs. The pose is presentation only: it bends and | TarantulaPose.luau | look.luau, tarantula.luau |  |
| `roblox_port/src/Shared/Data/Wasp.luau` | 136 | Shared | The mud dauber wasp's rules: every number of scripts/predator/wasp_director.gd (LIFE round 4, LIFE-14 to LIFE-17), unchanged, in | WaspDirector.luau, Heard.luau, WaspText.luau | mating.luau, nature.luau, wasp.luau |  |
| `roblox_port/src/Shared/Data/WaspLook.luau` | 75 | Shared | How the mud dauber wasp looks: numbers and names only; Client/WaspBody builds the parts and poses them each frame. A black-and-yellow | WaspBody.luau | wasp.luau |  |
| `roblox_port/src/Shared/Data/Wear.luau` | 87 | Shared | What age and use have done to the sill, the glass and the retreat, and the few small things left lying about: numbers and names | Dressing.luau, Patina.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/Breakaway.luau` | 71 | Shared | Godot windowsill.gd T09b: the pale east leaf tip falls on a committed jump. | SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, world.luau |  |
| `roblox_port/src/Shared/Habitat/DayLight.luau` | 142 | Shared | The light of the hour on the sill (ROBLOX-24, after Godot's LIFE-06 set_daylight): the life clock's daylight, 0 (night) to 1 | LivingWorld.luau, LookStream.luau, SpiderClient.client.luau | life.luau, world.luau |  |
| `roblox_port/src/Shared/Habitat/Dressing.luau` | 221 | Shared | Dresses the sill (ROBLOX-74, "more grass and detail"), from Data/Flora, on top of what Plants and Patina already draw: moss on the shaded | Scenery.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/Lit.luau` | 125 | Shared | The lighting, sky and screen effects (Data/Graphics): a soft warm sun picked by SunPick so that it shines in through the | Main.server.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/Materials.luau` | 32 | Shared | Material names (as Data/Graphics spells them) to Roblox's Enum.Material, so the data stays plain text and a typo is caught by | TrainPass.luau, Scenery.luau, Shapes.luau | preserve.luau, world.luau |  |
| `roblox_port/src/Shared/Habitat/Patina.luau` | 118 | Shared | Builds what age and use have done to the sill, the glass and the retreat, from Data/Wear: a worn strip along the front lip, grime | Scenery.luau | none | no direct test import |
| `roblox_port/src/Shared/Habitat/Plants.luau` | 520 | Shared | Builds the plants of the drawn world from Data/Flora: the Pilea that replaces the leaf and stem pieces of the sill, the trough's | Dressing.luau, Scenery.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 540 | Shared | Builds the drawn world from Data/Graphics: the sill's physical pieces (looks only), and a "Decor" model (a persistent one, ROBLOX-94) with the window wall, | LookStream.luau, Main.server.luau, WorldBuild.luau | minimal_hud.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, save_notice.luau, selftest_preserve.luau, shadows.luau, world.luau, world_client.luau |  |
| `roblox_port/src/Shared/Habitat/Shapes.luau` | 145 | Shared | Drawn-only parts for the decor builders (Habitat/Scenery, Plants, Patina) and the fly (Client/FlyBodies): every part is anchored, nothing collides with it, no | BirdBody.luau, BugBodies.luau, CatBody.luau, CrabBody.luau, FlyBodies.luau, LivingWorld.luau, PondBodies.luau, RareBody.luau, StationMouseBody.luau, WaspBody.luau, Dressing.luau, Patina.luau, Plants.luau, Scenery.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/SunPick.luau` | 68 | Shared | Finds a sun that shines in through the window: behind the back wall (-Z), standing between a low and a middling height, | Lit.luau | world.luau |  |
| `roblox_port/src/Shared/Habitat/TestTarget.luau` | 32 | Shared | Godot test_target.gd: a labelled prop, never prey. Path stepping is independent of rendering. | PerceptionStage.luau | perception_view.luau |  |
| `roblox_port/src/Shared/Habitat/WindowsillLayout.luau` | 95 | Shared | The windowsill of scripts/habitat/windowsill.gd ("windowsill-v1"), box for box. Coordinates are studs = Godot WU = cm, | Plants.luau, Scenery.luau, Shapes.luau, Region.luau, WorldMap.luau | checkpoint.luau, client_ant.luau, client_mating.luau, client_rival.luau, client_smoke.luau, eyes.luau, feeding_survival.luau, gaze.luau, inspect.luau, life.luau, lock.luau, mating.luau, nature.luau, notebook.luau, perception_client.luau, preserve.luau, quiet.luau, rival.luau, rivalnav.luau, scenarios.luau, settings.luau, state.luau, state_client.luau, state_offline.luau, title.luau, wasp.luau, world.luau, worldmap.luau, world_client.luau |  |
| `roblox_port/src/Shared/Learning/FieldNotebook.luau` | 193 | Shared | The naturalist's notebook (LEARN-01), a port of the frozen scripts/learning/field_notebook.gd without the file and the node. | SpiderClient.client.luau | antmimic.luau, notebook.luau, rare_sightings.luau |  |
| `roblox_port/src/Shared/Learning/NotebookWatch.luau` | 230 | Shared | Watches play for the moments the naturalist's notebook opens pages on: a port of the frozen scripts/learning/notebook_watch.gd. | SpiderClient.client.luau | antmimic.luau, notebook.luau |  |
| `roblox_port/src/Shared/Life/Ballooning.luau` | 153 | Shared | Ballooning, the lineage moves (ROBLOX-120, docs/PARK_WORLD_DESIGN.md section 5: "the spiderlings balloon. The player chooses one to follow: where it lands is drawn from | SelfTest.luau, SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, preserve.luau, selftest_preserve.luau |  |
| `roblox_port/src/Shared/Life/Growth.luau` | 117 | Shared | Frozen Godot scripts/life/growth.gd, LIFE-10..12. Durations and scales are game tuning, not measured instars. | MateStage.luau, SpiderClient.client.luau, LifeLoop.luau, Mating.luau, Checkpoint.luau, SpiderRig.luau | gaze.luau, growth.luau, life.luau, mating.luau, nature.luau, quiet.luau |  |
| `roblox_port/src/Shared/Life/LifeClock.luau` | 193 | Shared | The life clock: a port of the frozen scripts/life/life_clock.gd (LIFE-04). The windowsill's time of day and the spider's | SpiderClient.client.luau, WorldClient.luau, LifeLoop.luau, Checkpoint.luau, ContextPrompts.luau | feeding_survival.luau, life.luau, mating.luau, world_client.luau |  |
| `roblox_port/src/Shared/Life/LifeLoop.luau` | 264 | Shared | LifeLoop: the rest, sleep and day of the frozen scripts/habitat/habitat_loop.gd (T08, LIFE-04 to LIFE-06), without the | SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, compact_layout.luau, continuing.luau, feeding_survival.luau, growth.luau, life.luau, mating.luau, nature.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Life/LifeSession.luau` | 43 | Shared | LIFE-19..23: player progress lives outside world checkpoints. Session only until server saves are ported. | SpiderClient.client.luau | continuing.luau, growth.luau, nature.luau |  |
| `roblox_port/src/Shared/Life/Mating.luau` | 336 | Shared | The mating cycle and the new generation (ROBLOX-79). One plain record, life.mating, in LifeLoop's checkpoint graph beside life.mate (the mate's body, | SpiderClient.client.luau, Checkpoint.luau | client_mating.luau, mating.luau, nature.luau, selftest_preserve.luau, tarantula.luau |  |
| `roblox_port/src/Shared/Life/MatingScene.luau` | 162 | Shared | The mating scene (ROBLOX-89): what happens between "the meter is full" and "they part", as a pure plan. About fifteen seconds, in four beats, with a camera that | SpiderClient.client.luau | client_mating.luau, mating.luau |  |
| `roblox_port/src/Shared/Life/Nature.luau` | 165 | Shared | Nature's rules (ROBLOX-106, W4 of docs/OPEN_WORLD_DESIGN.md; the design called it "ROBLOX-97", a number never used). Nathan: "Normal mode should feel like it doesn't | SpiderClient.client.luau, Checkpoint.luau | lock.luau, nature.luau, nature_client.luau, preserve.luau |  |
| `roblox_port/src/Shared/Life/NeedsModel.luau` | 370 | Shared | NeedsModel: a port of the frozen scripts/needs/needs_model.gd (spec 11, 19.3, 21.3 NeedState; LIFE-05). The spider's | SpiderClient.client.luau, Checkpoint.luau, Feeding.luau | checkpoint.luau, compact_layout.luau, continuing.luau, feeding_survival.luau, growth.luau, life.luau, mating.luau, nature.luau, nature_client.luau, rest_storage.luau, rival.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Life/Nursery.luau` | 42 | Shared | The nursery rule (ROBLOX-116, docs/PARK_WORLD_DESIGN.md: Nathan's "born on the sill, the sash shut until ready"). In the preserve's first life the ranger hut's | HutLife.luau | preserve.luau |  |
| `roblox_port/src/Shared/Life/RareDirector.luau` | 74 | Shared | Optional life fields are part of the existing checkpoint object graph. | SpiderClient.client.luau, Checkpoint.luau | rare_sightings.luau |  |
| `roblox_port/src/Shared/Life/RareLedger.luau` | 70 | Shared | Player progress, outside rests. High-water marks prevent a rewound rest | SpiderClient.client.luau, RareDirector.luau, SaveProgress.luau | rare_sightings.luau |  |
| `roblox_port/src/Shared/Life/Water.luau` | 151 | Shared | The water (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "water (drowning)"): the pond's surface is not a place a jumping spider can live on. The sources the notebook's | SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, preserve.luau |  |
| `roblox_port/src/Shared/Movement/CameraMath.luau` | 292 | Shared | Pure camera and stick math, ported from the frozen Godot reference (c87ce00): | SpiderCamera.luau, LineFraming.luau, LockOn.luau | lock.luau, run.luau, settings.luau |  |
| `roblox_port/src/Shared/Movement/FocusState.luau` | 17 | Shared | D-041: toggle is optional, grounded only, and Cancel belongs to other actions first. | SpiderClient.client.luau | perception_view.luau |  |
| `roblox_port/src/Shared/Movement/InputState.luau` | 87 | Shared | Pure input state: test without Studio. +Y is forward on the control pad; look +X is right, +Y is down | SpiderInput.luau | run.luau |  |
| `roblox_port/src/Shared/Movement/InspectView.luau` | 147 | Shared | Inspect mode's view, as numbers (ROBLOX-90): an orbit of the spider by yaw, elevation and distance in body-lengths, the auto-orbit when the player is | SpiderCamera.luau, SpiderClient.client.luau | inspect.luau |  |
| `roblox_port/src/Shared/Movement/JumpInput.luau` | 165 | Shared | Jump input: a port of the frozen Godot scripts/movement/jump_controller.gd (c87ce00, hold mode). Pure: the motor is passed | SpiderClient.client.luau | run.luau, scenarios.luau |  |
| `roblox_port/src/Shared/Movement/JumpMath.luau` | 152 | Shared | Port of scripts/movement/jump_math.gd (spec 6.3, 27). Pure math, no Instances, so it runs in tests/run.luau too. | SpiderMotor.luau | run.luau |  |
| `roblox_port/src/Shared/Movement/LineFraming.luau` | 95 | Shared | The camera's line framing at a catch: a port of the frozen Godot camera_rig.gd (c87ce00; A-017, chunk 6A, capped in 6B). | SpiderCamera.luau | run.luau |  |
| `roblox_port/src/Shared/Movement/LockOn.luau` | 182 | Shared | Lock-on and the sidestep (ROBLOX-110). Nathan: "a lock on so you can track prey without the visual cues and the ability to side step". | SpiderCamera.luau, SpiderClient.client.luau | lock.luau |  |
| `roblox_port/src/Shared/Movement/SilkController.luau` | 334 | Shared | Engine adapter for the frozen safety line. One local-space anchor, at most one bend. | SpiderMotor.luau | rare_sightings.luau, scenarios.luau |  |
| `roblox_port/src/Shared/Movement/SpiderMotor.luau` | 811 | Shared | The spider's body on the windowsill: a kinematic port of the frozen Godot motor's core (scripts/movement/spider_motor.gd, | SpiderClient.client.luau, RivalDrive.luau | checkpoint.luau, compact_layout.luau, gaze.luau, lock.luau, mating.luau, nature.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, scenarios.luau, spawn_clearance.luau, state.luau, state_client.luau, station_debug.luau, station_threats.luau, verge_litter.luau | over 800 lines |
| `roblox_port/src/Shared/Movement/StickCarry.luau` | 54 | Shared | The carry over an edge: a port of the frozen Godot scripts/movement/player_controller.gd _carry (c87ce00). | SpiderClient.client.luau | run.luau, scenarios.luau |  |
| `roblox_port/src/Shared/Movement/SupportMath.luau` | 76 | Shared | Port of scripts/movement/support_math.gd (spec 6.1, 6.2). Pure geometry for supported locomotion; unit vectors in world space. | MateStage.luau, SpiderCamera.luau, SpiderClient.client.luau, LockOn.luau, SpiderMotor.luau, RivalDrive.luau | gaze.luau, idle.luau, lock.luau, look.luau, run.luau |  |
| `roblox_port/src/Shared/Movement/TetherMath.luau` | 62 | Shared | Pure safety-line operations from frozen Godot tether.gd / spider_motor.gd. | SilkController.luau | run.luau |  |
| `roblox_port/src/Shared/Movement/TitleShots.luau` | 166 | Shared | The camera of the first minute (ROBLOX-109), as pure functions of time: the drift the splash (First/SplashScreen) and the title card (Client/TitleCard) | TitleCard.luau | preserve.luau, title.luau |  |
| `roblox_port/src/Shared/Perception/Observation.luau` | 151 | Shared | Observation (spec 21.3): one piece of sensed evidence, as the sensor makes it and the memory keeps it. A port of the frozen | LockOn.luau, ObservationMemory.luau, PerceptionMath.luau, SensorCore.luau, Checkpoint.luau | perception.luau, sensor.luau |  |
| `roblox_port/src/Shared/Perception/ObservationMemory.luau` | 448 | Shared | ObservationMemory (spec 7, 21.3): what the observer remembers of what it sensed. A port of the frozen Godot | SpiderClient.client.luau, Sensor.luau, SensorCore.luau, Checkpoint.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, mating.luau, nature.luau, perception.luau, rest_storage.luau, sensor.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Perception/PerceptionMath.luau` | 171 | Shared | Pure helpers for the perception layer (spec 7): angles, apparent size, the exposure a classification needs, the evidence's | ObservationMemory.luau, Sensor.luau, SensorCore.luau, FlySenses.luau | perception.luau, sensor.luau |  |
| `roblox_port/src/Shared/Perception/Sensor.luau` | 414 | Shared | Sensor: the world half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00). SensorCore keeps what needs no world (which | SpiderClient.client.luau, SpiderEyes.luau, Checkpoint.luau | checkpoint.luau, compact_layout.luau, eyes.luau, garden_life.luau, mating.luau, nature.luau, rest_storage.luau, sensor.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Perception/SensorCore.luau` | 437 | Shared | SensorCore: the half of Godot's SensorSystem (scripts/perception/sensor_system.gd, c87ce00) that needs no world. The sensor turns world | Sensor.luau, Checkpoint.luau | perception.luau, sensor.luau |  |
| `roblox_port/src/Shared/Perception/Signal.luau` | 34 | Shared | A minimal in-process signal, the stand-in for a Godot `signal`: handlers run synchronously, in the order they were connected, when | FieldNotebook.luau, ObservationMemory.luau, SensorCore.luau | none | no direct test import |
| `roblox_port/src/Shared/Persistence/Checkpoint.luau` | 590 | Shared | The retreat checkpoint (S01-C; Godot's scripts/persistence/checkpoint.gd, T09; ROBLOX-25). A checkpoint is the whole world | SpiderClient.client.luau, SaveRest.luau | checkpoint.luau, compact_layout.luau, mating.luau, nature.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 207 | Shared | Where checkpoints live (S02; Godot's scripts/persistence/checkpoint_store.gd; ROBLOX-25), behind a DataStore-shaped | SpiderClient.client.luau | checkpoint.luau |  |
| `roblox_port/src/Shared/Persistence/CompactMigration.luau` | 108 | Shared | preserve-2 -> preserve-3: relocate habitats, not spider scale or progress. | Checkpoint.luau | none | no direct test import |
| `roblox_port/src/Shared/Persistence/Json.luau` | 147 | Shared | What a Roblox DataStore can hold, checked without the engine (ROBLOX-25), and the canonical text a checksum is taken over | CheckpointStore.luau, MemoryBackend.luau, SaveEnvelope.luau, SaveRest.luau, SaveSession.luau | checkpoint.luau, client_mating.luau, compact_layout.luau, mating.luau, nature.luau, rare_sightings.luau, rest_compression.luau, rest_storage.luau, state.luau, state_client.luau, world_client.luau |  |
| `roblox_port/src/Shared/Persistence/MemoryBackend.luau` | 101 | Shared | The in-memory store backend (ROBLOX-39): the same interface as the real DataStore backend, with a Roblox DataStore's rules (values | entrypoint or no static consumer | state.luau |  |
| `roblox_port/src/Shared/Persistence/ObjectRecord.luau` | 329 | Shared | ObjectRecord (ROBLOX-25): the state of a few live objects as one plain record that a DataStore could hold, and back. | Checkpoint.luau | checkpoint.luau, compact_layout.luau, feeding_survival.luau, mating.luau, rare_sightings.luau |  |
| `roblox_port/src/Shared/Persistence/SaveEnvelope.luau` | 153 | Shared | The versioned envelope every stored save travels in (ROBLOX-39), and how it is opened without ever guessing. | SaveProgress.luau, SaveRest.luau, SaveSession.luau | rest_compression.luau, rest_storage.luau, state.luau |  |
| `roblox_port/src/Shared/Persistence/SaveProgress.luau` | 187 | Shared | The player's progress record (ROBLOX-39): the small precious part of a save, kept apart from the world's rests. | SpiderClient.client.luau, SaveSession.luau | preserve.luau, rare_sightings.luau, rest_storage.luau, save_notice.luau, settings.luau, state.luau, state_client.luau, title.luau |  |
| `roblox_port/src/Shared/Persistence/SaveRest.luau` | 120 | Shared | The last rest of a mode, as the server keeps it (ROBLOX-39): a retreat checkpoint (Checkpoint) in an envelope, one per mode. | SaveSession.luau | checkpoint.luau, rest_storage.luau, state.luau, state_client.luau |  |
| `roblox_port/src/Shared/Persistence/SaveScheduler.luau` | 120 | Shared | When a save is written (ROBLOX-39): only decisions, no store and no clock of its own (the caller passes `now`, in seconds). It keeps, for | SaveSession.luau | state.luau |  |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 704 | Shared | One player's save session (ROBLOX-39): loads their records through a store backend, keeps their progress and rests in memory, and writes | SaveService.luau | rest_storage.luau, state.luau |  |
| `roblox_port/src/Shared/Persistence/SaveStores.luau` | 47 | Shared | Two small pure rules about the stores (ROBLOX-39): which store a build writes to, and what kind of failure a DataStore error is. | Persistence.server.luau, SaveSession.luau | state.luau |  |
| `roblox_port/src/Shared/Predator/Bird.luau` | 387 | Shared | The robin of the open ground (ROBLOX-120, docs/PARK_WORLD_DESIGN.md sections 4 and 5: the bird is the danger of the hut garden, the meadow and the open ground | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/Predator/Cat.luau` | 546 | Shared | The ranger's cat (ROBLOX-118, docs/PARK_WORLD_DESIGN.md section 10: "the cat and the game room live in the hut"): a house cat that lives in the ranger hut's | SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, feeding_survival.luau, preserve.luau, station_debug.luau |  |
| `roblox_port/src/Shared/Predator/CrabSpider.luau` | 154 | Shared | The crab spiders of the meadow's edge (ROBLOX-119, docs/PARK_WORLD_DESIGN.md zone 3; the notebook's page "The crab spider on the flower" says what is known of them): | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/Predator/Frog.luau` | 177 | Shared | The green frog of the pond's edge (ROBLOX-122, docs/PARK_WORLD_DESIGN.md zone 4: "a frog's tongue"; the notebook's page "The green frog" says what is known of it). | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/Predator/Mate.luau` | 370 | Shared | The mate (ROBLOX-79): a spider of the opposite sex that comes onto the sill when the played spider is full-grown and well fed, is courted by the | SelfTest.luau, SpiderClient.client.luau, Mating.luau, Checkpoint.luau, MateDrive.luau | client_mating.luau, mating.luau, nature.luau, rivalnav.luau |  |
| `roblox_port/src/Shared/Predator/MateDrive.luau` | 86 | Shared | The mate's legs (ROBLOX-79): the rival's own drive (Predator/RivalDrive: a SpiderMotor over the whole sill, the route graph, the keep-out around the | SpiderClient.client.luau | mating.luau, rivalnav.luau |  |
| `roblox_port/src/Shared/Predator/RivalDisplay.luau` | 171 | Shared | The male rival's contest display (ROBLOX-127): how a male jumping spider meets another spider, drawn on top of the rival's rules. Pure, Vector3-free and | SpiderClient.client.luau | look.luau, rival.luau |  |
| `roblox_port/src/Shared/Predator/RivalDrive.luau` | 499 | Shared | The rival spider's legs (ROBLOX-69): its own SpiderMotor, the player's proven surface-walking motor with the same collider, drives it over | SpiderClient.client.luau, MateDrive.luau | checkpoint.luau, nature.luau, rivalnav.luau, route_preparation.luau, station_threats.luau, wasp.luau |  |
| `roblox_port/src/Shared/Predator/RivalGrip.luau` | 77 | Shared | The grip on a caught rival (ROBLOX-77): the same tapping struggle as the fly's (Prey/Feeding's grip math, so the HUD's grip bar and the Grip button | SpiderClient.client.luau | checkpoint.luau, client_rival.luau, rival.luau, rivalnav.luau |  |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 829 | Shared | Where the rival spider can walk, and the ways between (ROBLOX-69). A graph of a region's box faces (the sill's, ROBLOX-94; any region's, ROBLOX-95, below): | RivalDrive.luau | checkpoint.luau, mating.luau, nature.luau, navigation_startup.luau, preserve.luau, rivalnav.luau, route_preparation.luau, station_threats.luau, wasp.luau, worldmap.luau | over 800 lines |
| `roblox_port/src/Shared/Predator/RivalSpider.luau` | 281 | Shared | Intraguild predator: the preserve's resident ranger-station patrol, present | SelfTest.luau, SpiderClient.client.luau, Checkpoint.luau, RivalGrip.luau | checkpoint.luau, client_rival.luau, growth.luau, mating.luau, nature.luau, rival.luau, rivalnav.luau, station_threats.luau, wasp.luau |  |
| `roblox_port/src/Shared/Predator/WaspDirector.luau` | 943 | Shared | WaspDirector: the black-and-yellow mud dauber's visits to the sill, without the engine. A port of the frozen | SpiderClient.client.luau, Checkpoint.luau | checkpoint.luau, mating.luau, nature.luau, station_threats.luau, wasp.luau | over 800 lines |
| `roblox_port/src/Shared/Prey/Ant.luau` | 134 | Shared | Ants (ROBLOX-119, the meadow's edge): ambient, not food. Small brown field ants of a hill in the meadow (World/Meadow.HILL, meadow_b4), out on its floor by day on a | Checkpoint.luau, PreyWorld.luau | preserve.luau |  |
| `roblox_port/src/Shared/Prey/Feeding.luau` | 89 | Shared | Frozen feeding_controller.gd: struggle after landing, then conserved nutrition grants. The energy itself belongs to the | Checkpoint.luau, RivalGrip.luau, PreyDirector.luau | feeding_survival.luau, preserve.luau, prey.luau, rival.luau |  |
| `roblox_port/src/Shared/Prey/Fly.luau` | 232 | Shared | Fly's evidence-owned decisions, reactions, flights, glances and surface bursts. | Checkpoint.luau, PreyDirector.luau | feeding_survival.luau, flies.luau, preserve.luau |  |
| `roblox_port/src/Shared/Prey/FlyFlight.luau` | 59 | Shared | Frozen FlyFlight: accelerate, sweep every step, brake for landing, reserve the destination. | Checkpoint.luau, Fly.luau | none | no direct test import |
| `roblox_port/src/Shared/Prey/FlySenses.luau` | 56 | Shared | scripts/prey/fly_senses.gd, A-028. No controls, plans or velocity enter this interface. | Checkpoint.luau, Fly.luau | prey.luau |  |
| `roblox_port/src/Shared/Prey/Harvestman.luau` | 141 | Shared | Harvestmen (ROBLOX-105, W3b part B): ambient, not food, not spiders: a small oval body high on eight very long legs. One walks the bed's soil and litter and one | Checkpoint.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `roblox_port/src/Shared/Prey/Ladybird.luau` | 195 | Shared | Ladybirds (ROBLOX-105, W3b part B): ambient beetles, not food, that walk the bed's plants among the aphids (World/Garden.plants: one on the dock, one on the | Checkpoint.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `roblox_port/src/Shared/Prey/Millipede.luau` | 186 | Shared | Millipedes (ROBLOX-105, W3b part B): ambient, not food. A seeded few in the bed walk the soil slowly round what stands on it, as the woodlice do (Prey/Woodlouse), | Checkpoint.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `roblox_port/src/Shared/Prey/PerchGraph.luau` | 47 | Shared | Geometry adapter for the frozen PerchGraph. Every planned leg and every flight tick is swept. | Checkpoint.luau, PreyDirector.luau | preserve.luau |  |
| `roblox_port/src/Shared/Prey/PlantWalk.luau` | 66 | Shared | A walk along a list of points on surfaces (ROBLOX-105, W3b part B): the aphid's creep from one of its perches to another and the ladybird's rounds over a | Ladybird.luau, PreyKinds.luau, Snail.luau | garden_life.luau |  |
| `roblox_port/src/Shared/Prey/PreyDirector.luau` | 219 | Shared | Solo client world of perceivable flies. Godot order: sensor, prey, motor, capture/feeding. | SpiderClient.client.luau, Checkpoint.luau, PreyWorld.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, mating.luau, nature.luau, preserve.luau, rest_storage.luau, state.luau, state_client.luau, station_debug.luau, verge_litter.luau |  |
| `roblox_port/src/Shared/Prey/PreyKinds.luau` | 372 | Shared | The bestiary's prey behaviours (ROBLOX-101, W3b part A), kept out of the frozen fly model: Prey/Fly calls in here only for a profile whose body asks for it | SelfTest.luau, SpiderClient.client.luau, Fly.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau, preserve.luau |  |
| `roblox_port/src/Shared/Prey/PreyMath.luau` | 84 | Shared | Frozen scripts/prey/prey_math.gd: explicit evidence, utility and swept-contact math. | Mate.luau, RivalSpider.luau, Fly.luau, FlyFlight.luau, FlySenses.luau, PerchGraph.luau, PreyDirector.luau | prey.luau |  |
| `roblox_port/src/Shared/Prey/PreyPopulation.luau` | 26 | Shared | Frozen prey_population.gd: delayed, twice-unseen vent entries; never teleport a replacement onto a perch. | Checkpoint.luau, PreyDirector.luau | none | no direct test import |
| `roblox_port/src/Shared/Prey/PreyRandom.luau` | 24 | Shared | A repeatable port stream (Park-Miller); Godot's random inputs are exported for parity fixtures. | MateStage.luau, Mating.luau, MatingScene.luau, Nature.luau, Checkpoint.luau, Mate.luau, RivalDisplay.luau, RivalDrive.luau, RivalGrip.luau, RivalSpider.luau, WaspDirector.luau, Ant.luau, Feeding.luau, Fly.luau, Harvestman.luau, Ladybird.luau, Millipede.luau, PreyPopulation.luau, Skater.luau, Snail.luau, Woodlouse.luau | feeding_survival.luau, garden_life.luau, nature.luau, preserve.luau, prey.luau, rival.luau |  |
| `roblox_port/src/Shared/Prey/PreyWorld.luau` | 391 | Shared | The prey of the whole world (ROBLOX-96, W3): one Prey/PreyDirector per region that has prey, run only where the spider is. The sill's director is the one the | SpiderClient.client.luau | checkpoint.luau, foundation.luau, garden_life.luau, rest_storage.luau |  |
| `roblox_port/src/Shared/Prey/Skater.luau` | 123 | Shared | Water striders (ROBLOX-122, the pond's edge): ambient, not the spider's food here. Common water striders (Gerridae) on the open water of the pond's margin | Checkpoint.luau, PreyWorld.luau | preserve.luau |  |
| `roblox_port/src/Shared/Prey/Snail.luau` | 194 | Shared | The garden snail (ROBLOX-105, W3b part B): ambient, not food, three times the spider's length. It crawls very slowly over the bed's soil and up the foot of the | Checkpoint.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `roblox_port/src/Shared/Prey/StationMouse.luau` | 47 | Shared | One ambient house mouse: authored floor routes, seeded pauses, no prey or | SpiderClient.client.luau | station_debug.luau |  |
| `roblox_port/src/Shared/Prey/Woodlouse.luau` | 190 | Shared | Woodlice (ROBLOX-96, W3): the garden's first ambient bugs, a seeded few in the bed that walk slowly about the soil, go under the big stone, the other stones' feet | Checkpoint.luau, PreyWorld.luau | checkpoint.luau, garden_life.luau |  |
| `roblox_port/src/Shared/Rig/Anatomy.luau` | 184 | Shared | Where the parts of the body sit, worked out from the appearance table alone: pure, Vector3 only, so tests/look.luau checks | Setae.luau, SpiderRig.luau | look.luau |  |
| `roblox_port/src/Shared/Rig/AntMimicPose.luau` | 114 | Shared | The ant-mimicking spider's antennae and walk as a pose (ROBLOX-64): pure and Vector3-free, display only. SpiderRig reads the pose, turns | SpiderClient.client.luau | antmimic.luau, look.luau |  |
| `roblox_port/src/Shared/Rig/CatPose.luau` | 343 | Shared | The ranger's cat drawn (ROBLOX-118; its sim is Predator/Cat): a domestic cat at true size, a brown mackerel tabby, posed from what the cat is doing. Pure: a list | CatBody.luau | preserve.luau, station_debug.luau |  |
| `roblox_port/src/Shared/Rig/DogGait.luau` | 80 | Shared | Presentation only. Stance paws remain in world space; travel drives the | LivingWorld.luau | dog_gait.luau |  |
| `roblox_port/src/Shared/Rig/Idle.luau` | 77 | Shared | Idle motion for the drawn spider (display only, never fed back into movement): a slow breathing bob, a small curious head | SpiderRig.luau | idle.luau, look.luau |  |
| `roblox_port/src/Shared/Rig/Living.luau` | 316 | Shared | Living motion for the drawn spider (ROBLOX-87): the small things an animal does when it is not being asked to do anything. Display only, full | SpiderRig.luau | idle.luau, look.luau |  |
| `roblox_port/src/Shared/Rig/PeacockDance.luau` | 166 | Shared | The peacock spider's courtship dance as a pose (ROBLOX-29): pure, Vector3-free, display only. Nothing here moves the body, the | SpiderClient.client.luau | growth.luau, look.luau, peacock.luau |  |
| `roblox_port/src/Shared/Rig/Setae.luau` | 420 | Shared | Where the spider's hairs (setae) go: pure layout from the appearance table, Vector3 only, so tests/run.luau and | SpiderRig.luau | look.luau, run.luau |  |
| `roblox_port/src/Shared/Rig/SpiderChoice.luau` | 109 | Shared | Which spider the player is (ROBLOX-31, ROBLOX-64, ROBLOX-81): the first spider, the peacock spider, the ant-mimicking spider or one of the two | SpiderClient.client.luau, PeacockText.luau, SettingsModel.luau | antmimic.luau, inspect.luau, look.luau, peacock.luau, settings.luau, state.luau, tarantula.luau |  |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 1647 | Shared | The drawn spider for Roblox: a port of scripts/presentation/spider_body.gd and surface_legs.gd (VISUAL-01 look), made cuter in | MateStage.luau, SpiderClient.client.luau | feeding_survival.luau, growth.luau, idle.luau, inspect.luau, look.luau | over 800 lines |
| `roblox_port/src/Shared/Rig/TarantulaPose.luau` | 168 | Shared | The tarantulas' threat display and silk mat as a pose (ROBLOX-82): pure and Vector3-free, display only. Nothing here moves the body, the | SpiderClient.client.luau | look.luau, tarantula.luau |  |
| `roblox_port/src/Shared/UI/AntMimicText.luau` | 35 | Shared | The words of the ant-mimicking spider's display key for the screen (ROBLOX-64): the prompt, the status line, the touch button and the | SpiderClient.client.luau, PeacockText.luau | antmimic.luau |  |
| `roblox_port/src/Shared/UI/BirdText.luau` | 23 | Shared | The robin in words (ROBLOX-120; the robin is Predator/Bird): its death card, the notice when its bill misses (the gentle rules), and the captions of what tells of it | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/UI/CatText.luau` | 24 | Shared | The ranger's cat in words (ROBLOX-118; the cat is Predator/Cat): its death card, the notice when its pat only knocks the spider aside (the gentle rules), and the | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/UI/ContextPrompts.luau` | 36 | Shared | Only the player-requested meal and dusk prompts enter the minimal play HUD. | SpiderClient.client.luau | feeding_survival.luau |  |
| `roblox_port/src/Shared/UI/ControlText.luau` | 268 | Shared | Words on the screen, written for the device the player is using now: keyboard and mouse, a controller, or touch. | NotebookPanel.luau, SettingsPanel.luau, SpiderClient.client.luau, SpiderEyes.luau, AntMimicText.luau, ContextPrompts.luau, InspectText.luau, LifeText.luau, MateText.luau, NotebookText.luau, PeacockText.luau, SettingsText.luau, TarantulaText.luau, TitleText.luau, WaspText.luau | antmimic.luau, client_mating.luau, eyes.luau, feeding_survival.luau, growth.luau, inspect.luau, lock.luau, notebook.luau, peacock.luau, run.luau, settings.luau, tarantula.luau, title.luau |  |
| `roblox_port/src/Shared/UI/CrabText.luau` | 11 | Shared | The crab spider in words (ROBLOX-119; the crab spider is Predator/CrabSpider): its death card and the notice when its lunge only knocks the spider off the flower (the | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/UI/EyeOptics.luau` | 328 | Shared | EyeOptics: the pure half of the spider-eye picture (ROBLOX-20). From k (how much the principal eyes are in use, 0 to 1) and the | SpiderEyes.luau | eyes.luau |  |
| `roblox_port/src/Shared/UI/FrogText.luau` | 11 | Shared | The green frog in words (ROBLOX-122; the frog is Predator/Frog): its death card and the notice when its tongue misses (the gentle rules). Pure: tests/preserve.luau | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/UI/Heard.luau` | 19 | Shared | What the player can hear or see of something that is not at the spider (ROBLOX-92): a creature on the sill is told of (a notice, a caption, a status line) only to a spider | SpiderClient.client.luau, WaspText.luau | client_mating.luau |  |
| `roblox_port/src/Shared/UI/HudLayout.luau` | 154 | Shared | Where the on-screen controls and the prompt panel go, in the safe area (ScreenInsets.CoreUISafeInsets: clear of notches, | SpiderClient.client.luau, SpiderHud.luau, SpiderInput.luau | lock.luau, notebook.luau, peacock.luau, run.luau, settings.luau |  |
| `roblox_port/src/Shared/UI/InspectText.luau` | 47 | Shared | The words of Inspect mode (ROBLOX-90): the Settings row's button (its label and note are in Data/SettingsSpec), the refusal, the name line on entering it, the name line and the controls line | SpiderClient.client.luau, SettingsModel.luau | inspect.luau, settings.luau |  |
| `roblox_port/src/Shared/UI/LifeText.luau` | 267 | Shared | The words of the life clock and the retreat for the screen (ROBLOX-24), from Godot's habitat_loop.gd caption(): the day and | SpiderClient.client.luau, SpiderHud.luau, ContextPrompts.luau | checkpoint.luau, client_mating.luau, garden_life.luau, growth.luau, life.luau, nature.luau, nature_client.luau, peacock.luau, preserve.luau, quiet.luau |  |
| `roblox_port/src/Shared/UI/MateText.luau` | 186 | Shared | The words of the mating cycle for the screen (ROBLOX-80): the notices for each beat Life/Mating reports, the status line while courting and while | SpiderClient.client.luau, LifeText.luau | client_mating.luau, mating.luau, nature.luau, preserve.luau, quiet.luau |  |
| `roblox_port/src/Shared/UI/NotebookText.luau` | 145 | Shared | The notebook's words and its layout rules for the screen (ROBLOX-37), from Godot's notebook_panel.gd: the heading, the empty | NotebookPanel.luau, SpiderClient.client.luau, SettingsText.luau | antmimic.luau, notebook.luau |  |
| `roblox_port/src/Shared/UI/PeacockText.luau` | 97 | Shared | The words of the peacock spider for the screen (ROBLOX-31): choosing the spider in the crack, the dance's prompts and status | SpiderClient.client.luau, InspectText.luau, SettingsModel.luau | antmimic.luau, client_mating.luau, inspect.luau, lock.luau, peacock.luau, settings.luau, tarantula.luau |  |
| `roblox_port/src/Shared/UI/PerceptionShapes.luau` | 101 | Shared | PerceptionShapes: the geometry the perception HUD draws with (ROBLOX-20, the drawer's polish), pure. A last-seen ring is 12 short | PerceptionHud.luau | hud.luau, lock.luau |  |
| `roblox_port/src/Shared/UI/PerceptionText.luau` | 10 | Shared | Frozen perception_text.gd: words belong to presentation, never the sensor. | PerceptionHud.luau, PerceptionView.luau | perception_view.luau |  |
| `roblox_port/src/Shared/UI/PerceptionView.luau` | 43 | Shared | Pure build_view from perception_hud.gd. Only memory and a camera adapter enter; never world actors. | PerceptionHud.luau | hud.luau |  |
| `roblox_port/src/Shared/UI/PreyText.luau` | 41 | Shared | What the screen says when a prey gets out of the jaws by its own trick (ROBLOX-101, Prey/PreyKinds.grip, kept by Prey/PreyWorld as `event`): a moth whose | SpiderClient.client.luau | garden_life.luau, preserve.luau |  |
| `roblox_port/src/Shared/UI/QuietHud.luau` | 190 | Shared | The quiet HUD (ROBLOX-113, W5 of docs/OPEN_WORLD_DESIGN.md): what the screen may say in Normal. Nathan: "minimal HUD", "no hand holding", "Normal mode should feel | PerceptionHud.luau, SpiderClient.client.luau | quiet.luau |  |
| `roblox_port/src/Shared/UI/RivalText.luau` | 45 | Shared | The words of the brown rival's contest for the screen (ROBLOX-73): what the spider's strike did to a rival that had seen it coming. The | SpiderClient.client.luau | client_rival.luau, growth.luau, quiet.luau, rival.luau |  |
| `roblox_port/src/Shared/UI/SaveText.luau` | 94 | Shared | The words about saving (ROBLOX-39): what the menu and a short toast say. Plain and honest: saved, saving, or off for this visit and why. | SpiderClient.client.luau | save_notice.luau, state_client.luau, state_offline.luau |  |
| `roblox_port/src/Shared/UI/SettingsModel.luau` | 270 | Shared | The settings as logic (ROBLOX-49): looking one up, cleaning a value, stepping it, saying it in words, putting everything back to the | SettingsPanel.luau, SpiderClient.client.luau, SpiderEyes.luau, SaveProgress.luau, SettingsNav.luau | minimal_hud.luau, settings.luau, state.luau |  |
| `roblox_port/src/Shared/UI/SettingsNav.luau` | 105 | Shared | Moving about the settings panel without a mouse (ROBLOX-49): the rows in order (a header per section, the settings, then Reset and Back) | SettingsPanel.luau | settings.luau |  |
| `roblox_port/src/Shared/UI/SettingsText.luau` | 119 | Shared | The settings panel's words for the device in use, and its layout rules for the screen (ROBLOX-49): sizes by kind, how a row is laid out | SettingsPanel.luau | settings.luau |  |
| `roblox_port/src/Shared/UI/TarantulaText.luau` | 36 | Shared | The words of the tarantulas' display key for the screen (ROBLOX-82): the prompt, the status line, the touch button and the controls card's | SpiderClient.client.luau, NotebookText.luau, PeacockText.luau | notebook.luau, tarantula.luau |  |
| `roblox_port/src/Shared/UI/TitleText.luau` | 72 | Shared | The words and the typeface of the first minute (ROBLOX-109): the splash while the world streams in (First/SplashScreen), the title card the start | CaughtPanel.luau, SpiderClient.client.luau, TitleCard.luau | title.luau |  |
| `roblox_port/src/Shared/UI/WaspText.luau` | 128 | Shared | The words of the wasp's visit for the screen (ROBLOX-26): the sound captions, the status line while it visits and the plain screen | CaughtPanel.luau, SpiderClient.client.luau | quiet.luau, wasp.luau |  |
| `roblox_port/src/Shared/UI/WaterText.luau` | 13 | Shared | The water in words (ROBLOX-122; the water is Life/Water): the caption while the spider struggles at the surface, its death card, and the notices when it gets out | SpiderClient.client.luau | preserve.luau |  |
| `roblox_port/src/Shared/World/AntForage.luau` | 35 | Shared | Clock-derived ambient workers. The carried fragments are presentation, not | LivingWorld.luau, LivedInSites.luau | living_world.luau |  |
| `roblox_port/src/Shared/World/DogGround.luau` | 42 | Shared | Cosmetic dog's ground LOD: an index of the same authored physical boxes the | LivingWorld.luau | living_world.luau |  |
| `roblox_port/src/Shared/World/Environment.luau` | 144 | Shared | Habitat weather is reconstructed from the saved life clock, not rerolled on load. | LivingWorld.luau, RareDirector.luau, AntForage.luau, DogGround.luau, Verge.luau | dog_gait.luau, living_world.luau, rare_sightings.luau |  |
| `roblox_port/src/Shared/World/Garden.luau` | 2720 | Shared | The world outside the glass (ROBLOX-95, docs/OPEN_WORLD_DESIGN.md W2): the generators of the three regions under the window, as pure data. Region asks here for every | SelfTest.luau, Checkpoint.luau, Ladybird.luau, PreyKinds.luau, PreyWorld.luau, LookPlan.luau, Region.luau | checkpoint.luau, foundation.luau, garden_life.luau, living_world.luau, preserve.luau, verge_litter.luau, world.luau, worldmap.luau | over 800 lines |
| `roblox_port/src/Shared/World/GardenPocket.luau` | 95 | Shared | A one-metre habitat directly below the window. Juvenile plants retain adult | Garden.luau, LivedInSites.luau | living_world.luau |  |
| `roblox_port/src/Shared/World/Hut.luau` | 2848 | Shared | The ranger hut and its garden, walkable (ROBLOX-116, docs/PARK_WORLD_DESIGN.md Phase B round 1): the preserve's first home ranges at full spider detail. Pure | HutLife.luau, LivingWorld.luau, Mate.luau, Garden.luau, GardenPocket.luau, Meadow.luau, Pond.luau, Region.luau, StationAir.luau, WorldMap.luau | compact_layout.luau, living_world.luau, preserve.luau, rivalnav.luau, station_debug.luau | over 800 lines |
| `roblox_port/src/Shared/World/LivedInSites.luau` | 117 | Shared | Additive, stable landmarks. Existing pieces/retreats never move. One stud is one centimetre. | LivingWorld.luau, Region.luau | living_world.luau |  |
| `roblox_port/src/Shared/World/LookPlan.luau` | 264 | Shared | Which regions' drawn looks a client holds, and at what detail, from where the spider is (ROBLOX-108). Pure: a plan is a function of the place, the tier, the | LookStream.luau, SelfTest.luau | preserve.luau, rest_storage.luau, worldmap.luau, world_client.luau |  |
| `roblox_port/src/Shared/World/Meadow.luau` | 1271 | Shared | The meadow's edge and the bench, bin and lamppost, walkable (ROBLOX-119, docs/PARK_WORLD_DESIGN.md Phase C round 1): home ranges 3 and 8 at full spider detail, where | HutLife.luau, SelfTest.luau, CrabSpider.luau, Garden.luau, PreserveLook.luau, Region.luau, WorldMap.luau | compact_layout.luau, preserve.luau, rivalnav.luau, shadows.luau | over 800 lines |
| `roblox_port/src/Shared/World/NavigationPreparation.luau` | 59 | Shared | Owns bounded loading work, before the first simulation tick. Surface and air | SpiderClient.client.luau | navigation_startup.luau |  |
| `roblox_port/src/Shared/World/Pond.luau` | 1305 | Shared | The pond's edge and the boardwalk, walkable (ROBLOX-122, docs/PARK_WORLD_DESIGN.md Phase D round 1): home range 4 at full spider detail where the boardwalk runs | SelfTest.luau, SpiderClient.client.luau, Frog.luau, Garden.luau, PreserveLook.luau, Region.luau, WorldMap.luau | compact_layout.luau, preserve.luau | over 800 lines |
| `roblox_port/src/Shared/World/Preserve.luau` | 150 | Shared | The preserve's map (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4 and 10): a nature preserve of 100 by 60 m in an American city, held between a railway | SelfTest.luau, Ballooning.luau, Hut.luau, Pond.luau, PreserveLook.luau, PreserveTrain.luau, WorldMap.luau | preserve.luau |  |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 1003 | Shared | The preserve's backdrop (ROBLOX-115, docs/PARK_WORLD_DESIGN.md sections 4, 7 and 10): every zone of World/Preserve drawn, and nothing of it walkable. Pure data | Region.luau | living_world.luau, preserve.luau | over 800 lines |
| `roblox_port/src/Shared/World/PreserveTrain.luau` | 98 | Shared | The trains on the railway beyond the preserve's north fence (ROBLOX-115, docs/PARK_WORLD_DESIGN.md: "the railway's vibration", "trains every few minutes"). | TrainPass.luau | preserve.luau |  |
| `roblox_port/src/Shared/World/Region.luau` | 165 | Shared | What a region is made of (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): the generators. Each is pure and deterministic from the region (its kind and its | LookStream.luau, SelfTest.luau, SpiderClient.client.luau, WorldClient.luau, WorldShadows.luau, Main.server.luau, RivalRoute.luau, PreyWorld.luau, DogGround.luau, LookPlan.luau, StationAir.luau, WorldBuild.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, living_world.luau, preserve.luau, rest_storage.luau, rivalnav.luau, shadows.luau, station_debug.luau, station_threats.luau, title.luau, verge_litter.luau, world.luau, worldmap.luau, world_client.luau |  |
| `roblox_port/src/Shared/World/StationAir.luau` | 194 | Shared | Bounded air navigation over the station's actual collision boxes. Grid edges | SpiderClient.client.luau, WaspDirector.luau | navigation_startup.luau, station_threats.luau |  |
| `roblox_port/src/Shared/World/StationTerritory.luau` | 29 | Shared | The inhabited ranger station, excluding its garden and exterior wall/eaves. | SelfTest.luau, WorldClient.luau, RivalDrive.luau, RivalSpider.luau, StationAir.luau, WorldBuild.luau | navigation_startup.luau, route_preparation.luau, station_debug.luau, station_threats.luau |  |
| `roblox_port/src/Shared/World/Verge.luau` | 232 | Shared | Walkable infill around the developed garden and its paths. Existing landmarks win | Garden.luau, Region.luau, WorldMap.luau | compact_layout.luau, living_world.luau, verge_litter.luau |  |
| `roblox_port/src/Shared/World/WorldBuild.luau` | 86 | Shared | Builds the physical world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): every region of the map, each as a folder of anchored boxes, all under one `World` folder in the | Main.server.luau | checkpoint.luau, compact_layout.luau, garden_life.luau, living_world.luau, minimal_hud.luau, nature_client.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, rare_sightings.luau, rest_storage.luau, route_preparation.luau, save_notice.luau, scenarios.luau, selftest.luau, selftest_preserve.luau, shadows.luau, spawn_clearance.luau, station_debug.luau, station_threats.luau, verge_litter.luau, world.luau, world_client.luau |  |
| `roblox_port/src/Shared/World/WorldMap.luau` | 529 | Shared | The map of the world (ROBLOX-94, docs/OPEN_WORLD_DESIGN.md): what regions there are, where each one is, where a life begins in it, where | LookStream.luau, MateStage.luau, SelfTest.luau, SpiderClient.client.luau, WorldClient.luau, Main.server.luau, WorldFocus.luau, Water.luau, Checkpoint.luau, CompactMigration.luau, CrabSpider.luau, Frog.luau, Mate.luau, RivalDrive.luau, RivalRoute.luau, RivalSpider.luau, Garden.luau, LookPlan.luau, Region.luau, StationAir.luau, StationTerritory.luau, WorldBuild.luau | checkpoint.luau, compact_layout.luau, foundation.luau, garden_life.luau, living_world.luau, minimal_hud.luau, nature.luau, nature_client.luau, navigation_startup.luau, outdoor_life_reset.luau, preserve.luau, rare_sightings.luau, rest_storage.luau, rivalnav.luau, route_preparation.luau, save_notice.luau, scenarios.luau, selftest.luau, selftest_preserve.luau, shadows.luau, spawn_clearance.luau, station_debug.luau, station_threats.luau, title.luau, verge_litter.luau, world.luau, worldmap.luau, world_client.luau |  |
| `roblox_port/src/Shared/World/Worlds.luau` | 51 | Shared | The worlds the engine can run (ROBLOX-115, docs/PARK_WORLD_DESIGN.md). One engine, two worlds: | WorldClient.luau, Main.server.luau, WorldMap.luau | preserve.luau |  |

## Dependency cycles

No cycles found in the lexical graph. This is not proof for dynamic requires.

## Runtime call-site inventory

Each line below is a call site, not an assertion that it runs each frame. Inspect the surrounding function and its callers before changing frequency.

| Source | Line | Call site |
|---|---:|---|
| `roblox_port/src/Client/BirdBody.luau` | 104 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/BirdBody.luau` | 118 | `local s = Instance.new("Sound")` |
| `roblox_port/src/Client/BirdBody.luau` | 132 | `local model = Instance.new("Folder")` |
| `roblox_port/src/Client/BugBodies.luau` | 367 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/BugBodies.luau` | 387 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/BugBodies.luau` | 516 | `while s < target do` |
| `roblox_port/src/Client/CatBody.luau` | 22 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/CatBody.luau` | 52 | `local s = Instance.new("Sound")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 29 | `local l=Instance.new("TextLabel")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 37 | `local gui=Instance.new("ScreenGui")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 40 | `local dim=Instance.new("Frame")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 44 | `local shade=Instance.new("UIGradient")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 48 | `local box=Instance.new("ScrollingFrame")` |
| `roblox_port/src/Client/CaughtPanel.luau` | 52 | `local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(880,10000);constraint.Parent=box` |
| `roblox_port/src/Client/CaughtPanel.luau` | 53 | `local list=Instance.new("UIListLayout");list.HorizontalAlignment=Enum.HorizontalAlignment.Center` |
| `roblox_port/src/Client/CaughtPanel.luau` | 102 | `local b=Instance.new("TextButton");b.Name=c.id;b.Text=c.text` |
| `roblox_port/src/Client/CaughtPanel.luau` | 109 | `local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,if titleLook then 6 else 4);round.Parent=b` |
| `roblox_port/src/Client/CrabBody.luau` | 65 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/CrabBody.luau` | 72 | `local model = Instance.new("Folder")` |
| `roblox_port/src/Client/FlyBodies.luau` | 346 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/FlyBodies.luau` | 370 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/HutLife.luau` | 40 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/HutLife.luau` | 63 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/HutLife.luau` | 69 | `moment = nil :: number?, -- when the ranger's moment began (the clock's), while it runs` |
| `roblox_port/src/Client/HutLife.luau` | 74 | `local holder = Instance.new("Part")` |
| `roblox_port/src/Client/HutLife.luau` | 83 | `local light = Instance.new("PointLight")` |
| `roblox_port/src/Client/HutLife.luau` | 94 | `local street = Instance.new("Part")` |
| `roblox_port/src/Client/HutLife.luau` | 103 | `local sl = Instance.new("PointLight")` |
| `roblox_port/src/Client/LivingWorld.luau` | 32 | `local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh` |
| `roblox_port/src/Client/LookStream.luau` | 44 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/LookStream.luau` | 170 | `local f = Instance.new("Folder")` |
| `roblox_port/src/Client/LookStream.luau` | 187 | `while i <= #self.jobs do` |
| `roblox_port/src/Client/LookStream.luau` | 209 | `local model = Instance.new("Model")` |
| `roblox_port/src/Client/MateStage.luau` | 30 | `MateStage.LIFT_HEIGHT = 2.4 -- how far a spiderling rises while it is seen` |
| `roblox_port/src/Client/MateStage.luau` | 67 | `wx = (g:next() - 0.5) * 0.9, wz = (g:next() - 0.5) * 0.9, -- the drift of the air while it rises` |
| `roblox_port/src/Client/MateStage.luau` | 133 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/MateStage.luau` | 144 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/MateStage.luau` | 158 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/MealPresentation.luau` | 6 | `local folder=Instance.new("Folder");folder.Name="MealRemains";folder.Parent=parent` |
| `roblox_port/src/Client/MealPresentation.luau` | 22 | `local model=Instance.new("Model");model.Name="EmptyHusk";model.Parent=self.folder` |
| `roblox_port/src/Client/MealPresentation.luau` | 23 | `local p=Instance.new("Part");p.Name="DryBody";p.Shape=Enum.PartType.Ball` |
| `roblox_port/src/Client/MealPresentation.luau` | 28 | `local w=Instance.new("Part");w.Anchored=true;w.CanCollide=false;w.CanQuery=false;w.CanTouch=false;w.CastShadow=false;w.Color=p.Color;w.Material=p.Material;w.Name="EmptyWing";w.Size=Vector3.new(.1,.01,.17);w.Transparency=.65;w.Parent=model` |
| `roblox_port/src/Client/NotebookArt.luau` | 6 | `local p=Instance.new("Frame");p.Name="Ink";p.BorderSizePixel=0;p.BackgroundColor3=colour` |
| `roblox_port/src/Client/NotebookArt.luau` | 8 | `if round then local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=p end` |
| `roblox_port/src/Client/NotebookArt.luau` | 12 | `local centre=Instance.new("Frame");centre.Name="Sketch";centre.BackgroundTransparency=1` |
| `roblox_port/src/Client/NotebookPanel.luau` | 45 | `local l = Instance.new("TextLabel")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 61 | `local f = Instance.new("ScrollingFrame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 70 | `local list = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 79 | `local b = Instance.new("TextButton")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 88 | `local corner = Instance.new("UICorner")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 96 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 103 | `local dim = Instance.new("Frame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 111 | `local paper = Instance.new("Frame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 119 | `local corner = Instance.new("UICorner")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 122 | `local stroke = Instance.new("UIStroke")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 126 | `local limit = Instance.new("UISizeConstraint")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 129 | `local inner = Instance.new("Frame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 135 | `local heading = Instance.new("TextLabel")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 143 | `local body = Instance.new("Frame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 161 | `local footer = Instance.new("Frame")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 166 | `local controls = Instance.new("TextLabel")` |
| `roblox_port/src/Client/NotebookPanel.luau` | 276 | `local pad = Instance.new("UIPadding")` |
| `roblox_port/src/Client/OldSkins.luau` | 6 | `local folder=Instance.new("Folder");folder.Name="OldSkins";folder.Parent=parent` |
| `roblox_port/src/Client/OldSkins.luau` | 22 | `local part=Instance.new("Part");part.Name=name;part.Size=size;part.CFrame=cf` |
| `roblox_port/src/Client/OldSkins.luau` | 29 | `local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=shell` |
| `roblox_port/src/Client/PerceptionHud.luau` | 24 | `local c = Instance.new("UICorner")` |
| `roblox_port/src/Client/PerceptionHud.luau` | 30 | `local s = Instance.new("UIStroke")` |
| `roblox_port/src/Client/PerceptionHud.luau` | 38 | `local f = Instance.new("Frame")` |
| `roblox_port/src/Client/PerceptionHud.luau` | 72 | `local l = Instance.new("TextLabel")` |
| `roblox_port/src/Client/PerceptionHud.luau` | 87 | `local pad = Instance.new("UIPadding")` |
| `roblox_port/src/Client/PerceptionHud.luau` | 97 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/PerceptionStage.luau` | 7 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/PerceptionStage.luau` | 11 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/PerceptionStage.luau` | 24 | `local sign = Instance.new("BillboardGui")` |
| `roblox_port/src/Client/PerceptionStage.luau` | 28 | `local label = Instance.new("TextLabel")` |
| `roblox_port/src/Client/PondBodies.luau` | 95 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/PondBodies.luau` | 102 | `local model = Instance.new("Folder")` |
| `roblox_port/src/Client/RareBody.luau` | 22 | `local model=Instance.new("Folder");model.Name="RareLuna";model.Parent=Workspace;self.model=model` |
| `roblox_port/src/Client/RareBody.luau` | 23 | `local supports=Instance.new("Folder");supports.Name="RareLunaSupport";supports.Parent=self.root;self.supports=supports` |
| `roblox_port/src/Client/RareBody.luau` | 38 | `local p=Instance.new("Part");p.Name="LunaWing"..sign;p.Anchored=true` |
| `roblox_port/src/Client/SaveClient.luau` | 75 | `local ev = remotes.client.OnClientEvent` |
| `roblox_port/src/Client/SaveClient.luau` | 136 | `self.remotes.server:FireServer({ kind = "hello", v = rules.PROTOCOL })` |
| `roblox_port/src/Client/SaveClient.luau` | 144 | `self.remotes.server:FireServer({ kind = "progress", progress = payload })` |
| `roblox_port/src/Client/SaveClient.luau` | 151 | `self.remotes.server:FireServer({kind="begin_life",mode=mode,serial=request.serial})` |
| `roblox_port/src/Client/SaveClient.luau` | 162 | `self.remotes.server:FireServer({ kind = "rest", mode = mode, record = record, life = self.lifeTokens[mode] })` |
| `roblox_port/src/Client/SelfTest.luau` | 146 | `while not cond() do` |
| `roblox_port/src/Client/SelfTest.luau` | 206 | `while #out > 5 do table.remove(out) end` |
| `roblox_port/src/Client/SelfTest.luau` | 228 | `local conn = RunService.RenderStepped:Connect(function(dt: number) table.insert(dts, dt) end)` |
| `roblox_port/src/Client/SelfTest.luau` | 443 | `while r.host.clock() < deadline do` |
| `roblox_port/src/Client/SelfTest.luau` | 473 | `if prof ~= nil then prof.start() end -- (and the frame by part while it lets down: the looks are planned again as it goes down)` |
| `roblox_port/src/Client/SelfTest.luau` | 476 | `while r.host.clock() < deadline do` |
| `roblox_port/src/Client/SelfTest.luau` | 600 | `while r.host.clock() < (r.bedAt :: number) + 2.0 do` |
| `roblox_port/src/Client/SelfTest.luau` | 659 | `say(r, string.format("INFO looks while settled: %d plans and %d parts made in the sample", looks.plans - plans0, looks.made - made0))` |
| `roblox_port/src/Client/SelfTest.luau` | 776 | `while train.schedule.pass(k).finish < now and k < 50 do k += 1 end` |
| `roblox_port/src/Client/SelfTest.luau` | 1355 | `need(not life.lifeOver, "the robin took the spider while it was held off")` |
| `roblox_port/src/Client/SelfTest.luau` | 1688 | `local probe=Instance.new("Part");probe.Anchored=true;probe.CanCollide=false;probe.CanQuery=false;probe.CanTouch=false` |
| `roblox_port/src/Client/SettingsPanel.luau` | 59 | `local c = Instance.new("UICorner")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 65 | `local l: any = Instance.new(class)` |
| `roblox_port/src/Client/SettingsPanel.luau` | 79 | `local b = Instance.new("TextButton")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 101 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 108 | `local dim = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 116 | `local paper = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 125 | `local limit = Instance.new("UISizeConstraint")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 128 | `local inner = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 136 | `local list = Instance.new("ScrollingFrame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 145 | `local layout = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 153 | `local footer = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 209 | `local frame = Instance.new("TextButton")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 219 | `local stroke = Instance.new("UIStroke")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 247 | `local bar = Instance.new("Frame") -- the hit area: as tall as a button, so a finger finds it` |
| `roblox_port/src/Client/SettingsPanel.luau` | 252 | `local track = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 260 | `local fill = Instance.new("Frame")` |
| `roblox_port/src/Client/SettingsPanel.luau` | 687 | `while self.repeatT >= SettingsText.REPEAT_RATE do` |
| `roblox_port/src/Client/Soundscape.luau` | 36 | `local s = Instance.new("Sound")` |
| `roblox_port/src/Client/Soundscape.luau` | 52 | `task.spawn(function()` |
| `roblox_port/src/Client/Soundscape.luau` | 64 | `local root = Instance.new("Folder")` |
| `roblox_port/src/Client/Soundscape.luau` | 67 | `local emitter = Instance.new("Part")` |
| `roblox_port/src/Client/Soundscape.luau` | 145 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderCamera.luau` | 243 | `while lengths[#lengths] < comfort and offset < roomDown - 1e-6 do` |
| `roblox_port/src/Client/SpiderCamera.luau` | 249 | `while lengths[#lengths] < comfort and offset < roomUp - 1e-6 do` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 190 | `local arc = Instance.new("Folder")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 240 | `task.spawn(function()` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 388 | `local lines = Instance.new("Folder")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 401 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 445 | `local d = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 452 | `local patch = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 456 | `local ring = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 460 | `local cross = Instance.new("Part")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 878 | `local lastEnd: any=nil -- the summary of the life that just ended, while its end screen is up` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1163 | `local menuButton=Instance.new("TextButton")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1197 | `local notebookButton=Instance.new("TextButton")` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1698 | `restPrompt={title="Moulting in the silk-lined crack",hint="The spider pulls free of its old skin. Wait here while the hours pass."}` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1748 | `do -- the Lock button (ROBLOX-110): only while something can be locked, or a lock holds` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1780 | `RunService:BindToRenderStep("SpiderSim", Enum.RenderPriority.Camera.Value + 1, function(frameDt: number)` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 1819 | `while accumulator >= DT do` |
| `roblox_port/src/Client/SpiderClient.client.luau` | 2413 | `task.spawn(function()` |
| `roblox_port/src/Client/SpiderEyes.luau` | 52 | `local f = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 64 | `local c = Instance.new("UICorner")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 70 | `local s = Instance.new("UIStroke")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 80 | `local g = Instance.new("UIGradient")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 100 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 131 | `local grade = Instance.new("ColorCorrectionEffect")` |
| `roblox_port/src/Client/SpiderEyes.luau` | 135 | `local blur = Instance.new("BlurEffect")` |
| `roblox_port/src/Client/SpiderHud.luau` | 31 | `local c = Instance.new("UICorner")` |
| `roblox_port/src/Client/SpiderHud.luau` | 37 | `local p = Instance.new("UIPadding")` |
| `roblox_port/src/Client/SpiderHud.luau` | 45 | `local l = Instance.new("TextLabel")` |
| `roblox_port/src/Client/SpiderHud.luau` | 68 | `local l = Instance.new("TextLabel")` |
| `roblox_port/src/Client/SpiderHud.luau` | 89 | `local f = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 96 | `local list = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/SpiderHud.luau` | 103 | `local limit = Instance.new("UISizeConstraint")` |
| `roblox_port/src/Client/SpiderHud.luau` | 112 | `local centre = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/SpiderHud.luau` | 118 | `local reticle = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 126 | `local stroke = Instance.new("UIStroke")` |
| `roblox_port/src/Client/SpiderHud.luau` | 133 | `local t = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 143 | `local aimBox = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 150 | `local aimList = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/SpiderHud.luau` | 161 | `local safe = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/SpiderHud.luau` | 170 | `local food = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 179 | `local foodText = Instance.new("TextLabel")` |
| `roblox_port/src/Client/SpiderHud.luau` | 190 | `local track = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 200 | `local foodFill = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 207 | `local grip = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 209 | `local gripFill=Instance.new("Frame");gripFill.Name="Grip";gripFill.Size=UDim2.fromScale(.4,1);gripFill.BackgroundColor3=Color3.fromRGB(245,35,38);gripFill.BorderSizePixel=0;gripFill.Parent=grip` |
| `roblox_port/src/Client/SpiderHud.luau` | 211 | `local court = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 213 | `local courtFill=Instance.new("Frame");courtFill.Name="Courtship";courtFill.Size=UDim2.fromScale(0,1);courtFill.BackgroundColor3=Color3.fromRGB(226,128,164);courtFill.BorderSizePixel=0;courtFill.Parent=court` |
| `roblox_port/src/Client/SpiderHud.luau` | 226 | `local dayBox = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 232 | `local dayList = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/SpiderHud.luau` | 245 | `local panel = Instance.new("Frame")` |
| `roblox_port/src/Client/SpiderHud.luau` | 250 | `local plist = Instance.new("UIListLayout")` |
| `roblox_port/src/Client/SpiderInput.luau` | 144 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/SpiderInput.luau` | 163 | `local b = Instance.new("TextButton")` |
| `roblox_port/src/Client/SpiderInput.luau` | 176 | `local corner = Instance.new("UICorner")` |
| `roblox_port/src/Client/StationMouseBody.luau` | 8 | `local folder=Instance.new("Folder");folder.Name="StationMouse";folder.Parent=parent` |
| `roblox_port/src/Client/TitleCard.luau` | 47 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/Client/TitleCard.luau` | 54 | `local veil = Instance.new("Frame")` |
| `roblox_port/src/Client/TitleCard.luau` | 61 | `local caption = Instance.new("TextLabel")` |
| `roblox_port/src/Client/TitleCard.luau` | 75 | `local limit = Instance.new("UISizeConstraint")` |
| `roblox_port/src/Client/TitleCard.luau` | 78 | `local skip = Instance.new("TextLabel")` |
| `roblox_port/src/Client/TitleCard.luau` | 91 | `local tap = Instance.new("TextButton")` |
| `roblox_port/src/Client/TrainPass.luau` | 28 | `local p = Instance.new("Part")` |
| `roblox_port/src/Client/TrainPass.luau` | 45 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/TrainPass.luau` | 51 | `local f = Instance.new("Folder")` |
| `roblox_port/src/Client/TrainPass.luau` | 60 | `local s = Instance.new("Sound")` |
| `roblox_port/src/Client/WaspBody.luau` | 83 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Client/WorldClient.luau` | 84 | `while not Worlds.known(named) and os.clock() < deadline and t ~= nil do` |
| `roblox_port/src/Client/WorldClient.luau` | 198 | `if remote == nil or not remote:IsA("RemoteEvent") then return false end` |
| `roblox_port/src/Client/WorldClient.luau` | 199 | `(remote :: RemoteEvent):FireServer(pos)` |
| `roblox_port/src/Client/WorldShadows.luau` | 137 | `while i <= #entries do` |
| `roblox_port/src/First/SplashScreen.luau` | 84 | `frame = function(): number return (game:GetService("RunService") :: any).RenderStepped:Wait() end,` |
| `roblox_port/src/First/SplashScreen.luau` | 101 | `local l = Instance.new("TextLabel")` |
| `roblox_port/src/First/SplashScreen.luau` | 114 | `local gui = Instance.new("ScreenGui")` |
| `roblox_port/src/First/SplashScreen.luau` | 120 | `local veil = Instance.new("Frame")` |
| `roblox_port/src/First/SplashScreen.luau` | 133 | `local dot = Instance.new("Frame")` |
| `roblox_port/src/First/SplashScreen.luau` | 142 | `local round = Instance.new("UICorner")` |
| `roblox_port/src/First/SplashScreen.luau` | 203 | `while s.phase ~= "done" do` |
| `roblox_port/src/Server/DataStoreBackend.luau` | 16 | `local ok, value = pcall(function(): any return self.ds:GetAsync(key) end)` |
| `roblox_port/src/Server/DataStoreBackend.luau` | 31 | `local result = self.ds:UpdateAsync(key, function(stored: any): any` |
| `roblox_port/src/Server/Main.server.luau` | 67 | `local foci = Instance.new("Folder")` |
| `roblox_port/src/Server/Persistence.server.luau` | 29 | `local dataStore=game:GetService("DataStoreService"):GetDataStore(storeName)` |
| `roblox_port/src/Server/Persistence.server.luau` | 44 | `local folder = Instance.new("Folder")` |
| `roblox_port/src/Server/Persistence.server.luau` | 46 | `local toServer = Instance.new("RemoteEvent")` |
| `roblox_port/src/Server/Persistence.server.luau` | 49 | `local toClient = Instance.new("RemoteEvent")` |
| `roblox_port/src/Server/Persistence.server.luau` | 59 | `sleep = function(seconds: number) task.wait(seconds) end,` |
| `roblox_port/src/Server/Persistence.server.luau` | 60 | `spawn = function(fn: (...any) -> ...any, ...: any) task.spawn(fn, ...) end,` |
| `roblox_port/src/Server/Persistence.server.luau` | 61 | `send = function(player: SaveService.Player, msg: { [string]: any }) toClient:FireClient(player :: any, msg) end,` |
| `roblox_port/src/Server/Persistence.server.luau` | 67 | `toServer.OnServerEvent:Connect(function(player: Player, msg: any)` |
| `roblox_port/src/Server/Persistence.server.luau` | 82 | `task.spawn(function()` |
| `roblox_port/src/Server/Persistence.server.luau` | 83 | `while true do` |
| `roblox_port/src/Server/Persistence.server.luau` | 84 | `task.wait(1)` |
| `roblox_port/src/Server/SaveService.luau` | 204 | `while (pending > 0 or self.departing > 0) and self.cfg.now() < deadline do` |
| `roblox_port/src/Server/WorldFocus.luau` | 31 | `local part = Instance.new("Part")` |
| `roblox_port/src/Server/WorldFocus.luau` | 87 | `function WorldFocus.listen(storage: Instance, parent: Instance): RemoteEvent` |
| `roblox_port/src/Server/WorldFocus.luau` | 89 | `if remote == nil or not remote:IsA("RemoteEvent") then` |
| `roblox_port/src/Server/WorldFocus.luau` | 90 | `local made = Instance.new("RemoteEvent")` |
| `roblox_port/src/Server/WorldFocus.luau` | 95 | `local event = remote :: RemoteEvent` |
| `roblox_port/src/Server/WorldFocus.luau` | 96 | `event.OnServerEvent:Connect(function(player: Player, at: any)` |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 287 | `game = "Your spider is pale and its jumps shorter while its skin hardens. The ten game-hour timing is a design choice. The empty skin stays in the crack.",` |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 288 | `godotGame = "Your spider is paler and its jumps shorter while the new skin hardens. How long that takes for a jumping spider has not been measured; the game's timing is a guess. Look for the old skin in the crack.",` |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 433 | `text = "Leafhoppers (Cicadellidae) are small wedge-shaped bugs, a few millimetres long and often green, with the wings held like a tent over the back. They suck sap from leaves. Young and adults walk with a sideways sidestep; disturbed, the young often walk round to the other side of the stem or lea` |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 503 | `text = "Harvestmen, or daddy longlegs, are not spiders but opilionids. The body is one simple oval, head and abdomen fused, with only two eyes and no silk or venom glands. Disturbed, they give off a foul odour. A leg falls off easily and goes on twitching, which can distract a predator while the har` |
| `roblox_port/src/Shared/Data/NotebookPages.luau` | 525 | `text = "A house cat stands 23 to 25 cm at the shoulder and weighs 4 to 5 kg. It hunts small mammals and birds first, and invertebrates last. Free-ranging cats kill an estimated 1.3 to 4.0 billion birds and 6.3 to 22.3 billion mammals a year in the United States. A bell on the collar warns prey: in o` |
| `roblox_port/src/Shared/Data/SettingsSpec.luau` | 56 | `note = "The view may turn to show the line while the spider hangs on it." },` |
| `roblox_port/src/Shared/Data/SettingsSpec.luau` | 80 | `note = "Change it anywhere you stand safely. Not while jumping, on silk, moulting or holding prey." },` |
| `roblox_port/src/Shared/Data/SettingsSpec.luau` | 83 | `note = "A slow, close look from every side. Only while you stand safely. Cancel leaves." },` |
| `roblox_port/src/Shared/Data/Wasp.luau` | 73 | `Wasp.scanDegS = 70.0 -- how fast it turns while it hovers` |
| `roblox_port/src/Shared/Habitat/Lit.luau` | 28 | `local made = Instance.new(className)` |
| `roblox_port/src/Shared/Habitat/Patina.luau` | 22 | `while x < L.x1 do` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 31 | `local f = Instance.new("Folder")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 39 | `local p = Instance.new("Part")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 88 | `local p = Instance.new("Part")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 115 | `local sill = Instance.new("Folder")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 164 | `local mesh = Instance.new("SpecialMesh")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 168 | `local mesh = Instance.new("SpecialMesh")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 263 | `local motes = Instance.new("ParticleEmitter")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 340 | `local mesh = Instance.new("SpecialMesh")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 450 | `local a0 = Instance.new("Attachment")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 453 | `local a1 = Instance.new("Attachment")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 458 | `local beam = Instance.new("Beam")` |
| `roblox_port/src/Shared/Habitat/Scenery.luau` | 503 | `local decor = Instance.new("Model")` |
| `roblox_port/src/Shared/Habitat/Shapes.luau` | 26 | `local p = Instance.new("Part")` |
| `roblox_port/src/Shared/Habitat/Shapes.luau` | 46 | `local mesh = Instance.new("SpecialMesh")` |
| `roblox_port/src/Shared/Habitat/Shapes.luau` | 130 | `local f = Instance.new("Folder")` |
| `roblox_port/src/Shared/Learning/FieldNotebook.luau` | 97 | `while #list > FieldNotebook.MAX_ENTRIES do table.remove(list, 1) end` |
| `roblox_port/src/Shared/Life/LifeClock.luau` | 77 | `while self.hour >= 24.0 do` |
| `roblox_port/src/Shared/Life/LifeSession.luau` | 31 | `while #self.lives > 30 do table.remove(self.lives,1) end` |
| `roblox_port/src/Shared/Life/Mating.luau` | 47 | `guard_day = 0, -- 1 or 2 while the sac is guarded` |
| `roblox_port/src/Shared/Life/Nature.luau` | 29 | `coldSpeed = 0.6, -- the walk's speed while it lasts` |
| `roblox_port/src/Shared/Life/NeedsModel.luau` | 172 | `while total >= NeedsModel.UPDATE_PERIOD_S - 1e-9 do` |
| `roblox_port/src/Shared/Movement/InspectView.luau` | 11 | `InspectView.HOLD_SECONDS = 0.6 -- holding the choose key or button this long (while resting awake in the crack) starts the view` |
| `roblox_port/src/Shared/Movement/LineFraming.luau` | 44 | `while k * step <= maxTurn + 1e-6 do` |
| `roblox_port/src/Shared/Movement/LockOn.luau` | 37 | `holdGain = 2.0, -- the pull back to the kept distance while circling, per WU of error (clamped to a full step)` |
| `roblox_port/src/Shared/Movement/SpiderMotor.luau` | 49 | `local FREE_UP_RATE = math.rad(240) -- the drawn up turns to world up while falling or on the line (Godot VISUAL_TURN)` |
| `roblox_port/src/Shared/Movement/SpiderMotor.luau` | 89 | `local probe = Instance.new("Part")` |
| `roblox_port/src/Shared/Movement/SpiderMotor.luau` | 141 | `transitionSerial = 0, -- counts sharp support turns while walking (concave and convex edges)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 34 | `function MemoryDataStore.GetAsync(self: any, key: string): any` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 54 | `function MemoryDataStore.SetAsync(self: any, key: string, value: any)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 132 | `local ok, existing = try(function() return self.store:GetAsync(k) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 134 | `local wrote = try(function() self.store:SetAsync(k, entry) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 148 | `local wrote, err = try(function() self.store:SetAsync(tmp, entry) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 150 | `local readOk, back = try(function() return self.store:GetAsync(tmp) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 160 | `local curOk, current = try(function() return self.store:GetAsync(main) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 173 | `local moved, merr = try(function() self.store:SetAsync(bak, current) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 179 | `local put, perr = try(function() self.store:SetAsync(main, entry) end)` |
| `roblox_port/src/Shared/Persistence/CheckpointStore.luau` | 190 | `local ok, entry = try(function() return self.store:GetAsync(which[1]) end)` |
| `roblox_port/src/Shared/Persistence/Json.luau` | 133 | `while i0 <= n do` |
| `roblox_port/src/Shared/Persistence/ObjectRecord.luau` | 111 | `while q <= #queue and not problem do` |
| `roblox_port/src/Shared/Persistence/SaveEnvelope.luau` | 84 | `while from < spec.current do` |
| `roblox_port/src/Shared/Persistence/SaveScheduler.luau` | 83 | `else -- changed while it was being written: still dirty, due once the interval has passed` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 230 | `self:demote("other_session",false) -- another life won while ownership was unavailable; never relabel our queued world` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 254 | `self.restLoaded = {} -- read again: another session may have written a rest while this one could not` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 528 | `released = false -- UpdateAsync may invoke this callback more than once` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 659 | `while self.busy and self.now() < limit and sleep do sleep(0.25) end` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 667 | `while attempt < SaveRules.FLUSH_ATTEMPTS and self.state == "active" and self.now() < limit do` |
| `roblox_port/src/Shared/Persistence/SaveSession.luau` | 692 | `while attempt < SaveRules.FLUSH_ATTEMPTS and self.now() < limit do` |
| `roblox_port/src/Shared/Predator/Bird.luau` | 141 | `while t < forage do` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 110 | `while true do` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 125 | `while n ~= nil do` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 187 | `while t < 22.5 do` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 279 | `look = nil :: Vector3?, -- the point its head follows, while it watches something` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 360 | `while h < 0 do h += 24; dd -= 1 end` |
| `roblox_port/src/Shared/Predator/Cat.luau` | 361 | `while h >= 24 do h -= 24; dd += 1 end` |
| `roblox_port/src/Shared/Predator/RivalDrive.luau` | 28 | `while b ~= 0 do a, b = b, a % b end` |
| `roblox_port/src/Shared/Predator/RivalDrive.luau` | 58 | `while gcd(stride, math.max(#waypoints, 1)) ~= 1 do stride += 1 end` |
| `roblox_port/src/Shared/Predator/RivalDrive.luau` | 80 | `while gcd(stride, math.max(#self.waypoints, 1)) ~= 1 do stride += 1 end` |
| `roblox_port/src/Shared/Predator/RivalDrive.luau` | 231 | `while self.hop <= #route do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 357 | `while i > 1 do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 370 | `while true do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 417 | `while #heap > 0 do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 470 | `while stPrev[at] ~= 0 do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 541 | `while #picked < math.min(k, #pool) do` |
| `roblox_port/src/Shared/Predator/RivalRoute.luau` | 759 | `while budget.left > 0 and os.clock() < budget.deadline do` |
| `roblox_port/src/Shared/Predator/WaspDirector.luau` | 470 | `while #self.recent > 3 do table.remove(self.recent, 1) end` |
| `roblox_port/src/Shared/Predator/WaspDirector.luau` | 806 | `while self.pathI <= #path and left > 0.0 do` |
| `roblox_port/src/Shared/Prey/Millipede.luau` | 70 | `while #m.trail > Millipedes.RINGS + 1 do table.remove(m.trail) end` |
| `roblox_port/src/Shared/Prey/PreyDirector.luau` | 206 | `local probe=Instance.new('Part');probe.Name='FlyClearanceProbe';probe.Shape=Enum.PartType.Ball;probe.Anchored=true;probe.CanCollide=false;probe.CanQuery=false;probe.CanTouch=false;probe.Transparency=1;probe.Parent=workspace` |
| `roblox_port/src/Shared/Prey/PreyPopulation.luau` | 10 | `while #self.owed>missing do table.remove(self.owed) end` |
| `roblox_port/src/Shared/Prey/PreyPopulation.luau` | 11 | `while #self.owed<missing do table.insert(self.owed,now+self.rng:draw(self.p.replenish_delay_s)) end` |
| `roblox_port/src/Shared/Prey/PreyWorld.luau` | 55 | `clock = 0, -- a running clock for the drawing (the directors' own stop while they wait)` |
| `roblox_port/src/Shared/Prey/Snail.luau` | 118 | `while #s.trail > 0 and now - s.trail[#s.trail].t > Snails.FADE_S do table.remove(s.trail) end` |
| `roblox_port/src/Shared/Prey/Snail.luau` | 142 | `while #s.trail > Snails.TRAIL do table.remove(s.trail) end` |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 166 | `_lineDir: Vector3, -- the last direction up the line (it stays while the pose blends out)` |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 191 | `local p = Instance.new("Part")` |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 210 | `local mesh = Instance.new("SpecialMesh")` |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 354 | `local model = Instance.new("Model")` |
| `roblox_port/src/Shared/Rig/SpiderRig.luau` | 824 | `local hl = Instance.new("Highlight")` |
| `roblox_port/src/Shared/UI/ControlText.luau` | 227 | `return `You can now run. Hold {ControlText.name(device, "run")} while moving.`` |
| `roblox_port/src/Shared/UI/EyeOptics.luau` | 259 | `while #list > maxCount do` |
| `roblox_port/src/Shared/UI/LifeText.luau` | 220 | `["the rival in the jaws is still struggling"] = "Not while a fight is on",` |
| `roblox_port/src/Shared/UI/LifeText.luau` | 221 | `["the spider is eating its rival"] = "Not while you are feeding",` |
| `roblox_port/src/Shared/UI/LifeText.luau` | 224 | `["the spider is feeding"] = "Not while you are feeding",` |
| `roblox_port/src/Shared/UI/LifeText.luau` | 225 | `["the prey in the jaws is still struggling"] = "Not while a fight is on",` |
| `roblox_port/src/Shared/UI/MateText.luau` | 46 | `MateText.REST_HATCHING = "Not while the brood is hatching"` |
| `roblox_port/src/Shared/UI/MateText.luau` | 80 | `if reason == "rest" then return "The visitor wandered off while you rested." end` |
| `roblox_port/src/Shared/UI/NotebookText.luau` | 132 | `{id="peacock_dance",text="Change to the peacock (in Settings, or while resting), then dance outside."},` |
| `roblox_port/src/Shared/UI/NotebookText.luau` | 133 | `{id="walking_like_an_ant",text="Change to the ant mimic (in Settings, or while resting), then stand still."},` |
| `roblox_port/src/Shared/UI/NotebookText.luau` | 135 | `{id="tarantula_cousins",text="Change to a tarantula (in Settings, or while resting), then rear up outside."},` |
| `roblox_port/src/Shared/UI/PeacockText.luau` | 19 | `PeacockText.NOT_RESTING = "You can change spider while resting in the silk-lined crack"` |
| `roblox_port/src/Shared/UI/SettingsModel.luau` | 163 | `while v < to do` |
| `roblox_port/src/Shared/UI/SettingsModel.luau` | 178 | `while digits < 6 and math.abs(step * 10 ^ digits - math.floor(step * 10 ^ digits + 0.5)) > 1e-9 do digits += 1 end` |
| `roblox_port/src/Shared/UI/SettingsText.luau` | 111 | `while size > 10 do` |
| `roblox_port/src/Shared/World/Environment.luau` | 111 | `while cycle>durations[leg] and leg<#route do cycle-=durations[leg];leg+=1 end` |
| `roblox_port/src/Shared/World/Garden.luau` | 879 | `while x < W.east do` |
| `roblox_port/src/Shared/World/Garden.luau` | 896 | `while y - K.height > W.foot - K.height do -- below the slab` |
| `roblox_port/src/Shared/World/Garden.luau` | 908 | `while y + K.height <= W.above do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1016 | `while y + K.height <= W.above do y += course; c += 1 end` |
| `roblox_port/src/Shared/World/Garden.luau` | 1017 | `while y + K.height <= U.head do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1021 | `while x < U.east do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1113 | `while y + K.height <= U.head + L.h do y += course; c += 1 end` |
| `roblox_port/src/Shared/World/Garden.luau` | 1114 | `while y + K.height <= U.top - K.joint / 2 do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1117 | `while x < U.east do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1221 | `while yy > H.foot do yy -= course end` |
| `roblox_port/src/Shared/World/Garden.luau` | 1224 | `while yy < U.top do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1425 | `while x < W.east do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1441 | `while y - K.height > W.foot - K.height do` |
| `roblox_port/src/Shared/World/Garden.luau` | 1449 | `while y + K.height <= W.top - K.joint / 2 do` |
| `roblox_port/src/Shared/World/Hut.luau` | 774 | `while true do` |
| `roblox_port/src/Shared/World/Hut.luau` | 1508 | `while x < hi.X - 1 do` |
| `roblox_port/src/Shared/World/Hut.luau` | 2226 | `while z < U.z1 - 1 do` |
| `roblox_port/src/Shared/World/Hut.luau` | 2258 | `while x < hi.X - 1 do` |
| `roblox_port/src/Shared/World/Hut.luau` | 2343 | `while x < hi.X - 5 and k < 4 do` |
| `roblox_port/src/Shared/World/Meadow.luau` | 774 | `while x < (b :: number) - 1 do` |
| `roblox_port/src/Shared/World/Pond.luau` | 170 | `while x < x1 - 1e-6 do` |
| `roblox_port/src/Shared/World/Pond.luau` | 397 | `while s <= s1 + 1e-6 do` |
| `roblox_port/src/Shared/World/Pond.luau` | 761 | `while x < x1 - 1e-6 do` |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 305 | `while y < EAVES - 4 do` |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 547 | `while gx <= x1 + 3.1 do` |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 549 | `while gz <= z1 + 3.1 do` |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 850 | `while x < 104 do` |
| `roblox_port/src/Shared/World/PreserveLook.luau` | 899 | `while z < 64 do` |
| `roblox_port/src/Shared/World/PreserveTrain.luau` | 74 | `while self.pass(cursor).finish < t do cursor += 1 end` |
| `roblox_port/src/Shared/World/StationAir.luau` | 128 | `while i>1 do local parent=i//2;if heap[parent].cost<=cost then break end;heap[i],heap[parent]=heap[parent],heap[i];i=parent end` |
| `roblox_port/src/Shared/World/StationAir.luau` | 134 | `while i*2<=#heap do` |
| `roblox_port/src/Shared/World/StationAir.luau` | 145 | `while #heap>0 do` |
| `roblox_port/src/Shared/World/StationAir.luau` | 150 | `while at~=first do at=previous[at];table.insert(reversed,nodes[at]) end` |
| `roblox_port/src/Shared/World/StationAir.luau` | 156 | `while i<#path do` |
| `roblox_port/src/Shared/World/WorldBuild.luau` | 30 | `local model = Instance.new("Model")` |
| `roblox_port/src/Shared/World/WorldBuild.luau` | 49 | `local world = Instance.new("Folder")` |
| `roblox_port/src/Shared/World/WorldBuild.luau` | 64 | `local looks = Instance.new("Folder")` |
| `roblox_port/src/Shared/World/WorldBuild.luau` | 69 | `local model = Instance.new("Model")` |
