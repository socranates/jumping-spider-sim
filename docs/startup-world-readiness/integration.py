from pathlib import Path
import subprocess,sys,json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
names=["client_smoke.luau","preserve.luau"]
files=list((ROOT/"roblox_port/src").rglob("*.luau"))+[ROOT/"roblox_port/tests"/name for name in names]
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
tool=Path(r"C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\luau\luau.exe")
with (HERE/"integration.txt").open("w",encoding="utf8",newline="\n") as log:
 result=subprocess.run([sys.executable,str(ROOT/"roblox_port/tests/run.py"),str(tool),*names],stdout=log,stderr=subprocess.STDOUT,cwd=ROOT)
(HERE/"integration-process.json").write_text(json.dumps({"exit_code":result.returncode,"suites":names,"inputs":inputs},indent=2)+"\n",encoding="utf8",newline="\n")
print("integration exit",result.returncode,flush=True);assert result.returncode==0
