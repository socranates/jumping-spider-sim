--!strict
-- Persistent saves, the server's side (ROBLOX-39). Wires the engine to SaveService: the DataStore, the two remotes, the players coming and
-- going, the once-a-second step and BindToClose. All the logic is in Server/SaveService and Shared/Persistence/Save*; this script only
-- connects them, so a failure here can never stop the world from being built (Main.server.luau is separate).
--
-- Which store: Studio and the test place use "WindowsillTest_v1", a live server "Windowsill_v1" (SaveStores.name). Reading and writing
-- need Game Settings > Security > "Enable Studio Access to API Services" in Studio and a place that has been published; without them
-- DataStore calls fail, the session is session-only and says so ("no_api"), and the game plays exactly as it did before saves existed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SaveRules = require(Shared.Data.SaveRules)
local SaveStores = require(Shared.Persistence.SaveStores)
local MemoryBackend = require(Shared.Persistence.MemoryBackend)
local SaveService = require(script.Parent.SaveService)
local DataStoreBackend = require(script.Parent.DataStoreBackend)

local isStudio = RunService:IsStudio()
local isTestPlace = ServerScriptService:FindFirstChild("PortTests") ~= nil
local storeName = SaveStores.name(isStudio, isTestPlace, Workspace:GetAttribute("SaveStore"))

-- The real DataStore when the service can be asked for one; otherwise the in-memory backend (a session that lasts as long as the server).
local backend: any
local okStore, store = pcall(function(): any return game:GetService("DataStoreService"):GetDataStore(storeName) end)
if okStore and store ~= nil then
	backend = DataStoreBackend.new(store)
else
	warn("[Windowsill] saves: no DataStore service (" .. tostring(store) .. "); saving stays in memory for this server")
	backend = MemoryBackend.new()
end
print("[Windowsill] saves: store " .. storeName .. (if okStore then "" else " (memory)"))
Workspace:SetAttribute("SaveStoreName", storeName)

local folder = Instance.new("Folder")
folder.Name = SaveRules.REMOTES_NAME
local toServer = Instance.new("RemoteEvent")
toServer.Name = "ToServer"
toServer.Parent = folder
local toClient = Instance.new("RemoteEvent")
toClient.Name = "ToClient"
toClient.Parent = folder

local service = SaveService.new({
	backend = backend,
	now = os.time,
	sleep = function(seconds: number) task.wait(seconds) end,
	spawn = function(fn: (...any) -> ...any, ...: any) task.spawn(fn, ...) end,
	send = function(player: SaveService.Player, msg: { [string]: any }) toClient:FireClient(player :: any, msg) end,
	jobId = game.JobId,
	log = function(text: string) warn("[Windowsill] saves: " .. text) end,
})

toServer.OnServerEvent:Connect(function(player: Player, msg: any)
	service:onMessage(player, msg)
end)
folder.Parent = ReplicatedStorage -- after the event is connected: a client that sees the folder can speak

Players.PlayerAdded:Connect(function(player: Player)
	service:addPlayer(player)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	service:removePlayer(player)
end)
for _, player in Players:GetPlayers() do
	service:addPlayer(player)
end

task.spawn(function()
	while true do
		task.wait(1)
		service:step()
	end
end)

game:BindToClose(function()
	service:shutdown()
end)
