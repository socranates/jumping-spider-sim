"""Derive a touch-font-only candidate without altering qualified source trees."""
from pathlib import Path
import argparse, hashlib, json
H=Path(__file__).resolve().parent; ROOT=H.parents[1]
BASE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
sha=lambda data:hashlib.sha256(data).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
source=BASE/'roblox_port/src/Client/SpiderInput.luau'
original=source.read_text(encoding='utf8')
anchor='\t\tb.TextSize = textSize or 18\n'
assert original.count(anchor)==1
patched=original.replace(anchor,anchor+'\t\tb.Font = Enum.Font.GothamMedium\n')
builder=ROOT/'docs/menu-overflow/build.py';code=builder.read_text(encoding='utf8')
anchor="paths['Client/CaughtPanel.luau']=H/'caught-panel.luau'"
assert code.count(anchor)==1
code=code.replace(anchor,"paths['Client/CaughtPanel.luau']=H.parent/'menu-overflow/caught-panel.luau'\npaths['Client/SpiderInput.luau']=H/'spider-input.luau'")
outputs={'spider-input.luau':patched.encode(),'build.py':code.encode()}
record=dict(inputs={'qualified_source':str(source),'qualified_source_sha256':sha(source.read_bytes()),
 'builder':'docs/menu-overflow/build.py','builder_sha256':sha(builder.read_bytes())},
 outputs={name:sha(data)for name,data in outputs.items()},
 scope='Explicit existing UI font for touch buttons; bindings, labels, sizes, hit targets and handlers unchanged.')
if a.check:
 for name,data in outputs.items():assert (H/name).read_bytes()==data
 assert json.loads((H/'derivation.json').read_text())==record
else:
 for name,data in outputs.items():
  assert not (H/name).exists();(H/name).write_bytes(data)
 assert not (H/'derivation.json').exists()
 (H/'derivation.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print('Touch font derivation verified'if a.check else 'Touch font candidate prepared; not built or published')
