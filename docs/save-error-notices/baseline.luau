-- Same actual-client failure probe on frozen predecessor and candidate.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
local Scenery=require("../src/Shared/Habitat/Scenery")
getfenv().warn=function(...) end -- Roblox diagnostic; plain CLI lacks warn.
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");workspace:SetAttribute("SelfTest",false)
Map.use("preserve")
local decor,replaced=Scenery.decor(nil,"preserve");decor.Parent=workspace
local hidden={};for id in replaced do hidden[id]=true end
Build.world(workspace,Map.SEED,hidden)
assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client did not load")
local d=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
d.title.seen=true
local ready=false;for _=1,120 do if d.fresh("free",false,nil) then ready=true;break end;frame(1/60) end
assert(ready,"fresh life did not start")
d.menu:hide();frame(1/60)
d.saveState.fail("synthetic baseline callback failure");frame(1/60)
local label=d.hud.saveNoticeLabel or d.hud.toastLabel
print("SAVE_ERROR_PROBE broken="..tostring(d.saveState.broken).." visible="..tostring(label.Visible).." text="..label.Text)
assert(d.saveState.broken and label.Visible,"save failure is hidden by active preserve HUD")
