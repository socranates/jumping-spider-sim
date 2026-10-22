-- Actual game/menu with protocol3 scripted replies and a fake save clock; no native/network proof.
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local Json=require("../src/Shared/Persistence/Json")
local SaveRules=require("../src/Shared/Data/SaveRules")
local SaveProgress=require("../src/Shared/Persistence/SaveProgress")
local SaveRest=require("../src/Shared/Persistence/SaveRest")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL MENU "..why) end end
local function fakeRemotes(): any
	local r: any = { fired = {} :: { any }, handlers = {} :: { (any) -> () } }
	r.server = { FireServer = function(_self: any, msg: any) table.insert(r.fired, Json.copy(msg)) end }
	r.client = { OnClientEvent = { Connect = function(_self: any, fn: (any) -> ()) table.insert(r.handlers, fn) end } }
	function r.deliver(msg: any) for _, h in r.handlers do h(msg) end end
	return r
end
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
workspace:SetAttribute("SaveWait", true)
local R = fakeRemotes()
-- The real-client transport fixture acknowledges intents; durability itself is exercised in state.luau.
local remember=R.server.FireServer
R.server.FireServer=function(self,msg)
 remember(self,msg)
 if msg.kind=="begin_life" then R.deliver({kind="life",mode=msg.mode,serial=msg.serial,token=`fixture:{msg.mode}:{msg.serial}`}) end
end
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = SaveRules.REMOTES_NAME
local toServer = Instance.new("Folder")
toServer.Name = "ToServer"
rawset(toServer, "FireServer", R.server.FireServer)
toServer.Parent = remotesFolder
local toClient = Instance.new("Folder")
toClient.Name = "ToClient"
rawset(toClient, "OnClientEvent", R.client.OnClientEvent)
toClient.Parent = remotesFolder
remotesFolder.Parent = game:GetService("ReplicatedStorage")
local loadedOk, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loadedOk then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local lp: any = game:GetService("Players").LocalPlayer
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	if not g then return nil end
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
local function firedOf(kind: string): { any }
	local out: { any } = {}
	for _, m in R.fired do if m.kind == kind then table.insert(out, m) end end
	return out
end
local function realWait(seconds: number)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do end
end

local Motor = require("../src/Shared/Movement/SpiderMotor")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local function storedRest(mode: string): any
	local motor = Motor.new({ world = workspace:FindFirstChild("Windowsill"), surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX })
	local prey = PreyDirector.engine(workspace:FindFirstChild("Windowsill"), Species.fly_like_prototype, 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, mode == "free" or mode == "easy")
	prey.feeding.needs = needs
	local life = LifeLoop.new(needs, function() return { ok = true, message = "" } end)
	if mode == "free" then life.mode, life.rules = "free", "gentle" end
	if mode == "easy" then life.mode, life.rules = "main", "gentle" end
	motor:place(Vector3.new(-25.5, Layout.SPAWN.Y, 6.0), Vector3.yAxis, Vector3.new(1, 0, 0))
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life }
	return assert(Checkpoint.capture(w, 0))
end


assert(loadedOk,"real client failed to load")
local d=assert(ClientStubs.driver);local time=os.clock();d.saveClient.cfg.now=function() return time end
local sequence=0
local function reply(msg) sequence+=1;msg.sequence=sequence;msg.epoch="menu-session";if msg.kind=="loaded" then msg.v=3 end;R.deliver(msg) end
local function advance() time+=6;frames(2) end
local function intent(mode,after)
 for _=1,8 do
  advance();local xs=firedOf("life_intent")
  for i=#xs,1,-1 do if xs[i].mode==mode and xs[i].serial>(after or 0) then return xs[i] end end
 end
 error("no intent for "..mode)
end
local function decide(r,rev,state,credential,reason)
 reply({kind="decision",decision={mode=r.mode,kind=r.intent,serial=r.serial,offerId=r.offerId,revision=rev,state=state,credential=credential,life="life_"..r.mode,reason=reason}})
