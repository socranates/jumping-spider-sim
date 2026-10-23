"""All-slot owner tests plus the unchanged preceding private recovery cohort."""
from pathlib import Path
import hashlib, importlib.util, json, re, subprocess, sys, tempfile
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
TOOLS = Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools")

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def build(focused=False):
    prior = load("game_entry_runner", H / "run-recovery-game-entry.py")
    runner = load("game_runner", ROOT / "roblox_port/tests/run.py")
    text, inputs = prior.build()
    assert text.endswith("end\n")
    text = text[:-4]
    module = H / "recovery-profile-owner-prototype.luau"
    code = module.read_text(encoding="utf8")
    for name, var in [("RecoveryServiceOwnerPrototype", "__serviceOwnerPrototype"), ("RecoveryPipelinePrototype", "__pipelinePrototype"), ("RecoveryReadLeasePrototype", "__readLeasePrototype")]:
        code = code.replace("require(script.Parent." + name + ")", var)
    text += "local __profileOwnerPrototype=(function()\n" + runner.requires(runner.strict(code)) + "\nend)()\n"
    tests = [H / "recovery-profile-owner-tests.luau", H / "recovery-profile-service-tests.luau"]
    for test in tests:
        text += runner.requires(test.read_text(encoding="utf8")) + "\n"
    text += "end\n"
    if focused:
        text = re.sub(r"\n(run\w+Checks)\(\)\nend", lambda m: "\n-- focused: skip " + m[1] + "\nend" if m[1] not in {"runProfileOwnerChecks", "runProfileServiceChecks"} else m[0], text)
    return text, inputs + [module] + tests

def main():
    prefix = sys.argv[1]
    assert prefix.replace("-", "").isalnum()
    focused = "--focused" in sys.argv[2:]
    out = H / (prefix + "-output.txt")
    assert not out.exists(), "Preserve prior evidence"
    text, inputs = build(focused)
    sha = lambda b: hashlib.sha256(b).hexdigest()
    inputs = list(dict.fromkeys(inputs))
    hashes = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in inputs}
    production = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for folder in ["roblox_port/src", "roblox_port/tests"] for p in (ROOT / folder).rglob("*") if p.is_file() and "__pycache__" not in p.parts}
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf8", delete=False) as f:
        f.write(text)
        path = Path(f.name)
    try:
        result = subprocess.run([str(TOOLS / "luau/luau.exe"), str(path)], capture_output=True, text=True)
    finally:
        path.unlink(missing_ok=True)
    assert hashes == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in inputs}
    assert production == {p: sha((ROOT / p).read_bytes()) for p in production}
    output = result.stdout + result.stderr
    out.write_text(output, encoding="utf8", newline="\n")
    receipt = dict(source=subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT, text=True).strip(), focused=focused, exit_code=result.returncode, inputs=hashes, production_inputs=production, bundle_sha256=sha(text.encode()), output_sha256=sha(output.encode()), production_connected=False, native_verified=False, real_datastore_verified=False, published=False)
    (H / (prefix + "-receipt.json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf8", newline="\n")
    print(output, flush=True)
    raise SystemExit(result.returncode)

if __name__ == "__main__":
    main()
