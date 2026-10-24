"""Prepare the sole normal client startup from its existing trusted integration seam."""
from pathlib import Path
import argparse,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
path='roblox_port/src/Client/SpiderClient.client.luau'
source=subprocess.check_output(['git','show','bd67582b5d53473f067244fc1e2e1f94adde173b:'+path],cwd=ROOT).decode('utf8').replace('\r\n','\n')
marker='\nsaveState.sig = `{#book.opened}:{session.finishedMain}:{M.title.seen}:{M.World:hutOpen()}:{M.RareLedger.signature(M.rareHistory)}`'
assert source.count(marker)==1
source=source.replace('-- No recovery owner is installed by the current engine startup.','-- The Preserve startup below installs its recovery owner before networking.')
old='-- engine startup, never an attribute/remote/player setting. Ordinary startup\n-- does not install recovery. Rebinding an already-started transport is refused.'
assert source.count(old)==1
source=source.replace(old,'-- engine startup, never an attribute/remote/player setting. The Preserve binds\n-- below before transport starts. Rebinding a started transport is refused.')
install='''-- The shipped Preserve installs recovery before any transport update. This is
-- trusted startup code, not a player attribute or an opt-in diagnostic hook.
if M.World.world=="preserve" then
 local Replacement=require(script.Parent.ReplacementClientPrototype)
 local Entry=require(script.Parent.RecoveryGameEntryPrototype)
 local installed,problem=saveState.installRecovery({
  client=function(cfg:any,options:any):any
   cfg.now=function():number return Workspace:GetServerTimeNow() end
   return Replacement.new(cfg,options)
  end,
  entry=function(cfg:any):any return Entry.new(cfg) end,
 })
 assert(installed,problem)
end
'''
source=source.replace(marker,'\n'+install+marker)
out=H/'spider-client.client.luau'
if a.check:assert out.read_bytes()==source.encode('utf8')
else:out.write_bytes(source.encode('utf8'))
print('Normal startup client prepared' if not a.check else 'Normal startup client derivation checked')
