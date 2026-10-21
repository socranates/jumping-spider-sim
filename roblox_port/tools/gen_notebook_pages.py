#!/usr/bin/env python3
"""Generates src/Shared/Data/NotebookPages.luau from the frozen Godot data/notebook/pages.json (LEARN-01) and copies that file to
tests/notebook_reference.json (then tools/reference_to_luau.py makes tests/notebook_reference.luau) so tests/notebook.luau can check
the port against Godot's own words. Ids, triggers, titles and sources are carried over verbatim, and so are the texts except the few
sentences listed in TEXT_FIXES below (corrected in the audit of 2026-10-19, each with its reason): the generated page then also carries
Godot's whole text as `godotText`. The "In this game" line is Godot's too except where the Roblox game differs: those pages are listed in
ADAPTED below with the reason, and the generated page then also carries Godot's line as `godotGame`. A line may name a control as {reel},
{letGo}, {drop}, {focus} or {display}; the panel fills in the name for the device in use (ControlText).
Usage (from roblox_port/):  python3 tools/gen_notebook_pages.py
That writes src/Shared/Data/NotebookPages.luau and tests/notebook_reference.json (a byte copy of Godot's file, so unchanged unless the
frozen JSON is); if the reference ever changes, run  python3 tools/reference_to_luau.py tests/notebook_reference.json  after it."""
import json, pathlib, shutil

HERE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = HERE.parent / "data" / "notebook" / "pages.json"
OUT = HERE / "src" / "Shared" / "Data" / "NotebookPages.luau"
REFERENCE = HERE / "tests" / "notebook_reference.json"

# id -> (the Roblox "In this game" line, why Godot's line is not true here)
ADAPTED = {
    "bold_jumper": ("This windowsill is built at true scale: one stud is one centimetre, about the length of the spider.",
                    "Roblox measures in studs, not Godot's game units."),
    "dragline": ("The spider here fixes a safety line when it leaps, where the surface holds silk, and a missed jump leaves it hanging. On the line, {reel} reels in and holding {letGo} lets go. {drop} lets it down on its line; hold it to keep lowering.",
                 "Roblox's controls differ (the D-pad walks), and lowering from anywhere is not true: some places cannot be let down from."),
    "legs_push": ("In this game the spider braces and crouches before a jump, then pushes off with its back legs. Both are drawn poses, not measurements.",
                  "Godot's line asks the player to watch the back legs straighten at take-off. The Roblox spider draws a brace and crouch while the jump is held and a brief push of legs III and IV after launch (ROBLOX-57), with invented timing and no measured pressure, so its line says what is drawn and that it is drawn."),
    "green_uv": ("A screen cannot show ultraviolet, so the eye view shows it as violet, and only the principal eyes see it ({focus}).",
                 "Roblox's eye view has a violet ultraviolet layer; it does not say 'UV not simulated'."),
    "hungry_at_home": ("Here hunger shows in the spider's thinner abdomen and in the words under the day. A spider that goes too long without food starves, except on Easy and in free play.",
                       "Godot's line says a reserve that runs out does not yet end a life, which the later rounds (and Roblox) made untrue."),
    "mud_dauber": ("You hear the wasp before it reaches the sill. The silk-lined crack is safe. Keeping still makes you hard to notice, and a jump or a drop on your line breaks its approach.",
                   "Roblox has no wasp shadow or felt landing (no vibration sense yet)."),
    "what_the_wasp_does": ("Being caught ends this spider's life. You can go back to your last rest, if you have one, or continue as another spider.",
                           "Roblox's catch screen offers the last rest or another spider."),
}


# Godot's wording that the audit of 2026-10-19 corrected: id -> (the sentence as Godot has it, the sentence the game uses, why). `old` must occur
# exactly once in Godot's text. docs/NOTEBOOK_SOURCES.md records what each figure and claim rests on; tests/notebook.luau lists these ids.
TEXT_FIXES = {
    "grown_up": ("In the field, males of the related Phidippus johnsoni became adult after about six to eight moults and females after about seven to nine.",
                 "In the lab, males of the related Phidippus johnsoni matured after 5 to 7 moults and females after 6 to 8.",
                 "Jackson 1978 gives 5 to 7 and 6 to 8 as the laboratory counts; its 6 to 8 and 7 to 9 for the field are estimates from measurements (the abstract says 'probably'), which Godot's line presented as counted."),
    "going_without_food": ("Adult females of the related Phidippus johnsoni were kept for 25 to 31 days without eating.",
                           "In the lab, jumping spiders have survived weeks without food, longer when cold and still.",
                           "The 25 to 31 days are not in Jackson 1978 (searched in the PDF; it reports months without food in the cold). The new sentence claims no figure."),
    "mud_dauber": ("It finds a spider by sight, then touches it with its antennae before it stings.",
                   "It searches by sight, then checks a spider with its antennae before it stings.",
                   "Uma et al. 2013 (discussion, citing Uma & Weiss 2010): sight picks out a possible prey item from 5 to 10 cm and contact chemistry decides if it is prey."),
    "getting_away": ("Not being seen matters most: the mud dauber finds its prey by sight.",
                     "The mud dauber searches by sight and then checks with its antennae, so a spider that stays out of sight is safer.",
                     "The same: sight finds the candidate, the antennae decide, so 'not being seen matters most' and 'finds its prey by sight' said more than the paper does."),
}

