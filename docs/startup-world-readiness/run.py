from pathlib import Path
import argparse,subprocess,tempfile,tarfile,io,shutil,runpy,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
BASE="6026d6c45fbad072c2bec14a3b893fb8e7abccc2"
p=argparse.ArgumentParser();p.add_argument("phase",choices=["baseline","candidate"]);p.add_argument("--suite",choices=["world_client.luau","title.luau"],default="world_client.luau");p.add_argument("--luau");a=p.parse_args()
TOOL=Path(a.luau) if a.luau else Path(r"C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\luau\luau.exe")
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder);src=snap/"roblox_port/src";tests=snap/"roblox_port/tests"
 if a.phase=="baseline":
  archive=subprocess.check_output(["git","archive","--format=tar",BASE,"roblox_port/src"],cwd=ROOT)
  with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
   for item in tree:
    assert item.isfile() or item.isdir()
    if not item.isfile():continue
    assert item.name.startswith("roblox_port/src/") and ".." not in Path(item.name).parts
    dest=snap/item.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(tree.extractfile(item).read())
 else:shutil.copytree(ROOT/"roblox_port/src",src)
 shutil.copytree(ROOT/"roblox_port/tests",tests)
 files=list(src.rglob("*.luau"))+[tests/a.suite]
 hashes={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
 runner=runpy.run_path(str(tests/"run.py"));code=runner["bundle"](a.suite)
 bundle=snap/"bundle.luau";bundle.write_text(code,encoding="utf8",newline="\n")
 prefix="title-" if a.suite=="title.luau" else ""
 with (OUT/(prefix+a.phase+".txt")).open("w",encoding="utf8",newline="\n") as log:result=subprocess.run([str(TOOL),str(bundle)],stdout=log,stderr=subprocess.STDOUT)
 (OUT/(prefix+a.phase+"-process.json")).write_text(json.dumps({"exit_code":result.returncode,"inputs":hashes,"suite":a.suite,"source_snapshot":BASE if a.phase=="baseline" else "worktree"},indent=2)+"\n",encoding="utf8",newline="\n")
 print(a.phase,a.suite,"exit",result.returncode,flush=True)
 assert (result.returncode!=0) if a.phase=="baseline" else result.returncode==0
