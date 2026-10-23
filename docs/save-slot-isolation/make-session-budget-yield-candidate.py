from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
prior=HERE/'session-budget-candidate.luau';source=prior.read_text(encoding='utf8')
assert hashlib.sha256(prior.read_bytes()).hexdigest()=='d217138209e3ea18838dcf0889d148c58dfcdb056a6792a6a0bfcb9e23bcc8ad'
def change(old,new):
 global source
 assert source.count(old)==1,old
 source=source.replace(old,new)
change('function SaveSession.demote(self: any, reason: string, retry: boolean)\n',
 'function SaveSession.demote(self: any, reason: string, retry: boolean)\n self._loadSerial=(self._loadSerial or 0)+1 -- invalidate suspended older acquisitions/reads\n')
change('local function readRests(self: any, maxReads: number?)\n',
 'local function readRests(self: any, maxReads: number?)\n local generation=self._loadSerial\n')
change('\t\t\tself.counters.requests += 1\n\t\t\tif not ok then',
 '\t\t\tself.counters.requests += 1\n   if self.closed or self.state~="active" or not self.lockHeld or self._loadSerial~=generation then return end\n\t\t\tif not ok then')
start=source.index('function SaveSession.load(');end=source.index('-- ---------------------------------------------------------------- what the client',start)
part=source[start:end]
part=part.replace('deferRests: boolean?): string','deferRests: boolean?): (string,boolean?)')
part=part.replace('if self.closed then return self.state end','if self.closed then return self.state,false end\n self._loadSerial=(self._loadSerial or 0)+1\n local ticket=self._loadSerial')
part=part.replace('local verdict, info = attemptLock(self)','local verdict, info = attemptLock(self)\n if self.closed or self._loadSerial~=ticket then return self.state,false end')
part=part.replace('if first or self.state == "active" then self:notify() end','if self.closed or self._loadSerial~=ticket then return self.state,false end\n\tif first or self.state == "active" then self:notify() end')
part=part.replace('return self.state\nend','return self.state,true\nend')
source=source[:start]+part+source[end:]
change('self:load(true) -- one lock request; subsequent steps read the rest slots',
 'local _,applied=self:load(true) -- one lock request; subsequent steps read the rest slots')
change('if SaveSession.isActive(self) then','if applied and not self.closed and SaveSession.isActive(self) then')
change('\t\t\t\treadRests(self,1)',
 '''    local generation=self._loadSerial
\t\t\t\treadRests(self,1)
    if self.closed or self.state~="active" or not self.lockHeld or self._loadSerial~=generation then return true end''')
change('\tself:notify()\n\treturn did :: boolean','\tif not self.closed then self:notify() end\n\treturn did :: boolean')
candidate=HERE/'session-budget-yield-candidate.luau';candidate.write_text(source,encoding='utf8',newline='\n')
(HERE/'session-budget-yield-manifest.json').write_text(json.dumps(dict(base_source='f4053597d03b99a61cb97e2eef1ec64ed174f22a',prior_candidate_sha256=hashlib.sha256(prior.read_bytes()).hexdigest(),candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),production_changed=False,scope='Paced recovery with closed/demoted/superseding-load fences across yielding backend operations'),indent=2)+'\n',encoding='utf8',newline='\n')
print('Generated private yield-fenced recovery candidate')
