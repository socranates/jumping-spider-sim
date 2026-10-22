-- Real WorldClient cache regression, under the CLI shim. Native stream behavior needs its own run.
local WorldMap=require("../src/Shared/World/WorldMap")
local WorldBuild=require("../src/Shared/World/WorldBuild")
local WorldClient=require("../src/Client/WorldClient")
local Region=require("../src/Shared/World/Region")
local pass,fail=0,0
local function case(name,fn)
 local ok,err=pcall(fn)
 if ok then pass+=1 else fail+=1;print("FAIL STREAM_READINESS "..name..": "..tostring(err)) end
 workspace:ClearAllChildren()
end
local function setup()
 workspace:ClearAllChildren();WorldMap.use("test_garden")
 local root=WorldBuild.world(workspace)
 local client=WorldClient.new(workspace,Instance.new("Player"),WorldMap)
 local bed=assert(WorldMap.region("bed_a"));client.region=bed
 local folder=assert(client:folderOf(bed))
 assert(client:creatureLive("bed_a") and client.whole.bed_a,"fixture was not first ready")
 return client,folder,root
end
case("atomic folder leaves after first arrival",function()
 local client,folder=setup();folder.Parent=nil
 assert(not client:regionReady("bed_a"),"fixture has not left")
 assert(not client:creatureLive("bed_a"),"resident still simulates on streamed-out geometry")
end)
case("one collision piece leaves after first arrival",function()
 local client,folder=setup();folder:GetChildren()[1].Parent=nil
 assert(not client:regionReady("bed_a"),"fixture is not partial")
 assert(not client:creatureLive("bed_a"),"resident still simulates on partial geometry")
end)
case("partial rearrival refuses then resumes same creature gate",function()
 local client,folder,root=setup();folder.Parent=nil
 local part=folder:GetChildren()[1];part.Parent=nil;folder.Parent=root
 assert(not client:creatureLive("bed_a"),"partial replacement treated as ready")
 part.Parent=folder
 assert(client:creatureLive("bed_a"),"complete geometry did not resume")
end)
print(string.format("STREAM_READINESS: %d passed, %d failed",pass,fail))
if fail>0 then error("stream readiness regression",0) end
