"""Use the production template builder with the real private recovery adapters."""
from pathlib import Path
import hashlib, importlib.util, json, re, subprocess, sys, tempfile
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
PRIVATE = ROOT / "docs/save-slot-isolation"
TOOLS = Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools")

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

def build(focused=False):
    prior = load("replacement_runner", PRIVATE / "run-replacement.py")
    runner = load("game_runner", ROOT / "roblox_port/tests/run.py")
    bundle, inputs = prior.build()
    body = (PRIVATE / "replacement-tests.luau").read_text(encoding="utf8")
    prefix = body.split('-- A player can leave before a cooperative initial factory', 1)[0]
    assert prefix != body and prefix.endswith(' return f\nend\n')
    prefix = prefix.replace("runReplacementChecks", "runServerTemplateRecoveryChecks", 1)
    setup = '''local Templates=require("../src/Server/RecoveryTemplates")
local Build=require("../src/Shared/World/WorldBuild")
WorldMap.use("preserve")
local authoredRoot=Instance.new("Folder");authoredRoot.Name="AuthoritativeRecoveryGeometry";authoredRoot.Parent=workspace
Build.region(assert(WorldMap.region(WorldMap.HOME)),authoredRoot)
local cache,problem=Templates.new(authoredRoot);assert(cache,problem)
local initialProfiles=assert(cache:profiles())
local authoredBytes={};for _,mode in Rules.MODES do authoredBytes[mode]=Json.canonical(initialProfiles[mode].template) end
'''
    prefix = prefix.replace("local count=0\n", "local count=0\n" + setup, 1)
    start = prefix.index("   local profiles={}\n", prefix.index("ownerFactory=function"))
    stop = prefix.index("   local deps=", start)
    prefix = prefix[:start] + "   local profiles=assert(cache:profiles())\n" + prefix[stop:]
    prefix = prefix.replace('..tostring(f.owner.runtime.problem))', '..tostring(f.owner.runtime.problem).." entry="..tostring(f.owner.runtime.entryJob and f.owner.runtime.entryJob.problem).." client="..tostring(client.replacementProblem))')
    suffix = '''for _,mode in Rules.MODES do
 local f=fixture();f.recover(mode)
 check(f.adoptions==1 and f.world.life.recoveryHistory~=nil and f.world.garden~=nil,"authored template did not enter actual recovered life")
 local record=assert(Checkpoint.capture(f.world,f.clock.now))
 check(f.client:sendRest(mode,record),"authored recovered life refused its next rest")
 f.drive(function() local r=f.client.bound.requests[mode];return r.candidate and r.candidate.stored end)
 check(f.owner.session.intents.requests[mode].storedSerial==1,"authored life lacked real stored acknowledgement")
 f.begin();f.drive(function() return f.client.transition==nil and #f.owners==2 end)
 check(nonP(f.b)==f.before and f.oldOwner:replacementClosed(),"authored profile replacement changed durable lives")
 local rows=assert(cache:profiles())
 for _,slot in Rules.MODES do check(Json.canonical(rows[slot].template)==authoredBytes[slot],"recovery/rest/replacement mutated cached authored template") end
 f.server:removePlayer(f.player)
 check(f.owner.session.closed,"authored fresh owner did not close")
 print("SERVER_TEMPLATE_RECOVERY mode="..mode.." authored_geometry=true actual_entry=true stored_rest=true replacement=true cache_unchanged=true")
end
cache:close();authoredRoot:Destroy()
print("SERVER_TEMPLATE_RECOVERY passed="..count.." failed=0")
end
runServerTemplateRecoveryChecks()
end
'''
    test = prefix + suffix
    assert bundle.endswith("end\n")
    bundle = bundle[:-4] + runner.requires(test) + "\nend\n"
    if focused:
        bundle = re.sub(r"\n(run\w+Checks)\(\)\nend", lambda m:"\n-- focused: skip " + m[1] + "\nend" if m[1] != "runServerTemplateRecoveryChecks" else m[0], bundle)
    return bundle, inputs, test

def main():
    prefix = sys.argv[1]; assert prefix.replace("-", "").isalnum()
    focused = "--focused" in sys.argv[2:]
    out = H / (prefix + "-output.txt"); assert not out.exists(), "Preserve prior evidence"
    bundle, inputs, test = build(focused)
    (H / (prefix + "-test.luau")).write_text(test, encoding="utf8", newline="\n")
    sha = lambda b:hashlib.sha256(b).hexdigest()
    inputs = list(dict.fromkeys(inputs))
    hashes = {p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
    production = {p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ["roblox_port/src", "roblox_port/tests"] for p in (ROOT / folder).rglob("*") if p.is_file() and "__pycache__" not in p.parts}
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf8", delete=False) as f:
        f.write(bundle); path = Path(f.name)
    try:
        result = subprocess.run([str(TOOLS / "luau/luau.exe"), str(path)], capture_output=True, text=True)
    finally:
        path.unlink(missing_ok=True)
    assert hashes == {p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
    assert production == {p:sha((ROOT / p).read_bytes()) for p in production}
    output = result.stdout + result.stderr; out.write_text(output, encoding="utf8", newline="\n")
    dirty = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT).returncode != 0
    receipt = dict(source=subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT, text=True).strip(), focused=focused, exit_code=result.returncode, source_uncommitted=dirty, inputs=hashes, production_inputs=production, generated_test_sha256=sha(test.encode()), bundle_sha256=sha(bundle.encode()), output_sha256=sha(output.encode()), ordinary_engine_recovery_installed=False, native_verified=False, real_datastore_verified=False, published=False)
    (H / (prefix + "-receipt.json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf8", newline="\n")
    print(output, flush=True); raise SystemExit(result.returncode)

if __name__ == "__main__":
    main()
