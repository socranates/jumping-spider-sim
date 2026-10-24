assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local gui=assert(game.Players.LocalPlayer.PlayerGui:FindFirstChild("TouchFontCheck"))
gui:Destroy()
print("[TOUCH_FONT_CLEANUP]","own_comparison_overlay_removed")
