"""Build normal and isolated self-test models with a portable evidence receipt.
Usage: python tools/build.py [path/to/rojo]. Does not publish.
"""
from pathlib import Path
import hashlib,json,subprocess,sys,tempfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
sha=lambda data:hashlib.sha256(data).hexdigest()
projects=[('default.project.json','TheWindowsill.rbxlx',False),('tests.project.json','TheWindowsillTests.rbxlx',True)]
# Legacy BuildInfo belongs to the retired runner. Current exports carry the
# evidence ID as Workspace.PortEvidence; this builder never stamps sources.
paths=sorted([*root.glob('src/**/*.luau'),*root.glob('tests/**/*.luau'),*[root/name for name,_,_ in projects]])
h=hashlib.sha256()
for path in paths:
    if path.name=='BuildInfo.luau':continue
    h.update(path.relative_to(root).as_posix().encode()+b'\0'+path.read_bytes().replace(b'\r\n',b'\n')+b'\0')
evidence=h.hexdigest()[:16]
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def source_name(path):
    parts=path.relative_to(root/'src').parts
    return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
expected={source_name(p):sha(p.read_bytes().replace(b'\r\n',b'\n'))for p in (root/'src').rglob('*.luau')}
rojo=sys.argv[1] if len(sys.argv)>1 else 'rojo'
outputs=[]
for name,filename,selftest in projects:
    project=json.loads((root/name).read_text())
    assert project['tree']['MaterialService']['$properties']['Use2022Materials'] is True,name
    assert project['tree']['Lighting']['$properties']['Technology']=='Future',name
    attrs=project['tree']['Workspace']['$attributes']
    assert attrs['World']=='preserve'and attrs['SaveWait']is True and attrs['TestTarget']is False
    assert attrs['SelfTest']is selftest
    if selftest:
        assert attrs['SaveStore'].startswith('WindowsillTest')
        assert project['tree']['ServerScriptService']['PortTests']=={'$className':'Folder','$ignoreUnknownInstances':False}
    else:
        assert 'SaveStore'not in attrs and 'PortTests'not in project['tree']['ServerScriptService']
    attrs['PortEvidence']=evidence
    # The temporary config stays beside src, preserving relative paths.
    with tempfile.NamedTemporaryFile('w',suffix='.project.json',prefix='.build-',dir=root,encoding='utf8',newline='\n',delete=False)as file:
        json.dump(project,file,indent=2);config=Path(file.name)
    output=root/filename
    try:subprocess.run([rojo,'build',str(config),'-o',str(output)],check=True)
    finally:config.unlink(missing_ok=True)
    actual={};disabled=[]
    def walk(node,parent=''):
        props=node.find('Properties');item=props.findtext("string[@name='Name']");path=parent+'.'+item if parent else item
        source=props.find("*[@name='Source']")
        if source is not None:actual[path]=sha((source.text or '').replace('\r\n','\n').encode())
        if node.attrib['class']in ['Script','LocalScript']:disabled.append(props.findtext("bool[@name='Disabled']")=='true')
        for child in node.findall('Item'):walk(child,path)
    for node in ET.parse(output).getroot().findall('Item'):walk(node)
    assert actual==expected and not any(disabled),'Export source/enablement mismatch'
    assert not any('PortTests.'in p or p.endswith('.SilkPlayback')for p in actual),'Legacy runner/playback must not ship'
    outputs.append(dict(file=filename,sha256=sha(output.read_bytes()),selftest=selftest,source_count=len(actual),attributes=attrs))
receipt=dict(evidence_id=evidence,source_count=len(expected),sources=expected,outputs=outputs,published=False,
 limits='Build identity, not native execution, rendering, device or online storage proof.')
(root/'build-receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print('evidence_id:',evidence)
