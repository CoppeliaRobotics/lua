if _DEVMODE then addLog(430, "Developer Mode is active") end

sim = require('sim-2')

pythonFailWarnOnly = true -- error msg can be read via sim.getNamedBoolParam("pythonSandboxInitFailMsg")

base16 = require('base16')
base64 = require('base64')

require('base-ce')

local l = auxFunc('getfiles', sim.getStringProperty(sim.handle_app, 'luaPath'), '*-ce', 'lua')
for i = 1, #l, 1 do require(string.gsub(l[i], "%.lua$", "")) end

--_setupLazyLoaders() -- because those were cleared out by our explicit requires

function s_init()
    sim.addLog(sim.verbosity_msgs, "Simulator launched, welcome! ")
    if sim.getIntProperty(sim.handle_app, 'headlessMode') == 0 then
        require('simURLDrop')
        if sim.getBoolProperty(sim.handle_app, 'signal.pythonSandboxInitFailed', {noError = true}) ~= true then
            require('pythonLuaSetupAssistant')
        end
    end
end

function s_cleanup()
    sim.addLog(sim.verbosity_msgs, "Leaving...")
end

function s_beforeSimulation()
    sim.addLog(sim.verbosity_msgs, "Simulation started.")
end

function s_afterSimulation()
    sim.addLog(sim.verbosity_msgs, "Simulation stopped.")
    ___m = nil
end

function s_sensing()
    local s = sim.getSimulationState()
    if s == sim.simulation_advancing_abouttostop and not ___m then
        sim.addLog(sim.verbosity_msgs, "Simulation stopping...")
        ___m = true
    end
end

function s_suspend()
    sim.addLog(sim.verbosity_msgs, "Simulation suspended.")
end

function s_resume()
    sim.addLog(sim.verbosity_msgs, "Simulation resumed.")
end

function restart()
    __restart = true
end

function s_nonSimulation()
    if __restart then return {cmd = 'restart'} end
end

function s_actuation()
    if __restart then return {cmd = 'restart'} end
end

function s_suspended()
    if __restart then return {cmd = 'restart'} end
end

sim.registerScriptFuncHook('sysCall_init', 's_init', false) -- hook on *before* init is incompatible with implicit module load...
sim.registerScriptFuncHook('sysCall_cleanup', 's_cleanup', false)
sim.registerScriptFuncHook('sysCall_beforeSimulation', 's_beforeSimulation', false)
sim.registerScriptFuncHook('sysCall_afterSimulation', 's_afterSimulation', false)
sim.registerScriptFuncHook('sysCall_sensing', 's_sensing', false)
sim.registerScriptFuncHook('sysCall_suspend', 's_suspend', false)
sim.registerScriptFuncHook('sysCall_resume', 's_resume', false)
sim.registerScriptFuncHook('sysCall_nonSimulation', 's_nonSimulation', false)
sim.registerScriptFuncHook('sysCall_actuation', 's_actuation', false)
sim.registerScriptFuncHook('sysCall_suspended', 's_suspended', false)
