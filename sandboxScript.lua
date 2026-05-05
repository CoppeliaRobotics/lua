import 'sim-2'
import 'sim-2.*' -- for global 'app', 'scene', 'self'

if _DEVMODE then sim.app:logInfo("Developer Mode is active") end

pythonFailWarnOnly = true -- error msg can be read via sim.getNamedBoolParam("pythonSandboxInitFailMsg")

base16 = require('base16')
base64 = require('base64')

require('base-ce')

local l = auxFunc('getfiles', sim.app.paths.lua, '*-ce', 'lua')
for i = 1, #l, 1 do require(string.gsub(l[i], "%.lua$", "")) end

--_setupLazyLoaders() -- because those were cleared out by our explicit requires

function s_init()
    sim.app:logInfo("Simulator launched, welcome! ")
    if sim.app.headlessMode == 0 then
        require('simURLDrop')
        if sim.getBoolProperty(sim.handle_app, 'signal.pythonSandboxInitFailed', {noError = true}) ~= true then
            require('pythonLuaSetupAssistant')
        end
    end
end

function s_cleanup()
    sim.app:logInfo("Leaving...")
end

function s_beforeSimulation()
    sim.app:logInfo("Simulation started.")
end

function s_afterSimulation()
    sim.app:logInfo("Simulation stopped.")
    ___m = nil
end

function s_sensing()
    if sim.scene.simulation.state == sim.simulation_advancing_lastbeforestop and not ___m then
        sim.app:logInfo("Simulation stopping...")
        ___m = true
    end
end

function s_suspend()
    sim.app:logInfo("Simulation suspended.")
end

function s_resume()
    sim.app:logInfo("Simulation resumed.")
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

sim.self:registerFunctionHook('sysCall_init', 's_init', false) -- hook on *before* init is incompatible with implicit module load...
sim.self:registerFunctionHook('sysCall_cleanup', 's_cleanup', false)
sim.self:registerFunctionHook('sysCall_beforeSimulation', 's_beforeSimulation', false)
sim.self:registerFunctionHook('sysCall_afterSimulation', 's_afterSimulation', false)
sim.self:registerFunctionHook('sysCall_sensing', 's_sensing', false)
sim.self:registerFunctionHook('sysCall_suspend', 's_suspend', false)
sim.self:registerFunctionHook('sysCall_resume', 's_resume', false)
sim.self:registerFunctionHook('sysCall_nonSimulation', 's_nonSimulation', false)
sim.self:registerFunctionHook('sysCall_actuation', 's_actuation', false)
sim.self:registerFunctionHook('sysCall_suspended', 's_suspended', false)
