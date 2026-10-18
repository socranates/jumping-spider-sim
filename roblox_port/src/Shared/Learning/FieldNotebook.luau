--!strict
-- The naturalist's notebook (LEARN-01), a port of the frozen scripts/learning/field_notebook.gd without the file and the node.
-- Spec 4: "an optional naturalist notebook with sourced facts, separated from in-world perception". Each page of
-- Data/NotebookPages opens the first time its trigger happens in play: the first jump, the first time in the eye view, a first
-- meal, and so on. The notebook belongs to the player, not to the spider: the client keeps it outside the world's checkpoints (a
-- return to a rest never erases a page) and a new, unrelated spider opens the same book. It decides nothing in the game and the
-- spider learns nothing from it. Pages are listed in the order they were found; a page not yet found cannot be read through
-- `view` or `list`, and nothing counts the pages left (spec 4: discovery must not become a completion checklist).
-- Differences from Godot: the book is held in memory for the session (no file: server-owned saving is separate work); `toRecord`
-- and `load` are the shape of Godot's save and its tolerant reading, for that later work. Checked in tests/notebook.luau.

local Signal = require(script.Parent.Parent.Perception.Signal)
local Data = require(script.Parent.Parent.Data.NotebookPages)

local FieldNotebook = {}
FieldNotebook.__index = FieldNotebook

export type Page = Data.Page
export type Record = { opened: { string }, eye_seconds: number }

-- What is wrong with a page, empty when nothing is (Godot's `problems`): a missing field, an unknown trigger or no source.
function FieldNotebook.problems(p: any): { string }
	local out: { string } = {}
	if type(p) ~= "table" then
		return { "not a page" }
	end
	for _, key in { "id", "trigger", "title", "text" } do
		local v = p[key]
		if type(v) ~= "string" or string.match(v, "^%s*$") then
			table.insert(out, `no {key}`)
		end
	end
	if not table.find(Data.triggers, p.trigger) then
		table.insert(out, `unknown trigger {tostring(p.trigger)}`)
	end
	if type(p.sources) ~= "table" or #p.sources == 0 then
		table.insert(out, "no source")
	end
	return out
end

-- `pages` defaults to the notebook's own; a page with a problem or a repeated id is left out (and listed in `dropped`).
function FieldNotebook.new(pages: { Page }?): any
	local self = setmetatable({
		pages = {} :: { Page },
		opened = {} :: { string },
		eyeSeconds = 0.0,
		dropped = {} :: { string },
		pageOpened = Signal.new(), -- (id): a page opened now, after it is in `opened`
		_byId = {} :: { [string]: Page },
		_open = {} :: { [string]: boolean },
	}, FieldNotebook)
	for _, p in pages or Data.pages do
		if #FieldNotebook.problems(p) == 0 and not self._byId[p.id] then
			table.insert(self.pages, p)
			self._byId[p.id] = p
		else
			table.insert(self.dropped, if type(p) == "table" and type(p.id) == "string" then p.id else "?")
		end
	end
	return self
end

function FieldNotebook.isOpen(self: any, id: string): boolean
	return self._open[id] == true
end

-- Whether the book has a page of this id at all (found or not). The panel never shows anything else about an unfound page.
function FieldNotebook.has(self: any, id: string): boolean
	return self._byId[id] ~= nil
end

-- The page, only once it is found: nil before its observation, so nothing can show it early.
function FieldNotebook.view(self: any, id: string): Page?
	if self._open[id] then
		return self._byId[id]
	end
	return nil
end

-- Found pages as {id, title}, in the order they were found.
function FieldNotebook.list(self: any): { { id: string, title: string } }
	local out = {}
	for _, id in self.opened do
		table.insert(out, { id = id, title = self._byId[id].title })
	end
	return out
end

-- The id of the page found last (nil when none).
function FieldNotebook.newest(self: any): string?
	return self.opened[#self.opened]
end

-- Opens every page with this trigger that is not open yet. Returns the ids opened now, in the order of the pages.
function FieldNotebook.notice(self: any, trigger: string): { string }
	local now: { string } = {}
	for _, p in self.pages do
		if p.trigger == trigger and not self._open[p.id] then
			self._open[p.id] = true
			table.insert(self.opened, p.id)
			table.insert(now, p.id)
		end
	end
	for _, id in now do
		self.pageOpened:emit(id)
	end
	return now
end

-- A leap of `distanceWu` studs: the first jump, and a far and a long one.
function FieldNotebook.noticeJump(self: any, distanceWu: number)
	if distanceWu ~= distanceWu or distanceWu < 0 or distanceWu == math.huge then return end
	self:notice("jump")
	if distanceWu >= Data.jumpFarWu then
		self:notice("jump_far")
	end
	if distanceWu >= Data.jumpLongWu then
		self:notice("jump_long")
	end
end

-- Time in the spider-eye view, in seconds of play (the game's own time: slow motion slows it, a menu holds it).
function FieldNotebook.addEyeTime(self: any, seconds: number)
	local before = self.eyeSeconds
	if seconds == seconds and seconds > 0 and seconds < math.huge then
		self.eyeSeconds += seconds
	end
	for _, mark in Data.eyeMarks do
		if before < mark and self.eyeSeconds >= mark then
			self:notice(`eye_time_{mark}`)
		end
	end
end

-- The player's notebook as a plain record (Godot's file, as a table).
function FieldNotebook.toRecord(self: any): Record
	return { opened = table.clone(self.opened), eye_seconds = self.eyeSeconds }
end

-- Reads a record (Godot's load_saved). Anything unreadable is an empty notebook; ids no page has any more and repeats are
-- dropped; a bad number of eye seconds is none. Announces nothing.
function FieldNotebook.load(self: any, record: any)
	table.clear(self.opened)
	table.clear(self._open)
	self.eyeSeconds = 0.0
	if type(record) ~= "table" then
		return
	end
	if type(record.opened) == "table" then
		for _, id in record.opened do
			if type(id) == "string" and self._byId[id] and not self._open[id] then
				self._open[id] = true
				table.insert(self.opened, id)
			end
		end
	end
	local eye = record.eye_seconds
	if type(eye) == "number" and eye == eye and eye >= 0 and eye < math.huge then
		self.eyeSeconds = eye
	end
end

return FieldNotebook
