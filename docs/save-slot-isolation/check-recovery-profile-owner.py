"""Compile every candidate and analyze the complete current overlay."""
from pathlib import Path
import ast, hashlib, json, shutil, subprocess, sys, tempfile
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
TOOLS = Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools")
tree = ast.parse((H / "check-recovery-pipeline.py").read_text(encoding="utf8"))
names = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "names" for t in n.targets))
tree = ast.parse((H / "check-recovery-game-entry.py").read_text(encoding="utf8"))
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    target = node.targets[0]
    if isinstance(target, ast.Subscript) and isinstance(target.value, ast.Name) and target.value.id == "names":
        names[ast.literal_eval(target.slice)] = ast.literal_eval(node.value)
names["Server/RecoveryProfileOwnerPrototype.luau"] = "recovery-profile-owner-prototype.luau"
prefix = sys.argv[1]
assert prefix.replace("-", "").isalnum()
assert not (H / (prefix + "-types.json")).exists(), "Preserve prior evidence"
sha = lambda b: hashlib.sha256(b).hexdigest()
production = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in (ROOT / "roblox_port/src").rglob("*.luau")}
production["roblox_port/default.project.json"] = sha((ROOT / "roblox_port/default.project.json").read_bytes())
candidates = {source: sha((H / source).read_bytes()) for source in names.values()}
rows = []
with tempfile.TemporaryDirectory() as tmp:
    folder = Path(tmp)
    shutil.copytree(ROOT / "roblox_port/src", folder / "src")
    shutil.copy2(ROOT / "roblox_port/default.project.json", folder / "default.project.json")
    for target, source in names.items():
        (folder / "src" / target).write_bytes((H / source).read_bytes())
    failures = []
    for target in names:
        result = subprocess.run([str(TOOLS / "luau/luau-compile.exe"), "--null", str(folder / "src" / target)], capture_output=True, text=True)
        if result.returncode:
            failures.append(target + "\n" + result.stdout + result.stderr)
    output = f"compile {len(names)-len(failures)}/{len(names)}\n" + "\n".join(failures)
    (H / (prefix + "-compile.txt")).write_text(output, encoding="utf8", newline="\n")
    rows.append(dict(name="compile", exit_code=int(bool(failures)), output_sha256=sha(output.encode())))
    assert not failures, output
    for name, command in [
        ("sourcemap", [str(TOOLS / "rojo/rojo.exe"), "sourcemap", "default.project.json", "--output", "sourcemap.json"]),
        ("strict", [str(TOOLS / "lsp/luau-lsp.exe"), "analyze", "--sourcemap=sourcemap.json", "--definitions=" + str(TOOLS / "globalTypes.d.luau"), "--ignore=**/tests/**", "--no-strict-dm-types", "src"]),
    ]:
        result = subprocess.run(command, cwd=folder, capture_output=True, text=True)
        output = result.stdout + result.stderr
        (H / (prefix + "-" + name + ".txt")).write_text(output, encoding="utf8", newline="\n")
        rows.append(dict(name=name, exit_code=result.returncode, output_sha256=sha(output.encode())))
        print(name, result.returncode, output[:5000], flush=True)
        if result.returncode:
            break
assert production == {path: sha((ROOT / path).read_bytes()) for path in production}
assert candidates == {source: sha((H / source).read_bytes()) for source in names.values()}
receipt = dict(source=subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT, text=True).strip(), candidates=candidates, production_inputs=production, steps=rows, production_connected=False, native_verified=False, real_datastore_verified=False)
(H / (prefix + "-types.json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf8", newline="\n")
assert len(rows) == 3 and all(row["exit_code"] == 0 for row in rows)
