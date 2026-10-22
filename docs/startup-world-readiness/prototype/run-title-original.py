from pathlib import Path
import subprocess,sys,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
phase=sys.argv[1];assert phase in {"baseline","candidate"}
TOOL=Path(r"C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\luau\luau.exe")
files=list((ROOT/"roblox_port/src").rglob("*.luau"))+[ROOT/"roblox_port/tests/title.luau"]
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
with (OUT/("title-"+phase+".txt")).open("w",encoding="utf8",newline="\n") as log:
 result=subprocess.run([sys.executable,str(ROOT/"roblox_port/tests/run.py"),str(TOOL),"title.luau"],stdout=log,stderr=subprocess.STDOUT,cwd=ROOT)
(OUT/("title-"+phase+"-process.json")).write_text(json.dumps({"exit_code":result.returncode,"inputs":hashes},indent=2)+"\n",encoding="utf8",newline="\n")
print(phase,"exit",result.returncode,flush=True)
assert (result.returncode!=0) if phase=="baseline" else result.returncode==0