# Reconciled with the Windows notebook implementation; the JSON remains a frozen reference. These replace the entries of ADAPTED above that have the same id.
EXTRA_ADAPTED = {
 "bold_jumper": "The first spider is inspired by the bold jumper. The peacock spider, the ant mimic and the two tarantulas are costumes on the same body: other species, the same game rules. Our models and four growth stages (three moults) are stylised; one stud represents a centimetre.",
 "hearing": "Buzzing is a human-audible cue, not a recording of what a spider experiences.",
 "home_before_dark": "Rest in the crack in the evening to sleep until morning. A day lasts about fifteen minutes of active play.",
 "new_skin": "Your spider is pale and its jumps shorter while its skin hardens. The ten game-hour timing is a design choice. The empty skin stays in the crack.",
 "grown_up": "The game compresses growth into three moults. Adulthood in a Standard main life opens Easy for this session. The male peacock look and dance are cosmetic choices at every gameplay stage.",
 "going_without_food": "Time is compressed here. The hunger bar, full when your spider is fed, empties in a little over a day and a half; a spider that then goes two more days without food dies, after warnings on the screen. On Easy and in free play it empties much more slowly and cannot starve.",
 "what_the_wasp_does": "A catch ends a Standard life. Return to your last rest or continue as an unrelated spider. In Easy and Free play the wasp only touches and leaves.",
}
for key, line in EXTRA_ADAPTED.items():
 ADAPTED[key] = (line, "Keep the current Roblox rules and artistic choices explicit.")
PEACOCK = {
 'id':'peacock_dance','trigger':'dance','title':'A fan and a dance',
 'text':'A male peacock spider, Maratus volans, unfolds colourful flaps on its abdomen and waves its third pair of legs during courtship. The display also sends vibrations through the surface beneath it. It is a message to a female, not just a dance people can see.',
 'game':'Our repeating dance is inspired by recorded displays. Its size, colour, timing and movement are stylised. Here the dance is also how you court a mate: it is available at every growth stage, but only a full-grown, well-fed spider is visited by one.',
 'sources':['Girard, M. B., Kasumovic, M. M. & Elias, D. O. (2011). Multi-Modal Courtship in the Peacock Spider, Maratus volans. PLoS ONE 6(9): e25390. https://doi.org/10.1371/journal.pone.0025390']}

ANTMIMIC = {
 'id':'walking_like_an_ant','trigger':'antennae','title':'Walking like an ant',
 'text':"Myrmarachne formicaria is a jumping spider that mimics an ant. It walks on all eight legs, and when it stands still it raises its front legs above its head and moves them together, like an ant's antennae. It makes only short stops, about a tenth of a second long, so it seems to move almost constantly, as ants do. In tests with Phidippus audax as the predator, ordinary spider targets were attacked 4.5 times as often as ants and 3 times as often as mimics; ants and mimics did not differ.",
 'game':"The ant mimic is a look only: where you go, how fast and what the wasp does are the first spider's. Its front legs rise when you keep still, and a stop shorter than about 83 milliseconds is not drawn as a pause. The waving, the sway of the body as it walks, the colours and the size are stylised: the real mimic's wobbling path is not walked. The female is drawn.",
 'sources':["Shamble, P. S., Hoy, R. R., Cohen, I. & Beatus, T. (2017). Walking like an ant: a quantitative and experimental approach to understanding locomotor mimicry in the jumping spider Myrmarachne formicaria. Proceedings of the Royal Society B 284: 20170308. https://doi.org/10.1098/rspb.2017.0308"]}

