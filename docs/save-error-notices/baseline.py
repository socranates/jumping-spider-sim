"""Run the same actual-client failure probe on immutable production source."""
from pathlib import Path
import argparse,subprocess,tempfile,zipfile,io,importlib.util,json,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);p.add_argument('--source',required=True);p.add_argument('--name',required=True);a=p.parse_args()
assert a.name in {'baseline','candidate'}
source=subprocess.check_output(['git','rev-parse',a.source+'^{commit}'],cwd=ROOT,text=True).strip()
archive=subprocess.check_output(['git','archive','--format=zip',source,'roblox_port/src'],cwd=ROOT)
assert not (HERE/(a.name+'.txt')).exists(),'preserve the previous run'
with tempfile.TemporaryDirectory(prefix='windowsill-notice-') as tmp:
 tmp=Path(tmp)
 with zipfile.ZipFile(io.BytesIO(archive)) as z:
  assert all(tmp in (tmp/name).resolve().parents for name in z.namelist());z.extractall(tmp)
 spec=importlib.util.spec_from_file_location('notice_runner',ROOT/'roblox_port/tests/run.py')
 r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 tests=tmp/'roblox_port/tests';tests.mkdir()
 for name in {'shim.luau',*(ref+'.luau' for ref in r.REFERENCES)}:
  (tests/name).write_bytes((ROOT/'roblox_port/tests'/name).read_bytes())
 (tests/'save_notice_probe.luau').write_bytes((HERE/'baseline.luau').read_bytes())
 r.HERE=tests;r.SRC=tmp/'roblox_port/src/Shared';r.CLIENT_TESTS.add('save_notice_probe.luau')
 assert all(tmp in (r.SRC/rel).resolve().parents for _,rel in r.MODULES+r.CLIENT_MODULES)
 client=tests.parent/'src/Client/SpiderClient.client.luau'
 assert client.read_bytes()==subprocess.check_output(['git','show',source+':roblox_port/src/Client/SpiderClient.client.luau'],cwd=ROOT)
 f=tmp/'probe.luau';f.write_text(r.bundle('save_notice_probe.luau'),encoding='utf8',newline='\n')
 with (HERE/(a.name+'.txt')).open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([a.luau,str(f)],stdout=log,stderr=subprocess.STDOUT)
 receipt={'source':source,'exit_code':result.returncode,'source_archive_sha256':hashlib.sha256(archive).hexdigest(),
          'test_sha256':hashlib.sha256((HERE/'baseline.luau').read_bytes()).hexdigest(),
          'bundle_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'expected_failure':a.name=='baseline'}
 (HERE/(a.name+'-process.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps(receipt))
