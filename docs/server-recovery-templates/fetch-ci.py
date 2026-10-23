"""Collect the exact recovery capability CI run; never rerun or dispatch a job."""
from pathlib import Path
import hashlib,io,json,os,re,subprocess,sys,urllib.request,urllib.error,zipfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUN=str(json.loads((HERE/'ci-start.json').read_text(encoding='utf8'))['id'])
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
API='https://api.github.com/repos/socranates/jumping-spider-sim'
HEADERS={'Accept':'application/vnd.github+json','User-Agent':'Windowsill-audit'}

def metadata(path):
    with urllib.request.urlopen(urllib.request.Request(API+path,headers=HEADERS),timeout=30) as response:
        return json.load(response)

info=metadata('/actions/runs/'+RUN)
assert info['head_sha']==SOURCE and info['path']=='.github/workflows/roblox-port.yml'
jobs=metadata('/actions/runs/'+RUN+'/jobs')
if info['status']!='completed':
    print(json.dumps({'run':RUN,'status':info['status'],'conclusion':info['conclusion'],
                      'steps':[(s['name'],s['status'],s['conclusion']) for j in jobs['jobs'] for s in j['steps']]}))
    sys.exit(3)
assert info['conclusion']=='success',info['conclusion']
required={'Toolchain (Luau 0.743, luau-lsp 1.70.1, Rojo 7.7.1)','Every module compiles',
          'Strict types','All suites','Runner failure and cleanup regressions'}
steps={s['name']:s['conclusion'] for j in jobs['jobs'] for s in j['steps']}
assert all(steps.get(name)=='success' for name in required)

# Use the existing Git credential only for the archive request, never print it
# and never forward it to the signed storage redirect.
env=dict(os.environ,GIT_TERMINAL_PROMPT='0',GCM_INTERACTIVE='never')
credential_result=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\npath=socranates/jumping-spider-sim.git\n\n',
                                 text=True,capture_output=True,env=env,check=True)
credential=dict(line.split('=',1) for line in credential_result.stdout.splitlines() if '=' in line)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None
request=urllib.request.Request(API+'/actions/runs/'+RUN+'/logs',headers={**HEADERS,'Authorization':'Bearer '+credential['password']})
try:
    with urllib.request.build_opener(NoRedirect).open(request,timeout=30) as response:archive=response.read()
except urllib.error.HTTPError as error:
    assert error.code==302,error.code
    with urllib.request.urlopen(error.headers['Location'],timeout=45) as response:archive=response.read()

with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
    logs={}
    for key,needle in [('toolchain','toolchain ('),('compile','every module compiles'),('types','strict types'),
                       ('suites','all suites'),('runner','runner failure and cleanup regressions')]:
        matches=[name for name in bundle.namelist() if needle in name.lower() and name.endswith('.txt')]
        assert len(matches)==1,(key,matches)
        logs[key]=bundle.read(matches[0]).decode('utf-8-sig')
for name in ['luau.zip','lsp.zip','rojo.zip','globalTypes.d.luau']:
    assert re.search(r'\b'+re.escape(name)+r': OK\s*$',logs['toolchain'],re.M),name
assert 'compile 223/223' in logs['compile']
assert 'Ran 5 tests' in logs['runner'] and re.search(r'\bOK\s*$',logs['runner'],re.M)
clean='\n'.join(re.sub(r'^\d{4}-\d\d-\d\dT\S+\s+','',line) for line in logs['suites'].splitlines())
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',clean,re.M)
assert len(rows)==77 and sum(int(row[1]) for row in rows)==468936 and all(int(row[2])==0 for row in rows)
assert not any(re.search(r'\b(?:failed|fail)=[1-9]\d*\b|\[SELFTEST\] FAIL|##\[error\]',line) for text in logs.values() for line in text.splitlines())
workflow=subprocess.check_output(['git','show',SOURCE+':.github/workflows/roblox-port.yml'],cwd=ROOT)
assert (ROOT/'.github/workflows/roblox-port.yml').read_bytes().replace(b'\r\n',b'\n')==workflow
hashes={}
for key,text in logs.items():
    path=HERE/('ci-'+key+'.txt');path.write_text(text,encoding='utf8',newline='\n')
    hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
receipt={k:info[k] for k in ['id','head_sha','status','conclusion','html_url','created_at','updated_at']}
receipt.update(jobs_evidence=jobs,logs_sha256=hashes,workflow_sha256=hashlib.sha256(workflow).hexdigest(),
               modules_compiled=223,suites=77,passed=468936,failed=0,runner_regressions=5,
               all_download_checksums_verified=True,published=False)
(HERE/'ci-final.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='jobs_evidence'},indent=2))
