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
 'game':"A game day is about fifteen minutes, so weeks become days: a mate on the sill, a courtship you hold for eight seconds, one night to the sac and two guard days. The real mother makes and guards the sac; here the sac is drawn the same whichever spider you play, and no claim is made that a male guards eggs. A real brood is far larger than the eight to twelve shown: a Phidippus johnsoni female laid about 200 eggs in all. The first spider's sex is the game's choice (a female), and the peacock spider's mate is drawn with the male's colours although the real female is mottled grey-brown. Nothing can harm the sac, and you carry on as one of the spiderlings, which a real one could not choose.",
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

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    doc = json.loads(SOURCE.read_text(encoding="utf-8"))
    shutil.copyfile(SOURCE, REFERENCE)
    out = [
        "--!strict",
        "-- The naturalist's notebook pages (LEARN-01), GENERATED by tools/gen_notebook_pages.py from the frozen Godot",
        "-- data/notebook/pages.json. Do not edit by hand. Ids, triggers, titles and sources are Godot's, word for word, and so are the texts",
        "-- except four sentences the audit of 2026-10-19 corrected (the generator's TEXT_FIXES): those pages keep Godot's whole text as `godotText`.",
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
                "moult_ready", "moulted", "adult", "wasp", "wasp_escaped", "wasp_caught", "starving", "dance", "antennae", "hatched", "tarantula"]
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
        "",
        "NotebookPages.pages = {",
    ]
    fixed = []
    for p in doc["pages"] + [PEACOCK, ANTMIMIC, MATING, TARANTULA]:
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
    print("wrote", OUT, len(doc["pages"])+4, "pages;", len(ADAPTED), "with a Roblox 'In this game' line;", len(fixed), "with a corrected text")


main()
