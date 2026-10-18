--!strict
-- Moving about the settings panel without a mouse (ROBLOX-49): the rows in order (a header per section, the settings, then Reset and Back)
-- and which one is chosen. Up and Down step through the choosable rows and wrap; the shoulder buttons (PageUp and PageDown) jump from section
-- to section. Pure: tests/settings.luau checks it; Client/SettingsPanel draws it.
local SettingsModel = require(script.Parent.SettingsModel)

local SettingsNav = {}
SettingsNav.__index = SettingsNav

export type Row = { kind: string, id: string?, title: string?, section: string? }
-- kind: "header" (not choosable), "setting" (id), "reset", "back"

function SettingsNav.rows(): { Row }
	local out: { Row } = {}
	for _, sec in SettingsModel.sections() do
		table.insert(out, { kind = "header", id = sec.id, title = sec.title, section = sec.id })
		for _, item in sec.items do
			table.insert(out, { kind = "setting", id = item.id, section = sec.id })
		end
	end
	table.insert(out, { kind = "reset" })
	table.insert(out, { kind = "back" })
	return out
end

function SettingsNav.new(): any
	local rows = SettingsNav.rows()
	local self = setmetatable({ rows = rows, at = 1 }, SettingsNav)
	self:first()
	return self
end

local function choosable(row: Row): boolean
	return row.kind ~= "header"
end

function SettingsNav.first(self: any)
	for i, r in self.rows do
		if choosable(r) then
			self.at = i
			return
		end
	end
end

function SettingsNav.current(self: any): Row
	return self.rows[self.at]
end

function SettingsNav.select(self: any, index: number): boolean
	local r = self.rows[index]
	if r == nil or not choosable(r) then return false end
	self.at = index
	return true
end

function SettingsNav.selectId(self: any, id: string): boolean
	for i, r in self.rows do
		if r.kind == "setting" and r.id == id then
			self.at = i
			return true
		end
	end
	return false
end

-- One choosable row down (+1) or up (-1), wrapping.
function SettingsNav.move(self: any, dir: number)
	local n = #self.rows
	local step = if dir < 0 then -1 else 1
	local i = self.at
	for _ = 1, n do
		i = (i - 1 + step) % n + 1
		if choosable(self.rows[i]) then
			self.at = i
			return
		end
	end
end

-- The first setting of the next (+1) or previous (-1) section, wrapping; from Reset or Back, the first or last section.
function SettingsNav.section(self: any, dir: number)
	local starts: { number } = {}
	for i, r in self.rows do
		if r.kind == "header" then table.insert(starts, i + 1) end
	end
	if #starts == 0 then return end
	local here = self.rows[self.at]
	local current = 0
	for k, s in starts do
		if s <= self.at then current = k end
	end
	local target: number
	if dir < 0 then
		-- partway down a section, Previous goes to its start first
		if here.kind == "setting" and starts[current] ~= self.at then target = current else target = (current - 2) % #starts + 1 end
		if here.kind ~= "setting" then target = #starts end
	else
		target = current % #starts + 1
		if here.kind ~= "setting" then target = 1 end
	end
	self.at = starts[target]
end

return SettingsNav
