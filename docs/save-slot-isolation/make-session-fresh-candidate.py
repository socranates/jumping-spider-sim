from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
source=(ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau').read_text(encoding='utf8')
needle='self.backend:read(self.rkey[mode])'
assert source.count(needle)==3
source=source.replace(needle,'readCurrent(self,self.rkey[mode])')
marker='local function canonical(v: any): string'
helper='''-- Rest observations that grant authority must bypass a provider's read cache.
-- MemoryBackend and other providers without a cache retain their read contract.
-- A failed fresh read is an error; it must never fall back to stale data.
local function readCurrent(self: any, key: string): (boolean, any, string?)
 local fresh = self.backend.readFresh
 if type(fresh)=="function" then return fresh(self.backend,key) end
 return self.backend:read(key)
end

'''
assert source.count(marker)==1
(HERE/'session-fresh-candidate.luau').write_text(source.replace(marker,helper+marker),encoding='utf8',newline='\n')
print('Created private SaveSession candidate; three reads changed, production unchanged.')
