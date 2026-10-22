from pathlib import Path
import hashlib,io,json,os,re,subprocess,sys,urllib.request,urllib.error,zipfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
RUN,SOURCE=sys.argv[1:]
API='https://api.github.com/repos/socranates/jumping-spider-sim'
HEADERS={'Accept':'application/vnd.github+json','User-Agent':'Windowsill-audit'}
def metadata(path):
 with urllib.request.urlopen(urllib.request.Request(API+path,headers=HEADERS),timeout=30) as r:return json.load(r)
info=metadata('/actions/runs/'+RUN);jobs=metadata('/actions/runs/'+RUN+'/jobs')
assert info['head_sha']==SOURCE and info['path']=='.github/workflows/roblox-port.yml'
assert info['status']=='completed' and info['conclusion']=='failure'
out=HERE/('failed-ci-'+RUN);out.mkdir(exist_ok=False)
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
 matches=[n for n in bundle.namelist() if 'all suites' in n.lower() and n.endswith('.txt')];assert len(matches)==1
 text=bundle.read(matches[0]).decode('utf-8-sig')
p=out/'suites.txt';p.write_text(text,encoding='utf8',newline='\n')
clean='\n'.join(re.sub(r'^\d{4}-\d\d-\d\dT\S+\s+','',line) for line in text.splitlines())
rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',clean,re.M)
receipt={k:info[k] for k in ['id','head_sha','status','conclusion','html_url']}
receipt.update(suites=len(rows),passed=sum(int(r[1]) for r in rows),failed=sum(int(r[2]) for r in rows),
 failed_suites=[r for r in rows if int(r[2])],log_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
 steps=[{k:s[k] for k in ['name','status','conclusion']} for j in jobs['jobs'] for s in j['steps']],published=False)
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
