"""Derive a new real-clock service diagnostic; never edit production sources."""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent
ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def emit(name,text):
 path=H/name
 if a.check:assert path.read_bytes()==text.encode('utf8'),name
 else:path.write_text(text,encoding='utf8',newline='\n')
def change(text,old,new):
 assert text.count(old)==1,old
 return text.replace(old,new)
# Retain actual application-menu/client tests and bounded cost observations.
c=(ROOT/'docs/recovery-native-cost/native-client.luau').read_text(encoding='utf8')
c=c.replace('Clock x10','Real clock').replace('clock_scale=10','clock_scale=1')
assert ')*10' in c or ')*scale' in c or '*10' in c
c=c.replace('*10','*1')
emit('native-service-client.luau',c)
s=(ROOT/'docs/recovery-native-cost/native-server.server.luau').read_text(encoding='utf8')
s=s.replace('"NativeApplicationClockScale",10','"NativeApplicationClockScale",1').replace('*10 end','*1 end').replace('clock_scale=10','clock_scale=1')
s=change(s,'local Service=require(script.Parent.ReplacementServicePrototype)',
 '''local Service=require(script.Parent.ReplacementServicePrototype)
local Gate=require(script.Parent.RequestAdmissionGate)
local Accounts=require(script.Parent.RecoveryAccountLifetimes)''')
s=change(s,'local ds={}\n','''local ds={}
local nativeStarts={};local providerActive=0
local function started(kind,key)
 table.insert(nativeStarts,{kind=kind,key=key,at=now()});providerActive+=1
end
''')
s=change(s,'function ds:GetAsync(key,options)\n','function ds:GetAsync(key,options)\n started("read",key)\n')
s=change(s,'function ds:UpdateAsync(key,fn)\n','function ds:UpdateAsync(key,fn)\n started("update",key)\n')
s=change(s,'provider("read",started);return value','provider("read",started);providerActive-=1;return value')
s=change(s,'provider("update",started);return value','provider("update",started);providerActive-=1;return value')
s=change(s,'local holdAck=true;', '''-- Explicit synthetic policy, not claimed Roblox platform budgets.
local gate=Gate.new({now=now,available=function() return {read=1000,write=1000} end,
 actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
local accounts=Accounts.new(gate,{now=now,sleep=task.wait,legacyHistory=function() return {} end})
local holdAck=true;''')
s=change(s,'errors=#errors,lockReleased=', 'errors=#errors,accountGate=gate:inspect(),providerActive=providerActive,nativeStarts=#nativeStarts,lockReleased=')
s=change(s,'sleep=task.wait,spawn=task.spawn,jobId=', 'sleep=task.wait,spawn=task.spawn,accountLifetimes=accounts,jobId=')
# Additional native cancellation cases use actual task scheduling/providers and
# distinct synthetic accounts. No test manually resumes a coroutine.
s=change(s,' selectedPlayer=readyPlayer;service:addPlayer(selectedPlayer)',
 (H/'native-service-preflight.luau').read_text(encoding='utf8')+'\n selectedPlayer=readyPlayer;service:addPlayer(selectedPlayer)')
s=change(s,'print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()));reportCost()',
 '''check(providerActive==0,"provider did not drain at final departure")
 local ledger=gate:inspect();local nr,nw,nh=0,0,0
 for _,row in nativeStarts do if now()-row.at<60 then nh+=1;nr+=1;if row.kind=="update" then nw+=1 end end end
 check(ledger.history==nh and ledger.read==nr and ledger.write==nw,"native SDK ledger mismatch")
 check(ledger.started==0 and ledger.scopes==0,"native service scope survived departure")
 print("[NATIVE_SERVICE_LEDGER]",tag,Json.canonical({starts=#nativeStarts,history=nh,read=nr,write=nw,active=providerActive,scopes=ledger.scopes}))
 print("[NEW_APP_NATIVE_SERVER_END]",tag,Json.canonical(snapshot()));reportCost()''')
s=s.replace('clock_scale=10','clock_scale=1')
emit('native-service-server.server.luau',s)
print('Native service diagnostics checked' if a.check else 'Native service diagnostics derived')
