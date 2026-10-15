--!strict
-- A minimal in-process signal, the stand-in for a Godot `signal`: handlers run synchronously, in the order they were connected, when
-- the signal is emitted. Pure Luau (no BindableEvent) so the plain CLI can run the perception logic that announces its changes with it.
local Signal = {}
Signal.__index = Signal

export type Signal = {
	connect: (self: Signal, handler: (...any) -> ()) -> () -> (),
	emit: (self: Signal, ...any) -> (),
}

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal) :: any
end

-- Returns a function that disconnects this handler.
function Signal.connect(self: any, handler: (...any) -> ()): () -> ()
	table.insert(self._handlers, handler)
	return function()
		local i = table.find(self._handlers, handler)
		if i then
			table.remove(self._handlers, i)
		end
	end
end

function Signal.emit(self: any, ...: any)
	local handlers: { (...any) -> () } = table.clone(self._handlers)
	for _, handler in handlers do
		handler(...)
	end
end

return Signal
