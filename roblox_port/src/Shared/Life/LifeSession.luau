--!strict
-- LIFE-19..23: player progress lives outside world checkpoints. Session only until server saves are ported.
local Session = {}
Session.__index = Session
-- Authored lethal outcomes handled by the client. Keep unknown outcomes out;
-- newer predators and water must reach the same ending/lineage path as hunger.
local LETHAL_CAUSES = table.freeze({
 wasp=true,starved=true,rival=true,night=true,
 cat=true,crab_spider=true,bird=true,frog=true,drowned=true,
})
Session.SPOTS = { Vector3.new(12,.31,9), Vector3.new(-8,.31,-10), Vector3.new(24,.31,8), Vector3.new(-2,.31,10) }
function Session.new(): any
	return setmetatable({ mode="main", rules="standard", ended=false, summary=nil,
		deaths=0, lives={}, finishedMain=false, started=false }, Session)
end
function Session.begin(self: any, mode: string, easy: boolean): boolean
	if mode ~= "main" and mode ~= "free" then return false end
	if mode == "main" and easy and not self.finishedMain then return false end
	self.mode, self.rules = mode, if mode == "free" or easy then "gentle" else "standard"
	self.ended, self.summary, self.started = false, nil, true
	return true
end
function Session.finishAdult(self: any, stage: any): boolean
 local adult=if type(stage)=="table" then stage:isAdult() else stage==3
	if not adult or self.mode ~= "main" or self.rules ~= "standard" or self.finishedMain then return false end
	self.finishedMain = true
	return true
end
function Session.endLife(self: any, cause: string, summary: any): boolean
	if self.ended or self.rules == "gentle" or not LETHAL_CAUSES[cause] then return false end
	self.ended, self.deaths = true, self.deaths + 1
	self.summary = table.clone(summary)
	self.summary.cause, self.summary.mode, self.summary.rules = cause, self.mode, self.rules
	return true
end
function Session.archive(self: any)
	if self.summary then table.insert(self.lives, table.clone(self.summary)) end
	while #self.lives > 30 do table.remove(self.lives,1) end
	self.summary = nil
end
function Session.another(self: any): Vector3?
	if not self.ended then return nil end
	self:archive()
	self.ended, self.started = false, true
	return Session.SPOTS[#self.lives % #Session.SPOTS + 1]
end
function Session.title(self: any): string
	return if self.mode == "free" then "FREE PLAY" elseif self.rules == "gentle" then "THE WINDOWSILL (EASY)" else "THE WINDOWSILL"
end
return Session
