"""Check diagnostic cached copy against the actual reference and existing suites.

No production file is overwritten. The existing bundler maps SpiderRig to the
experimental copy only for the explicitly labelled prototype suite processes.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--profile',required=True);p.add_argument('--luau',required=True);p.add_argument('--out',required=True)
a=p.parse_args();profile=Path(a.profile).resolve();out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
frozen=profile/'frozen-source'
spec=importlib.util.spec_from_file_location('rig_bundler',frozen/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
manifest=json.loads((profile/'manifest.json').read_text(encoding='utf-8'))
cached=profile/'RigCached.luau'
raw=cached.read_bytes().replace(b'\r\n',b'\n')
row=next(x for x in manifest['scripts'] if x['path']=='ReplicatedStorage.Shared.Rig.RigCached')
assert hashlib.sha256(raw).hexdigest()==row['sha256']
source=frozen/'roblox_port/src/Shared/Rig/SpiderRig.luau'
assert source.read_bytes()==subprocess.check_output(['git','show',manifest['source']+':roblox_port/src/Shared/Rig/SpiderRig.luau'],cwd=ROOT)
reference=str(HERE/'reference.luau')
r.CLIENT_MODULES.append(('RigCached',str(cached)))
r.NAMES.add('RigCached');r.CLIENT_TESTS.add(reference)
rows=[]
for test in [reference,'look.luau','idle.luau','growth.luau','feeding_survival.luau','client_rival.luau','inspect.luau']:
    original=list(r.CLIENT_MODULES)
    if test!=reference:
        r.CLIENT_MODULES=[(name,str(cached) if name=='SpiderRig' else path) for name,path in r.CLIENT_MODULES]
    bundle=r.bundle(test)
    r.CLIENT_MODULES=original
    with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf-8',delete=False) as f:
        f.write(bundle);temp=Path(f.name)
    began=time.monotonic()
    try:
        proc=subprocess.run([a.luau,str(temp)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    finally:
        temp.unlink(missing_ok=True)
    name=Path(test).name
    (out/(name+'.txt')).write_text(proc.stdout+proc.stderr,encoding='utf-8',newline='\n')
    rows.append({'suite':name,'exit_code':proc.returncode,'elapsed_seconds':time.monotonic()-began,'scope':'CLI shim; isolated prototype, not production or native timing'})
    rows[-1]['bundle_sha256']=hashlib.sha256(bundle.encode('utf-8')).hexdigest()
    print(name,'exit',proc.returncode,flush=True)
    if proc.returncode:break
receipt={'source':manifest['source'],'cached_source_sha256':row['sha256'],'reference_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
         'rows':rows,'passed':len(rows)==7 and all(x['exit_code']==0 for x in rows),'native_verified':False,'performance_gain_verified':False,'production_changed':False}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
assert receipt['passed'],receipt
