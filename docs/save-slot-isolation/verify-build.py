"""Read-only release-place preflight: exact production scripts and no diagnostic payload.
This does not publish or verify a destination. Run immediately before choosing a release file.
"""
from pathlib import Path
import hashlib,json,sys,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent

def verify(path):
 path=Path(path);raw=path.read_bytes();assert len(raw)<32*1024*1024,'unexpectedly large release XML'
 manifest=json.loads((HERE/'source-manifest.json').read_text(encoding='utf-8'))
 expected={r['instance']:r['sha256'] for r in manifest['files']};found={};forbidden=[]
 def walk(item,parent=''):
  name=item.findtext("./Properties/string[@name='Name']") or item.attrib['class'];full=parent+'.'+name if parent else name
  if name in {'ChetSlotNativeSpec','ChetSlotFixture','ChetAdapterNativeSpec','ChetRetirementNativeSpec','ChetRetirementFixture','ChetIsolatedSaveLab','ChetIsolatedAdapterLab','SilkPlayback','PortTests'}:forbidden.append(full)
  if item.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
   assert full not in found,'duplicate script path: '+full
   text=item.findtext("./Properties/ProtectedString[@name='Source']")
   if text is None:text=item.findtext("./Properties/string[@name='Source']")
   assert text is not None,'missing script source: '+full
   found[full]=hashlib.sha256(text.replace('\r\n','\n').encode('utf-8')).hexdigest()
  if item.attrib['class']=='Workspace':
   attrs=item.findtext("./Properties/BinaryString[@name='AttributesSerialize']")
   assert attrs in {None,''},'release file unexpectedly contains authored diagnostic/workspace attributes'
  for child in item.findall('Item'):walk(child,full)
 for item in ET.fromstring(raw).findall('Item'):walk(item)
 assert not forbidden,'diagnostic content: '+', '.join(forbidden[:5])
 assert set(found)==set(expected),'production script set differs: extra='+str(sorted(set(found)-set(expected))[:5])+' missing='+str(sorted(set(expected)-set(found))[:5])
 mismatches=[name for name in found if found[name]!=expected[name]];assert not mismatches,'script fingerprint mismatch: '+str(mismatches[:5])
 return {'path':str(path.resolve()),'sha256':hashlib.sha256(raw).hexdigest(),'source_commit':manifest['source_commit'],'matched_scripts':len(found),'diagnostic_content':False}

if __name__=='__main__':print(json.dumps(verify(sys.argv[1]),indent=2))