MATING = {
 'id':'eggs_and_wind','trigger':'hatched','title':'Eggs, silk and wind',
 'text':"Jumping spiders court mostly by sight, and often by vibration too: a male shows a display and the female decides. She lays her eggs in a silken nest. A Phidippus johnsoni mother stays with it until the young hatch and leave: in the lab the eggs hatched about three weeks after laying, and the spiderlings left about three weeks after that. Many young spiders then travel by ballooning: they climb high, let out a thread of silk and are carried off by the air. The electric field in the air can trigger the take-off.",
 'game':"A game day is about fifteen minutes, so weeks become days: a mate on the sill, a courtship you hold for eight seconds, one night to the sac and two guard days. In Normal the mate decides when the courtship is full: a thin spider, or a court that broke off, stood far or looked away, is often refused, and a rival may cut in. The real mother makes and guards the sac; here the sac is drawn the same whichever spider you play, and no claim is made that a male guards eggs. A real brood is far larger than the eight to twelve shown: a Phidippus johnsoni female laid about 200 eggs in all. The first spider's sex is the game's choice (a female), and the peacock spider's mate is drawn with the male's colours although the real female is mottled grey-brown. Nothing can harm the sac, and you carry on as one of the spiderlings, which a real one could not choose.",
 'sources':[
  "Jackson, R. R. (1978). The life history of Phidippus johnsoni (Araneae, Salticidae). Journal of Arachnology 6: 1-29.",
  "Foelix, R. F. (2011). Biology of Spiders, 3rd edition. Oxford University Press.",
  "Bell, J. R., Bohan, D. A., Shaw, E. M. & Weyman, G. S. (2005). Ballooning dispersal using silk: world fauna, phylogenies, genetics and models. Bulletin of Entomological Research 95(2): 69-114. https://doi.org/10.1079/BER2004350",
  "Morley, E. L. & Robert, D. (2018). Electric Fields Elicit Ballooning in Spiders. Current Biology 28(14): 2324-2330. https://doi.org/10.1016/j.cub.2018.05.057"]}


TARANTULA = {
 'id':'tarantula_cousins','trigger':'tarantula','title':'Velvet cousins (Theraphosidae)',
 'text':"Tarantulas (family Theraphosidae) are large, heavy, long-lived spiders. They are not jumping spiders: their eyes sit close together on a small mound and are poor, and they feel their way with the hairs on their legs. Their fangs strike downward, side by side. Most New World tarantulas have urticating hairs on the abdomen and cast them at an attacker. A threatened tarantula rears up and lifts its front legs, and all of them spin silk from spinnerets at the rear of the abdomen.",
 'game':"The Mexican redknee and the Greenbottle blue are costumes on the first spider's body, nothing more. A real tarantula's body is five or more centimetres long; yours is the first spider's size. You still see, jump, spin your safety line and are hunted exactly as the first spider does, which no real tarantula could do. The rear-up and the turn with the spinnerets sweeping ({display}) are drawn poses with invented angles and timing, and no silk mat is laid. The colours are stylised, the redknee's rust patch is drawn as a small cluster of hairs (no hairs are cast), and the greenbottle's bars soften at the last growth stage as a game choice.",
 'sources':[
  "Foelix, R. F. (2011). Biology of Spiders, 3rd edition. Oxford University Press.",
  "Bertani, R. & Guadanucci, J. P. L. (2013). Morphology, evolution and usage of urticating setae by tarantulas (Araneae: Theraphosidae). Zoologia 30(4): 403-418. https://doi.org/10.1590/S1984-46702013000400006"]}

# ROBLOX-101 checked W3's five sources where they could be opened (docs/NOTEBOOK_SOURCES.md): two sentences said a little more than their sources ("feed in
# groups" for the aphids' colonies, "glands in their armour" for glands on the sides of the body), the gnats' fact sheet is of 2003 (reviewed 2025), not 2009,
# and the woodlice's sentence gains the fact sheet it was checked against.
GROUND_LIFE = {
 'id':'ground_life','trigger':'garden_bed','title':'Life on the ground',
 'text':"Fungus gnats are small dark flies whose larvae live in damp soil and eat fungi and rotting matter; the adults fly weakly. Aphids are soft, pear-shaped insects that live in colonies and suck sap from leaves and stems. A jumping spider hunts small insects of many kinds; the related Phidippus johnsoni takes aphids. Woodlice are crustaceans, not insects, with seven pairs of legs: they keep to damp places under stones and litter, and glands on the sides of the body give off a sticky secretion that puts spiders off.",
 'game':"The gnats and the aphids in the bed are the house fly's model made smaller and slower, with no measured numbers behind them: a gnat is a third of a housefly meal here and an aphid a sixth, and the aphids only walk. The woodlice walk the soil, go under cover when you come near and cannot be caught, which is the game's way of saying the spider leaves them alone.",
 'sources':[
  "Cranshaw, W. S. & Cloyd, R. A. (2003, reviewed 2025). Fungus Gnats as Houseplant and Indoor Pests. Colorado State University Extension, Fact Sheet 5.584.",
  "Warren, P. & Schalau, J. (2014). Aphids. University of Arizona Cooperative Extension, AZ1635.",
  "Jackson, R. R. (1977). Prey of the jumping spider Phidippus johnsoni (Araneae: Salticidae). Journal of Arachnology 5: 145-149.",
  "Hopkin, S. P. (1991). A key to the woodlice of Britain and Ireland. Field Studies Council (AIDGAP), Shrewsbury.",
  "Katz, O., DeVries, Z. & Larson, J. (2023). Sowbugs and Pillbugs. University of Kentucky Entomology, ENTFACT-439.",
  "Fischer, A., Gries, R., Roman-Torres, C. A., Devireddy, A. & Gries, G. (2025). Glandular quinoline-derivates protect crustacean woodlice from spider predation. Journal of the Royal Society Interface 22: 20250260. https://doi.org/10.1098/rsif.2025.0260"]}

