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
    sim.app:addLog("Simulator launched, welcome! ")
    if sim.getIntProperty(sim.handle_app, 'headlessMode') == 0 then
        require('simURLDrop')
        if sim.getBoolProperty(sim.handle_app, 'signal.pythonSandboxInitFailed', {noError = true}) ~= true then
            require('pythonLuaSetupAssistant')
        end
    end
end

function s_cleanup()
    sim.app:addLog("Leaving...")
end

function s_beforeSimulation()
    sim.app:addLog("Simulation started.")
end

function s_afterSimulation()
    sim.app:addLog("Simulation stopped.")
    ___m = nil
end

function s_sensing()
    local s = sim.getSimulationState()
    if s == sim.simulation_advancing_lastbeforestop and not ___m then
        sim.app:addLog("Simulation stopping...")
        ___m = true
    end
end

function s_suspend()
    sim.app:addLog("Simulation suspended.")
end

function s_resume()
    sim.app:addLog("Simulation resumed.")
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
