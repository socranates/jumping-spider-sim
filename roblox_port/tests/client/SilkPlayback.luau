--!strict
-- Included only in tests.project.json. Drives the real player controller, not a duplicate motor.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
return function(driver: any)
	local rows={}
	local function untilState(predicate,seconds)
		local deadline=os.clock()+seconds
		repeat RunService.Heartbeat:Wait(); if predicate(driver.get()) then return true end until os.clock()>=deadline
		return false
	end
	local function check(name,fn)
		local ok,err=pcall(fn)
		table.insert(rows,{name=name,passed=ok,detail=if ok then "" else tostring(err)})
	end
	check("player walks to edge and hangs",function()
		driver.place(Vector3.new(-1,4.51,0))
		driver.drop()
		assert(driver.get().walking,"did not start edge walk")
		assert(untilState(function(s) return s.line=="locked" and s.taut and s.position.Y<3.9 end,12),"no hanging state")
	end)
	check("held lower reaches sill floor",function()
		driver.input:set("Drop",true)
		assert(untilState(function(s) return s.mode=="attached" and s.position.Y<0.4 end,15),"did not land on sill")
		driver.input:set("Drop",false)
	end)
	check("player reels back to leaf",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no line")
		driver.input:set("Forward",true)
		assert(untilState(function(s) return s.mode=="attached" and s.position.Y>3.5 end,12),"no leaf recovery")
		driver.input:set("Forward",false)
	end)
	-- ROBLOX-08 controls through the real client: the same path a key, button or finger takes (SpiderInput.simulate).
	local function wait(seconds: number)
		local t=os.clock()+seconds
		repeat RunService.Heartbeat:Wait() until os.clock()>=t
	end
	check("a tap of Jump hops forward",function()
		driver.place(Vector3.new(-22,0.31,6)); wait(0.2)
		local start=driver.get().position
		driver.input:simulate("Jump",true); RunService.Heartbeat:Wait(); driver.input:simulate("Jump",false)
		assert(untilState(function(s) return s.mode=="air" end,1),"no hop")
		assert(untilState(function(s) return s.mode=="attached" end,3),"did not land")
		local moved=(driver.get().position-start).Magnitude
		assert(moved>1.2 and moved<1.8,`hopped {moved}`)
	end)
	check("Q during an aim cancels it and the release does not leap",function()
		driver.place(Vector3.new(-22,0.31,6)); wait(0.2)
		local start=driver.get().position
		driver.input:simulate("Jump",true); wait(0.4)
		assert(driver.jump:isAiming(),"no aim after a 0.4 s hold")
		driver.input:simulate("Cancel",true); wait(0.05); driver.input:simulate("Cancel",false); wait(0.05)
		driver.input:simulate("Jump",false); wait(0.4)
		assert(driver.get().mode=="attached" and (driver.get().position-start).Magnitude<0.05,"leapt after a cancel")
		assert(driver.jump.last and driver.jump.last.kind=="cancelled","no cancel recorded")
	end)
	check("a key and a finger hold Cancel together; only a deliberate hold lets go of the line",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no hang")
		wait(0.6)
		driver.input:simulate("Cancel",true,"touch")
		driver.input:simulate("Cancel",true,Enum.KeyCode.Q)
		wait(0.25)
		driver.input:simulate("Cancel",false,"touch")
		assert(driver.input.held.Cancel==true and driver.get().line=="locked","releasing the finger dropped the key's hold")
		assert(untilState(function(s) return s.line=="none" end,1.5),"a held Q did not let go")
		driver.input:simulate("Cancel",false,Enum.KeyCode.Q)
		assert(untilState(function(s) return s.mode=="attached" end,6),"did not land after letting go")
	end)
	check("on the line the prompts name each device's controls, wrap and stay on screen; the camera never rolls",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no hang")
		local gui=game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("SpiderPrompts") :: ScreenGui
		local panel=gui:WaitForChild("PromptPanel") :: Frame
		local expected: {[string]: string}={keyboard="hold Q: let go",gamepad="hold B: let go",touch="hold Let go: let go"}
		for device,word in expected do
			driver.setDevice(device); wait(0.15)
			local hint=panel:FindFirstChild("PromptHint") :: TextLabel
			assert(hint.Visible and string.find(hint.Text,word,1,true),`{device}: "{hint.Text}"`)
			assert(hint.TextFits,`{device}: the hint does not fit`)
			local a,b,screen=panel.AbsolutePosition,panel.AbsoluteSize,gui.AbsoluteSize
			assert(a.X>=0 and a.Y>=0 and a.X+b.X<=screen.X+1 and a.Y+b.Y<=screen.Y+1,`{device}: panel off screen`)
		end
		driver.setDevice("keyboard")
		local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Include; overlap.FilterDescendantsInstances={driver.sill}
		local deadline=os.clock()+1.5
		driver.input:simulate("Forward",true)
		repeat
			RunService.Heartbeat:Wait()
			local cf=workspace.CurrentCamera.CFrame
			assert(math.abs(cf.RightVector.Y)<1e-4,"the camera rolled")
			assert(#workspace:GetPartBoundsInRadius(cf.Position,0.05,overlap)==0,"the camera is inside the sill")
		until os.clock()>deadline
		driver.input:simulate("Forward",false)
	end)
	local passed=0
	for _,row in rows do if row.passed then passed+=1 end end
	print("PORT_CLIENT_REPORT "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),tests=#rows,passed=passed,failed=#rows-passed,results=rows}))
	driver.input:clear()
	-- Leave a recoverable hanging pose for visual inspection in the test place.
	driver.place(Vector3.new(-1,4.51,0)); driver.drop()
end
