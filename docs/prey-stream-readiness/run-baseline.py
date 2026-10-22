from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location("runner",ROOT/"roblox_port/tests/run.py");r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
assert not (HERE/"baseline.txt").exists(),"Preserve the recorded baseline; replay in an isolated archive"
expected=subprocess.check_output(["git","show","e51c546:roblox_port/src/Shared/Prey/PreyWorld.luau"],cwd=ROOT)
assert (ROOT/"roblox_port/src/Shared/Prey/PreyWorld.luau").read_bytes()==expected,"Baseline requires unchanged e51c546 runtime"
name="../../docs/prey-stream-readiness/probe-baseline.luau";r.CLIENT_TESTS.add(name)
cli=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
with tempfile.NamedTemporaryFile("w",suffix=".luau",encoding="utf8",delete=False) as f:f.write(r.bundle(name));temp=Path(f.name)
try:result=subprocess.run([str(cli),str(temp)],capture_output=True,text=True)
finally:temp.unlink(missing_ok=True)
text=result.stdout+result.stderr;assert "PREY_STREAM:" in text,"harness failed before assertions"
(HERE/"baseline.txt").write_text(text,encoding="utf8",newline="\n");print(text);print("PROBE_EXIT="+str(result.returncode))
receipt=dict(source=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),runtime_source="e51c546bde74ee41d07c6c8f08f26a10dd193a14",exit=result.returncode,probe_sha256=hashlib.sha256((HERE/"probe-baseline.luau").read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256((ROOT/"roblox_port/src/Shared/Prey/PreyWorld.luau").read_bytes()).hexdigest(),output_sha256=hashlib.sha256(text.encode()).hexdigest(),scope="Existing cached-population before/after/view behavior under CLI shim, not engine streaming")
(HERE/"baseline.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
