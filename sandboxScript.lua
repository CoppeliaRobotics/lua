import 'sim-2'
import 'sim-2.*' -- for global 'app', 'scene', 'self', etc...
import 'utils'

if _DEVMODE then sim.app:logInfo("Developer Mode is active") end

pythonFailWarnOnly = true -- error msg can be read via sim.getNamedBoolParam("pythonSandboxInitFailMsg")

base16 = require('base16')
base64 = require('base64')

apropos = utils.apropos

require('base-ce')

local l = auxFunc('getfiles', sim.app.paths.lua, '*-ce', 'lua')
for i = 1, #l, 1 do require(string.gsub(l[i], "%.lua$", "")) end

if sim.app.customData.lastSession ~= sim.app.sessionId then
    sim.app.customData.lastSession = sim.app.sessionId
    sim.app.customData.serverPort_start = 20000
    sim.app.customData.serverPort_range = 1000
    sim.app.customData.serverPort_next = sim.app.customData.serverPort_start
end

function s_init()
    sim.app:logInfo(sim.self.language:capitalize() .. " sandbox script initialized")
    if sim.app.headlessMode == 0 then
        require('simURLDrop')
        if sim.app:getBoolProperty('signal.pythonSandboxInitFailed', {noError = true}) ~= true then
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
    if sim.scene.simulation.state == sim.simulationState.lastBeforeStop and not ___m then
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

sim.self:registerFunctionHook('sysCall_init', 's_init', {when = 'after'}) -- hook on *before* init is incompatible with implicit module load...
sim.self:registerFunctionHook('sysCall_cleanup', 's_cleanup', {when = 'after'})
sim.self:registerFunctionHook('sysCall_beforeSimulation', 's_beforeSimulation', {when = 'after'})
sim.self:registerFunctionHook('sysCall_afterSimulation', 's_afterSimulation', {when = 'after'})
sim.self:registerFunctionHook('sysCall_sensing', 's_sensing', {when = 'after'})
sim.self:registerFunctionHook('sysCall_suspend', 's_suspend', {when = 'after'})
sim.self:registerFunctionHook('sysCall_resume', 's_resume', {when = 'after'})
sim.self:registerFunctionHook('sysCall_nonSimulation', 's_nonSimulation', {when = 'after'})
sim.self:registerFunctionHook('sysCall_actuation', 's_actuation', {when = 'after'})
sim.self:registerFunctionHook('sysCall_suspended', 's_suspended', {when = 'after'})

-- convenience vars: (sel/sel1/cur/h)
do
    local mt = getmetatable(_G) or {}
    local app = rawget(_G, 'app')
    local scene = rawget(_G, 'scene')
    do
        local old_index = mt.__index
        mt.__index = function(tbl, key)
            local v
            if old_index then
                if type(old_index) == "function" then
                    v = old_index(tbl, key)
                else
                    v = rawget(old_index, key)
                end
            else
                v = rawget(tbl, key)
            end
            if v ~= nil then return v end
            if (key == 'cur' or key == 'CUR') then return app.current end
            if (key == 'sel' or key == 'SEL') then return scene.selection end
            if (key == 'sel1' or key == 'SEL1') then return scene.selection[#scene.selection] end
            if (key == 'h' or key == 'H') then return function(...) return scene:getObject(...) end end
            if key == 'pe' then return utils.pe end
        end
    end
    do
        local old_newindex = mt.__newindex
        mt.__newindex = function(tbl, key, value)
            if (key == 'cur' or key == 'CUR') then app.current = value return end
            if (key == 'sel' or key == 'SEL') then scene.selection = value return end
            if (key == 'sel1' or key == 'SEL1') then scene.selection = {value} return end
            if old_newindex then
                if type(old_newindex) == "function" then
                    return old_newindex(tbl, key, value)
                else
                    return rawset(old_newindex, key, value)
                end
            else
                return rawset(tbl, key, value)
            end
        end
    end
    setmetatable(_G, mt)
end
