
local costs={}
local function timed(name,fn)
 local before=gcinfo();local at=os.clock();local result=fn()
 print(`COPY_COST stage={name} elapsed_ms={(os.clock()-at)*1000} heap_kib_before={before} heap_kib_after={gcinfo()}`)
 return result
end
local restores,validations,offerEvents=0,0,0
local continuation=__mods.SaveContinuation.new({rules=Rules,copy=Json.copy,
 validate=function(mode,r,retired)
 validations+=1
 if BASELINE then return #SaveRest.check(mode,r)==0 and #Checkpoint.check(r,world)==0 end
 return #SaveRest.check(mode,r,world)==0
end,
onOffer=function(mode,info) if info then offerEvents+=1 end end,
 onRestore=function(mode,r) restores+=1;assert(#Checkpoint.check(r,world)==0);return true end})
timed("receive_one_full_preserve_offer",function()
 assert(continuation:receive({kind="loaded",v=3,epoch="copy-cost",sequence=1,status="saved",offers={main={id="full",protected=false,record=fullRecord}}}))
end)
timed("repeat_unchanged_offer_5",function()
 for seq=3,7 do continuation:receive({kind="offer",epoch="copy-cost",sequence=seq,mode="main",offer={id="full",protected=false,record=fullRecord}}) end
end)
local copies=0;local copy=continuation.cfg.copy
continuation.cfg.copy=function(v) copies+=1;return copy(v) end
timed("menu_metadata_100_reads",function() for _=1,100 do assert(continuation:offerInfo("main").id=="full") end end)
assert(copies==0,"menu metadata copied the full world")
timed("explicit_continue_core",function() assert(continuation:choose("main","continue","full")) end)
assert(restores==1)
timed("queue_full_checkpoint",function() assert(continuation:checkpoint("main",fullRecord)) end)
local request=continuation:decision("main")
continuation:receive({kind="decision",epoch="copy-cost",sequence=8,decision={mode="main",kind="continue",serial=request.serial,offerId="full",revision=1,state="writable",credential="copy-grant",life=nil}})
local wire
timed("copy_outgoing_full_checkpoint_only",function()
 continuation:update(100,function(msg)
  if msg.kind=="rest" then
   wire=msg
  end
 end)
end)
assert(wire and #SaveRest.check("main",wire.record)==0)
print(`COPY_COST outgoing_canonical_chars={#assert(Json.canonical(wire))} record_chars={#assert(Json.canonical(fullRecord))}`)
assert(validations==(if BASELINE then 7 else 2),"unexpected full validation count")
assert(offerEvents==(if BASELINE then 6 else 1),"unchanged offer caused a redraw")
print(`COPY_COST validation_calls={validations} nonempty_offer_callbacks={offerEvents}`)
print("COPY_COST_DONE one_full_preserve_slot metadata_reads_100_full_copies_0 restores_1")
