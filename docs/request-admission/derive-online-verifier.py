"""Derive the independent verifier for test-bound real-store diagnostics."""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
s=(H/'verify-native-service.py').read_text(encoding='utf8')
s=s.replace("'Windowsill-native-service.rbxlx'","'Windowsill-online-service.rbxlx'")
s=s.replace("H/'native-service-client.luau'","H/'online-service-client.luau'").replace("H/'native-service-server.server.luau'","H/'online-service-server.server.luau'")
s=s.replace("b'game.PlaceId==0'","b'game.GameId==10771634917 and game.PlaceId==109879630247781'")
old="server=(H/'online-service-server.server.luau').read_text(encoding='utf8');assert 'GetService(\"DataStoreService\")' not in server and ':GetDataStore(' not in server"
new='''server=(H/'online-service-server.server.luau').read_text(encoding='utf8')
assert server.count(':GetDataStore(')==1 and 'DataStores:GetDataStore("WindowsillTest_v1")' in server
assert 'assert(allowedKeys[key]' in server and 'game.GameId==10771634917 and game.PlaceId==109879630247781' in server
project=json.loads((out/'native.project.json').read_text(encoding='utf8'))
assert project['placeId']==109879630247781 and project['gameId']==10771634917 and project['servePlaceIds']==[0,109879630247781]
assert project['tree']['ServerScriptService']['Server']['Persistence']['$properties']['Disabled'] is True'''
assert s.count(old)==1;s=s.replace(old,new)
s=s.replace('memory_store=True','memory_store=False')
s=s.replace('online_verified=False,published=False)','online_verified=False,published=False,universe=10771634917,place_id=109879630247781)')
s=s.replace("qualified=json.loads((H/'service-types-qualified-1-types.json').read_text(encoding='utf8'))","""subprocess.run([__import__('sys').executable,str(H/'qualify-native-callback.py'),'--check'],check=True)
qualified=json.loads((H/'native-callback-types-1-types.json').read_text(encoding='utf8'))""")
target=H/'verify-online-service.py'
if a.check:assert target.read_bytes()==s.encode()
else:target.write_text(s,encoding='utf8',newline='\n')
print('Online verifier derived' if not a.check else 'Online verifier derivation checked')
