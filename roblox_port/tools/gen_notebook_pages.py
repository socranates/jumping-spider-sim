#!/usr/bin/env python3
"""Generates src/Shared/Data/NotebookPages.luau from the frozen Godot data/notebook/pages.json (LEARN-01) and copies that file to
tests/notebook_reference.json (then tools/reference_to_luau.py makes tests/notebook_reference.luau) so tests/notebook.luau can check
the port against Godot's own words. Ids, triggers, titles, texts and sources are carried over verbatim. The "In this game" line is
Godot's too except where the Roblox game differs: those pages are listed in ADAPTED below with the reason, and the generated page then
also carries Godot's line as `godotGame`. A line may name a control as {reel}, {letGo}, {drop} or {focus}; the panel fills in the
name for the device in use (ControlText).
Usage (from roblox_port/):  python3 tools/gen_notebook_pages.py"""
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
    "legs_push": ("The drawn spider does not yet show its back legs pushing off.",
                  "Roblox's rig has no take-off leg pose (ROBLOX_PORT.md: hydraulic push/landing pose parity is partial)."),
    "green_uv": ("A screen cannot show ultraviolet, so the eye view shows it as violet, and only the principal eyes see it ({focus}).",
                 "Roblox's eye view has a violet ultraviolet layer; it does not say 'UV not simulated'."),
    "hungry_at_home": ("Here hunger shows in the spider's thinner abdomen and in the words under the day. A spider that goes too long without food starves, except on Easy and in free play.",
                       "Godot's line says a reserve that runs out does not yet end a life, which the later rounds (and Roblox) made untrue."),
    "mud_dauber": ("You hear the wasp before it reaches the sill. The silk-lined crack is safe. Keeping still makes you hard to notice, and a jump or a drop on your line breaks its approach.",
                   "Roblox has no wasp shadow or felt landing (no vibration sense yet)."),
    "what_the_wasp_does": ("Being caught ends this spider's life. You can go back to your last rest, if you have one, or continue as another spider.",
                           "Roblox's catch screen offers the last rest or another spider."),
}


# Reconciled with the Windows notebook implementation; the JSON remains a frozen reference.
EXTRA_ADAPTED = {
 "bold_jumper": "The first spider is inspired by the bold jumper. The peacock is a different species with the same game rules. Our models and three growth stages are stylised; one stud represents a centimetre.",
 "hearing": "Buzzing is a human-audible cue, not a recording of what a spider experiences.",
 "home_before_dark": "Rest in the crack in the evening to sleep until morning. A day lasts about fifteen minutes of active play.",
 "new_skin": "Your spider is pale and its jumps shorter while its skin hardens. The ten game-hour timing is a design choice. The empty skin stays in the crack.",
 "grown_up": "The game compresses growth into three moults. Adulthood in a Standard main life opens Easy for this session. The male peacock look and dance are cosmetic choices at every gameplay stage.",
 "what_the_wasp_does": "A catch ends a Standard life. Return to your last rest or continue as an unrelated spider. In gentle Free play the wasp only touches and leaves.",
}
for key, line in EXTRA_ADAPTED.items():
 ADAPTED[key] = (line, "Keep the current Roblox rules and artistic choices explicit.")
PEACOCK = {
 'id':'peacock_dance','trigger':'dance','title':'A fan and a dance',
 'text':'A male peacock spider, Maratus volans, unfolds colourful flaps on its abdomen and waves its third pair of legs during courtship. The display also sends vibrations through the surface beneath it. It is a message to a female, not just a dance people can see.',
 'game':'Our repeating dance is inspired by recorded displays. Its size, colour, timing and movement are stylised. There is no mating simulation, and the cosmetic dance is available at every gameplay growth stage.',
 'sources':['Girard, M. B., Kasumovic, M. M. & Elias, D. O. (2011). Multi-Modal Courtship in the Peacock Spider, Maratus volans. PLoS ONE 6(9): e25390. https://doi.org/10.1371/journal.pone.0025390']}

