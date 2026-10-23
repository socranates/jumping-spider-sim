from pathlib import Path
import json,urllib.request
HERE=Path(__file__).resolve().parent
SOURCE='8c9b71896736d85d43e02fec1521bcd567cdb33f'
url='https://api.github.com/repos/socranates/jumping-spider-sim/actions/workflows/roblox-port.yml/runs?head_sha='+SOURCE
with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Windowsill-audit','Accept':'application/vnd.github+json'}),timeout=30) as response:
 runs=json.load(response)['workflow_runs']
matches=[r for r in runs if r['head_sha']==SOURCE and r['head_branch']=='codex/save-continue' and r['event']=='push']
assert len(matches)==1,'expected one existing push run; never dispatch a duplicate'
info=matches[0];receipt={k:info[k] for k in ['id','head_sha','head_branch','status','conclusion','html_url','created_at','updated_at']}
(HERE/'ci-start.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
