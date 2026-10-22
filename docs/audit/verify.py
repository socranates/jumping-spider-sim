"""Compile current source and summarize audit evidence without publishing.
Run from anywhere with --compiler PATH. Final CLI/CI/native evidence may be
absent: the receipt explicitly keeps those gates false until present.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--compiler',required=True)
args=parser.parse_args()
compiled=[]
for source in sorted((ROOT/'roblox_port/src').rglob('*.luau')):
    result=subprocess.run([args.compiler,'-O0','--null',str(source)],capture_output=True,text=True)
    compiled.append(dict(path=source.relative_to(ROOT).as_posix(),exit_code=result.returncode,
                         sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
    if result.returncode:
        print(source, result.stderr)
(OUT/'compile-final.json').write_text(json.dumps(compiled,indent=2),encoding='utf-8')
text=(OUT/'cli-final-1.txt').read_text(encoding='utf-8') if (OUT/'cli-final-1.txt').exists() else ''
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
failures=[line for line in text.splitlines() if re.search(r'\bfailed=[1-9]|^FAIL |\[SELFTEST\] FAIL|not enough memory',line)]
ci=json.loads((OUT/'ci-final.json').read_text()) if (OUT/'ci-final.json').exists() else None
process=json.loads((OUT/'cli-final-process.json').read_text()) if (OUT/'cli-final-process.json').exists() else None
manifest=json.loads((OUT/'source-manifest.json').read_text())
source_matches=all(hashlib.sha256((ROOT/'roblox_port'/row['path']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==row['sha256'] for row in manifest['files'])
port=ROOT/'roblox_port'
evidence_hash=hashlib.sha256()
for path in sorted([*port.glob('src/**/*.luau'),*port.glob('tests/**/*.luau'),*port.glob('*.project.json')]):
    if path.name!='BuildInfo.luau':
        evidence_hash.update(path.relative_to(port).as_posix().encode()+b'\0'+path.read_bytes()+b'\0')
actual_evidence=evidence_hash.hexdigest()[:16]
receipt=dict(baseline=dict(release='v51',place_version=140,source_commit='14e60991c785c4293c3560e6d8b7ecded7e7ac75',evidence_id='d9ddc5e0ed43d301'),
             candidate=dict(branch='codex/foundation-audit',source_commit='5ee048a791da5fa4f5b99aac53d9769bcd358845',evidence_id='c7af2726574c44cc'),
             published=False,compile=dict(passed=sum(x['exit_code']==0 for x in compiled),total=len(compiled),optimization=0),
             local_cli=dict(completed_summaries=len(rows),passed=sum(int(x[1]) for x in rows),failed=sum(int(x[2]) for x in rows),failure_lines=failures),
             ci=ci,local_process=process,source_manifest_matches=source_matches,computed_evidence_id=actual_evidence,
             builds=[dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in [port/'TheWindowsill.rbxlx',port/'TheWindowsillTests.rbxlx']],
             native=None,performance_matrix_complete=False,physical_phone_tested=False)
native=OUT/'native-final.txt'
if native.exists():
    native_text=native.read_text()
    ends=re.findall(r'\[SELFTEST\] END pass=(\d+) fail=(\d+) skip=(\d+)',native_text)
    if ends:
        passed,failed,skipped=map(int,ends[-1])
        guard=f'[CHET_AUDIT_SOURCE_FINGERPRINTS] 215 215 {manifest["source_commit"]}' in native_text
        ready=f'[CHET_AUDIT_NATIVE_READY] {receipt["candidate"]["evidence_id"]}' in native_text
        receipt['native']=dict(passed=passed,failed=failed,skipped=skipped,source_guard_matches=guard,evidence_matches=ready)
receipt['correctness_gates_pass']=bool(len(compiled)==215 and all(x['exit_code']==0 for x in compiled)
    and source_matches and actual_evidence==receipt['candidate']['evidence_id']
    and manifest['source_commit']==receipt['candidate']['source_commit']
    and len(rows)==60 and not failures and process and process['exit_code']==0
    and process['source_commit']==receipt['candidate']['source_commit']
    and ci and ci['conclusion']=='success'
    and ci['head_sha']==receipt['candidate']['source_commit'] and receipt['native']
    and receipt['native']['source_guard_matches'] and receipt['native']['evidence_matches']
    and receipt['native']['passed']>=274 and receipt['native']['failed']==receipt['native']['skipped']==0)
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:receipt[key] for key in ['compile','local_cli','native','correctness_gates_pass']},indent=2))
if any(x['exit_code'] for x in compiled):raise SystemExit(1)
