from pathlib import Path
import runpy,subprocess,tempfile,json,hashlib,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
r=runpy.run_path(str(ROOT/"roblox_port/tests/run.py"))
original=(ROOT/"roblox_port/tests/state.luau").read_text(encoding="utf8")
body=r["requires"](original)+"\n";bundle=r["bundle"]("state.luau");assert bundle.endswith(body)
probe=(HERE/"known-life-probe.luau").read_text(encoding="utf8")
bundle=bundle[:-len(body)]+r["requires"](probe)
files=list((ROOT/"roblox_port/src").rglob("*.luau"))
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
luau=Path(r"C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\luau\luau.exe")
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/"probe.luau";p.write_text(bundle,encoding="utf8",newline="\n")
 result=subprocess.run([str(luau),str(p)],capture_output=True,text=True)
(HERE/"known-life-candidate.txt").write_text(result.stdout+result.stderr,encoding="utf8",newline="\n")
(HERE/"known-life-candidate-process.json").write_text(json.dumps({"exit_code":result.returncode,"probe_sha256":hashlib.sha256(probe.encode()).hexdigest(),"inputs":inputs},indent=2)+"\n",encoding="utf8",newline="\n")
print(result.stdout);print("exit",result.returncode)
assert result.returncode==0
