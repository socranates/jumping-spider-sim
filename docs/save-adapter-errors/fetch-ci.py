from pathlib import Path
import io,json,os,subprocess,sys,urllib.request,urllib.error,zipfile,re,ast
run=sys.argv[1]
api='https://api.github.com/repos/socranates/jumping-spider-sim'
headers={'Accept':'application/vnd.github+json','User-Agent':'Windowsill-release-verification'}
def metadata(url):
 with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=40) as r:return json.load(r)
info=metadata(api+'/actions/runs/'+run)
if info['status']!='completed':
 print(json.dumps({k:info[k] for k in ['id','head_sha','status','conclusion']}));sys.exit(3)
assert info['conclusion']=='success',info['conclusion']
env=dict(os.environ,GIT_TERMINAL_PROMPT='0',GCM_INTERACTIVE='never')
result=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\npath=socranates/jumping-spider-sim.git\n\n',text=True,capture_output=True,env=env,check=True)
credential=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):return None
request=urllib.request.Request(api+'/actions/runs/'+run+'/logs',headers={**headers,'Authorization':'Bearer '+credential['password']})
try:
 with urllib.request.build_opener(NoRedirect).open(request,timeout=40) as r:archive=r.read()
except urllib.error.HTTPError as e:
 assert e.code==302,e.code
 location=e.headers['Location']
 with urllib.request.urlopen(location,timeout=60) as r:archive=r.read()
repo=Path(r'C:\Users\natha\windowsill-publish');out=repo/'docs/save-adapter-errors'
with zipfile.ZipFile(io.BytesIO(archive)) as z:
 matches=[name for name in z.namelist() if 'all suites' in name.lower() and name.endswith('.txt')]
 assert len(matches)==1,matches
 text=z.read(matches[0]).decode('utf-8-sig')
(out/'ci-all-suites.txt').write_text(text,encoding='utf-8',newline='\n')
tree=ast.parse((repo/'roblox_port/tests/run.py').read_text(encoding='utf-8'))
names=[]
for node in ast.walk(tree):
 if isinstance(node,ast.For) and isinstance(node.target,ast.Name) and node.target.id=='test_file' and isinstance(node.iter,ast.BoolOp):
  names=ast.literal_eval(node.iter.values[-1])
assert len(names)==62 and all((repo/'roblox_port/tests'/n).is_file() for n in names)
failed=[line for line in text.splitlines() if re.search(r'\b(?:failed|fail)=[1-9]\d*\b|\[SELFTEST\] FAIL|##\[error\]',line)]
assert not failed,failed[:5]
receipt={k:info[k] for k in ['id','head_sha','status','conclusion','html_url','created_at','updated_at']}
summaries=re.findall(r'^.*?([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',text,re.M)
receipt.update(suites=len(names),failed_summary_lines=failed,summary_rows=len(summaries),passed=sum(int(r[1]) for r in summaries),failed=sum(int(r[2]) for r in summaries))
assert len(summaries)==62 and receipt['passed']==443235 and receipt['failed']==0
(out/'ci-final.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(receipt,indent=2))
for line in text.splitlines():
 if re.search(r'\bRARE passed=|SELFTEST_PRESERVE passed=|SELFTEST passed=',line):print(line)