end
frames(20);check(firedOf("hello")[1].v==3,"actual game negotiates3")
local records={main=storedRest("main"),free=storedRest("free"),easy=storedRest("easy")}
local offers={};for _,mode in SaveRules.MODES do offers[mode]={id="offer_"..mode,record=records[mode],protected=false} end
reply({kind="loaded",status="session",reason="other_session",progress=SaveProgress.snapshot({opened={},eye_seconds=0},true,nil,{}),offers=offers});frames(30);d.session.started=false;d.openMenu()
check(not d.stores.main:loadBest().ok and not d.stores.easy:loadBest().ok,"viewing offers never adopts local rests")
check(find("SpiderLifeMenu","Continue") and find("SpiderLifeMenu","ContinueEasy"),"remote menu choices")
check(string.find(find("SpiderLifeMenu","Continue").Text,"without saving",1,true),"temporary continuation described before choice")
local refreshCalls=0;local refresh=d.saveClient.refreshOffer
d.saveClient.refreshOffer=function(self,mode) refreshCalls+=1;return refresh(self,mode) end
reply({kind="offer",mode="main",offer=offers.main});frames(2)
check(refreshCalls==0,"render callback never recursively refreshes")
d.menu:choose("Continue");local first=intent("main")
check(first.offerId=="offer_main" and first.intent=="continue","choice binds displayed id")
check(d.session.started and d.currentStore()==d.stores.main and d.stores.main:loadBest().ok,"actual controller restores explicit snapshot")
local pos=d.motor.pos;local sig=assert(Json.canonical(d.stores.main:loadBest().record))
decide(first,1,"readonly",nil,"other_session");frames(2)
check((d.motor.pos-pos).Magnitude<.01 and Json.canonical(d.stores.main:loadBest().record)==sig,"decision never restores twice")
check(d.life.save().ok,"readonly local rest retained");advance();check(#firedOf("rest")==0,"readonly cannot upload")
decide(first,2,"writable","grant_main");reply({kind="status",status="saved"});advance()
local xs=firedOf("rest");local rest=xs[#xs]
check(rest and rest.mode=="main" and rest.credential=="grant_main" and #SaveRest.check("main",rest.record)==0,"grant sends actual controller checkpoint")
check(d.saveClient:status()=="saving","no Saved before storage receipt")
reply({kind="stored",mode="main",serial=first.serial,credential="grant_main",restSerial=rest.restSerial});frames(2)
check(d.saveClient:status()=="saved","durable receipt confirms controller save")
decide(first,3,"changed",nil,"changed")
local newer=Json.copy(records.main);newer.player.position[1]+=1
reply({kind="offer",mode="main",offer={id="new_main",record=newer,protected=false}});frames(2);d.openMenu()
check(find("SpiderLifeMenu","RemoteMain"),"changed recovery offers replacement")
local current=assert(Json.canonical(d.stores.main:loadBest().record));local active=d.motor.pos
d.menu:choose("RemoteMain")
check(find("SpiderLifeMenu","CancelLoad") and string.find(find("SpiderLifeMenu","Sub").Text,"unsaved world",1,true),"replacement requires confirmation")
reply({kind="offer",mode="main",offer={id="newest_main",record=records.main,protected=false}});d.menu:choose("RemoteMain")
check(d.saveClient:decision("main").state=="changed" and Json.canonical(d.stores.main:loadBest().record)==current,"offer change during confirmation cannot silently rebind")
check((d.motor.pos-active).Magnitude<.01,"stale choice preserves running spider")
d.menu:choose("RemoteMain");d.menu:choose("CancelLoad")
check(Json.canonical(d.stores.main:loadBest().record)==current,"cancel preserves local world")
d.menu:choose("RemoteMain");d.menu:choose("RemoteMain");local second=intent("main",first.serial)
check(second.offerId=="newest_main","new confirmation binds refreshed explicit id")
for _,pair in {{"easy","ContinueEasy"},{"free","Free"}} do
 local mode,choice=pair[1],pair[2];d.openMenu();d.menu:choose(choice)
 check(find("SpiderLifeMenu","CancelLoad"),mode..": remote switch asks before discarding visit")
 d.menu:choose(if mode=="free" then "RemoteFree" else "ContinueEasy");local r=intent(mode)
 check(r.offerId=="offer_"..mode,mode..": separate slot binding")
 check(d.currentStore()==d.stores[mode] and d.life.rules=="gentle",mode..": actual slot/rules restored")
end
-- Restoration failure keeps the current live world/store and removes the new upload path.
d.openMenu();local mainRequest=d.saveClient:decision("main")
if mainRequest then decide({mode="main",intent=mainRequest.kind,serial=mainRequest.serial,offerId=mainRequest.offerId},mainRequest.revision+1,"changed",nil,"changed") end
reply({kind="offer",mode="main",offer={id="failure-main",record=records.main,protected=false}});d.openMenu()
local beforeStore=d.currentStore();local beforePosition=d.motor.pos
local restore=Checkpoint.restore;Checkpoint.restore=function() return false,{"synthetic restore failure"} end
local previousWarn=warn;getfenv().warn=function() end
d.menu:choose("RemoteMain");d.menu:choose("RemoteMain")
Checkpoint.restore=restore;getfenv().warn=previousWarn
check(d.currentStore()==beforeStore and (d.motor.pos-beforePosition).Magnitude<.01,"failed restoration keeps current world and store")
check(d.saveClient:decision("main")==nil and d.saveClient:isTemporary("main"),"failed restoration cannot leave a credential request behind")
d.openMenu();check(find("SpiderLifeMenu","RemoteMain"),"failed restore still allows another explicit saved-world choice")
-- New confirmation never silently rebinds to an offer arriving while it is shown.
d.menu:choose("New")
check(find("SpiderLifeMenu","CancelNew"),"New asks before replacing a running life")
reply({kind="offer",mode="main",offer={id="changed-during-new",record=records.main,protected=false}})
d.menu:choose("New")
check(d.saveClient:decision("main")==nil and d.saveClient:isTemporary("main"),"stale New confirmation revokes old permission and starts only a temporary life")
d.session.finishedMain=false;d.openMenu()
check(find("SpiderLifeMenu","Easy")==nil and find("SpiderLifeMenu","ContinueEasy")==nil,"Easy choices remain locked without the unlock")
check(not d.menu:choose("Easy"),"locked Easy cannot be activated through menu choice")
print(`CONTINUATION_MENU passed={passed} failed={failed}`)
assert(failed==0,"menu failures")