# ROBLOX-101 (W3b part A): the bestiary's first four, one page each, opened by the first close look at one (NotebookWatch: a prey of the kind within lookWu of the
# spider). Every sentence rests on a source opened for it; docs/NOTEBOOK_SOURCES.md says which supports which.
SPRINGTAILS = {
 'id':'springtails','trigger':'look_springtail','title':'Springtails and the spring',
 'text':"Springtails (Collembola) have six legs like insects, but biologists count them a lineage of their own. Most are about a millimetre long, white, grey or blue-grey. Many carry a forked spring, the furcula, clasped under the abdomen; released, it strikes the ground and flips the animal into the air, up to about 10 cm. They live in damp soil and litter and eat fungi and decaying plants, and small or young spiders are among the many small predators that eat them.",
 'game':"Here a springtail is an eighth of a housefly meal and easy to hold once caught: the hard part is getting close. Its flick is a hop of 1.5 to 4 studs, set off when you come near or move fast beside it. The numbers are the game's, not measurements.",
 'sources':[
  "Koehler, P. G., Aparicio, M. L. & Pfiester, M. (1994, revised 2022). Springtails. University of Florida IFAS Extension, ENY-228.",
  "Missouri Department of Conservation (undated, read 2026). Springtails. Missouri Field Guide, mdc.mo.gov.",
  "Blevins, H., Larson, J. & DeVries, Z. (2023). Springtails. University of Kentucky Entomology, ENTFACT-420."]}

LEAFHOPPERS = {
 'id':'leafhoppers','trigger':'look_leafhopper','title':'Leafhoppers: the sidestep and the jump',
 'text':"Leafhoppers (Cicadellidae) are small wedge-shaped bugs, a few millimetres long and often green, with the wings held like a tent over the back. They suck sap from leaves. Young and adults walk with a sideways sidestep; disturbed, the young often walk round to the other side of the stem or leaf, while adults jump and fly readily. The jump comes from the strong hind legs, which carry rows of spines: long-legged leafhoppers push off in 3 to 5 thousandths of a second.",
 'game':"Here a leafhopper is half a housefly meal but struggles as hard as a whole one. Watched from its side it slips round its stem or leaf (the game's adults do it too); come at it fast and it jumps 3 to 10 studs, and sometimes flies on. The numbers are the game's.",
 'sources':[
  "University of Illinois Extension (undated, read 2026). Leafhopper. Illinois Extension insect pages, extension.illinois.edu.",
  "University of Nebraska-Lincoln Extension (undated, read 2026). Leafhoppers. Backyard Farmer, byf.unl.edu.",
  "Utah State University Extension (undated, read 2026). Leafhoppers. Utah Pests IPM Ornamental Pest Guide.",
  "Burrows, M. & Sutton, G. P. (2008). The effect of leg length on jumping performance of short- and long-legged leafhopper insects. Journal of Experimental Biology 211: 1317-1325."]}

