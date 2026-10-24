local Hud=require("../src/Client/SpiderHud")
local Settings=require("../src/Shared/UI/SettingsModel")
local passed,failed=0,0
local function check(v,msg)if v then passed+=1 else failed+=1;print("FAIL HUNGER_VEIL "..msg)end end
local function view(food,style)
 return {minimal=true,device="keyboard",food=food,hungerStyle=style or "veil",dot=true,status={}}
end
local gui=Instance.new("Folder");local hud=Hud.new(gui)
check(#hud.hungerEdges==4 and #hud.centre:GetChildren()<20,"bounded overlays, no emitter or image asset")
local oldExtent,oldOpacity=0,0
for i=100,0,-1 do
 local extent,opacity=Hud.hungerVeil(i/100)
 check(extent>=oldExtent and opacity>=oldOpacity,"hunger closes inward monotonically")
 check(extent<=.32+1e-9 and opacity<=.4,"central 36 percent clear, tint bounded")
 oldExtent,oldOpacity=extent,opacity
end
hud:update(view(1),1/60)
for _,edge in hud.hungerEdges do check(not edge.Visible,"fed spider sees a clear scene") end
hud:update(view(0),10)
check(not hud.food.Visible and not hud.foodText.Visible and hud.foodText.Text=="","veil replaces bar with no hunger words")
for _,edge in hud.hungerEdges do
 check(edge.Visible and not edge.Active and edge.BackgroundTransparency>=.6,"soft edges never intercept input or become opaque")
 check(edge:GetChildren()[1].ClassName=="UIGradient","edge fades towards centre")
end
check(hud.reticle.Visible,"manual aim remains available")
local low=hud.hungerFood;hud:update(view(1),.1)
check(hud.hungerFood>low and hud.hungerFood<1,"eating eases the pressure instead of flashing")
local stopped=view(0);stopped.hungerPaused=true;hud:update(stopped,.1)
for _,edge in hud.hungerEdges do check(not edge.Visible,"menus, death and inspection clear veil") end
hud:update(view(.2,"bar"),.1)
check(hud.food.Visible and math.abs(hud.foodFill.Size.X.Scale-.2)<1e-8,"accessibility fallback retains exact wordless reserve")
for _,edge in hud.hungerEdges do check(not edge.Visible,"bar choice disables every edge") end
-- Settings uses the same versioned account format as the existing choices.
check(Settings.default("HungerDisplay")=="veil" and Settings.clean("HungerDisplay","bar")=="bar","default and fallback validate")
check(Settings.clean("HungerDisplay","opaque")==nil,"unknown appearance refused")
local results={}
for _,fps in {30,60,144} do
 local h=Hud.new(gui);h:update(view(1),0)
 for _=1,fps*2 do h:update(view(.1),1/fps) end
 table.insert(results,h.hungerFood)
end
check(math.abs(results[1]-results[2])<1e-10 and math.abs(results[1]-results[3])<1e-10,"transition follows elapsed time at 30/60/144 FPS")
print(`HUNGER_VEIL passed={passed} failed={failed}`)
if failed>0 then error("hunger veil checks failed")end