ANTMIMIC = {
 'id':'walking_like_an_ant','trigger':'antennae','title':'Walking like an ant',
 'text':"Myrmarachne formicaria is a jumping spider that mimics an ant. It walks on all eight legs, and when it stands still it raises its front legs above its head and moves them together, like an ant's antennae. It makes only short stops, about 83 milliseconds on average, so it seems to move almost constantly, as ants do. In tests with Phidippus audax as the predator, ordinary spider targets were attacked 4.5 times as often as ants and 3 times as often as mimics; ants and mimics did not differ.",
 'game':"The ant mimic is a look only: where you go, how fast and what the wasp does are the first spider's. Its front legs rise when you keep still, and a stop shorter than about 83 milliseconds is not drawn as a pause. The waving, the sway of the body as it walks, the colours and the size are stylised: the real mimic's wobbling path is not walked. The female is drawn.",
 'sources':["Shamble, P. S., Hoy, R. R., Cohen, I. & Beatus, T. (2017). Walking like an ant: a quantitative and experimental approach to understanding locomotor mimicry in the jumping spider Myrmarachne formicaria. Proceedings of the Royal Society B 284: 20170308. https://doi.org/10.1098/rspb.2017.0308"]}

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    doc = json.loads(SOURCE.read_text(encoding="utf-8"))
    shutil.copyfile(SOURCE, REFERENCE)
    out = [
        "--!strict",
        "-- The naturalist's notebook pages (LEARN-01), GENERATED by tools/gen_notebook_pages.py from the frozen Godot",
        "-- data/notebook/pages.json. Do not edit by hand. Ids, triggers, titles, texts and sources are Godot's, word for word",
        "-- (docs/NOTEBOOK_SOURCES.md says how far each source was checked: citations were confirmed, no paper was read in full).",
        "-- `game` is the page's \"In this game\" line: Godot's own where it is true of the Roblox game, otherwise the Roblox one,",
        "-- with Godot's kept as `godotGame` (tests/notebook.luau lists exactly which). {reel}, {letGo}, {drop} and {focus} are filled",
        "-- in with the name of that control on the device in use. Pages are listed in Godot's order.",
        "-- Numbers: the thresholds Godot's field_notebook.gd and notebook_watch.gd use for the moments that open a page.",
        "local NotebookPages = {}",
        "",
        "export type Page = { id: string, trigger: string, title: string, text: string, game: string, godotGame: string?, sources: { string } }",
        "",
        "-- Every trigger a page may name (Godot field_notebook.gd TRIGGERS). \"eye_time_N\": N seconds in the spider-eye view, all told.",
        "NotebookPages.triggers = {",
    ]
    triggers = ["start", "jump", "jump_far", "jump_long", "eye_view", "eye_time_20", "eye_time_60", "shimmer",
                "fly_recognised", "catch", "meal", "felt", "buzz", "rest", "sleep", "hungry", "well_fed",
                "moult_ready", "moulted", "adult", "wasp", "wasp_escaped", "wasp_caught", "starving", "dance", "antennae"]
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
    for p in doc["pages"] + [PEACOCK, ANTMIMIC]:
        adapted = p["id"] in ADAPTED
        game = ADAPTED[p["id"]][0] if adapted else p["game"]
        out.append("\t{")
        out.append(f"\t\tid = {lua_str(p['id'])},")
        out.append(f"\t\ttrigger = {lua_str(p['trigger'])},")
        out.append(f"\t\ttitle = {lua_str(p['title'])},")
        out.append(f"\t\ttext = {lua_str(p['text'].replace('You are a bold jumping spider,', 'The first spider is inspired by the bold jumping spider,'))},")
        out.append(f"\t\tgame = {lua_str(game)},")
        if adapted:
            out.append(f"\t\tgodotGame = {lua_str(p['game'])},")
        out.append("\t\tsources = {")
        out += [f"\t\t\t{lua_str(s)}," for s in p["sources"]]
        out.append("\t\t},")
        out.append("\t},")
    out += ["} :: { Page }", "", "return NotebookPages", ""]
    OUT.write_text("\n".join(out), encoding="utf-8", newline="\r\n")
    print("wrote", OUT, len(doc["pages"])+2, "pages;", len(ADAPTED), "with a Roblox 'In this game' line")


main()
