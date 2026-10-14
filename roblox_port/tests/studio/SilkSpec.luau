--!strict
return function(check)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Silk=require(Shared.Movement.SilkController)
	local world=Instance.new("Folder"); world.Name="SilkTestWorld"; world.Parent=workspace
	local function part(name,position,size,profile)
		local p=Instance.new("Part"); p.Name=name; p.Position=position; p.Size=size; p.Anchored=true
		p:SetAttribute("ProfileId",profile or "solid"); p.Parent=world; return p
	end
	part("Floor",Vector3.new(100,-0.5,0),Vector3.new(30,1,20))
	local leaf=part("Leaf",Vector3.new(100,5,0),Vector3.new(4,0.2,4))
	local wall=part("Wall",Vector3.new(106,4,0),Vector3.new(0.2,8,8))
	local surfaces={solid={attachable=true,silk_anchor_allowed=true},noSilk={attachable=true,silk_anchor_allowed=false},slippery={attachable=false,silk_anchor_allowed=true}}
	local function new() return Silk.new(world,surfaces,{max_line_length_wu=20,reel_speed_wu_s=1.5},35) end
	local function drop()
		local s=new()
		local p=Vector3.new(101.95,5.41,0)
		assert(s:startDrop(p,Vector3.yAxis,Vector3.xAxis))
		return s,Vector3.new(102.36,5.41,0),Vector3.new(0.6,0,0)
	end
	local ok,err=pcall(function()
		check("floor refuses lowering without room below",function()
			local s=new(); local plan=s:planDrop(Vector3.new(110,0.31,0),Vector3.yAxis,Vector3.zAxis)
			assert(plan==nil)
		end)
		check("raised leaf chooses nearest edge",function()
			local s=new(); local plan=s:planDrop(Vector3.new(100,5.41,1),Vector3.yAxis,Vector3.zAxis)
			assert(plan and plan.direction.Z>0.95 and math.abs(plan.distance-1)<0.12)
		end)
		check("anchor policy and moving local-space anchor",function()
			local s=new(); local p=Vector3.new(100,5.41,0)
			leaf:SetAttribute("ProfileId","noSilk")
			assert(not s:startDrop(p,Vector3.yAxis,Vector3.xAxis))
			leaf:SetAttribute("ProfileId","solid")
			assert(s:startDrop(p,Vector3.yAxis,Vector3.xAxis))
			local old=s.anchor; leaf.Position+=Vector3.new(0,1,0); s:refresh()
			local offset=s.anchor-old; leaf.Position-=Vector3.new(0,1,0)
			assert((offset-Vector3.yAxis).Magnitude<1e-5)
		end)
		check("payout never constrains a valid flight",function()
			local s=new(); local p=Vector3.new(100,5.41,0)
			local hit=workspace:Raycast(p,Vector3.new(0,-1,0),s.params)
			assert(s:anchorAt(hit,p))
			for i=1,30 do s:payout(Vector3.new(100+i/10,6,0)); assert(s.mode=="payout" and not s.taut) end
		end)
		check("miss catches within paid length and settles",function()
			local s,p,v=drop(); s.lowering=false; s:lock(p,0.25)
			local caught=false
			for _=1,180 do
				local hit; p,v,hit=s:step(p,v,0,false)
				assert(not hit,"unexpected landing")
				caught=caught or s.taut
				assert(s:path(p)<=s.rest+0.02 and v.Magnitude<15)
			end
			assert(caught and v.Magnitude<0.5)
		end)
		check("deliberate leaf drop hangs then lowers to floor",function()
			local s,p,v=drop()
			for _=1,120 do local hit; p,v,hit=s:step(p,v,0,false); assert(not hit) end
			assert(s.taut and p.Y<5)
			local landed=nil
			for _=1,480 do p,v,landed=s:step(p,v,-1,false); if landed then break end end
			assert(landed and landed.Instance.Name=="Floor")
		end)
		check("reel after leaf drop grabs the leaf",function()
			local s,p,v=drop()
			for _=1,90 do p,v=s:step(p,v,0,false) end
			local landed=nil
			for _=1,360 do p,v,landed=s:step(p,v,1,false); if landed then break end end
			assert(landed and landed.Instance==leaf,`no leaf grab: {s.block} p={p}`)
		end)
		check("wall drop lowers to floor",function()
			local s=new(); local p=Vector3.new(105.59,6,0); local v=Vector3.new(-0.6,0,0)
			assert(s:startDrop(p,-Vector3.xAxis,-Vector3.xAxis))
			local landed=nil
			for _=1,480 do p,v,landed=s:step(p,v,-1,false); if landed then break end end
			assert(landed and landed.Instance.Name=="Floor")
		end)
		check("one bend snags at a second obstruction and clears again",function()
			local s,p,v=drop()
			for _=1,120 do p,v=s:step(p,v,0,false) end
			assert(s.bend~=nil,"leaf edge should retain one bend")
			local bend=s.bend
			local obstruction=part("SecondObstacle",(bend+p)*0.5,Vector3.one*0.12,"slippery")
			s:geometry(p)
			local snagged=s.snagged
			obstruction:Destroy(); s:geometry(p)
			assert(snagged and not s.snagged,"second obstruction must snag then clear")
			s:geometry(Vector3.new(101.95,5.41,0))
			assert(s.bend==nil,"clear direct path removes bend")
		end)
		check("anchor deletion releases without invalid coordinates",function()
			local s,p,v=drop(); leaf.Parent=nil
			p,v=s:step(p,v,0,false); leaf.Parent=world
			assert(s.mode=="none" and p.X==p.X and v.X==v.X)
		end)
		check("blocked reel cannot pull through nonattachable wall",function()
			local s=new(); wall:SetAttribute("ProfileId","slippery")
			local p=Vector3.new(105.5,6,0); local v=Vector3.zero
			local hit=workspace:Raycast(p,Vector3.xAxis,s.params)
			assert(s:anchorAt(hit,p)); s:lock(p,0.25)
			-- A point behind the wall must be stopped by a body sweep.
			local moved=s:move(p,Vector3.new(2,0,0),v,1)
			wall:SetAttribute("ProfileId","solid")
			assert(moved.X<105.61)
		end)
	end)
	world:Destroy()
	if not ok then error(err) end
end
