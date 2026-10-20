# Everything to scale: the audit (ROBLOX-114, 2026-10-20)

Nathan: "make everything to scale". The game's unit is 1 stud = 1 cm. Every object in the world was checked against its real size: the physical boxes, the
drawn looks, the view out of the window and the creatures. The creatures were measured as drawn, not from their data: `tools/preview/scene.py --lineup`
stands every one of them side by side on a ruler of 1 cm ticks (millimetre ticks on the small row) with the real body code at its real scale, and writes what
each measures to `<prefix>lineup.txt` (its whole length with legs, its body from head or cephalothorax to the end of the abdomen, its span, its height; an
ellipsoid counts as its box, so a turned one reads a little long). The house and the garden were checked against their numbers in `World/Garden`,
`Data/Graphics` and `Data/Flora`, and looked at in the previews (`house`, `house_eye`, `garden_eye`, `window`, `bed`, `kitchen`, `counter`).

Verdicts: **true** (within the real range), **fixed** (wrong, changed this round), **golden** (wrong or odd, but a Godot-golden number that is never changed:
recorded), **kept** (wrong or short, left for a reason given, for Nathan to decide). "Well-known standard" means a building size anyone in the trade would give;
the other sources were opened for this audit.

## The creatures (as drawn; body length unless said)

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| The first spider (Phidippus audax) | 10.0 mm at the first stage, 11.4, 13.1, 14.9 mm at the adult stage; legs to 21.7 mm overall | adult females 8 to 15 mm, males 6 to 13 mm (Wikipedia, Phidippus audax) | true for the adult; **golden** for the first stage | none. The first stage is already an adult's size: a real spiderling leaving the sac is a few millimetres. `Growth.SCALES` (1 to 1.5) and the body length (1.0) are Godot's; the notebook says the growth stages are stylised. |
| The rival | 10.0 mm (the first stage's look, drawn brown) | as above | true | none |
| The mate on the first spider (a male) | 0.9 of the adult, +-5%: 13.4 to 14.1 mm | males 6 to 13 mm (Wikipedia) | **fixed** | `MatingRules.scale.male` 0.9 to 0.85: 12.0 to 13.3 mm |
| The peacock spider (Maratus volans, the male) | 4.5 mm at the first stage, 6.8 mm at the adult (Growth's 1.5 times) | about 5 mm, both sexes (Wikipedia, Maratus volans); the look's own comment said 4.5 mm | **fixed** | its own growth, `Appearances.growth` { 0.74, 0.85, 0.98, 1.11 } read by `SpiderRig.growthScale`: 3.4, 3.8, 4.4 and 5.0 mm |
| The peacock's mate (a female) | 1.15 of his adult, +-5%: 7.4 to 8.2 mm before the fix above | about 5 mm (Wikipedia) | **fixed** | `MatingRules.scale.female` 1.15 to 1.05, on his true adult: 5.0 to 5.5 mm (`MateStage` now scales the look's own adult) |
| The ant mimic (Myrmarachne formicaria, the female) | 4.9 mm at the first stage, 7.4 mm at the adult | 5 to 6.5 mm (Arachnologische Gesellschaft, European Spider of the Year 2019) | **fixed** | its own growth { 0.82, 0.94, 1.08, 1.22 }: 4.1, 4.6, 5.3 and 6.0 mm. `AntMimic.bodyLengthStuds` (the playbacks' 5 mm) unchanged. |
| The tarantulas (redknee, greenbottle blue) | 17.0 mm at the adult stage (the first spider's body in a tarantula's build) | a real body is 5 cm and more | true as a costume | none: the notebook says it in so many words ("A real tarantula's body is five or more centimetres long; yours is the first spider's size") |
| House fly (Musca domestica) | 7.3 mm (9.1 with legs) | 6 to 7 mm (the brief; FlyLook's own "about 0.7 cm") | true (a box reads a little long) | none |
| Fruit fly (Drosophila) | 4.4 mm: the house fly at the golden `visual_scale` 0.6 | about 2.5 mm (BioNumbers 100750) | **golden, drawn scale fixed** | drawn at `FlyLook.trueScale.fruit_fly` 0.4: 2.9 mm. The profile's 0.6 is untouched; only `FlyBodies` reads the drawn scale. |
| Fungus gnat | 3.1 mm | 2 to 4 mm (the brief) | true | none |
| Aphid | 2.4 mm | 1 to 3 mm (the brief) | true | none |
| Springtail | 1.6 mm | 1 to 2 mm (the brief) | true | none |
| Leafhopper | 3.1 mm | 3 to 10 mm (the brief) | true | none |
| Small moth | 7.6 mm, 16.5 mm across the folded wings | a micro or small macro moth, 5 to 12 mm | true | none |
| Crane fly | 18.5 mm, 60 mm across the legs | Tipula paludosa 1.5 to 2.5 cm (Wikipedia) | true | none |
| Woodlouse | 9.9 mm | about 1 to 1.5 cm (the brief) | true (small) | none |
| Ladybird | 6.7 mm | 5 to 8 mm (the brief) | true | none |
| Millipede | 26 mm | the notebook's game line says about 2.4 cm; garden millipedes 2 to 5 cm | true | none |
| Garden snail | shell 30 by 26 by 23 mm, foot 4 cm | shell 28 to 32 mm across (the notebook's page, Dekle & Fasulo, UF/IFAS EENY240) | true | none |
| Harvestman | body 5.0 mm, legs II 3.1 cm along them, 4.95 cm span | body 5 to 7 mm (female), legs up to 50 mm (NatureSpot, Leiobunum rotundum) | true (a smaller one) | none |
| Mud dauber wasp | 23.7 mm (32 with antennae and legs) | 2 to 3 cm (the notebook's page) | true | none |

## The house

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| Bricks | 21.5 x 6.5 cm faces, 1 cm joints (7.5 cm a course) | UK standard 215 x 65 mm, 10 mm mortar (well-known standard) | true | none |
| The back door | 85 x 200 cm, a flat slab of WoodPlanks; read very wide in the `house` view | British standard external door 813 x 1981 mm (2 ft 8 in by 6 ft 6 in; well-known standard) | **fixed** | 81.3 x 198.1, a 4.5 cm frame, a glazed upper panel, a panel below and a lever handle (3 parts at full; eaves 146 to 149). Most of the "wide" was the `house` camera's 62 degrees stretching what stands at the frame's edge: the new `house_eye` view (eyes 1.6 m up, 6 m out, 45 degrees) shows it as a person does. |
| The back step | 14 cm high, 30 deep | a step's rise 15 to 22 cm (well-known standard) | true | none |
| The kitchen window | 62 wide, glass 1.1 m, head 1.125 m over the sill | a kitchen window | true | none |
| Its glazing bars and frame | mullions 0.7 cm, the frame's trim 0.5 cm, the raised sash's bottom rail 0.8 cm | a sash's glazing bars about 2 cm, its bottom rail 5 to 8 cm (well-known joinery) | **kept** | thinner than real; widening them changes the sun's pattern on the sill, which Nathan asked to keep. For Nathan. |
| The other window | 62 x 112.5 | as the kitchen's | true | none |
| Eaves | 2.4 m over the lawn | a bungalow's eaves 2.3 to 2.6 m (well-known) | true | none |
| Gutter | 12 cm wide, 7 deep | a half-round 112 mm gutter (well-known standard; the brief's ~11 cm) | true | none |
| Downpipe | 7 cm square | 68 mm round (the brief) | true | none |
| Roof | 35 degrees, tile joints about 12 cm apart along the eave | a plain tile 265 x 165 mm (well-known standard) | true | none |
| The wall | 36.5 cm thick (the brick face to the room's plaster) | a cavity wall about 30 cm plus plaster | true | none |
| The outer sill | stone slab 60 x 10.5 x 3 cm, its front edge the wall's face | a stone sill 5 to 7 cm thick projecting 4 to 5 cm past the wall to throw the rain (well-known) | **kept** | it is physical ground the spider walks out on; a projecting sill moves the descent's geometry. For Nathan. |
| The window box | two halves 15 x 8.2 cm, **2.8 cm tall**, flowers 5 to 8 cm tall | a window box 15 to 20 cm tall and deep (well-known) | **kept** | a miniature. A real one 15 cm tall on the outer sill would shade the sill (the sun comes in below y 14.4) and its boxes are physical. For Nathan: a real box (and true-size flowers) means a new light on the sill, or a box hung below the sill on brackets. |
| Black-eyed Susans (Rudbeckia hirta) | heads about 3.4 cm across, 5 to 8 cm tall | heads up to 10 cm across, plants 30 to 100 cm (Wikipedia, Rudbeckia hirta) | **kept** | miniature with the box, the same reason. For Nathan. |

## The kitchen

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| Worktop height | 86 cm over the floor | UK and US 90 to 91 cm; older European kitchens 85 (well-known standards) | true (low end) | none: raising it puts the floor below the lawn or the worktop above the sill board |
| The floor | at the lawn's level (y -90; the lawn -90.4) | a house floor stands at least 15 cm over the ground outside (damp-proof course, well-known) | **kept** | the sill's 90 cm above the garden fixes it; a raised floor means a lower worktop or a higher sill. For Nathan. |
| Worktop | 3 cm thick, 60 cm deep | 3 to 4 cm, 60 cm (the brief) | true | none |
| Sink | bowl 40 x 40, 20 deep | a single bowl about 40 x 34 to 45, 18 to 20 deep | true | none |
| Tap | 14 cm tall, its spout 11 cm out | a pillar tap 15 cm; a kitchen mixer 25 to 35 cm | **kept** (short) | physical box; it was moved out of the sill's view last round |
| Toaster | 18.6 x 13.6 x 20 cm | a two-slice toaster about 28 x 17 x 19 cm | **kept** (small) | its box is built round the retreat under it; a bigger one moves the home |
| Kettle | 22 cm tall on its base, 18 across | a jug kettle 22 to 25 cm | true | none |
| Cupboard doors, plinth | doors 73 cm tall, 30 wide; plinth 10 cm | 72 cm, 30 to 60 wide; plinth 10 to 15 cm (well-known) | true | none |
| Floor tiles, upstand tiles | 30 cm; 10 cm | 30 x 30 floor tiles, 10 x 10 wall tiles (well-known) | true | none |

## The sill (the Godot layout: `WindowsillLayout.PIECES`, byte for byte)

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| Sill board | 60 x 25 cm, 1 cm thick | a window board 15 to 30 deep, 2 to 2.5 cm thick | true, **golden** thickness | none |
| Pilea leaves | 5 to 7 cm across, 0.4 cm thick | Pilea peperomioides leaves 5 to 10 cm (the brief) | true (thick: golden) | none |
| Pilea petioles | 1 cm boxes, drawn as rods 1 cm across | 2 to 4 mm | **golden** | none: the drawn rod fills its climbable box so the spider's feet meet it |
| The planter | 14 x 8 x 4.6 cm | the smallest troughs about 20 x 10 x 8 cm | **golden** | none |
| Grass on the sill | 0.35 to 1.6 cm sprouts | seedlings | true | none |

## The garden

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| Bed grass | tufts 1.4 to 3.2 cm, blades 1.4 to 2.4 mm wide; clumps 1.8 to 3.4 cm; seed heads 0.7 cm | a lawn mown to 6 to 9 cm in summer (Iowa State University Extension), its uncut edges longer; blades 3 to 5 mm (the brief) | **fixed** | tufts 5 to 12 cm, clumps 6 to 14, blades 3 to 4.5 mm, seed heads 2.2 cm by 3.5 mm (drawn only; no draw moves) |
| Dandelion flower | head 2.6 cm across | 2 to 5 cm open; the bracts' cup 14 to 25 mm (Wikipedia, Taraxacum officinale) | **fixed** | head 3.6 cm, bracts 2.2, centre 1.6 |
| Dandelion stalk | 12 cm | 5 to 40 cm (Wikipedia) | true | none |
| Dandelion leaves | 4.6 x 2.0 cm | 5 to 45 cm long, 1 to 10 wide (Wikipedia) | **kept** (short) | physical boxes the aphids and ladybirds walk: longer leaves move the bed's perches and paths (a next round, with its pins). For Nathan. |
| Dock | an 18 cm stem with leaves 4.5 to 6.5 cm | a young dock's stem leaves 5 to 15 cm | true (small) | none |
| Stones in the bed | 3.2 to 6 cm, the retreat's flat stone 8 cm | garden stones | true | none |
| Pebbles, litter, twigs | 2.5 to 8 mm; 0.9 to 2.8 cm; 2 to 6 cm | gravel, leaf fragments, twigs | true | none |
| The bushes beside the bed | 44 to 54 cm tall, 36 to 48 across | a garden box or privet 0.5 to 2 m (the brief); a clipped young box ball 40 to 60 | true (low end) | none |
| The drawn bushes on the lawn | 55 to 150 cm | as above | true | none |
| Fences | 1.8 m, posts 9 cm every 1.7 m | 1.8 m, 7.5 to 10 cm posts (the brief; well-known) | true | none |
| The garden | 10 x 14 m | a small back garden | true | none |
| The lawn | a flat ground in Roblox's Grass material, no blades | blades 5 to 15 cm | **kept** | blades over 140 m2 are beyond any part budget; the material stands in |

## The view

| Object | The game has | Real size, and where from | Verdict | Change |
|---|---|---|---|---|
| The bungalows | 2.6 m walls, 5.1 m to the ridge, 6 to 7.6 m wide; their faces **40 cm behind the back fence** | a bungalow's ridge 4.5 to 5.5 m; facing habitable windows of one- and two-storey houses at least 21 m apart (Cheshire East Local Plan, policy HOU 13, table 8.2: the usual British "21 m rule") | **fixed** (the distance) | their faces at z -2150, 21 m from this house's back wall (their gardens 7.3 m deep behind the fence); a second ground part under them (the sill's Decor 1,261 and 363 parts) |
| The trees beyond the side fences | 7.2 m and 5.1 m tall, crowns 9.8 and 6.3 m across; trunks **56 and 47 cm** | a garden tree of that height has a trunk of about 20 to 35 cm (judged; urban trees vary widely, Vaz Monteiro, Doick & Handley 2016) | **fixed** | trunks 33 and 24 cm (w 0.75 and 0.45 on the glass) |
| The hills | 27 m off, up to 9 m tall over the lawn | a hill is kilometres off | **kept**, moved | no part can stand kilometres off; they are the near rise of the land beyond the houses, 36 m off now (behind the bungalows), lower (tops 1.2 lower on the glass), each a part of at most 2,048 studs with its sphere mesh scaled (`Scenery.MAX_PART`) |

## Previewed

`tools/preview/scene.py`: `--lineup` (new; views `lineup_small`, `lineup_spiders`, `lineup_bugs`, `lineup_big`) and the views `house_eye` and `garden_eye`
(new) beside `house` (ROBLOX-103's camera), `window`, `garden`, `bed`, `ambient_dandelion`, `kitchen` and `counter`, before and after. Layout and size only,
not Roblox's materials or light.
