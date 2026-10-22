--!strict
-- Owns bounded loading work, before the first simulation tick. Surface and air
-- graphs may finish at different real times; neither may activate gameplay early.
-- Dependencies are supplied so failure/budget tests need no engine scheduler.
local Preparation = {}
Preparation.__index = Preparation
Preparation.FRAME_SECONDS = .008
Preparation.MAX_SLICES = 64
Preparation.TIMEOUT_SECONDS = 40

function Preparation.new(config: any): any
	local now = config.now or os.clock
	local self: any = setmetatable({ config = config, now = now, started = now(),
		status = "pending", problem = nil, slices = 0, airTurn = false }, Preparation)
	self.airThread = coroutine.create(function() config.air.prepare(function() coroutine.yield() end) end)
	local ok, problem = pcall(config.prepare)
	if not ok then
		self.status, self.problem = "failed", tostring(problem)
		coroutine.close(self.airThread)
	end
	return self
end

local function work(self: any)
	local deadline = self.now() + Preparation.FRAME_SECONDS
	for _ = 1, Preparation.MAX_SLICES do
		if self.now() - self.started >= Preparation.TIMEOUT_SECONDS then error("navigation preparation timed out") end
		local airDone = coroutine.status(self.airThread) == "dead"
		local surfaceDone = self.config.pending() == 0
		if airDone and surfaceDone then
			assert(self.config.air.ready(), "air navigation did not finish")
			self.status = "ready"
			return
		end
		if self.now() >= deadline then return end
		if not airDone and (self.airTurn or surfaceDone) then
			local ok, problem = coroutine.resume(self.airThread)
			assert(ok, tostring(problem))
		else
			local ok, problem = self.config.advance()
			assert(ok, tostring(problem))
		end
		self.airTurn = not self.airTurn
		self.slices += 1
	end
end

function Preparation.step(self: any): (string, string?)
	if self.status ~= "pending" then return self.status, self.problem end
	local ok, problem = pcall(function(): any work(self); return nil end)
	if not ok then
		self.status, self.problem = "failed", tostring(problem)
		if coroutine.status(self.airThread) == "suspended" then coroutine.close(self.airThread) end
		if self.config.air.cancelPreparation then self.config.air.cancelPreparation(self.airThread) end
	end
	return self.status, self.problem
end

return table.freeze(Preparation)
