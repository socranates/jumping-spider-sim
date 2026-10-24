"""Retain the completed, failed full run before changing its input files."""
from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent;PORT=H.parents[1]/'roblox_port'
sha=lambda b:hashlib.sha256(b).hexdigest()
data=(H/'ground-checks/full-cli.txt').read_bytes()
counts=[(m[1].strip(),int(m[2]),int(m[3]))for m in re.finditer(r'^([^\n]*?)passed=(\d+) failed=(\d+)[^\n]*$',data.decode(),re.M)]
assert len(counts)==79
assert [(n,f)for n,p,f in counts if f]==[('SELFTEST_PRESERVE',4),('LIVING_WORLD',20)]
record=dict(exit_code=1,suite_count=79,summaries=counts,log_sha256=sha(data),
 inputs={f.relative_to(PORT).as_posix():sha(f.read_bytes())for folder in ['src','tests']for f in (PORT/folder).rglob('*')if f.is_file()and '__pycache__'not in f.parts},
 limits='Completed ordinary Windows full-run failure. Input hashes captured at completion before any subsequent source/test edits. Retained as failed; no native or release qualification.')
target=H/'ground-checks/failed-full-receipt.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print([(n,p,f)for n,p,f in counts if f])
