from pathlib import Path
HERE=Path(__file__).resolve().parent
source=(HERE/'build-session-cache-native.py').read_text(encoding='utf8')
source=source.replace('session-fresh-types.json','session-budget-yield-types.json').replace('session-fresh-candidate.luau','session-budget-yield-candidate.luau')
source=source.replace("assert json.loads((HERE/'session-adapter-receipt.json').read_text())['exit_code']==0", "assert json.loads((HERE/'session-budget-yield-fixed-receipt.json').read_text())['exit_code']==0\nassert json.loads((HERE/'session-budget-yield-controls-receipt.json').read_text())['exit_code']==0")
start=source.index("spec=importlib.util.spec_from_file_location");end=source.index("fixtureModule=",start)
source=source[:start]+'''raw=(HERE/'session-native-fixtures.json').read_text(encoding='utf8').strip()
prior=json.loads((HERE/'prepared-session-cache-native-manifest.json').read_text())
assert hashlib.sha256((HERE/'session-native-fixtures.json').read_bytes()).hexdigest()==prior['fixtures_sha256']
assert ']==]' not in raw
'''+source[end:]
source=source.replace("(HERE/'session-native-fixtures.json').write_text(raw+'\\n',encoding='utf8',newline='\\n')\n",'')
source=source.replace("test=(HERE/'session-adapter-tests.luau').read_text(encoding='utf8')",'''controls=(HERE/'session-budget-candidate-tests.luau').read_text(encoding='utf8')
yielded=(HERE/'session-budget-yield-tests.luau').read_text(encoding='utf8')
test='local function controls()\\n'+controls+'\\nreturn passedBudget end\\nlocal function yielded()\\n'+yielded+'\\nreturn checksYield end\\nlocal a,b=controls(),yielded();assert(a==82 and b==44);local checks=a+b\\n' ''')
source=source.replace('checks==111','checks==126')
source=source.replace('local Shared=game.ReplicatedStorage.Shared','local Shared=game.ReplicatedStorage.Shared\nlocal SaveRules=require(Shared.Data.SaveRules)')
source=source.replace('SessionCache','SessionBudget').replace('NATIVE_SESSION_CACHE','NATIVE_SESSION_BUDGET').replace('session-cache','session-budget')
source=source.replace("prior=json.loads((HERE/'prepared-session-budget-native-manifest.json').read_text())", "prior=json.loads((HERE/'prepared-session-cache-native-manifest.json').read_text())")
source=source.replace('Real SaveSession/DataStoreBackend against cached fake DataStore; actual engine options; no real DataStore or progress migration; never publish','Paced recovery, retained observations and actual coroutine suspension across close/demote/superseding load; MemoryBackend; no real DataStore or full-game transport; never publish')
(HERE/'build-session-budget-native.py').write_text(source,encoding='utf8',newline='\n')
print('Generated budget native builder from source-guarded diagnostic scaffold')
