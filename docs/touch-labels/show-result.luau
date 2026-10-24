-- Reframe only the temporary comparison GUI for the short Studio viewport.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local gui=assert(game.Players.LocalPlayer.PlayerGui:FindFirstChild("TouchFontCheck"))
local paper=assert(gui:FindFirstChildWhichIsA("Frame"))
paper.Position=UDim2.fromOffset(20,4);paper.Size=UDim2.fromOffset(670,250)
for _,child in paper:GetChildren()do
 if child:IsA("TextLabel")then
  if string.find(child.Text,"Original font at left",1,true)==1 then child.Position=UDim2.fromOffset(10,170)end
  if string.find(child.Text,"Candidate failures:",1,true)==1 then child.Position=UDim2.fromOffset(10,205)end
 end
end
print("[TOUCH_FONT_REFLOW]","fixture_display_only_no_metrics_or_game_widgets_changed")
