--!strict
-- The sole engine save entry point. It installs the complete Preserve owner at
-- cold server startup; no legacy scheduler wrapper or second save service runs.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local SSS=game:GetService("ServerScriptService")
local WS=game:GetService("Workspace")
local DataStores=game:GetService("DataStoreService")
local Shared=RS:WaitForChild("Shared")
local Rules=require(Shared.Data.SaveRules)
local Stores=require(Shared.Persistence.SaveStores)
local Map=require(Shared.World.WorldMap)
local Worlds=require(Shared.World.Worlds)
local Backend=require(script.Parent.DataStoreBackend)
local Compression=require(script.Parent.RestCompression)
local Composition=require(script.Parent.RecoveryStartup)
local Templates=require(script.Parent.RecoveryTemplates)
local BaseService=require(script.Parent.SaveService)
local testPlace=SSS:FindFirstChild("PortTests")~=nil
local storeName=Stores.name(Run:IsStudio(),testPlace,WS:GetAttribute("SaveStore"))
local codec=Compression.engine()
local function loadStore(): (any,any)
 local okay,value=pcall(function():any return DataStores:GetDataStore(storeName) end)
 if okay and value then
  return value,function():any return {
   read=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),
   write=DataStores:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)} end
 end
 warn("[Windowsill] DataStore unavailable; this visit cannot save: "..tostring(value))
 local unavailable={}
 function unavailable:GetAsync(...:any):any error("403: DataStore service unavailable") end
 function unavailable:UpdateAsync(...:any):any error("403: DataStore service unavailable") end
 -- Only a local failing adapter is admitted in this branch; it issues no SDK
 -- request and must reach the ordinary explicit no_api/session-only outcome.
 return unavailable,function():any return {read=4,write=4} end
end
local dataStore,available=loadStore()
local backend=Backend.new(dataStore,codec)
local function now():number return WS:GetServerTimeNow() end
local function sleep(seconds:number) task.wait(seconds) end
local function spawn(fn:any,...:any) task.spawn(fn,...) end
local function log(message:string) warn("[Windowsill] saves: "..message) end
local runTag=tostring(os.time())
local keyOf=if testPlace then function(player:any):string return `t{runTag}_{player.UserId}` end else nil
local worldId=Worlds.choose(WS:GetAttribute(Worlds.ATTRIBUTE))
local closing=false
local catalog,composition
if worldId==Worlds.PRESERVE then
 local root=WS:WaitForChild("World",90)
 assert(root and Map.world()==Worlds.PRESERVE,"save startup requires the authored Preserve world")
 local problem
 catalog,problem=Templates.new(root,function():boolean return not closing end)
 assert(catalog,problem)
end
assert(RS:FindFirstChild(Rules.REMOTES_NAME)==nil,"only one save engine may own the remotes")
local folder=Instance.new("Folder");folder.Name=Rules.REMOTES_NAME
local toServer=Instance.new("RemoteEvent");toServer.Name="ToServer";toServer.Parent=folder
local toClient=Instance.new("RemoteEvent");toClient.Name="ToClient";toClient.Parent=folder
local config={backend=backend,dataStore=dataStore,codec=codec,catalog=catalog,available=available,
 now=now,sleep=sleep,spawn=spawn,jobId=game.JobId,keyOf=keyOf,log=log,
 send=function(player:any,message:any) toClient:FireClient(player,message) end}
local service
if worldId==Worlds.PRESERVE then composition=Composition.new(config);service=composition.service
else service=BaseService.new(config) end -- frozen Test Garden keeps its ordinary save path
toServer.OnServerEvent:Connect(function(player:Player,message:any) service:onMessage(player,message) end)
folder.Parent=RS
WS:SetAttribute("SaveStoreName",storeName)
WS:SetAttribute("SaveStartupReady",true)
print("[Windowsill] saves: "..storeName.."; "..(if composition then "account-owned Preserve startup" else "ordinary Test Garden startup"))
Players.PlayerAdded:Connect(function(player:Player) if not closing then service:addPlayer(player) end end)
Players.PlayerRemoving:Connect(function(player:Player) service:removePlayer(player) end)
for _,player in Players:GetPlayers() do service:addPlayer(player) end
local nextOrdinary=now()
local connection=Run.Heartbeat:Connect(function()
 if closing then return end
 if composition or now()>=nextOrdinary then nextOrdinary=now()+1;service:step() end
end)
game:BindToClose(function()
 closing=true;connection:Disconnect()
 if catalog then catalog:close() end
 service:shutdown()
end)
