backCompatibility=require('defaultMainScriptBackCompatibility')
-- This is the main script. The main script is not supposed to be modified,
-- unless there is a very good reason to do it.
-- Without main script, there is no simulation.

function sysCall_init()
    sim.handleSimulationStart()
    backCompatibility.handle(0)
end

function sysCall_actuation()
    backCompatibility.handle(1)
    sim.handleChildScripts(sim.syscb_actuation)
    backCompatibility.handle(2)
    sim.handleCustomizationScripts(sim.syscb_actuation)
    sim.handleAddOnScripts(sim.syscb_actuation)
    sim.handleSandboxScript(sim.syscb_actuation)
    backCompatibility.handle(3)
    sim.handleDynamics(sim.getSimulationTimeStep())
end

function sysCall_sensing()
    sim.handleSensingStart()
    backCompatibility.handle(4)
    sim.handleProximitySensor(sim.handle_all_except_explicit)
    sim.handleVisionSensor(sim.handle_all_except_explicit)
    backCompatibility.handle(5)
    sim.handleChildScripts(sim.syscb_sensing)
    backCompatibility.handle(6)
    sim.handleCustomizationScripts(sim.syscb_sensing)
    sim.handleAddOnScripts(sim.syscb_sensing)
    sim.handleSandboxScript(sim.syscb_sensing)
    backCompatibility.handle(7)
end

function sysCall_cleanup()
    sim.handleChildScripts(sim.syscb_cleanup)
    backCompatibility.handle(8)
    sim.resetProximitySensor(sim.handle_all_except_explicit)
    sim.resetVisionSensor(sim.handle_all_except_explicit)
    backCompatibility.handle(9)
end

function sysCall_suspend()
    sim.handleChildScripts(sim.syscb_suspend)
    sim.handleCustomizationScripts(sim.syscb_suspend)
    sim.handleAddOnScripts(sim.syscb_suspend)
    sim.handleSandboxScript(sim.syscb_suspend)
end

function sysCall_suspended()
    sim.handleChildScripts(sim.syscb_suspended)
    sim.handleCustomizationScripts(sim.syscb_suspended)
    sim.handleAddOnScripts(sim.syscb_suspended)
    sim.handleSandboxScript(sim.syscb_suspended)
end

function sysCall_resume()
    sim.handleChildScripts(sim.syscb_resume)
    sim.handleCustomizationScripts(sim.syscb_resume)
    sim.handleAddOnScripts(sim.syscb_resume)
    sim.handleSandboxScript(sim.syscb_resume)
end

