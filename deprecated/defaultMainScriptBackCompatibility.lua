-- keep lazy loading
_S.mainScriptBackComp = {}

function _S.mainScriptBackComp.handle(item)
    if item == 0 then
        sim.openModule(sim.handle_all)
        sim.handleGraph(sim.handle_all_except_explicit, 0)
    end
    if item == 3 then
        sim.handleModule(sim.handle_all, false)
        auxFunc('simHandleJoint', sim.handle_all_except_explicit, sim.getSimulationTimeStep())
        auxFunc('simHandlePath', sim.handle_all_except_explicit, sim.getSimulationTimeStep())
        sim.handleIkGroup(sim.handle_all_except_explicit)
    end
    if item == 4 then
        sim.handleCollision(sim.handle_all_except_explicit)
        sim.handleDistance(sim.handle_all_except_explicit)
    end
    if item == 7 then
        sim.handleModule(sim.handle_all, true)
        if sim.getSimulationState() ~= sim.simulation_advancing_lastbeforestop then
            sim.handleGraph(
                sim.handle_all_except_explicit,
                sim.getSimulationTime() + sim.getSimulationTimeStep()
            )
        end
    end
    if item == 8 then
        sim.resetCollision(sim.handle_all_except_explicit)
        sim.resetDistance(sim.handle_all_except_explicit)
    end
    if item == 9 then sim.closeModule(sim.handle_all) end
end

return _S.mainScriptBackComp
