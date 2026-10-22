"""Run the current regression against all production modules from frozen Git source."""
from pathlib import Path
import argparse,subprocess,tempfile,zipfile,io,importlib.util,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);a=p.parse_args()
source=subprocess.check_output(['git','rev-parse','b1be9f1'],cwd=ROOT,text=True).strip()
archive=subprocess.check_output(['git','archive','--format=zip',source,'roblox_port/src'],cwd=ROOT)
with tempfile.TemporaryDirectory(prefix='windowsill-reset-baseline-') as tmp:
 tmp=Path(tmp)
 with zipfile.ZipFile(io.BytesIO(archive)) as z:
  assert all(tmp in (tmp/n).resolve().parents for n in z.namelist());z.extractall(tmp)
 spec=importlib.util.spec_from_file_location('reset_runner',ROOT/'roblox_port/tests/run.py')
 r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
 tests=tmp/'roblox_port/tests';tests.mkdir()
 for name in {'shim.luau','outdoor_life_reset.luau',*(ref+'.luau' for ref in r.REFERENCES)}:
  (tests/name).write_bytes((ROOT/'roblox_port/tests'/name).read_bytes())
 # The inline SpiderClient loader reads HERE.parent/src, independently of SRC.
 # Bind both; changing SRC alone mixes an old model with the current controller.
 r.HERE=tests;r.SRC=tmp/'roblox_port/src/Shared'
 assert all(tmp in (r.SRC/rel).resolve().parents for _,rel in r.MODULES+r.CLIENT_MODULES)
 client=tests.parent/'src/Client/SpiderClient.client.luau'
 assert client.read_bytes()==subprocess.check_output(['git','show',source+':roblox_port/src/Client/SpiderClient.client.luau'],cwd=ROOT)
 bundle=r.bundle('outdoor_life_reset.luau');f=tmp/'probe.luau';f.write_text(bundle,encoding='utf8',newline='\n')
 with (OUT/'baseline.txt').open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([a.luau,str(f)],stdout=log,stderr=subprocess.STDOUT)
 (OUT/'baseline-process.json').write_text(json.dumps({'exit_code':result.returncode,'source_commit':source,'expected_failure':True,
  'source_archive_sha256':hashlib.sha256(archive).hexdigest(),'bundle_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),
  'test_sha256':hashlib.sha256((tests/'outdoor_life_reset.luau').read_bytes()).hexdigest(),
  'scope':'Current regression and shim; all production modules and inline controller from frozen Git source'},indent=2)+'\n',encoding='utf8',newline='\n')
 print('frozen baseline exit',result.returncode)
