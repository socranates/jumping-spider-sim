"""Independently compare Gate debt with actual mock SDK starts and imports."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build():
 s=importlib.util.spec_from_file_location('service_ledger_runner',H/'run-service.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(True);a=bundle.index('local function runAccountServiceChecks()');prefix,body=bundle[:a],bundle[a:]
 marker='local function requested()';assert body.count(marker)==1;body=body.replace(marker,'local function requested(kind)',1)
 marker='  f.starts=(f.starts or 0)+1';assert body.count(marker)==1
 body=body.replace(marker,marker+'''
  assert(kind=="read" or kind=="update","unknown physical request kind")
  f.providerLedger=f.providerLedger or {};table.insert(f.providerLedger,{at=f.clock.now,kind=kind})''',1)
 for before,after in [('function ds:GetAsync(key,opts)\n  requested()','function ds:GetAsync(key,opts)\n  requested("read")'),
  ('function ds:UpdateAsync(key,fn)\n  requested()','function ds:UpdateAsync(key,fn)\n  requested("update")')]:
  assert body.count(before)==1;body=body.replace(before,after,1)
 assert 'requested()' not in body
 marker=' f.seeds=0;f.accounts=__accountLifetimes.new';assert body.count(marker)==1
 body=body.replace(marker,''' local import=f.g.importLegacy
 f.g.importLegacy=function(g,scope,history)
  local okay,why=import(g,scope,history)
  if okay then f.importedLedger=f.importedLedger or {};for _,at in history do table.insert(f.importedLedger,at) end end
  return okay,why
 end
'''+marker,1)
 marker='local count=0';assert body.count(marker)==1;body=body.replace(marker,'local count,audits=0,0',1)
 marker=' check(total==(f.starts or 0),"service/provider dispatch totals differ")';assert body.count(marker)==1
 body=body.replace(marker,marker+'''
 local reads,writes,rows=0,0,0;local now=f.clock.now
 for _,row in f.providerLedger or {} do if now-row.at<60 then
  rows+=1;reads+=1;if row.kind=="update" then writes+=1 end
 end end
 for _,at in f.importedLedger or {} do if now-at<60 then rows+=1;reads+=1;writes+=1 end end
 local q=f.g:inspect()
 check(q.history==rows and q.read==reads and q.write==writes,"Gate ledger differs from physical SDK starts plus complete unknown debt")
 audits+=1''',1)
 marker='print("ACCOUNT_SERVICE passed="';assert body.count(marker)==1
 body=body.replace(marker,'print("ACCOUNT_GATE_LEDGER audits="..audits.." independent_physical_trace=true")\n'+marker,1)
 return prefix+body,list(dict.fromkeys(paths+[Path(__file__).resolve()]))
def main():
 prefix=sys.argv[1];out=H/(prefix+'-output.txt');assert not out.exists();bundle,paths=build();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-service-ledger-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  independent_actual_SDK_trace=True,native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output[-2400:]);assert r.returncode==0
 m=re.search(r'ACCOUNT_GATE_LEDGER audits=(\d+) independent_physical_trace=true',output);assert m and int(m[1])>=36
if __name__=='__main__':main()