MOTHS = {
 'id':'small_moths','trigger':'look_moth','title':'Moths at the window',
 'text':"Moths are Lepidoptera, the scale-winged insects: tiny scales cover their wings like shingles. Most fly at night, and many are drawn to lights. A flying insect does not steer straight at a lamp: it keeps its back toward the light, as it would to the sky, and near a lamp that can keep it circling. The scales help it escape: they stick to a spider's sticky silk but come away from the wing. Spiders are among the many animals that eat moths, and Phidippus johnsoni has been found with one.",
 'game':"Here a moth is a housefly meal. It rests on the wall and the outer sill by day, drawn with its wings spread flat (many moths fold them like a tent), and flutters from dusk. Your first grab at one may slip, leaving scales; a jumping spider's catch is not a web, so that slip is the game's borrowing.",
 'sources':[
  "Missouri Department of Conservation (undated, read 2026). Moths. Missouri Field Guide, mdc.mo.gov.",
  "Fabian, S. T., Sondhi, Y., Allen, P. E., Theobald, J. C. & Lin, H.-T. (2024). Why flying insects gather at artificial light. Nature Communications 15. https://doi.org/10.1038/s41467-024-44785-3",
  "Alicea-Serrano, A. M., Onyak, A., Dhinojwala, A. & Blackledge, T. A. (2021). Robust performance of spider viscid silk on hairy and smooth insect substrates. Integrative and Comparative Biology 61(4): 1432-1439, citing Eisner, T., Alsop, R. & Ettershank, G. (1964), Adhesiveness of spider silk, Science 146: 1058-1061.",
  "Jackson, R. R. (1977). Prey of the jumping spider Phidippus johnsoni (Araneae: Salticidae). Journal of Arachnology 5: 145-149."]}

CRANE_FLIES = {
 'id':'crane_flies','trigger':'look_crane_fly','title':'Crane flies: legs to spare',
 'text':"Crane flies (Tipulidae) are large, slender flies on long, fragile legs. They look like giant mosquitoes, but they are not mosquitoes and do not bite, and the short-lived adults feed little or not at all. A special seam in the legs lets them break off easily, to escape predators. Like most flies they come to lights at night. A Phidippus johnsoni was found with one in the field; its prey is usually a quarter to three quarters its own size, sometimes as large or a little larger.",
 'game':"Here a crane fly is two housefly meals and a harder struggle than a house fly; it can leave a leg in your fangs and get away, once, and is drawn with a leg fewer after. It is bigger than your spider: real jumping spiders take prey that large only sometimes. It flies slowly from dusk.",
 'sources':[
  "University of Maine Cooperative Extension (undated, read 2026). Crane Flies. Home and Garden IPM.",
  "Layton, B. (2019). Crane Fly. Bug's Eye View 5(5), Mississippi State University Extension.",
  "Jackson, R. R. (1977). Prey of the jumping spider Phidippus johnsoni (Araneae: Salticidae). Journal of Arachnology 5: 145-149."]}

# ROBLOX-117: the hoverfly of the hut garden's flowers, opened by the first close look at one. Sources opened this round (docs/NOTEBOOK_SOURCES.md).
HOVERFLIES = {
 'id':'hoverflies','trigger':'look_hoverfly','title':'Hoverflies: a fly dressed as a bee',
 'text':"Hoverflies, or flower flies (Syrphidae), are flies that look like bees or wasps, many with black and yellow stripes across the abdomen; they mimic them as protection from predators. They do not bite or sting. Tell one from a bee by its single pair of wings, its large eyes and short antennae. The adults hover over flowers and dart about, feeding on nectar and pollen. Their larvae hunt aphids: one can eat up to 400 of them.",
 'game':"Here a hoverfly is a housefly meal and a half that struggles like one. It holds still in the air a moment over the flowers and then darts on; the hovers, the darts and the meal are the game's numbers.",
 'sources':[
  "University of Wisconsin-Madison Extension, Division of Horticulture (undated, read 2026). Hover, Flower, or Syrphid Flies, Syrphidae.",
  "University of Minnesota Extension (undated, read 2026). Syrphid flies. Beneficial insects."]}

# ROBLOX-118: the ranger's cat, opened the first time it notices the spider (NotebookWatch.onCat). Sources opened this round (docs/NOTEBOOK_SOURCES.md).
CAT = {
 'id':'the_cat','trigger':'cat','title':'The cat and the bell',
 'text':"A house cat stands 23 to 25 cm at the shoulder and weighs 4 to 5 kg. It hunts small mammals and birds first, and invertebrates last. Free-ranging cats kill an estimated 1.3 to 4.0 billion birds and 6.3 to 22.3 billion mammals a year in the United States. A bell on the collar warns prey: in one study, cats brought home about half as many mammals while they wore bells. A bold jumping spider can hear airborne sound, through special hairs, from more than 3 m away.",
 'game':"Here the ranger's cat lives in the hut and never goes outside. It sleeps much of the day and walks the two rooms at dawn and dusk, and you hear its bell before you see it. It pats at what moves near it: get up high, into a gap, or keep still. In Normal a pat that lands kills; on Easy and in free play it knocks you aside. Its day and its reach are the game's.",
 'sources':[
  "Gouvernement du Quebec (undated, read 2026). Chat domestique. Fiches des especes fauniques, quebec.ca.",
  "Loss, S. R., Will, T. & Marra, P. P. (2013). The impact of free-ranging domestic cats on wildlife of the United States. Nature Communications 4: 1396. https://doi.org/10.1038/ncomms2380",
  "Ruxton, G. D., Thomas, S. & Wright, J. W. (2002). Bells reduce predation of wildlife by domestic cats (Felis catus). Journal of Zoology 256: 81-83 (as summarised by Conservation Evidence).",
  "Shamble, P. S., Menda, G., Golden, J. R., Nitzany, E. I., Walden, K., Beatus, T., Elias, D. O., Cohen, I., Miles, R. N. & Hoy, R. R. (2016). Airborne acoustic perception by a jumping spider. Current Biology 26: 2913-2920 (as reported by NPR, 14 October 2016)."]}

