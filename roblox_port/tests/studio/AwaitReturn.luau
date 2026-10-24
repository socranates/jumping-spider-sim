-- Wait for actual local-return preparation without changing production budgets.
return function(driver:any,step:()->()):any
 for _=1,10000 do
  local birth=driver.saveState.birth
  if driver.saveState.localRestore.job==nil and driver.saveState.birthReturn==nil and not (birth and birth.returnRequested and not birth.failed) then return driver.saveState.localReturnResult end
  step()
 end
 error("local return preparation did not finish")
end
