--!strict
-- Frozen field_notebook.gd rules. Player discoveries, never spider perception or a world checkpoint.
local Pages = require(script.Parent.Parent.Data.NotebookPages)
local Signal = require(script.Parent.Parent.Perception.Signal)
local Book = {}
Book.__index = Book
function Book.new(): any
	local byId = {}
	for _, page in Pages do byId[page.id] = page end
	return setmetatable({pages=Pages, byId=byId, opened={}, eyeSeconds=0, pageOpened=Signal.new()}, Book)
end
function Book.isOpen(self: any, id: string): boolean return table.find(self.opened,id) ~= nil end
function Book.page(self: any, id: string): any
	-- A UI can only read discovered pages; no hidden-page count is exposed by the view.
	return if self:isOpen(id) then self.byId[id] else nil
end
function Book.notice(self: any, trigger: string): {string}
	local opened = {}
	for _, page in self.pages do
		if page.trigger == trigger and not self:isOpen(page.id) then
			table.insert(self.opened,page.id); table.insert(opened,page.id)
			self.pageOpened:emit(page.id)
		end
	end
	return opened
end
function Book.noticeJump(self: any, distance: number)
	if distance ~= distance or distance < 0 or distance == math.huge then return end
	self:notice("jump")
	if distance >= 5 then self:notice("jump_far") end
	if distance >= 8 then self:notice("jump_long") end
end
function Book.addEyeTime(self: any, seconds: number)
	if seconds ~= seconds or seconds <= 0 or seconds == math.huge then return end
	local before = self.eyeSeconds
	self.eyeSeconds += seconds
	for _, mark in {20,60} do
		if before < mark and self.eyeSeconds >= mark then self:notice("eye_time_"..mark) end
	end
end
function Book.toRecord(self: any): any
	return {opened=table.clone(self.opened),eye_seconds=self.eyeSeconds}
end
function Book.load(self: any, record: any)
	-- Godot's tolerant player-notes load: drop missing/duplicate IDs; malformed data becomes empty.
	self.opened={};self.eyeSeconds=0
	if type(record) ~= "table" then return end
	if type(record.opened)=="table" then
		for _,id in record.opened do
			if type(id)=="string" and self.byId[id] and not self:isOpen(id) then table.insert(self.opened,id) end
		end
	end
	local t=record.eye_seconds
	if type(t)=="number" and t==t and t<math.huge then self.eyeSeconds=math.max(0,t) end
end
return Book
