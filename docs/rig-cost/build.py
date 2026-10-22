"""Build a local-only rig cost/pose experiment. Never publishes or edits game source."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import shutil
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCE = "3647a94c67f83076a0c7be09d75ef4a60bb0b4d5"
p = argparse.ArgumentParser()
p.add_argument("--rojo", required=True)
p.add_argument("--out", required=True)
a = p.parse_args()
out = Path(a.out).resolve()
assert not out.exists(), "choose a new directory"
out.mkdir(parents=True)
archive = out / "frozen-source.zip"
subprocess.run(["git", "archive", "--format=zip", "--output=" + str(archive), SOURCE, "roblox_port"], cwd=ROOT, check=True)
frozen = out / "frozen-source"
frozen.mkdir()
with zipfile.ZipFile(archive) as z:
    for name in z.namelist():
        target = (frozen / name).resolve()
        assert target == frozen or frozen in target.parents, name
    z.extractall(frozen)
original = frozen / "roblox_port/src/Shared/Rig/SpiderRig.luau"
assert original.read_bytes() == subprocess.check_output(["git", "show", SOURCE + ":roblox_port/src/Shared/Rig/SpiderRig.luau"], cwd=ROOT)
raw = original.read_text(encoding="utf-8")


def replace(text, old, new, count=1):
    assert text.count(old) == count, (old[:100], text.count(old), count)
    return text.replace(old, new)


# A separate instrumented copy. Inclusive leg time contains segment and cast time.
measured = replace(raw, "SpiderRig.__index = SpiderRig", """SpiderRig.__index = SpiderRig
local probe = {setup=0,pose=0,body=0,bodyHair=0,legs=0,bulk=0,segmentBody=0,segmentHair=0,casts=0,castCalls=0,updates=0}
SpiderRig._probe = probe""")
measured = replace(measured, "\tself._t += dt", "\tlocal stamp = os.clock()\n\tprobe.updates += 1\n\tself._t += dt")
for marker, key in [
    ("\tlocal bodyBatch, hairBatch = self._bodyBatch, self._hairBatch", "setup"),
    ("\tfor _, f in self._bodyFixed do\n\t\tlocal group = f.group", "pose"),
    ("\t-- The hairs, in the second batch: a kind", "body"),
    ("\t-- Legs: planted feet stay put in the world;", "bodyHair"),
    ("\tself.placed = bodyBatch.n + hairBatch.n", "legs"),
]:
    measured = replace(measured, marker, f"\tprobe.{key} += os.clock()-stamp; stamp=os.clock()\n" + marker)
measured = replace(measured, "\tend\nend\n\n-- Draws the rig for a frame", "\tend\n\tprobe.bulk += os.clock()-stamp\nend\n\n-- Draws the rig for a frame")
measured = replace(measured, "\tlocal rod, tip, band = seg.rod, seg.tip, seg.band", "\tlocal segmentStamp=os.clock()\n\tlocal rod, tip, band = seg.rod, seg.tip, seg.band")
measured = replace(measured, "\t-- Leg setae stand out from the segment", "\tprobe.segmentBody += os.clock()-segmentStamp; segmentStamp=os.clock()\n\t-- Leg setae stand out from the segment")
measured = replace(measured, "\tend\nend\n\n-- Writes the size a fan part", "\tend\n\tprobe.segmentHair += os.clock()-segmentStamp\nend\n\n-- Writes the size a fan part")
measured = replace(measured, "\t\tlocal hit = Workspace:Raycast(point + up * (0.35 * k), -up * (1.0 * k), self._params)", "\t\tlocal castStamp=os.clock()\n\t\tlocal hit = Workspace:Raycast(point + up * (0.35 * k), -up * (1.0 * k), self._params)\n\t\tprobe.casts += os.clock()-castStamp; probe.castCalls += 1")

# Experimental copy only: cache a hair's invariant local rotation, preserving all
# geometry, lengths, scaling, update thresholds and existing batch submissions.
cached = replace(raw, "dir: Vector3 }", "dir: Vector3, rotation: CFrame }")
cached = replace(cached, "local entry: LegHair = {", "local entry: LegHair = { rotation = CFrame.identity,", count=2)
cached = replace(cached, "\t\t\t\ttable.insert(leg.hairs, entry)", "\t\t\t\tentry.rotation = CFrame.lookAt(Vector3.zero, entry.dir, Vector3.xAxis)\n\t\t\t\ttable.insert(leg.hairs, entry)", count=2)
cached = replace(cached, "rc * CFrame.lookAt(base + dir * (spec.length * g * 0.5), base + dir * spec.length*g, Vector3.xAxis)", "rc * (hair.rotation + (base + dir * (spec.length * g * 0.5)))")
for name, text in [("RigMeasured", measured), ("RigCached", cached)]:
    (out / (name + ".luau")).write_text(text, encoding="utf-8", newline="\n")

# A second Rig node beside the directory-backed Shared path creates duplicate
# folders in Rojo, even though every script path remains unique. Use one tree.
shared = out / "shared-source"
shutil.copytree(frozen / "roblox_port/src/Shared", shared)
for name in ("RigMeasured", "RigCached"):
    shutil.copyfile(out / (name + ".luau"), shared / "Rig" / (name + ".luau"))

project = {"name": "WindowsillRigExperimentNeverPublish", "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {"Shared": {"$path": str(shared)}},
    "StarterPlayer": {"StarterPlayerScripts": {"RigExperiment": {"$path": str(HERE / "driver.client.luau")}}},
    "Players": {"$properties": {"CharacterAutoLoads": False}},
    "Workspace": {"$properties": {"StreamingEnabled": False}, "$attributes": {"RigExperiment": True, "RigSource": SOURCE}},
}}
config = out / "rig.project.json"
config.write_text(json.dumps(project, indent=2), encoding="utf-8", newline="\n")
place = out / "Windowsill-rig-experiment.rbxlx"
subprocess.run([a.rojo, "build", str(config), "-o", str(place)], check=True)

import xml.etree.ElementTree as ET
root = ET.parse(place).getroot()
rows = []
instance_paths = set()


def walk(item, path=""):
    props = item.find("Properties")
    name = props.find("string[@name='Name']").text
    path = path + "." + name if path else name
    assert path not in instance_paths, "duplicate instance path: " + path
    instance_paths.add(path)
    code = props.find("*[@name='Source']")
    if code is not None:
        text = (code.text or "").replace("\r\n", "\n").encode()
        rows.append({"path": path, "bytes": len(text), "adler32": zlib.adler32(text), "sha256": hashlib.sha256(text).hexdigest()})
    for child in item.findall("Item"):
        walk(child, path)


for item in root.findall("Item"):
    walk(item)
assert len(rows) > 100 and len({r["path"] for r in rows}) == len(rows), "missing/duplicate source fingerprints"
assert any(r["path"] == "ReplicatedStorage.Shared.Rig.SpiderRig" for r in rows)
# Also bind every shared production dependency, not just the primary rig.
for file in (frozen / "roblox_port/src/Shared").rglob("*.luau"):
    rel = file.relative_to(frozen).as_posix()
    assert file.read_bytes() == subprocess.check_output(["git", "show", SOURCE + ":" + rel], cwd=ROOT), rel
guard = 'assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("RigExperiment")==true);local expected={'
guard += ",".join("{" + json.dumps(r["path"]) + "," + str(r["bytes"]) + "," + str(r["adler32"]) + "}" for r in rows) + "};"
guard += 'for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local n=0;for _,root in {game.ReplicatedStorage.Shared,game.StarterPlayer.StarterPlayerScripts} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected and #game.ServerScriptService:GetChildren()==0 and #game.ReplicatedFirst:GetChildren()==0);print("[CHET_RIG_GUARD]",workspace:GetAttribute("RigSource"),n)'
(out / "guard.luau").write_text(guard, encoding="utf-8", newline="\n")
manifest = {"source": SOURCE, "place_sha256": hashlib.sha256(place.read_bytes()).hexdigest(),
            "scripts": rows, "builder_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "scope": "Isolated CPU/pose experiment; not whole-game FPS, save verification or release"}
(out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"place": str(place), "scripts": len(rows), "sha256": manifest["place_sha256"]}))
