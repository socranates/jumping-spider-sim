from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location("runner",ROOT/"roblox_port/tests/run.py");r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name="../../docs/audit/current-native/readiness-repro.luau";r.CLIENT_TESTS.add(name)
cli=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
with tempfile.NamedTemporaryFile("w",suffix=".luau",encoding="utf8",delete=False) as f:
 f.write(r.bundle(name));temp=Path(f.name)
try:
 result=subprocess.run([str(cli),str(temp)],capture_output=True,text=True)
finally:temp.unlink(missing_ok=True)
(HERE/"candidate.txt").write_text(result.stdout+result.stderr,encoding="utf8",newline="\n")
print(result.stdout+result.stderr);print("REPRO_EXIT="+str(result.returncode))
assert result.returncode==0 and "STREAM_READINESS: 3 passed, 0 failed" in result.stdout,"Candidate must pass all three independent assertions"
receipt={"source":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"runtime_sha256":hashlib.sha256((ROOT/"roblox_port/src/Client/WorldClient.luau").read_bytes()).hexdigest(),"passed":3,"failed":0,"exit":result.returncode,"scope":"CLI component proof: current non-station gate refuses removed/partial geometry and resumes after complete rearrival; no actual network stream-out proven","probe_sha256":hashlib.sha256((ROOT/"docs/audit/current-native/readiness-repro.luau").read_bytes()).hexdigest()}
(HERE/"candidate.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
