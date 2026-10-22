"""Package tracked active Roblox material and bounded verification docs; never publish."""
from pathlib import Path
import hashlib,json,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
DEST=Path(r"C:\Users\natha\claude-xfer\Windowsill-save-slot-isolation-1984fdd8e8dee0ad-native-verified.zip")
refs={".gitattributes",".gitignore",".github/workflows/roblox-port.yml","README.md","docs/DECISIONS.md","docs/NOTEBOOK_SOURCES.md","data/notebook/pages.json","chet/foundation-audit.md","chet/save-compaction.md","chet/life-retirement.md","chet/save-adapter-errors.md","chet/save-slot-isolation.md"}
prefixes=("roblox_port/","docs/audit/","docs/save-compaction/","docs/life-retirement/","docs/save-adapter-errors/","docs/save-slot-isolation/","docs/performance-pass/")
paths=set(subprocess.check_output(["git","ls-files"],cwd=ROOT,text=True).splitlines())
paths.update(p.relative_to(ROOT).as_posix() for p in OUT.rglob("*") if p.is_file() and "__pycache__" not in p.parts)
paths.add("chet/save-slot-isolation.md")
paths=sorted(n for n in paths if (n in refs or n.startswith(prefixes)) and not n.endswith("/portable-package.json"))
manifest={"source_commit":"3647a94c67f83076a0c7be09d75ef4a60bb0b4d5","evidence_id":"1984fdd8e8dee0ad","published":False,"files":[]}
assert json.loads((OUT/"receipt.json").read_text(encoding="utf-8"))["offline_gates_pass"],"offline source or regression gates incomplete or failed"
DEST.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(DEST,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for name in paths:
  raw=(ROOT/name).read_bytes();z.writestr(name,raw)
  manifest["files"].append({"path":name,"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()})
 z.writestr("SAVE_SLOT_PACKAGE_MANIFEST.json",json.dumps(manifest,indent=2)+"\n")
with zipfile.ZipFile(DEST) as z:
 assert z.testzip() is None
 for row in manifest["files"]:assert hashlib.sha256(z.read(row["path"])).hexdigest()==row["sha256"]
receipt={"path":str(DEST),"files":len(paths)+1,"bytes":DEST.stat().st_size,"sha256":hashlib.sha256(DEST.read_bytes()).hexdigest()}
(OUT/"portable-package.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps(receipt,indent=2))