# ROBLOX-105 (W3b part B): the garden's ambient bugs, one page each, opened by the first close look at one (NotebookWatch: one of the view's bugs of the kind,
# out in the open, within lookWu of the spider). Every sentence rests on a source opened for it; docs/NOTEBOOK_SOURCES.md says which supports which.
LADYBIRDS = {
 'id':'ladybirds','trigger':'look_ladybird','title':'Ladybirds: bright for a reason',
 'text':"Ladybirds, or lady beetles, are beetles with domed, oval bodies, red, orange, yellow, pink or black and usually spotted. The bright colours are a warning, to discourage animals that might eat them: disturbed, a ladybird releases an odorous, noxious fluid from its leg joints, called reflex bleeding. Adults and larvae both eat aphids and other small, soft-bodied insects. The larva looks nothing like the adult: shaped like a small alligator, spiny and black with bright spots.",
 'game':"Here the ladybirds walk the dock and the dandelion among the aphids and now and then stop over one and eat it. Strike one and you let it go, which is the game's way of saying the spider leaves it alone. The walks, the waits and how often it eats are the game's.",
 'sources':[
  "Bessin, R. (undated, revised 2026). Ladybugs. University of Kentucky Entomology, ENTFACT-702.",
  "Bohart Museum of Entomology (undated, read 2026). Lady Bugs & Lady Beetles. Information No. 055, University of California, Davis."]}

MILLIPEDES = {
 'id':'millipedes','trigger':'look_millipede','title':'Millipedes: the coil',
 'text':"Millipedes have long segmented bodies with two pairs of legs on each segment, where centipedes have one pair. Most feed on decaying vegetation, living secretively in soil and leaf mould and beneath stones, logs and bark. When threatened, most roll into a coil with their legs on the inside, offering only their body armour to the predator, and some can release substances that taste or smell foul as a defence.",
 'game':"Here a millipede is about 2.4 cm long and walks the bed's soil slowly, going under the stones for a while; come close and it coils, head in the middle, until you have gone. Strike it and you let it go. The speeds and the waits are the game's.",
 'sources':[
  "Buglife - The Invertebrate Conservation Trust (undated, read 2026). Millipedes. Bug Directory, buglife.org.uk."]}

SNAILS = {
 'id':'garden_snails','trigger':'look_snail','title':'Snails: eyes on stalks',
 'text':"The brown garden snail's shell grows to 28 to 32 mm across. A land snail's head carries retractable tentacles: the longer, upper pair bears the eyes, which see light and dark but no colours, and the shorter pair tastes and smells. It moves by waves of muscle along its foot, aided by mucus that the foot secretes all the time, which leaves a slimy trail. Most land snails are nocturnal, but after rain they may come out by day.",
 'game':"Here the snail is far bigger than your spider. It crawls about a millimetre a second over the bed and up the foot of the wall, mostly from dusk, and its trail fades in a few minutes. Its eye stalks draw in when you come near; strike it and it draws into its shell. The speeds and the trail's fading are the game's.",
 'sources':[
  "Dekle, G. W. & Fasulo, T. R. (2001, revised 2024). Brown Garden Snail, Cornu aspersum (Muller, 1774). University of Florida IFAS Extension, EENY240.",
  "Missouri Department of Conservation (undated, read 2026). Land Snails and Slugs. Missouri Field Guide, mdc.mo.gov."]}

