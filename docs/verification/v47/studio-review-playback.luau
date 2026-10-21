-- Temporary Studio-only playback, inserted as Client/SilkPlayback for review and removed before publication.
local Review = {}
function Review.run(d)
    Review.ctx = d
    local command=Instance.new("BindableEvent")
    command.Name="ChetReviewCommand";command.Parent=game.Players.LocalPlayer.PlayerScripts
    command.Event:Connect(function(kind,phase)
        if kind=="leaf" then Review.view(Vector3.new(10,7,15)) else Review.fixture(kind,phase) end
    end)
    _G.ChetReview = d
    task.spawn(function()
        local deadline = os.clock()+20
        while not d.session.started and os.clock()<deadline do
            if d.menu:isShowing() then d.menu:choose("New") end
            task.wait(0.2)
        end
        task.wait(3)
        if d.title:holding() then d.title:skip() end
        task.wait(2)
        local RS = game:GetService("RunService")
        local base = Vector3.new(-5,0.31,-9)
        local function measure(run,creep)
            d.place(base); d.motor.heading=Vector3.zAxis; d.cam:snap()
            d.input:simulate("Forward",true,"review")
            d.input:simulate("Run",run,"review")
            d.input:simulate("Creep",creep,"review")
            local p=d.motor.pos; local t=os.clock()
            for _=1,45 do RS.RenderStepped:Wait() end
            local speed=(d.motor.pos-p).Magnitude/(os.clock()-t)
            d.input:clear()
            return speed
        end
        local walk,run,creep,both=measure(false,false),measure(true,false),measure(false,true),measure(true,true)
        print("[CHET_NATIVE_RUN]",walk,run,run/math.max(walk,0.001),creep,both)
        d.memory:clear(); d.lockOn.release(d.lock,"review")
        d.input:simulate("Creep",true,Enum.KeyCode.ButtonL1)
        print("[CHET_NATIVE_L1_EMPTY]",d.input.held.Creep==true,d.lock.trackId==nil)
        d.input:clear()
        local map=require(game.ReplicatedStorage.Shared.World.WorldMap)
        local region=map.region("garden_c3")
        assert(region,"missing garden_c3")
        d.place(region.spawn.pos+Vector3.yAxis*0.31)
        d.life.clock.hour=12
        task.wait(12)
        local leaves={}
        for _,m in workspace:GetDescendants() do
            if m:IsA("SpecialMesh") and m.MeshId=="rbxassetid://128470594939908" and m.Parent:IsA("BasePart") then table.insert(leaves,m.Parent) end
        end
        table.sort(leaves,function(a,b)return(a.Position-d.motor.pos).Magnitude<(b.Position-d.motor.pos).Magnitude end)
        assert(#leaves>0,"no live milkweed meshes")
        local leaf=leaves[1]; _G.ChetLeaf=leaf
        print("[CHET_MILKWEED]",#leaves,leaf:GetFullName(),leaf.Size,leaf.CFrame,leaf.Color,leaf.Transparency,leaf.CanCollide,leaf.CanQuery,leaf:FindFirstChildOfClass("SpecialMesh").Scale)
        _G.ChetView=function(offset)
            local focus=leaf.Position
            local target=CFrame.lookAt(focus+offset,focus)
            RS:UnbindFromRenderStep("ChetReviewCam")
            RS:BindToRenderStep("ChetReviewCam",Enum.RenderPriority.Camera.Value+20,function()
                workspace.CurrentCamera.CFrame=target
                workspace.CurrentCamera.Focus=CFrame.new(focus)
                local dof=game.Lighting:FindFirstChild("MacroDOF")
                if dof then dof.FocusDistance=offset.Magnitude end
            end)
        end
        Review.view = _G.ChetView
        _G.ChetView(Vector3.new(10,7,15))
        task.wait(2)
        local n,total,worst=0,0,0; local stop=os.clock()+5
        while os.clock()<stop do local dt=RS.RenderStepped:Wait();n+=1;total+=dt;worst=math.max(worst,dt) end
        print("[CHET_MILKWEED_FRAME]",n,total*1000/n,1000/(total*1000/n),worst*1000)
        print("[CHET_REVIEW_READY]",game.PlaceId,leaf.Position)
    end)
end

-- Diagnostic fixtures use the actual Roblox renderers; these are not encounters.
function Review.focus(at, offset, fov)
    local RS=game:GetService("RunService")
    RS:UnbindFromRenderStep("ChetReviewCam")
    RS:BindToRenderStep("ChetReviewCam",Enum.RenderPriority.Camera.Value+20,function()
        local cam=workspace.CurrentCamera
        cam.CFrame=CFrame.lookAt(at+offset,at);cam.Focus=CFrame.new(at);cam.FieldOfView=fov or 35
        local dof=game.Lighting:FindFirstChild("MacroDOF")
        if dof then dof.FocusDistance=offset.Magnitude;dof.InFocusRadius=10 end
    end)
end
function Review.fixture(kind, phase)
    local RS=game:GetService("RunService")
    if Review.connection then Review.connection:Disconnect() end
    if Review.folder then Review.folder:Destroy() end
    local folder=Instance.new("Folder");folder.Name="ChetTemporaryFixture";folder.Parent=workspace;Review.folder=folder
    local d=Review.ctx
    local at=d.motor.pos+Vector3.new(0,50,0)
    local t=0
    local Shared=game.ReplicatedStorage.Shared
    if kind=="first_spider" or kind=="rival_spider" or kind=="first_spider_male" then
        local Rig=require(Shared.Rig.SpiderRig)
        local rig=Rig.new(folder,d.world.root,kind,if kind=="first_spider" then "full" else "low",true)
        rig:setGrowthStage(4)
        local Display=require(Shared.Predator.RivalDisplay);local display=Display.new()
        local i={state="stalk",distance=5.5,seed=914,day=2,smaller=true,event=""}
        if phase=="spread" then i.distance=4 elseif phase=="grapple" then i.state="lunge"
        elseif phase=="retreat" or phase=="hold" then i.state="recover";i.event="missed";i.smaller=phase=="retreat"
        elseif phase=="none" or phase==nil then i.state="patrol" end
        Review.rig=rig;Review.display=display;Review.phase=i
        Review.connection=RS.RenderStepped:Connect(function(dt)
            t+=dt
            if kind=="rival_spider" then rig.threat=Display.step(display,dt,i);i.event="" end
            rig:update(CFrame.new(at),dt,true,false)
        end)
        Review.focus(at+Vector3.new(0,0.1,-0.05),Vector3.new(1.1,0.65,-2.1),35)
        print("[CHET_FIXTURE]",kind,phase,rig:count().total,at)
    elseif kind=="bird" then
        local body=require(game.Players.LocalPlayer.PlayerScripts.Client.BirdBody).new(folder,"full")
        local b={here=true,pos=at,heading=-Vector3.zAxis,pose=phase or "stand",cock=1,flying=false}
        Review.connection=RS.RenderStepped:Connect(function(dt)body:draw(b,dt,0)end)
        Review.focus(at+Vector3.new(0,5,0),Vector3.new(25,9,-30),40)
    elseif kind=="frog" then
        local body=require(game.Players.LocalPlayer.PlayerScripts.Client.PondBodies).new(folder,"full")
        local target=at+Vector3.new(0,0.9,-12)
        local f={here=true,pos=at,heading=-Vector3.zAxis,mouth=function()return at+Vector3.new(0,0.9,-4.4)end,
            tongue=function()return if phase=="tongue" then target else nil end}
        Review.connection=RS.RenderStepped:Connect(function(dt)t+=dt;body:draw(f,target,nil,nil,t)end)
        Review.focus(at+Vector3.new(0,1,-4),Vector3.new(15,6,-17),40)
    elseif kind=="fly" or kind=="hoverfly" or kind=="cricket" then
        local body=require(game.Players.LocalPlayer.PlayerScripts.Client.FlyBodies).new(folder,"full")
        local Species=require(Shared.Data.Species)
        local profile=if kind=="cricket" then Species.cricket_night_prototype elseif kind=="hoverfly" then Species.hoverfly_prototype else Species.fly_like_prototype
        local f={id="review",state=if kind=="hoverfly" then "REPOSITION" else "PERCHED",position=at,heading=-Vector3.zAxis,normal=Vector3.yAxis,profile=profile,serial=1,airborne=function(self)return self.state=="REPOSITION"end,alive=function()return true end}
        Review.connection=RS.RenderStepped:Connect(function(dt)t+=dt;body:draw({f},t)end)
        Review.focus(at,Vector3.new(1.1,1.7,-2.1),35)
    elseif kind=="strider" then
        local body=require(game.Players.LocalPlayer.PlayerScripts.Client.BugBodies).new(folder,"full")
        local b={id="s",kind="skater",position=at,heading=-Vector3.zAxis,normal=Vector3.yAxis,state="skate"}
        Review.connection=RS.RenderStepped:Connect(function(dt)t+=dt;b.position=at+Vector3.new(0,0,math.sin(t)*0.8);body:draw({b},t)end)
        Review.focus(at,Vector3.new(5,5,-7),40)
    end
end

return setmetatable(Review,{__call=function(_,d) Review.run(d) end})
