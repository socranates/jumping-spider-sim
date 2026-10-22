"""Regenerate a static audit index; no game files are modified.
Requires only Python's standard library. Dependency/test matches are lexical,
not a proof that a test executes a function or that a dynamic require resolves.
"""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / "roblox_port"
OUT = Path(__file__).resolve().parent
SOURCES = sorted((PORT / "src").rglob("*.luau"))
names = {p.name.removesuffix(".luau"): p for p in SOURCES}
tests = list((PORT / "tests").glob("*.luau"))


def requires(text):
    result = set()
    for line in text.splitlines():
        if line.lstrip().startswith("--"):
            continue
        for match in re.finditer(r"require\(((?:[^()\n]|\([^()\n]*\))*)\)", line):
            tokens = re.findall(r"[A-Za-z_][A-Za-z_0-9.]*", match[1])
            for token in reversed(tokens):
                key = token.split(".")[-1]
                if key in names:
                    result.add(key)
                    break
    return sorted(result)


def rel(p):
    return p.relative_to(ROOT).as_posix()


records = []
for p in SOURCES:
    text = p.read_text(encoding="utf-8")
    lines = text.splitlines()
    purpose = next((s.lstrip("- ") for s in lines if s.startswith("-- ") and len(s) > 8), "No module summary; inspect source.")
    key = p.name.removesuffix(".luau")
    direct = [t.name for t in tests if re.search(r'require\("\.\./src/[^"\n]*/' + re.escape(key) + r'"\)', t.read_text(encoding="utf-8"))]
    records.append(dict(path=rel(p), name=key, lines=len(lines), purpose=purpose,
                        side=p.relative_to(PORT / "src").parts[0], strict=lines[0].strip()=="--!strict",
                        requires=requires(text), tests=direct, any_casts=text.count(":: any")))
byname = {r["name"]: r for r in records}
for r in records:
    r["required_by"] = [q["path"] for q in records if r["name"] in q["requires"]]
edges = {r["name"]: r["requires"] for r in records}
cycles = set()
def visit(name, chain):
    if name in chain:
        cycles.add(" -> ".join(chain[chain.index(name):] + [name])); return
    if name in completed:
        return
    for target in edges.get(name, []):
        visit(target, chain + [name])
    completed.add(name)
completed = set()
for name in edges:
    visit(name, [])
baseline = json.loads((ROOT / "docs/verification/v51/release.json").read_text())
header = f"Baseline: v51, source `{baseline['source_commit']}`, place {baseline['place_version']}, evidence `{baseline['evidence_id']}`. Audit branch: `codex/foundation-audit`.\n\n"
out = ["# Foundation map\n", header,
       f"Static index: {len(records)} source files, {sum(r['lines'] for r in records):,} lines. Shared means available to either side; consumers determine execution. Direct test names are lexical matches, not coverage percentages. Requires inferred from literal module names; dynamic cases need manual review.\n",
       "## Source inventory\n\n| Source | Lines | Side | Purpose from source | Required by | Direct tests | Flags |\n|---|---:|---|---|---|---|---|\n"]
for r in records:
    flags = (['over 800 lines'] if r['lines']>800 else []) + ([] if r['tests'] else ['no direct test import']) + ([] if r['strict'] else ['no strict directive'])
    purpose = r['purpose'].replace('|','/')[:190]
    consumers = ', '.join(Path(x).name for x in r['required_by']) or 'entrypoint or no static consumer'
    out.append(f"| `{r['path']}` | {r['lines']} | {r['side']} | {purpose} | {consumers} | {', '.join(r['tests']) or 'none'} | {', '.join(flags)} |\n")
out.append("\n## Dependency cycles\n\n" + ('\n'.join(sorted(cycles)) if cycles else 'No cycles found in the lexical graph. This is not proof for dynamic requires.') + '\n')
out.append("\n## Runtime call-site inventory\n\nEach line below is a call site, not an assertion that it runs each frame. Inspect the surrounding function and its callers before changing frequency.\n\n| Source | Line | Call site |\n|---|---:|---|\n")
pattern = re.compile(r"BindToRenderStep|RenderStepped|Heartbeat|Stepped:|while\s|task\.(wait|spawn|delay)|RemoteEvent|RemoteFunction|FireServer|FireClient|OnServerEvent|OnClientEvent|GetDataStore|UpdateAsync|GetAsync|SetAsync|Instance\.new")
for p in SOURCES:
    for i,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        if not line.lstrip().startswith('--') and pattern.search(line):
            out.append(f"| `{rel(p)}` | {i} | `{line.strip().replace('|','/')[:300]}` |\n")
if (OUT/'DATA.md').exists():
    out.append('\n' + (OUT/'DATA.md').read_text(encoding='utf-8'))
(OUT/'MAP.md').write_text(''.join(out),encoding='utf-8')
(OUT/'inventory.json').write_text(json.dumps(dict(baseline=baseline,modules=records,cycles=sorted(cycles)),indent=2),encoding='utf-8')
branches=subprocess.run(['git','branch','--all','--format=%(refname:short) %(objectname)'],cwd=ROOT,capture_output=True,text=True,check=True)
(OUT/'branches.txt').write_text(branches.stdout,encoding='utf-8')
print(f'Indexed {len(records)} files; {sum(r["lines"]>800 for r in records)} over 800 lines; {sum(not r["tests"] for r in records)} without direct test imports; {len(cycles)} lexical cycles.')
