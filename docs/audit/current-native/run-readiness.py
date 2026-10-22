from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location("runner",ROOT/"roblox_port/tests/run.py");r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name="../../docs/audit/current-native/readiness-repro.luau";r.CLIENT_TESTS.add(name)
cli=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
with tempfile.NamedTemporaryFile("w",suffix=".luau",encoding="utf8",delete=False) as f:
 f.write(r.bundle(name));temp=Path(f.name)
try:
 result=subprocess.run([str(cli),str(temp)],capture_output=True,text=True)
finally:temp.unlink(missing_ok=True)
(HERE/"readiness-baseline.txt").write_text(result.stdout+result.stderr,encoding="utf8",newline="\n")
print(result.stdout+result.stderr);print("REPRO_EXIT="+str(result.returncode))
assert result.returncode!=0 and "STREAM_READINESS: 0 passed, 3 failed" in result.stdout,"Expected the three old-cache failures"
receipt={"source":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"runtime_source":"068a87891770dbdf291ec3cab0e67480d14c0251","passed":0,"failed":3,"exit":result.returncode,"scope":"CLI component proof: already-cached non-station creature gate permits missing/partial geometry; no actual stream-out engine behavior proven","probe_sha256":hashlib.sha256((HERE/"readiness-repro.luau").read_bytes()).hexdigest()}
(HERE/"readiness-baseline.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
