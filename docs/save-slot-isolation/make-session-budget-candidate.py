from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';source=p.read_text(encoding='utf8')
assert hashlib.sha256(p.read_bytes()).hexdigest()=='e6ecd86cd0a89f7daeb6d08414260162e20e8ff706672726f81900ecc14338e2'
def change(old,new):
 global source
 assert source.count(old)==1,old
 source=source.replace(old,new)
change('local function readRests(self: any)\n\tfor _, mode in SaveRules.MODES do\n\t\tif not self.restLoaded[mode] then',
'''local function readRests(self: any, maxReads: number?)
 local start=self.restReadCursor or 1
 local reads=0
 for offset=0,#SaveRules.MODES-1 do
  local index=(start+offset-1)%#SaveRules.MODES+1
  local mode=SaveRules.MODES[index]
  if not self.restLoaded[mode] then
   if maxReads and reads>=maxReads then break end
   reads+=1;self.restReadCursor=index%#SaveRules.MODES+1''')
change('function SaveSession.load(self: any): string','function SaveSession.load(self: any, deferRests: boolean?): string')
change('\t\tself.restLoaded = {} -- read again: another session may have written a rest while this one could not\n\t\treadRests(self)',
'''\t\tself.restLoaded = {} -- read again: another session may have written a rest while this one could not
  self.restRetryAt=0
  self.restLoadNotification=deferRests==true
  if not deferRests then readRests(self) end''')
change('\t\t\tself:load()','\t\t\tself:load(true) -- one lock request; subsequent steps read the rest slots')
change('\t\t\tif SaveSession.isActive(self) then','\t\t\tif SaveSession.isActive(self) and not self.restLoadNotification then')
change('\t\t\t\treadRests(self)','\t\t\t\treadRests(self,1)')
start=source.index('\t\telseif not SaveSession.restsLoaded(self) then');end=source.index('\n\t\telse\n\t\t\tdid = false',start)
part=source[start:end];needle='\n\t\t\telse\n\t\t\t\tdid = false';assert part.count(needle)==1
part=part.replace(needle,'''
    if self.restLoadNotification and self.state=="active" and SaveSession.restsLoaded(self) then
     self.restLoadNotification=false
     local loaded=self.cfg.onLoaded
     if loaded then loaded(self:snapshot()) end
    end'''+needle)
source=source[:start]+part+source[end:]
# Preserve immediate merged-progress notification; only rest slots await fresh
# verification. Keep old values internally, never label them freshly loaded.
source=source.replace('restLoadNotification','restReloading')
source=source.replace('if SaveSession.isActive(self) and not self.restReloading then','if SaveSession.isActive(self) then')
source=source.replace('''     local loaded=self.cfg.onLoaded
     if loaded then loaded(self:snapshot()) end
''','')
source=source.replace('local before: { [string]: any } = {}','local before: { [string]: any } = {}\n    local beforeLoaded: {[string]:boolean} = {}')
source=source.replace('for _, mode in SaveRules.MODES do before[mode] = self.rests[mode] end','for _, mode in SaveRules.MODES do before[mode] = self.rests[mode];beforeLoaded[mode]=self.restLoaded[mode]==true end')
source=source.replace('if self.rests[mode] ~= nil and before[mode] == nil then','if self.rests[mode] ~= nil and (before[mode] == nil or (self.restReloading and not beforeLoaded[mode])) then')
assert source.count('if not request or request.done then rests[mode]=self.rests[mode] end')==1
source=source.replace('if not request or request.done then rests[mode]=self.rests[mode] end','if (not request or request.done) and (not self.restReloading or self.restLoaded[mode]) then rests[mode]=self.rests[mode] end')
candidate=HERE/'session-budget-candidate.luau';candidate.write_text(source,encoding='utf8',newline='\n')
(HERE/'session-budget-candidate-manifest.json').write_text(json.dumps(dict(base_source='f4053597d03b99a61cb97e2eef1ec64ed174f22a',original_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),production_changed=False,scope='One request per periodic recovery step; round-robin rest reads; immediate merged progress and freshly validated rest callbacks'),indent=2)+'\n',encoding='utf8',newline='\n')
print('Private budget candidate generated; production unchanged')
