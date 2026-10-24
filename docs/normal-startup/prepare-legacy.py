"""Derive narrow incoming-offer validation changes, preserving earlier candidates."""
from pathlib import Path
import argparse
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
continuation=(ROOT/'roblox_port/src/Client/SaveContinuation.luau').read_text(encoding='utf8')
old='validate:(string,any,boolean)->boolean';assert continuation.count(old)==1
continuation=continuation.replace(old,'validate:(string,any,boolean,boolean?)->boolean')
old='self.cfg.validate(mode,value.record,true)';assert continuation.count(old)==1
continuation=continuation.replace(old,'self.cfg.validate(mode,value.record,true,value.protected)')
client=(H/'spider-client.client.luau').read_text(encoding='utf8')
old='''   cfg.now=function():number return Workspace:GetServerTimeNow() end
   return Replacement.new(cfg,options)'''
new='''   cfg.now=function():number return Workspace:GetServerTimeNow() end
   cfg.continuation=table.clone(cfg.continuation)
   cfg.continuation.validate=require(script.Parent.RecoveryOfferValidation).new(cfg.continuation.validate)
   return Replacement.new(cfg,options)'''
assert client.count(old)==1;client=client.replace(old,new)
for name,source in [('continuation-legacy.luau',continuation),('spider-client-legacy.client.luau',client)]:
 path=H/name;data=source.encode()
 if a.check:assert path.read_bytes()==data
 else:path.write_bytes(data)
print('Legacy validation derivation checked' if a.check else 'Legacy validation candidates prepared')
