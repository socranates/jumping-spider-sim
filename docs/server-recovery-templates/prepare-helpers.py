"""Adapt existing source-bound gate collectors without changing old evidence."""
from pathlib import Path
H=Path(__file__).resolve().parent
OLD=H.parent/'restored-slot-ownership'
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
for name in ['check-production.py','locate-ci.py','fetch-ci.py','full.py','build-production.py']:
    text=(OLD/name).read_text(encoding='utf8').replace('8c9b71896736d85d43e02fec1521bcd567cdb33f',SOURCE)
    text=text.replace('468880','468936').replace('==76','==77').replace('suites=76','suites=77').replace('expected_suites=76','expected_suites=77')
    text=text.replace('222/222','223/223').replace('modules_compiled=222','modules_compiled=223')
    text=text.replace('Windowsill-production-8c9b718','Windowsill-production-46c299f')
    if name=='build-production.py':
        text=text.replace('==222','==223').replace('native_scripted_fixture_checks=82','native_scripted_fixture_checks=82')
    path=H/name;assert not path.exists();path.write_text(text,encoding='utf8',newline='\n')
text=(OLD/'build-native.py').read_text(encoding='utf8')
text=text.replace("tree['Workspace']['$attributes']", "tree['ServerScriptService']['Server']['TemplateNative']={'$path':str(HERE/'native-server.server.luau')}\ntree['Workspace']['$attributes']")
text=text.replace('==223','==225').replace('Windowsill-restored-slot-review','Windowsill-template-review')
text=text.replace("'scope':'Current actual-client", "'scope':'Includes actual-server authored template/recapture checks; current actual-client")
(H/'build-native.py').write_text(text,encoding='utf8',newline='\n')
(H/'native-client.luau').write_bytes((OLD/'native-probe.luau').read_bytes())
print('Prepared current-source helpers; no test or CI dispatch')
