--!strict
-- ReplicatedFirst's one script (ROBLOX-109): the game's own loading screen, First/SplashScreen. Whatever happens in it, it ends: SplashScreen.run is
-- itself inside a pcall; an unready client retains a recovery message until ready or destroyed. This pcall also covers the require.
local ok, err = pcall(function()
	local module = script.Parent:WaitForChild("SplashScreen", 10)
	if module == nil then error("SplashScreen did not arrive") end
	local SplashScreen: any = (require :: any)(module)
	SplashScreen.run()
end)
if not ok then warn("[Windowsill] splash: " .. tostring(err)) end
