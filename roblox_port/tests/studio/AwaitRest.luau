-- Drive actual frames until a returned local-rest result is finalized. Immediate
-- refusals remain immediate; waiting is bounded and does not change game code.
return function(result:any,step:()->()):any
 assert(type(result)=="table","no rest result")
 for _=1,10000 do
  if not result.pending then return result end
  step()
 end
 error("local rest preparation did not finish")
end
