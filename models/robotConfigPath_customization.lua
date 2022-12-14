function sysCall_init()
    self=sim.getObject'.'
    states=sim.readCustomTableData(self,'path')
    state=ObjectProxy'./State'
    speed=speed or 1
end

function sysCall_userConfig()
    if states and not corout then
        corout=coroutine.create(function()
            local old=sim.setThreadAutomaticSwitch(false)
            sim.fastIdleLoop(true)
            for i=1,#states,speed do
                state:setConfig(states[i])
                sim.switchThread()
                sim.wait(0.001,false)
            end
            sim.fastIdleLoop(false)
            sim.setThreadAutomaticSwitch(old)
            corout=nil
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
