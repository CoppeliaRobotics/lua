--lua

require('sandboxCommon')

function sysCall_init()
    sim.addLog(sim.verbosity_msgs,"Simulator launched, welcome!")
end

function sysCall_cleanup()
    sim.addLog(sim.verbosity_msgs,"Leaving...")
end

function sysCall_beforeSimulation()
    sim.addLog(sim.verbosity_msgs,"Simulation started.")
end

function sysCall_afterSimulation()
    sim.addLog(sim.verbosity_msgs,"Simulation stopped.")
    ___m=nil
end

function sysCall_sensing()
    local s=sim.getSimulationState()
    if s==sim.simulation_advancing_abouttostop and not ___m then
        sim.addLog(sim.verbosity_msgs,"simulation stopping...")
        ___m=true
    end
end

function sysCall_suspend()
    sim.addLog(sim.verbosity_msgs,"Simulation suspended.")
end

function sysCall_resume()
    sim.addLog(sim.verbosity_msgs,"Simulation resumed.")
end

function restart()
    __restart=true
end

function sysCall_nonSimulation()
    if __restart then
        return {cmd='restart'}
    end
end

function sysCall_actuation()
    if __restart then
        return {cmd='restart'}
    end
end

function sysCall_suspended()
    if __restart then
        return {cmd='restart'}
    end
end
