"""Derive the single menu fix and its builder without changing qualified inputs."""
from pathlib import Path
import argparse, hashlib, json

H = Path(__file__).resolve().parent
ROOT = H.parents[1]
p = argparse.ArgumentParser(); p.add_argument('--check', action='store_true'); a = p.parse_args()
sha = lambda data: hashlib.sha256(data).hexdigest()
source = ROOT/'roblox_port/src/Client/CaughtPanel.luau'
original = source.read_text(encoding='utf8')
old = ' self:setLook("card")\n return self'
new = ''' self:setLook("card")
 -- Recompute only when the engine's layout or safe viewport changes. Centering
 -- overflowing content puts its first rows above CanvasPosition zero, where
 -- the player cannot scroll back to them.
 list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:_align() end)
 box:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:_align() end)
 return self'''
assert original.count(old) == 1
patched = original.replace(old, new)
anchor = 'function CaughtPanel.select(self:any, delta:number)'
assert patched.count(anchor) == 1
patched = patched.replace(anchor, '''function CaughtPanel._align(self:any)
 local height=self.box.AbsoluteWindowSize.Y
 local fits=self.look=="title" and height>0 and self.list.AbsoluteContentSize.Y<=height
 self.list.VerticalAlignment=if fits then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
end
'''+anchor)
old = ' self.list.VerticalAlignment=if title then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top'
assert patched.count(old) == 1
patched = patched.replace(old, ' self:_align()')
builder = ROOT/'docs/integrated-release/build.py'
code = builder.read_text(encoding='utf8')
anchor = "paths['Shared/World/LookPlan.luau']=H.parent/'frame-ordinary/look-plan.luau'"
assert code.count(anchor) == 1
code = code.replace(anchor, anchor+"\npaths['Client/CaughtPanel.luau']=H/'caught-panel.luau'")
outputs = {'caught-panel.luau': patched.encode(), 'build.py': code.encode()}
record = dict(inputs={str(source.relative_to(ROOT)): sha(source.read_bytes()),
                      str(builder.relative_to(ROOT)): sha(builder.read_bytes())},
              outputs={name: sha(data) for name, data in outputs.items()},
              scope='menu presentation only; no game rules, text, save or input changes')
if a.check:
    for name, data in outputs.items(): assert (H/name).read_bytes() == data
    assert json.loads((H/'derivation.json').read_text()) == record
else:
    for name, data in outputs.items():
        assert not (H/name).exists(); (H/name).write_bytes(data)
    assert not (H/'derivation.json').exists()
    (H/'derivation.json').write_bytes((json.dumps(record, indent=2)+'\n').encode())
print('Menu layout derivation verified' if a.check else 'Menu layout source and builder prepared')
