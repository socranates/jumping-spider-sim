--!strict
-- Included only in tests.project.json. Drives the real player controller, not a duplicate motor.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
return function(driver)
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
	local passed=0
	for _,row in rows do if row.passed then passed+=1 end end
	print("PORT_CLIENT_REPORT "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),tests=#rows,passed=passed,failed=#rows-passed,results=rows}))
	driver.input:clear()
	-- Leave a recoverable hanging pose for visual inspection in the test place.
	driver.place(Vector3.new(-1,4.51,0)); driver.drop()
end