HARVESTMEN = {
 'id':'harvestmen','trigger':'look_harvestman','title':'Harvestmen: not spiders',
 'text':"Harvestmen, or daddy longlegs, are not spiders but opilionids. The body is one simple oval, head and abdomen fused, with only two eyes and no silk or venom glands. Disturbed, they give off a foul odour. A leg falls off easily and goes on twitching, which can distract a predator while the harvestman flees. They are mostly active at night or in shade, and eat many kinds of organic matter, dead animals among them; some prey on aphids and other small insects.",
 'game':"Here one harvestman walks the bed's litter and one the house wall, from dusk through the night, high on legs that span about four studs, and takes no notice of you. Strike one and you let it go. The legs drawn and the speeds are the game's.",
 'sources':[
  "University of Kentucky Entomology (undated, read 2026). Kentucky Harvestmen. Kentucky Critter Files.",
  "Missouri Department of Conservation (undated, read 2026). Daddy Longlegs (Harvestmen). Missouri Field Guide, mdc.mo.gov."]}

# The Roblox game's own pages, after Godot's, in this order: each carries its id, trigger, title, text, "In this game" line and sources, and docs/NOTEBOOK_SOURCES.md
# says how far each source was checked (ROBLOX-96 adds the ground-life page: the bed's gnats, aphids and woodlice, opened by the first step onto a garden bed).
# ROBLOX-119: the crab spider on the meadow's flowers, opened the first time the spider comes close to one (NotebookWatch.onCrab). Sources opened this round
# (docs/NOTEBOOK_SOURCES.md).
CRAB = {
 'id':'crab_spider','trigger':'crab_spider','title':'The crab spider on the flower',
 'text':"The goldenrod crab spider (Misumena vatia) lives in North America and Europe. Females are 6 to 9 mm long, males 3 to 4 mm. It waits on a flower, usually a yellow or white one, its first two pairs of legs held open, and grabs what comes near, injecting venom with small fangs. It takes flies, bees, butterflies and hoverflies. It can turn from white to yellow to match its flower; that change takes 10 to 25 days, and the change back about six. In North America it is most common on goldenrod.",
 'game':"Here two crab spiders sit on the meadow's flowers, a yellow one on goldenrod and a white one on yarrow, still and nearly the flower's colour, front legs open. Walk or land within their reach and they grab: in Normal that ends the life; on Easy and in free play you drop clear. Their reach and where they sit are the game's.",
 'sources':[
  "Animal Diversity Web, University of Michigan Museum of Zoology (read 2026). Misumena vatia, goldenrod crab spider.",
  "University of Minnesota Extension (undated, read 2026). Goldenrod crab spider.",
  "Wikipedia (read 2026). Misumena vatia."]}

