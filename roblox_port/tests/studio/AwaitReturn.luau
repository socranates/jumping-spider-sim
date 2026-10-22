-- Wait for actual local-return preparation without changing production budgets.
return function(driver:any,step:()->()):any
 for _=1,10000 do
  if driver.saveState.localRestore.job==nil then return driver.saveState.localReturnResult end
  step()
 end
 error("local return preparation did not finish")
end
