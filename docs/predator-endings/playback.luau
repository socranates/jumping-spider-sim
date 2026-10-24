--!strict
-- Unpublished unbound memory fixture. End-handler boundaries are deliberately
-- invoked; fast-clock survival accumulates from normal fresh needs over ticks.
-- No claim of natural predator encounters, feeding, reproduction or online saves.
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Probe=require(script.Parent.MatrixProbe)
local Texts:{{CAUSE:string,LINE:string,SUB:string}}={require(RS.Shared.UI.CatText),require(RS.Shared.UI.CrabText),require(RS.Shared.UI.BirdText),require(RS.Shared.UI.FrogText),require(RS.Shared.UI.WaterText)}
return function(d:any)
 assert(Run:IsStudio()and Run:IsClient()and game.PlaceId==0 and game.GameId==0)
 local tag=tostring(DateTime.now().UnixTimestampMillis)
 local connection;local diagnostic;local replies={};local serial=0
 local clock:any=nil;local originalAdvance:any=nil
 local function emit(kind:string,value:any)print("[LIFE_END_"..kind.."]",tag,Http:JSONEncode(value))end
 local function waitFor(fn:()->boolean,seconds:number?)
  local deadline=os.clock()+(seconds or 90)
  repeat if fn()then return end;assert(not d.saveState.broken,"save application failed");Run.Heartbeat:Wait()until os.clock()>=deadline
  error("life-end fixture deadline")
 end
 local function inspect(action:string):any
  serial+=1;local ticket=serial;diagnostic.Command:FireServer(action,ticket)
  waitFor(function():boolean return replies[ticket]~=nil end,30)
  return replies[ticket]
 end
 local function facts():any
  return{day=d.life.clock.day,hour=d.life.clock.hour,energy=d.needs.energy,streak=d.needs.starvingStreakH,
   rules=d.session.rules,mode=d.session.mode,ended=d.session.ended,life_over=d.life.lifeOver,
   attached=d.motor.mode=="attached",retreat=d.world:inRetreat(d.motor.pos),meals=d.prey.feeding.mealsFinished}
 end
 local function restoreClock()
  if clock and originalAdvance then clock.advance=originalAdvance end
  clock=nil;originalAdvance=nil
 end
 local function fresh(mode:string,easy:boolean)
  restoreClock()
  waitFor(function():boolean return not d.saveState.application:busy()end)
  d.openMenu(true)
  local slot=if mode=="free"then"free"elseif easy then"easy"else"main"
  assert(d.fresh(mode,easy,nil,d.saveState.menuOffers[slot]),"fresh mode refused")
  waitFor(function():boolean
   local decision=d.saveClient:decision(slot)
   return decision~=nil and decision.state=="writable"and not d.saveState.application:held()
    and not d.world.playerLoading and not d.menu:isShowing()and not d.title:holding()
  end)
  d.place(Vector3.new(-25.5,.31,6),Vector3.yAxis)
  waitFor(function():boolean return d.motor.mode=="attached"and d.world:inRetreat(d.motor.pos)=="sill_crevice"end)
 end
 local function fastClock()
  clock=d.life.clock;originalAdvance=clock.advance
  local original=originalAdvance
  clock.advance=function(self:any,dt:number,asleep:boolean):number return original(self,dt*120,asleep)end
 end
 local okay,why=xpcall(function()
  Probe.ready({fixture="life-endings",online=false})
  diagnostic=assert(RS:WaitForChild("NormalStartupDiagnostic",90))
  connection=diagnostic.Report.OnClientEvent:Connect(function(ticket:any,value:any)replies[ticket]=value end)
  waitFor(function():boolean return WS:GetAttribute("SaveStartupReady")==true and d.saveClient.newLifeEnabled and not d.saveClient:offerPending()and Players.LocalPlayer:GetAttribute("TitleReady")==true end)
  emit("BEGIN",{fast_clock=120,storage="yielding-memory",source="current ordinary with diagnostic boundary hooks"})
  for _,text in Texts do
   fresh("main",false)
   local deaths=d.session.deaths
   d.endLife(text.CAUSE)
   waitFor(function():boolean return d.session.ended and d.caughtPanel:isShowing()end,3)
   assert(d.session.deaths==deaths+1 and d.session.summary.cause==text.CAUSE)
   assert(d.caughtPanel.line.Text==text.LINE and d.caughtPanel.sub.Text==text.SUB)
   d.endLife("wasp");assert(d.session.deaths==deaths+1 and d.session.summary.cause==text.CAUSE)
   emit("ENDING",{cause=text.CAUSE,line=d.caughtPanel.line.Text,deaths=d.session.deaths,duplicate_refused=true})
   -- Wait through the actual end-card delay, then invoke its actual callback.
   waitFor(function():boolean return d.caughtPanel.seconds>=4 end,8)
   local count=#d.session.lives
   assert(d.caughtPanel:choose("Another"),"Another choice refused")
   waitFor(function():boolean return not d.session.ended and not d.caughtPanel:isShowing()end)
   assert(#d.session.lives==count+1 and d.session.lives[#d.session.lives].cause==text.CAUSE)
   emit("ANOTHER",{cause=text.CAUSE,archived=#d.session.lives,resumed=true})
  end
  fresh("main",false)
  assert(d.needs.energy>.5 and d.needs.starvingStreakH==0 and not d.needs.gentle)
  local began=d.life.elapsed;emit("SURVIVAL_START",facts());fastClock()
  waitFor(function():boolean return d.session.ended end,90)
  assert(d.life.lifeOver and d.session.summary.cause=="starved"and d.caughtPanel:isShowing())
  local ended=facts();ended.action_seconds=d.life.elapsed-began
  assert(ended.meals==0 and ended.energy==0 and ended.streak>=12 and ended.action_seconds>5)
  emit("STARVED",ended);restoreClock()
  -- Easy's availability is a setup precondition here, not a reproduced adult life.
  d.session.finishedMain=true
  for _,mode in {"easy","free"}do
   fresh(if mode=="free"then"free"else"main",mode=="easy")
   local start=(d.life.clock.day-1)*24+d.life.clock.hour
   assert(d.needs.gentle and d.needs.energy>.5)
   fastClock()
   waitFor(function():boolean return(d.life.clock.day-1)*24+d.life.clock.hour-start>=72 end,120)
   assert(not d.session.ended and not d.life.lifeOver and d.needs.energy>=.1-1e-9 and d.needs.starvingStreakH==0)
   for _,text in Texts do d.endLife(text.CAUSE)end
   assert(not d.session.ended and not d.caughtPanel:isShowing())
   emit("GENTLE",facts());restoreClock()
  end
  local final=inspect("finish")
  assert(final.active==0 and final.gate.scopes==0 and final.gate.started==0 and final.gate.queued==0 and final.optionsCreated==final.optionsDestroyed)
  emit("CLEANUP",final)
 end,debug.traceback)
 restoreClock();d.input:clear();if connection then connection:Disconnect()end
 emit(if okay then"PASS"else"FAIL",{problem=if okay then nil else tostring(why)})
 Probe.finish(okay,why)
end
