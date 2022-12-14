function sysCall_init()
    self=sim.getObject'.'
    state=ObjectProxy'./State'
    speed=speed or 1
end

function sysCall_userConfig()
    if states then
        corout=coroutine.create(function()
            for i=1,#states,speed do
                state:setConfig(states[i]:data())
                sim.wait(0.001,false)
            end
        end)
    end
end

function sysCall_nonSimulation()
    if not corout then return end
    if coroutine.status(corout)~='dead' then
        local ok,errorMsg=coroutine.resume(corout)
        if errorMsg then
            error(debug.traceback(corout,errorMsg),2)
        end
    end
end

function ObjectProxy(p,t)
    t=t or sim.scripttype_customizationscript
    return sim.getScriptFunctions(sim.getScript(t,sim.getObject(p)))
end
