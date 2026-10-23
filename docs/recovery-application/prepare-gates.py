"""Prepare current immutable-source gates without overwriting older receipts."""
from pathlib import Path
H=Path(__file__).resolve().parent;OLD=H.parent/'server-recovery-templates'
SOURCE='216b83c7f2b5136230d8bda58653717433eccc51'
for name in ['check-production.py','full.py','locate-ci.py','fetch-ci.py']:
 text=(OLD/name).read_text(encoding='utf8')
 text=text.replace('46c299f5e36038d06f164c968e5fda78bb4407e8',SOURCE)
 if name=='full.py':text=text.replace('expected_suites=77,expected_assertions=468936','expected_suites=78,expected_assertions=468959')
 if name=='fetch-ci.py':text=text.replace('223/223','224/224').replace('len(rows)==77','len(rows)==78').replace('468936','468959').replace('modules_compiled=223,suites=77','modules_compiled=224,suites=78')
 out=H/name;assert not out.exists();out.write_text(text,encoding='utf8',newline='\n')
print('Prepared current-source static, Windows and observing-only CI gates')
