--!strict
-- Read-only observation adapter. Rebase after restores/new lives; never interpret HUD strings.
local Watch={}
Watch.__index=Watch
function Watch.new(book: any): any return setmetatable({book=book,captures=0,taken=0,energy=.55},Watch) end
function Watch.rebase(self: any, prey: any, needs: any)
	self.captures=prey.captures; self.taken=prey.feeding.taken; self.energy=needs.energy
end
function Watch.tick(self: any, dt: number, prey: any, needs: any, eye: boolean, shimmer: boolean)
	if prey.captures>self.captures then self.book:notice("catch") end
	if prey.feeding.taken>self.taken then self.book:notice("meal") end
	if needs.energy~=self.energy then
		if needs.energy<=.25 then self.book:notice("hungry")
		elseif needs.energy>=.85 then self.book:notice("well_fed") end
		if needs.energy<=0 and not needs.gentle then self.book:notice("starving") end
	end
	self:rebase(prey,needs)
	if eye then
		self.book:notice("eye_view");self.book:addEyeTime(dt)
		if shimmer then self.book:notice("shimmer") end
	end
end
function Watch.life(self: any, kind: string, stage: number)
	local trigger=({rest_started="rest",woke="sleep",moult_ready="moult_ready",moulted="moulted",starved="starving"})[kind]
	if trigger then self.book:notice(trigger) end
	if kind=="moulted" and stage>=3 then self.book:notice("adult") end
end
function Watch.wasp(self: any, event: any)
	if event.kind=="visit_started" then self.book:notice("wasp")
	elseif event.kind=="caught" then self.book:notice("wasp_caught")
	elseif event.kind=="left" and event.escaped then self.book:notice("wasp_escaped") end
end
return Watch
