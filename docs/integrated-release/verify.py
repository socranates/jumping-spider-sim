"""Bind full CLI results to the clean playable and isolated player models."""
from pathlib import Path
import argparse, ast, hashlib, json, re, subprocess, sys
import xml.etree.ElementTree as ET

H = Path(__file__).resolve().parent
ROOT = H.parents[1]
sha = lambda data: hashlib.sha256(data).hexdigest()
p = argparse.ArgumentParser()
p.add_argument('--candidate', type=Path, required=True)
p.add_argument('--player', type=Path, required=True)
p.add_argument('--prefix', default='full2')
p.add_argument('--check', action='store_true')
a = p.parse_args()
inputs = {}

def bind(path):
    inputs[path.relative_to(ROOT).as_posix()] = sha(path.read_bytes())

def sources(folder):
    manifest = json.loads((folder/'manifest.json').read_text(encoding='utf8'))
    place = Path(manifest['place'])
    assert sha(place.read_bytes()) == manifest['place_sha256']
    actual = {}
    disabled = []
    def walk(node, parent=''):
        props = node.find('Properties')
        name = props.findtext("string[@name='Name']")
        path = parent+'.'+name if parent else name
        source = props.find("*[@name='Source']")
        if source is not None:
            actual[path] = sha((source.text or '').replace('\r\n', '\n').encode())
        if node.attrib['class'] in ['Script', 'LocalScript']:
            disabled.append(props.findtext("bool[@name='Disabled']") == 'true')
        for child in node.findall('Item'):
            walk(child, path)
    tree = ET.parse(place).getroot()
    for node in tree.findall('Item'):
        walk(node)
    assert actual == manifest['sources'] and not any(disabled)
    assert sha((folder/'guard.luau').read_bytes()) == manifest['guard_sha256']
    assert 'TypeError:' not in (folder/'strict.txt').read_text(encoding='utf8')
    return manifest, tree

def model_path(rel):
    parts = Path(rel).parts
    prefix = {'First': 'ReplicatedFirst', 'Shared': 'ReplicatedStorage.Shared',
              'Server': 'ServerScriptService.Server',
              'Client': 'StarterPlayer.StarterPlayerScripts.Client'}[parts[0]]
    return '.'.join([prefix, *parts[1:-1], parts[-1][:-5].removesuffix('.server').removesuffix('.client')])

clean, _ = sources(a.candidate)
assert clean['source_count'] == 273 and clean['diagnostics'] is False
assert (a.candidate/'compile.txt').read_text().strip() == 'compile 273/273'
config = json.loads((a.candidate/'roblox_port/default.project.json').read_text())
assert config['tree']['Workspace']['$attributes'] == {
    'World': 'preserve', 'SelfTest': False, 'TestTarget': False, 'SaveWait': True}
assert len(clean['overlays']) == 57
for rel, overlay in clean['overlays'].items():
    path = ROOT/overlay['source']; bind(path)
    assert sha(path.read_bytes()) == overlay['sha256']
    code = path.read_text(encoding='utf8')
    if path.name in ['worker-v3.luau', 'operation.luau']:
        code = code.replace('require("./worker-facade")', 'require(script.Parent.RequestAdmissionFacade)')
    assert clean['sources'][model_path(rel)] == sha(code.encode())

receipt_path = H/(a.prefix+'-receipt.json')
run = json.loads(receipt_path.read_text()); bind(receipt_path)
assert run['all_passed'] and run['full']
assert run['runner_sha256'] == sha((H/'run-cli.py').read_bytes())
stage = Path(run['stage'])
for folder in [stage, a.candidate]:
    subprocess.run([sys.executable, str(H/'prepare-test-support.py'), '--stage', str(folder), '--check'], check=True)
    game = {f.relative_to(folder/'roblox_port/src').as_posix(): sha(f.read_bytes())
            for f in (folder/'roblox_port/src').rglob('*.luau')}
    assert game == run['inputs'] and len(game) == 273
    tests = {f.relative_to(folder/'roblox_port/tests').as_posix(): sha(f.read_bytes())
             for f in (folder/'roblox_port/tests').rglob('*')
             if f.is_file() and '__pycache__' not in f.parts}
    assert tests == run['test_inputs']
    assert {model_path(rel): sha((folder/'roblox_port/src'/rel).read_bytes().replace(b'\r\n', b'\n'))
            for rel in game} == clean['sources']
module = ast.parse((stage/'roblox_port/tests/run.py').read_text())
main = next(n for n in module.body if isinstance(n, ast.FunctionDef) and n.name == 'main')
loop = next(n for n in main.body if isinstance(n, ast.For))
default_suites = ast.literal_eval(loop.iter.values[1])
assert run['requested'] == default_suites
assert [r['suite'] for r in run['results']] == default_suites
total = 0
for row in run['results']:
    output = H/row['output']; bind(output)
    assert row['exit_code'] == 0 and sha(output.read_bytes()) == row['output_sha256']
    summaries = re.findall(r'passed=(\d+) failed=(\d+)', output.read_text())
    assert summaries and all(int(failed) == 0 for _, failed in summaries), row['suite']
    total += sum(int(passed) for passed, _ in summaries)

