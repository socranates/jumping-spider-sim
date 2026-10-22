"""Generate a small Studio command-bar checksum guard from this checkout's source."""
from pathlib import Path
import hashlib
import json
import subprocess
import zlib

repo = Path(__file__).resolve().parents[3]
port = repo / "roblox_port"
out = Path(__file__).resolve().parent
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
prefixes = {
    "First": "ReplicatedFirst",
    "Shared": "ReplicatedStorage.Shared",
    "Client": "StarterPlayer.StarterPlayerScripts.Client",
    "Server": "ServerScriptService.Server",
}
rows = []
for p in sorted((port / "src").rglob("*.luau")):
    relative = p.relative_to(port / "src")
    names = list(relative.parts)
    prefix = prefixes[names.pop(0)]
    name = names[-1].removesuffix(".luau").removesuffix(".client").removesuffix(".server")
    assert name != "init", "handle Rojo init-module naming explicitly if introduced"
    names[-1] = name
    data = p.read_bytes().replace(b"\r\n", b"\n")
    rows.append(dict(path=p.relative_to(port).as_posix(), instance=prefix + "." + ".".join(names),
                     length=len(data), adler32=zlib.adler32(data), sha256=hashlib.sha256(data).hexdigest()))

lua = 'assert(not game:GetService("RunService"):IsRunning());local expected={\n'
lua += ",\n".join("{" + json.dumps(r["instance"]) + "," + str(r["length"]) + "," + str(r["adler32"]) + "}" for r in rows)
lua += r'''
};local passed=0
for _,row in expected do
 local item=game
 for name in string.gmatch(row[1],"[^.]+") do item=assert(item:FindFirstChild(name),row[1]) end
 local source=string.gsub(item.Source,"\r\n","\n")
 local a,b=1,0
 for i=1,#source do a=(a+string.byte(source,i))%65521;b=(b+a)%65521 end
 assert(#source==row[2] and b*65536+a==row[3],"SOURCE_MISMATCH "..row[1])
 passed+=1
end
local count=0
for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do
 for _,item in root:GetDescendants() do if item:IsA("LuaSourceContainer") then count+=1 end end
end
assert(count==#expected,"unexpected script count "..count)
'''
lua += 'print("[CHET_V51_SOURCE_FINGERPRINTS]",passed,#expected,' + json.dumps(commit) + ')\n'
(out / "source-guard.luau").write_text(lua, encoding="utf-8", newline="\n")
(out / "source-manifest.json").write_text(json.dumps(dict(source_commit=commit, count=len(rows), files=rows), indent=2), encoding="utf-8", newline="\n")
print(f"Generated guard for {len(rows)} source modules at {commit}")
