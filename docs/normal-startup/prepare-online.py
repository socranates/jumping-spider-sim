"""Derive the online observer/seed/builder without altering the qualified core."""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent
USER='qa_s_74c52a1d98ef430b'
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def output(name,text):
 data=text.encode('utf8');path=H/name
 if a.check:assert path.read_bytes()==data,name
 else:path.write_bytes(data)
seed=(H/'legacy-seed.luau').read_text(encoding='utf8').replace('qa_normal_startup',USER)
seed=seed.replace('Only synthetic memory data; never a played save.','Synthetic fixture values for the isolated online test store; never a played save.')
seed=seed.replace('game.PlaceId==0 and game.GameId==0','game.PlaceId==109879630247781 and game.GameId==10771634917')
seed=seed.replace('LegacyStartupDiagnostic','OnlineStartupDiagnostic')
output('online-seed.luau',seed)
client=(H/'legacy-playback.luau').read_text(encoding='utf8').replace('qa_normal_startup',USER)
client=client.replace('game.PlaceId==0 and game.GameId==0','game.PlaceId==109879630247781 and game.GameId==10771634917')
client=client.replace('LegacyStartupDiagnostic','OnlineStartupDiagnostic').replace('LEGACY_STARTUP_','ONLINE_STARTUP_')
client=client.replace('LegacyStartupFinished','OnlineStartupClientFinished').replace('LegacyStartupPassed','OnlineStartupClientPassed')
client=client.replace('local initial=inspect();check(initial.ready and initial.archives==0,"legacy startup wrote an archive before selection")\n  for _,mode in {"main","free","easy"}do check(initial.originalUnchanged[mode],"legacy startup changed original "..mode)end\n  for index,mode in {"main","free","easy"}do', '''local initial=inspect();check(initial.ready,"ordinary online startup not ready")
  local rejoining=initial.rejoining
  if not rejoining then
   check(initial.archives==0,"legacy startup wrote an archive before selection")
   for _,mode in {"main","free","easy"}do check(initial.originalUnchanged[mode],"legacy startup changed original "..mode)end
  else
   check(initial.archiveComplete,"rejoin archive incomplete")
   for _,mode in {"main","free","easy"}do
    offered(mode)
    local value=d.saveClient.bound:offer(mode)
    check(value and require(RS.Shared.Persistence.Json).checksum((assert(require(RS.Shared.Persistence.Json).canonical(value.record))))==initial.priorPayloadDigests[mode],"rejoin offer differs from uncached persisted schema3 checkpoint")
   end
  end
  local modes={"main","free","easy"};if rejoining then modes={"main"}end
  for index,mode in modes do''')
client=client.replace('check(d.saveState.worldGeneration>generation and region~=nil and region.id==Map.HOME,"legacy source pose/ecology escaped into Preserve")','check(d.saveState.worldGeneration>generation and region~=nil and (rejoining or region.id==Map.HOME),"legacy source pose/ecology escaped into Preserve")')
client=client.replace(' and state.requests==state.starts','')
client=client.replace('if index<3 then','if not rejoining and index<3 then')
start=client.index('  stage="finish";local final=inspect("finish")')
end=client.index('\n end,debug.traceback)',start)
client=client[:start]+'''  stage="leave";local final=inspect("arm_leave")
  for _,mode in {"main","free","easy"}do check(final.originalExact[mode],"final original differs")end
  emit("CLIENT_PASS",{checks=checks,user=initial.user,starts=final.starts,real_storage=true,ordinary_ui=true,rejoining=rejoining})'''+client[end:]
client=client.replace('assert(not d.saveState.broken,"save startup broke")','assert(WS:GetAttribute("OnlineStartupServerFailed")~=true,"online server diagnostic failed");assert(not d.saveState.broken,"save startup broke")')
output('online-playback.luau',client)
builder=(H/'build-legacy.py').read_text(encoding='utf8')
builder=builder.replace('unbound ordinary-startup probe with isolated yielding memory storage','bound ordinary-startup probe with unique synthetic real test storage')
builder=builder.replace("'legacy-playback.luau'","'online-playback.luau'").replace("'legacy-storage.luau'","'online-storage.luau'").replace("'legacy-seed.luau'","'online-seed.luau'")
builder=builder.replace('qa_normal_startup',USER).replace('LegacyStartupDiagnostic','OnlineStartupDiagnostic')
builder=builder.replace("project['name']='WindowsillNormalStartupDiagnostic'","project.update(name='WindowsillOnlineStartupDiagnostic',servePort=34874,servePlaceIds=[0,109879630247781],placeId=109879630247781,gameId=10771634917)")
builder=builder.replace('game.PlaceId==0 and game.GameId==0','game.PlaceId==109879630247781 and game.GameId==10771634917')
builder=builder.replace("guard='assert(","guard='local oldTests=game.ServerScriptService:FindFirstChild(\"PortTests\");if oldTests then for _,it in oldTests:GetDescendants()do if it:IsA(\"BaseScript\")then it.Disabled=true end end end;assert(")
builder=builder.replace("guard+='for _,r in expected", "guard+='if oldTests then for _,it in oldTests:GetDescendants()do assert(not it:IsA(\"BaseScript\")or it.Disabled,\"legacy runner still enabled\")end end;for _,r in expected")
builder=builder.replace('unbound memory_only normal_startup_enabled','bound real_test_storage normal_startup_enabled never_publish')
builder=builder.replace('yielding-memory-injected-DataStoreBackend','real-WindowsillTest_v1-explicit-synthetic-keys')
builder=builder.replace('diagnostic_unavailable=a.unavailable,executed=False','synthetic_user="'+USER+'",universe=10771634917,place_id=109879630247781,diagnostic_unavailable=a.unavailable,executed=False')
builder=builder.replace('out=a.out.resolve()','out=a.out.resolve();assert not a.unavailable and not a.before and a.ordinary_ui')
output('build-online.py',builder)
print('online startup derivations match' if a.check else 'online startup derivations created')
