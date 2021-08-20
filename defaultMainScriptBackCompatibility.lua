_S.mainScriptBackComp={}

function _S.mainScriptBackComp.handle(item)
	if item==0 then
        sim.openModule(sim.handle_all)
		sim.handleGraph(sim.handle_all_except_explicit,0)
	end
	if item==1 then
		sim.resumeThreads(sim.scriptthreadresume_default)
		sim.resumeThreads(sim.scriptthreadresume_actuation_first)
		sim.launchThreadedChildScripts()
	end
	if item==2 then
		sim.resumeThreads(sim.scriptthreadresume_actuation_last)
	end
	if item==3 then
        sim.handleModule(sim.handle_all,false)
		sim.handleIkGroup(sim.handle_all_except_explicit)
	end
	if item==4 then
		sim.handleCollision(sim.handle_all_except_explicit)
		sim.handleDistance(sim.handle_all_except_explicit)
	end
	if item==5 then
		sim.resumeThreads(sim.scriptthreadresume_sensing_first)
	end
	if item==6 then
		sim.resumeThreads(sim.scriptthreadresume_sensing_last)
	end
	if item==7 then
        sim.handleModule(sim.handle_all,true)
		sim.resumeThreads(sim.scriptthreadresume_allnotyetresumed)
		if sim.getSimulationState()~=sim.simulation_advancing_abouttostop and sim.getSimulationState()~=sim.simulation_advancing_lastbeforestop then
			sim.handleGraph(sim.handle_all_except_explicit,sim.getSimulationTime()+sim.getSimulationTimeStep())
		end
	end
	if item==8 then
		sim.resetCollision(sim.handle_all_except_explicit)
		sim.resetDistance(sim.handle_all_except_explicit)
	end
    if item==9 then
        sim.closeModule(sim.handle_all)
    end
end

return _S.mainScriptBackComp