ROBLOX_PAGES = [PEACOCK, ANTMIMIC, MATING, TARANTULA, GROUND_LIFE, SPRINGTAILS, LEAFHOPPERS, MOTHS, CRANE_FLIES, LADYBIRDS, MILLIPEDES, SNAILS, HARVESTMEN, HOVERFLIES, CAT, CRAB]

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    doc = json.loads(SOURCE.read_text(encoding="utf-8"))
    shutil.copyfile(SOURCE, REFERENCE)
    out = [
        "--!strict",
        "-- The naturalist's notebook pages (LEARN-01), GENERATED by tools/gen_notebook_pages.py from the frozen Godot",
        "-- data/notebook/pages.json. Do not edit by hand. Ids, triggers, titles and sources are Godot's, word for word, and so are the texts",
        "-- except four sentences the audit of 2026-10-19 corrected (the generator's TEXT_FIXES): those pages keep Godot's whole text as `godotText`. The pages after",
        "-- Godot's are the Roblox game's own (the generator's ROBLOX_PAGES), with their own triggers.",
        "-- docs/NOTEBOOK_SOURCES.md says how far each source was checked: every citation was confirmed; a few papers were opened and read in part",
        "-- (that file says which and which parts), none was read in full, and the other pages rest on abstracts, search snippets or textbook knowledge.",
        "-- `game` is the page's \"In this game\" line: Godot's own where it is true of the Roblox game, otherwise the Roblox one,",
        "-- with Godot's kept as `godotGame` (tests/notebook.luau lists exactly which). {reel}, {letGo}, {drop}, {focus} and {display} are filled",
        "-- in with the name of that control on the device in use. Pages are listed in Godot's order.",
        "-- Numbers: the thresholds Godot's field_notebook.gd and notebook_watch.gd use for the moments that open a page.",
        "local NotebookPages = {}",
        "",
        "export type Page = { id: string, trigger: string, title: string, text: string, game: string, godotGame: string?, godotText: string?, sources: { string } }",
        "",
        "-- Every trigger a page may name (Godot field_notebook.gd TRIGGERS). \"eye_time_N\": N seconds in the spider-eye view, all told.",
        "NotebookPages.triggers = {",
    ]
    triggers = ["start", "jump", "jump_far", "jump_long", "eye_view", "eye_time_20", "eye_time_60", "shimmer",
                "fly_recognised", "catch", "meal", "felt", "buzz", "rest", "sleep", "hungry", "well_fed",
                "moult_ready", "moulted", "adult", "wasp", "wasp_escaped", "wasp_caught", "starving", "dance", "antennae", "hatched", "tarantula", "garden_bed",
                "look_springtail", "look_leafhopper", "look_moth", "look_crane_fly",
                "look_ladybird", "look_millipede", "look_snail", "look_harvestman", "look_hoverfly", "cat", "crab_spider"]
    out += ["\t" + lua_str(t) + "," for t in triggers]
    out += [
        "}",
        "",
        "-- The reserve at or under hungryAt is \"hungry\"; at or over wellFedAt, \"well fed\" (LIFE_DESIGN.md round 1).",
        "NotebookPages.hungryAt = 0.25",
        "NotebookPages.wellFedAt = 0.85",
        "-- A leap at least this long (studs, launch to landing point; one stud is a centimetre) is far; at least jumpLongWu is long.",
        "NotebookPages.jumpFarWu = 5.0",
        "NotebookPages.jumpLongWu = 8.0",
        "-- Seconds in the spider-eye view, all told, that open the pages named eye_time_N.",
        "NotebookPages.eyeMarks = { 20, 60 }",
        "-- A fly taking off this close (studs) is heard (Godot soundscape.gd HEAR_WU, which gave the caption the buzz page answered to).",
        "NotebookPages.hearWu = 10.0",
        "-- How long the note that a page opened stays on the screen (Godot notebook_panel.gd NOTE_S).",
        "NotebookPages.noteSeconds = 6.0",
        "-- ROBLOX-101: a prey of the bestiary within this many studs of the spider is a close look, which opens its kind's page (`looks`: prey kind -> trigger).",
        "NotebookPages.lookWu = 4.0",
        "-- ROBLOX-105: the ambient bugs' close looks too (NotebookWatch: one of the view's bugs of the kind, out in the open, within lookWu).",
        "NotebookPages.looks = { springtail = \"look_springtail\", leafhopper = \"look_leafhopper\", moth = \"look_moth\", crane_fly = \"look_crane_fly\",",
        "\tladybird = \"look_ladybird\", millipede = \"look_millipede\", snail = \"look_snail\", harvestman = \"look_harvestman\", hoverfly = \"look_hoverfly\" } :: { [string]: string }",
        "",
        "NotebookPages.pages = {",
    ]
    fixed = []
    for p in doc["pages"] + ROBLOX_PAGES:
        adapted = p["id"] in ADAPTED
        game = ADAPTED[p["id"]][0] if adapted else p["game"]
        text = p["text"].replace("You are a bold jumping spider,", "The first spider is inspired by the bold jumping spider,")
        godot_text = None
        if p["id"] in TEXT_FIXES:
            old, new, _why = TEXT_FIXES[p["id"]]
            assert text.count(old) == 1, f"TEXT_FIXES[{p['id']}]: the sentence is not in Godot's text exactly once"
            godot_text, text = text, text.replace(old, new)
            fixed.append(p["id"])
        assert len(text) <= 520, f"page {p['id']} is {len(text)} characters (the limit is 520)"
        out.append("\t{")
        out.append(f"\t\tid = {lua_str(p['id'])},")
        out.append(f"\t\ttrigger = {lua_str(p['trigger'])},")
        out.append(f"\t\ttitle = {lua_str(p['title'])},")
        out.append(f"\t\ttext = {lua_str(text)},")
        out.append(f"\t\tgame = {lua_str(game)},")
        if adapted:
            out.append(f"\t\tgodotGame = {lua_str(p['game'])},")
        if godot_text is not None:
            out.append(f"\t\tgodotText = {lua_str(godot_text)},")
        out.append("\t\tsources = {")
        out += [f"\t\t\t{lua_str(s)}," for s in p["sources"]]
        out.append("\t\t},")
        out.append("\t},")
    out += ["} :: { Page }", "", "return NotebookPages", ""]
    assert sorted(fixed) == sorted(TEXT_FIXES), f"TEXT_FIXES names a page that is not there: {sorted(set(TEXT_FIXES) - set(fixed))}"
    OUT.write_text("\n".join(out), encoding="utf-8", newline="\r\n")
    print("wrote", OUT, len(doc["pages"])+len(ROBLOX_PAGES), "pages;", len(ADAPTED), "with a Roblox 'In this game' line;", len(fixed), "with a corrected text")


main()