player, tree = sources(a.player)
assert player['candidate_manifest_sha256'] == sha((a.candidate/'manifest.json').read_bytes())
assert player['clean_place_sha256'] == clean['place_sha256']
assert player['source_count'] == 274 and player['unchanged_game_sources'] == 273
assert player['universe'] == 10771634917 and player['place_id'] == 109879630247781
assert player['test_store'] == 'WindowsillTest_player57_20261023a1'
assert {k: v for k, v in player['sources'].items() if k != 'ReplicatedFirst.PlayerArrivalProbe'} == clean['sources']
assert player['readonly_probe_sha256'] == sha((H/'player-probe.client.luau').read_bytes())
assert player['sources']['ReplicatedFirst.PlayerArrivalProbe'] == player['readonly_probe_sha256']
player_project = json.loads((a.player/'player-test.project.json').read_text())
assert player_project['gameId'] == player['universe'] and player_project['placeId'] == player['place_id']
assert player_project['servePlaceIds'] == [player['place_id']]
attrs = player_project['tree']['Workspace']['$attributes']
assert attrs == {**config['tree']['Workspace']['$attributes'], 'SaveStore': player['test_store']}
assert player_project['tree']['ServerScriptService']['PortTests'] == {'$className': 'Folder', '$ignoreUnknownInstances': False}
for service in ['ReplicatedFirst', 'ReplicatedStorage', 'ServerScriptService', 'StarterPlayer', 'Workspace']:
    node = next(n for n in tree.findall('Item') if n.find('Properties').findtext("string[@name='Name']") == service)
    assert node.attrib['class'] == service
    if service == 'ServerScriptService':
        marker = next(n for n in node.findall('Item') if n.find('Properties').findtext("string[@name='Name']") == 'PortTests')
        assert marker.attrib['class'] == 'Folder' and not marker.findall('Item')

editor_path = H/'editor-check.json'; bind(editor_path)
editor = json.loads(editor_path.read_text(encoding='utf8'))
assert editor['source_identity_verified_in_studio'] and editor['sources'] == 274
assert editor['universe'] == player['universe'] and editor['place_id'] == player['place_id']
assert editor['guard_sha256'] == player['guard_sha256']
assert editor['manifest_sha256'] == sha((a.player/'manifest.json').read_bytes())
assert sha(Path(editor['saved_editor']).read_bytes()) == editor['saved_editor_sha256']
image = H/editor['screenshot']; bind(image)
assert sha(image.read_bytes()) == editor['screenshot_sha256']

# The review remains private; this verifier never activates source or publishes.
tracked = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', clean['base'], 'roblox_port/src'], cwd=ROOT, text=True).splitlines()
assert len(tracked) == 224
for rel in tracked:
    expected = subprocess.check_output(['git', 'show', clean['base']+':'+rel], cwd=ROOT)
    assert (ROOT/rel).read_bytes().replace(b'\r\n', b'\n') == expected.replace(b'\r\n', b'\n'), rel
    source_rel = Path(rel).relative_to('roblox_port/src').as_posix()
    if source_rel not in clean['overlays']:
        assert clean['sources'][model_path(source_rel)] == sha(expected.replace(b'\r\n', b'\n')), rel
assert len(list((ROOT/'roblox_port/src').rglob('*.luau'))) == 224
for name in ['build.py', 'build-player-test.py', 'prepare-test-support.py', 'run-cli.py', 'player-probe.client.luau', 'collect-player.py', 'verify.py']:
    bind(H/name)
result = dict(inputs=inputs, suites=len(default_suites), passed=total, failed=0,
    clean_model=str(a.candidate.resolve()), clean_manifest_sha256=sha((a.candidate/'manifest.json').read_bytes()),
    clean_place_sha256=clean['place_sha256'], player_model=str(a.player.resolve()),
    player_manifest_sha256=sha((a.player/'manifest.json').read_bytes()), player_place_sha256=player['place_sha256'],
    game_sources=273, qualified_overlays=57, production_activated=False,
    player_source_identity_verified_in_studio=True,
    player_executed=False, player_published=False, goal_complete=False)
target = H/'qualification.json'
if a.check:
    assert json.loads(target.read_text()) == result
else:
    assert not target.exists()
    target.write_bytes((json.dumps(result, indent=2)+'\n').encode())
print(f'Integrated models verified; {len(default_suites)} suites, {total} passed, 0 failed; no publication claimed')
