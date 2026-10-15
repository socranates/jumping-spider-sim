--!strict
-- Pure build_view from perception_hud.gd. Only memory and a camera adapter enter; never world actors.
local Text = require(script.Parent.PerceptionText)
local View = {}
function View.edgeFade(age: number): number
	if age < 0 or age >= 1.4 then return 0 end
	local t = math.clamp(age / 0.12, 0, 1)
	return t*t*(3-2*t) * (1-age/1.4)^1.5
end
function View.build(memory: any, camera: any, showMark: boolean?): any
	local out: any = {edges={}, rings={}, labels={}}
	local sectors: {[number]: any} = {}
	for _, c in memory:contacts() do
		if c.cueCount > 0 and c.cueDirection.Magnitude > 0.7 and not c:isInspectedNow() then
			local alpha = 0.6 * View.edgeFade(memory:cueAgeS(c))
			if alpha > 0 then
				local e = camera.edge(c.cueDirection)
				e.alpha, e.trackId = alpha, c.trackId
				local sector = math.floor(math.atan2(c.cueDirection.X, c.cueDirection.Z) / (math.pi/8) + 0.5)
				if not sectors[sector] or sectors[sector].alpha < alpha then sectors[sector] = e end
			end
		end
		if not c.hasPosition then continue end
		local point, visible, radius = camera.project(c.position, c.sizeWu)
		if not visible then continue end
		if c:isInspectedNow() then
			table.insert(out.rings, {pos=point, radius=radius, alpha=0.85, dash=1, kind="live", trackId=c.trackId})
			table.insert(out.labels, {pos=point, offset=radius+8, text=Text.category(c.category), alpha=1})
		elseif c:hasMark() then
			local stale = memory:stalenessOf(c)
			local covered = camera.covered(c.position, math.max(c.sizeWu, 0.2)*0.5+0.06)
			if showMark ~= false then
				table.insert(out.rings, {pos=point, radius=radius, alpha=(0.6-0.48*stale)*(if covered then 0.6 else 1),
					dash=1-0.7*stale, kind="mark", trackId=c.trackId})
			end
			local age = memory:ageS(c)
			if age < 2.5 then table.insert(out.labels, {pos=point, offset=radius+8, text=Text.LOST, alpha=math.clamp(1-age/2.5,0,1)}) end
		end
	end
	for _, e in sectors do table.insert(out.edges, e) end
	return out
end
return View
